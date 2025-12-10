"""Public API for Helm tools - Local chart management with strongly-typed interfaces.

This module provides rules for managing local Helm charts within Bazel builds.
For Git-based charts, compose this module with git_tools.
"""

load("@helm_tools//private:implementation.bzl", "create_helm_release_targets")
load("@helm_tools//private:repository_implementation.bzl", "create_helm_repository_target")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

def _create_json_config_target(target_def):
    """Creates a JSON configuration file and helm wrapper target.
    
    This function generates a JSON config file that the Go wrapper will use
    to execute helm commands.
    
    Args:
        target_def: Target definition with configuration
    """
    # Check if chart is a Bazel label that needs expansion
    chart_is_label = target_def.config.chart.startswith(":") or target_def.config.chart.startswith("//") or target_def.config.chart.startswith("@")
    
    # Build the configuration dict
    config = {
        "type": "release",
        "command": target_def.command,
        "release_name": target_def.config.release_name,
        "chart": target_def.config.chart if not chart_is_label else "__CHART_PATH__",  # Placeholder for label expansion
        "namespace": target_def.config.namespace,
        "kube_context": target_def.config.kube_context,
    }
    
    # Add optional fields
    if hasattr(target_def, "repo_name") and target_def.repo_name:
        # Repository will be loaded from repo config file
        pass  # Will be handled with --repo-config flag
    elif target_def.config.repo_url:
        config["repo_url"] = target_def.config.repo_url
    
    if target_def.config.chart_version:
        config["version"] = target_def.config.chart_version
    
    if target_def.config.timeout:
        config["timeout"] = target_def.config.timeout
    
    # Don't add values_file to config - it will be handled separately
    
    # Add flags
    flags = []
    if hasattr(target_def, "helm_args") and target_def.helm_args:
        flags.extend(target_def.helm_args.split(" "))
    if flags:
        config["flags"] = flags
    
    # Create the config file
    config_name = target_def.name + "_config"
    write_file(
        name = config_name,
        out = target_def.name + "_config.json",
        content = [json.encode(config)],
    )
    
    # Build data dependencies
    data_deps = [
        "@helm_binary//:helm",
        ":" + config_name,
    ]
    
    # If chart is a Bazel label, add it to data deps and pass as argument
    if chart_is_label:
        data_deps.append(target_def.config.chart)
    
    # Build args for the wrapper
    wrapper_args = [
        "--config", "$(location :{})".format(config_name),
        "--helm", "$(location @helm_binary//:helm)",
    ]
    
    # If chart is a Bazel label, pass the expanded path
    if chart_is_label:
        # Handle both single files (like archives) and filegroups
        # For archives (.tar.gz), pass the file directly
        # For directories/filegroups, extract the directory path
        if target_def.config.chart.endswith(".tar.gz") or target_def.config.chart.endswith(":archive"):
            # Direct file reference (archive)
            wrapper_args.extend([
                "--chart", "$(location {})".format(target_def.config.chart),
            ])
        else:
            # For filegroups containing chart directories, extract the directory path
            wrapper_args.extend([
                "--chart", "$$(dirname $$(echo $(locations {}) | cut -d' ' -f1))".format(target_def.config.chart),
            ])
    
    # Add repository config if using repo_name
    if hasattr(target_def, "repo_name") and target_def.repo_name:
        # Depend on the repository stamp file to ensure it's added
        data_deps.append(target_def.repo_name)  # This is the genrule output
        data_deps.append("{}_config".format(target_def.repo_name))
        wrapper_args.extend([
            "--repo-config", "$(location {}_config)".format(target_def.repo_name),
        ])
    
    if hasattr(target_def, "values_file") and target_def.values_file:
        data_deps.append(target_def.values_file)
        wrapper_args.extend([
            "--values", "$(location {})".format(target_def.values_file),
        ])

    # Merge default tags with user-provided tags
    default_tags = ["local", "no-remote", "no-cache"]
    merged_tags = list(default_tags + (target_def.tags if target_def.tags else []))

    # Create the sh_binary using Go wrapper
    sh_binary(
        name = target_def.name,
        srcs = ["@helm_tools//:helm_wrapper"],
        args = wrapper_args,
        data = data_deps,
        visibility = target_def.visibility,
        tags = merged_tags,
        **target_def.kwargs
    )

