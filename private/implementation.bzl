"""Core implementation for Helm tools following functional programming principles.

All functions are pure with no side effects and return immutable data structures.
"""

load(":utils.bzl", "aggregate_validation_errors", "is_bazel_label", "join_errors")
load(":validation.bzl", "validate_chart_name", "validate_helm_release_name", "validate_namespace", "validate_repo_url_direct", "validate_repository_configuration", "validate_timeout")

def create_helm_release_targets(
        name,
        chart,
        chart_path = None,
        values_file = None,
        namespace = 'default',
        create_namespace = False,
        release_name = None,
        wait = False,
        timeout = None,
        atomic = False,
        force = False,
        repo_url = None,
        repo_name = None,
        chart_version = None,
        visibility = None,
        tags = None,
        kwargs = None):
    """Creates all Helm release targets using pure functional approach.

    This is a pure function that returns a struct describing the targets to create.
    No side effects or mutations occur within this function.

    Args:
        name: Base name for targets
        chart: Chart name (for repository), local path, or archive
        chart_path: Path to chart within archive (optional)
        values_file: Values file label
        namespace: Kubernetes namespace
        create_namespace: Whether to create namespace
        release_name: Helm release name
        wait: Whether to wait
        timeout: Operation timeout
        atomic: Whether to use atomic operations
        force: Whether to force updates
        repo_url: Repository URL (optional, for repository charts)
        repo_name: Reference to helm_repository target (optional, mutually exclusive with repo_url)
        chart_version: Chart version (optional, for repository charts)
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments

    Returns:
        Struct containing target definitions (immutable)
    """

    # Validate that repo_url and repo_name are mutually exclusive
    if repo_url and repo_name:
        return struct(
            error = "Cannot specify both repo_url and repo_name. Use repo_url for direct repository URLs or repo_name to reference a helm_repository target.",
            targets = None,
        )

    # Validate inputs (pure functions, no mutations)
    validations = _validate_inputs(release_name, namespace, timeout, chart, repo_url, repo_name, chart_version)
    if not validations.valid:
        return struct(
            error = validations.error,
            targets = None,
        )

    # Build immutable configuration
    config = _build_configuration(
        release_name = release_name,
        namespace = namespace,
        chart = chart,
        timeout = timeout,
        repo_url = repo_url,
        repo_name = repo_name,
        chart_version = chart_version,
    )

    # Build Helm arguments
    helm_args_list = []
    if create_namespace:
        helm_args_list.append("--create-namespace")
    if wait:
        helm_args_list.append("--wait")
    if atomic:
        helm_args_list.append("--atomic")
    if force:
        helm_args_list.append("--force")
    helm_args = " ".join(helm_args_list)

    # Create target definitions (immutable struct)
    targets = _create_target_definitions(
        name = name,
        config = config,
        helm_args = helm_args,
        values_file = values_file,
        repo_name = repo_name,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )

    return struct(
        error = None,
        targets = targets,
    )

def _validate_inputs(release_name, namespace, timeout, chart, repo_url, repo_name, chart_version):
    """Validates inputs using pure functions.

    Args:
        release_name: Release name to validate
        namespace: Namespace to validate
        timeout: Timeout to validate
        chart: Chart name or path to validate
        repo_url: Repository URL to validate (optional)
        repo_name: Repository name reference (optional)
        chart_version: Chart version to validate (optional)

    Returns:
        Struct with validation results (immutable)
    """

    # Collect all validation results
    validations = [
        validate_helm_release_name(release_name),
        validate_namespace(namespace),
        validate_timeout(timeout),
    ]

    # Validate chart name only if using repository and chart is not a Bazel label
    # Bazel labels (like :target or //path:target) are archives/paths, not chart names
    if (repo_url or repo_name) and not is_bazel_label(chart):
        validations.append(validate_chart_name(chart))

    # Validate repository configuration
    if repo_url:
        # Validate that repo_url can be used directly (only OCI or file URLs)
        validations.append(validate_repo_url_direct(repo_url))
    
    validations.append(validate_repository_configuration(repo_url, chart_version))

    # Aggregate errors
    all_valid, errors = aggregate_validation_errors(validations)

    return struct(
        valid = all_valid,
        error = join_errors(errors),
    )

