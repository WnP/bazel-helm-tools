"""Implementation for Helm repository management following functional programming principles.

All functions are pure with no side effects and return immutable data structures.
"""

load(":utils.bzl", "aggregate_validation_errors", "join_errors")
load(":validation.bzl", "validate_repository_url")

def generate_repository_name(url):
    """Generates a consistent repository name from URL.
    
    Pure function that converts a URL to a valid repository name by:
    - Returning empty string for OCI repositories (they don't need to be added)
    - Stripping http:// or https:// prefix
    - Replacing all non-alphanumeric characters with underscores
    
    Args:
        url: Repository URL
        
    Returns:
        Generated repository name string, or empty string for OCI repositories
    """
    if not url:
        return ""
    
    # OCI repositories don't need to be added, they're used directly
    if url.startswith("oci://"):
        return ""
    
    # Remove common URL prefixes
    prefixes = ("https://", "http://")
    clean_url = url
    for prefix in prefixes:
        if clean_url.startswith(prefix):
            clean_url = clean_url[len(prefix):]
            break
    
    # Replace non-alphanumeric characters with underscores
    result = []
    for i in range(len(clean_url)):
        char = clean_url[i]
        if char.isalnum():
            result.append(char)
        else:
            result.append("_")
    
    return "".join(result)

def create_helm_repository_target(
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
        kwargs = None):
    """Creates Helm repository add target using pure functional approach.
    
    This is a pure function that returns a struct describing the target to create.
    No side effects or mutations occur within this function.
    
    Note: OCI repositories (oci://) don't require adding and will return an error.
    
    Args:
        name: Base name for target
        url: Repository URL
        ca_file: CA bundle file to verify certificates (optional)
        cert_file: Identify client using this certificate file (optional)
        force_update: Force update of repository (bool)
        insecure_skip_tls_verify: Skip TLS certificate checks (bool)
        no_update: Skip running update after adding repository (bool)
        password: Chart repository password (optional)
        username: Chart repository username (optional)
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments
        
    Returns:
        Struct containing target definition and output info (immutable)
    """
    
    # Validate URL
    url_validation = validate_repository_url(url)
    if not url_validation[0]:
        return struct(
            error = url_validation[1],
            target = None,
            output_file = None,
        )
    
    # Check if it's an OCI repository
    if url.startswith("oci://"):
        return struct(
            error = "OCI repositories don't need to be added with 'helm repo add'. Use them directly in helm_release.",
            target = None,
            output_file = None,
        )
    
    # Generate repository name from URL
    repo_name = generate_repository_name(url)
    if not repo_name:
        return struct(
            error = "Failed to generate repository name from URL",
            target = None,
            output_file = None,
        )
    
    # Build Helm command arguments
    helm_args = _build_repository_arguments(
        repo_name = repo_name,
        url = url,
        ca_file = ca_file,
        cert_file = cert_file,
        force_update = force_update,
        insecure_skip_tls_verify = insecure_skip_tls_verify,
        no_update = no_update,
        password = password,
        username = username,
    )
    
    # Create target definition
    target = _create_repository_add_target(
        name = name,
        helm_args = helm_args,
        output_file = repo_name,
        ca_file = ca_file,
        cert_file = cert_file,
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
    )
    
    return struct(
        error = None,
        target = target,
        output_file = repo_name,
        repo_name = repo_name,
    )

def _build_repository_arguments(
        repo_name,
        url,
        ca_file,
        cert_file,
        force_update,
        insecure_skip_tls_verify,
        no_update,
        password,
        username):
    """Builds Helm repo add command arguments functionally.
    
    Pure function that constructs arguments without mutations.
    
    Args:
        repo_name: Generated repository name
        url: Repository URL
        ca_file: CA bundle file (optional)
        cert_file: Client certificate file (optional)
        force_update: Whether to force update
        insecure_skip_tls_verify: Whether to skip TLS verification
        no_update: Whether to skip update
        password: Repository password (optional)
        username: Repository username (optional)
        
    Returns:
        Tuple of command arguments (immutable)
    """
    # Start with base command
    args = ["repo", "add", repo_name, url]
    
    # Build optional arguments functionally
    optional_args = [
        ("--ca-file", "$(location {})".format(ca_file)) if ca_file else None,
        ("--cert-file", "$(location {})".format(cert_file)) if cert_file else None,
        ("--force-update",) if force_update else None,
        ("--insecure-skip-tls-verify",) if insecure_skip_tls_verify else None,
        ("--no-update",) if no_update else None,
        ("--password", password) if password else None,
        ("--username", username) if username else None,
    ]
    
    # Flatten optional arguments (filter None values and extend)
    for arg_tuple in optional_args:
        if arg_tuple:
            args.extend(arg_tuple)
    
    # Add output redirection to create marker file
    args.extend(["&&", "touch", "$@"])
    
    return tuple(args)

def _create_repository_add_target(
        name,
        helm_args,
        output_file,
        ca_file,
        cert_file,
        visibility,
        tags,
        kwargs):
    """Creates repository add target definition.
    
    Args:
        name: Base name for target
        helm_args: Helm command arguments tuple
        output_file: Output file name (repository name)
        ca_file: CA bundle file (optional)
        cert_file: Client certificate file (optional)
        visibility: Target visibility
        tags: Target tags
        kwargs: Additional arguments
        
    Returns:
        Target definition struct (immutable)
    """
    # Build data dependencies
    data_deps = []
    if ca_file:
        data_deps.append(ca_file)
    if cert_file:
        data_deps.append(cert_file)
    
    return struct(
        name = name,
        type = "sh_binary",
        srcs = ["@helm_binary//:helm"],
        args = helm_args,
        data = tuple(data_deps),
        visibility = visibility,
        tags = tags,
        kwargs = kwargs,
        output_file = output_file,
    )

# Export functions for testing
testable = struct(
    generate_repository_name = generate_repository_name,
    build_repository_arguments = _build_repository_arguments,
    create_repository_add_target = _create_repository_add_target,
)