def helm_repository(
        name,
        url,
        ca_file = None,
        cert_file = None,
        force_update = False,
        insecure_skip_tls_verify = False,
        no_update = False,
        password = None,
        username = None,
        visibility = None,
        tags = None,
        **kwargs):
    """Creates a Helm repository target that adds a repository to Helm.

    This rule generates a target that runs 'helm repo add' with the specified
    repository URL and authentication options. The repository name is automatically
    generated from the URL by stripping the protocol and replacing non-alphanumeric
    characters with underscores.

    Note: OCI repositories (oci://) don't need to be added and should be used
    directly in helm_release with repo_url parameter.

    Generated output:
    - {name}: Target that adds the repository
    - Output file: A marker file named after the generated repository name

    Example:
        helm_repository(
            name = "prometheus_repo",
            url = "https://prometheus-community.github.io/helm-charts",
        )

        helm_release(
            name = "prometheus",
            chart = "kube-prometheus-stack",
            repo_name = ":prometheus_repo",  # Reference the repository
            namespace = "monitoring",
        )

    Example with authentication:
        helm_repository(
            name = "private_repo",
            url = "https://charts.example.com",
            username = "myuser",
            password = "mypass",
            ca_file = ":ca-bundle.pem",
        )

    Args:
        name: Base name for generated target
        url: Repository URL (required)
        ca_file: CA bundle file to verify certificates (optional)
        cert_file: Client certificate file for authentication (optional)
        force_update: Force repository update even if already exists (bool)
        insecure_skip_tls_verify: Skip TLS certificate verification (bool)
        no_update: Skip repository update after adding (bool)
        password: Repository password (optional)
        username: Repository username (optional)
        visibility: Target visibility
        tags: Additional tags for target
        **kwargs: Additional arguments passed to sh_binary rule
    """
    # Create repository target using implementation
    result = create_helm_repository_target(
        name = name,
        url = url,
        ca_file = ca_file,
        cert_file = cert_file,
        force_update = force_update,
        insecure_skip_tls_verify = insecure_skip_tls_verify,
        no_update = no_update,
        password = password,
        username = username,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )

    # Handle errors from implementation
    if result.error:
        fail(result.error)

    # Merge default tags with user-provided tags
    default_tags = ["local", "no-remote", "no-cache"]
    merged_tags = list(default_tags + (tags if tags else []))

    # Create a stamp file to mark this repository as configured
    # The actual helm repo add will be run by helm_wrapper when needed
    write_file(
        name = name,
        out = name + ".stamp",
        content = ["# Helm repository: {} -> {}\n".format(result.repo_name, url)],
        visibility = visibility,
        tags = merged_tags,
        **kwargs
    )
    
    # Create the config file with all repository details
    config_name = name + "_config"
    repo_config = {
        "type": "repository",
        "repo_name": result.repo_name,
        "url": url,
    }
    
    # Add optional authentication and TLS settings
    if ca_file:
        repo_config["ca_file"] = ca_file
    if cert_file:
        repo_config["cert_file"] = cert_file
    if username:
        repo_config["username"] = username
    if password:
        repo_config["password"] = password
    if force_update:
        repo_config["force_update"] = force_update
    if insecure_skip_tls_verify:
        repo_config["insecure_skip_tls_verify"] = insecure_skip_tls_verify
    if no_update:
        repo_config["no_update"] = no_update
    
    write_file(
        name = config_name,
        out = name + "_config.json",
        content = [json.encode(repo_config)],
    )