def _build_configuration(release_name, namespace, chart, timeout, repo_url, repo_name, chart_version):
    """Builds immutable configuration struct.

    Pure function that creates configuration without side effects.

    Args:
        release_name: Helm release name
        namespace: Kubernetes namespace
        chart: Chart name or path
        timeout: Operation timeout
        repo_url: Repository URL (optional)
        repo_name: Repository name reference (optional)
        chart_version: Chart version (optional)

    Returns:
        Immutable configuration struct
    """
    # Determine the actual repository name if repo_name is provided
    resolved_repo_name = ""
    if repo_name:
        # If repo_name is a label, extract the repository name from it
        # For now, we'll pass it through and handle it in the command building
        resolved_repo_name = repo_name
    
    return struct(
        release_name = release_name,
        namespace = namespace,
        chart = chart,
        timeout = timeout,
        repo_url = repo_url or "",
        repo_name = resolved_repo_name,
        chart_version = chart_version or "",
        is_repository_chart = bool(repo_url or repo_name),
    )





def _create_install_target(name, config, helm_args, values_file, repo_name, visibility, tags, kwargs):
    """Creates install target definition.

    Args:
        name: Base name for target
        config: Configuration struct
        helm_args: Helm arguments string
        values_file: Values file label
        repo_name: Repository target reference (optional)
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments

    Returns:
        Target definition struct (immutable)
    """
    # All targets now use JSON config with Go wrapper
    return struct(
        name = name + "_install",
        type = "sh_binary_with_wrapper",  # All use wrapper now
        repo_name = repo_name,
        command = "install",
        config = config,
        helm_args = helm_args,
        values_file = values_file,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )

def _create_upgrade_target(name, config, helm_args, values_file, repo_name, visibility, tags, kwargs):
    """Creates upgrade target definition.

    Args:
        name: Base name for target
        config: Configuration struct
        helm_args: Helm arguments string
        values_file: Values file label
        repo_name: Repository target reference (optional)
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments

    Returns:
        Target definition struct (immutable)
    """
    # All targets now use JSON config with Go wrapper
    return struct(
        name = name + "_upgrade",
        type = "sh_binary_with_wrapper",  # All use wrapper now
        repo_name = repo_name,
        command = "upgrade",
        config = config,
        helm_args = helm_args,
        values_file = values_file,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )

def _create_uninstall_target(name, config, visibility, tags, kwargs):
    """Creates uninstall target definition.

    Args:
        name: Base name for target
        config: Configuration struct
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments

    Returns:
        Target definition struct (immutable)
    """
    return struct(
        name = name + "_uninstall",
        type = "sh_binary_with_wrapper",
        command = "uninstall",
        config = config,
        helm_args = "",
        values_file = None,
        repo_name = None,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )

def _create_status_target(name, config, visibility, tags, kwargs):
    """Creates status target definition.

    Args:
        name: Base name for target
        config: Configuration struct
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments

    Returns:
        Target definition struct (immutable)
    """
    return struct(
        name = name + "_status",
        type = "sh_binary_with_wrapper",
        command = "status",
        config = config,
        helm_args = "",
        values_file = None,
        repo_name = None,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )

def _create_values_target(name, config, visibility, tags, kwargs):
    """Creates values target definition.

    Args:
        name: Base name for target
        config: Configuration struct
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments

    Returns:
        Target definition struct (immutable)
    """
    return struct(
        name = name + "_values",
        type = "sh_binary_with_wrapper",
        command = "get",
        config = config,
        helm_args = "",
        values_file = None,
        repo_name = None,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )

def _create_target_definitions(
        name,
        config,
        helm_args,
        values_file,
        repo_name,
        visibility,
        tags,
        kwargs):
    """Creates target definitions using immutable structures.

    Pure function that returns target specifications using focused helper functions.

    Args:
        name: Base name for targets
        config: Configuration struct
        helm_args: Helm arguments string
        values_file: Values file label
        repo_name: Repository target reference (optional)
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments

    Returns:
        Tuple of target definitions (immutable)
    """
    return (
        _create_install_target(name, config, helm_args, values_file, repo_name, visibility, tags, kwargs),
        _create_upgrade_target(name, config, helm_args, values_file, repo_name, visibility, tags, kwargs),
        _create_uninstall_target(name, config, visibility, tags, kwargs),
        _create_status_target(name, config, visibility, tags, kwargs),
        _create_values_target(name, config, visibility, tags, kwargs),
    )

# Export internal functions for testing
testable = struct(
    validate_inputs = _validate_inputs,
    build_configuration = _build_configuration,
    create_target_definitions = _create_target_definitions,
)