def helm_release(
        name,
        chart,
        chart_path = None,
        values_file = None,
        namespace = "default",
        create_namespace = True,
        release_name = None,
        wait = True,
        timeout = "10m",
        atomic = False,
        force = False,
        repo_url = None,
        repo_name = None,
        chart_version = None,
        kube_context = None,
        visibility = None,
        tags = None,
        **kwargs):
    """Creates targets for managing a Helm release with strongly-typed validation.

    This macro generates five targets for managing Helm charts following
    functional programming principles. The chart can be from:
    1. A Helm repository - chart name from a public or OCI repository
    2. A local chart - path to a chart directory in your repository
    3. An archive from git_tools - tar.gz file containing the repository
    4. A pre-added repository - using repo_name parameter

    Generated targets:
    - {name}_install: Installs the Helm chart
    - {name}_upgrade: Upgrades the Helm chart
    - {name}_uninstall: Uninstalls the Helm chart
    - {name}_status: Checks release status
    - {name}_values: Gets release values

    Example (repository chart - most common):
        helm_release(
            name = "prometheus",
            chart = "kube-prometheus-stack",  # Chart name from repository
            repo_url = "https://prometheus-community.github.io/helm-charts",
            chart_version = "51.3.0",
            namespace = "monitoring",
            kube_context = "prod-cluster",
            values_file = ":prometheus-values.yaml",
        )

    Example (using helm_repository):
        helm_repository(
            name = "prometheus_repo",
            url = "https://prometheus-community.github.io/helm-charts",
        )

        helm_release(
            name = "prometheus",
            chart = "kube-prometheus-stack",
            repo_name = ":prometheus_repo",  # Reference the repository target
            chart_version = "51.3.0",
            namespace = "monitoring",
            kube_context = "prod-cluster",
        )

    Example (OCI registry):
        helm_release(
            name = "my_chart",
            chart = "my-app",
            repo_url = "oci://ghcr.io/organization/charts",
            chart_version = "1.0.0",
            namespace = "default",
            kube_context = "staging-cluster",
        )

    Example (local chart):
        helm_release(
            name = "my_app",
            chart = "//charts/my-app",  # Local chart directory
            namespace = "production",
            kube_context = "prod-cluster",
            values_file = ":values.yaml",
        )

    Example (with git_tools for Git-based chart):
        # If Chart.yaml is in a subdirectory, use sparse_paths:
        git_repository(
            name = "cilium_repo",
            url = "https://github.com/cilium/cilium.git",
            branch = "main",
            sparse_paths = ["install/kubernetes/cilium"],  # Chart.yaml will be at archive root!
        )

        helm_release(
            name = "cilium",
            chart = ":cilium_repo",  # Archive with Chart.yaml at root
            namespace = "kube-system",
            kube_context = "prod-cluster",
        )

        # If Chart.yaml is at repository root, just clone normally:
        git_repository(
            name = "my_chart",
            url = "https://github.com/org/helm-chart.git",
            branch = "main",
        )

        helm_release(
            name = "my_app",
            chart = ":my_chart",
            namespace = "default",
            kube_context = "staging-cluster",
        )

    Args:
        name: Base name for generated targets (validated)
        chart: Chart name (for repository), local path, or archive from git_tools
        chart_path: Path to chart within archive (reserved for future use)
        values_file: Label of values YAML file (optional)
        namespace: Kubernetes namespace (default: "default", validated)
        create_namespace: Whether to create namespace if missing (bool)
        release_name: Helm release name (defaults to name, validated)
        wait: Wait for release to be ready (bool)
        timeout: Timeout for operations (validated format, e.g. "10m", "1h")
        atomic: Rollback on failure (bool)
        force: Force resource updates through recreate/replace (bool)
        repo_url: Repository URL for Helm charts (optional, e.g. "https://charts.bitnami.com/bitnami")
        repo_name: Reference to helm_repository target (optional, mutually exclusive with repo_url)
        chart_version: Specific chart version to install (optional, defaults to latest)
        kube_context: Kubernetes context name (REQUIRED) - The kubectl context to use for all operations
        visibility: Target visibility
        tags: Additional tags for targets
        **kwargs: Additional arguments passed to sh_binary rules
    """
    release_name = release_name or name

    # Delegate to implementation module (functional approach)
    result = create_helm_release_targets(
        name = name,
        chart = chart,
        chart_path = chart_path,
        values_file = values_file,
        namespace = namespace,
        create_namespace = create_namespace,
        release_name = release_name,
        wait = wait,
        timeout = timeout,
        atomic = atomic,
        force = force,
        repo_url = repo_url,
        repo_name = repo_name,
        chart_version = chart_version,
        kube_context = kube_context,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )

    # Handle errors from implementation
    if result.error:
        fail(result.error)

    # Create targets from definitions
    for target_def in result.targets:
        if target_def.type == "sh_binary_with_wrapper":
            # Use JSON config with Go wrapper for repo_name cases
            _create_json_config_target(
                target_def = target_def,
            )
        else:
            # For non-repo_name cases, also use JSON config
            _create_json_config_target(
                target_def = target_def,
            )
