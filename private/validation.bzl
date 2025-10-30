"""Pure validation functions for Helm configuration.

All functions follow functional programming principles:
- Pure functions with no side effects
- Return (is_valid, error_message) tuples
- Immutable inputs and outputs
"""

load(
    ":utils.bzl",
    "aggregate_validation_errors",
    "check_empty",
    "check_first_character",
    "check_last_character",
    "check_string_length",
    "format_error_message",
    "is_alphanumeric_hyphen_or_underscore",
    "is_alphanumeric_or_hyphen",
    "is_bazel_label",
    "is_lowercase_letter",
    "starts_with_any",
    "validate_characters",
    "validate_numeric_part",
)

def validate_semantic_version(version):
    """Validates semantic version format.

    Pure function that checks if a version string follows semantic versioning.

    Args:
        version: Version string to validate

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    is_valid, error = check_empty(version, "version")
    if not is_valid:
        return (False, error)

    # Remove 'v' prefix if present
    if version.startswith("v"):
        version = version[1:]

    parts = version.split(".")
    if len(parts) != 3:
        return (False, format_error_message(
            "version",
            "must have exactly 3 parts (major.minor.patch)",
        ))

    for i in range(len(parts)):
        part = parts[i]
        is_valid, error = validate_numeric_part(part, 0, len(part))
        if not is_valid:
            return (False, format_error_message(
                "version part '{}'".format(part),
                "contains non-digit characters",
            ))

    return (True, None)

def validate_helm_release_name(name):
    """Validates Helm release name.

    Pure function that checks if a release name follows Helm naming conventions.

    Args:
        name: Release name to validate

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    # Check empty
    is_valid, error = check_empty(name, "release name")
    if not is_valid:
        return (False, error)

    # Check length
    is_valid, error = check_string_length(name, "release name", 53)
    if not is_valid:
        return (False, error)

    # Check first character
    is_valid, error = check_first_character(
        name,
        "release name",
        "a lowercase letter",
        is_lowercase_letter,
    )
    if not is_valid:
        return (False, error)

    # Check all characters are lowercase alphanumeric or hyphen
    for i in range(len(name)):
        char = name[i]
        if not is_alphanumeric_or_hyphen(char):
            return (False, format_error_message(
                "release name",
                "can only contain lowercase letters, numbers, and hyphens",
            ))
        if char.isupper():
            return (False, format_error_message(
                "release name",
                "must be lowercase",
            ))

    # Check last character
    is_valid, error = check_last_character(
        name,
        "release name",
        "a hyphen",
        lambda c: c == "-",
    )
    if not is_valid:
        return (False, error)

    return (True, None)

def validate_namespace(namespace):
    """Validates Kubernetes namespace name.

    Pure function that checks if a namespace follows Kubernetes naming conventions.

    Args:
        namespace: Namespace to validate

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    # Check empty
    is_valid, error = check_empty(namespace, "namespace")
    if not is_valid:
        return (False, error)

    # Check length
    is_valid, error = check_string_length(namespace, "namespace", 63)
    if not is_valid:
        return (False, error)

    # Check characters
    is_valid, error = validate_characters(
        namespace,
        "namespace",
        "alphanumeric characters and hyphens",
        is_alphanumeric_or_hyphen,
    )
    if not is_valid:
        return (False, error)

    # Check first character
    is_valid, error = check_first_character(
        namespace,
        "namespace",
        "an alphanumeric character",
        lambda c: c.isalnum(),
    )
    if not is_valid:
        return (False, error)

    # Check last character
    is_valid, error = check_last_character(
        namespace,
        "namespace",
        "a non-alphanumeric character",
        lambda c: not c.isalnum(),
    )
    if not is_valid:
        return (False, error)

    return (True, None)

def _validate_bazel_target_name(name, field_description):
    """Validates Bazel target name.

    Pure function that checks if a Bazel target name follows naming conventions.

    Args:
        name: Target name to validate
        field_description: Description for error messages

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    if not name:
        return (False, format_error_message(field_description, "cannot be empty"))

    # Labels like ":" and "//" are invalid - they need actual target names
    if name == ":" or name == "//":
        return (False, format_error_message(field_description, "must specify a target name"))

    # Bazel target names can contain alphanumeric, hyphen, underscore, dot, slash, colon, and @
    has_alphanumeric = False
    for i in range(len(name)):
        char = name[i]
        if char.isalnum():
            has_alphanumeric = True
        if not (char.isalnum() or char == "-" or char == "_" or char == "." or char == "/" or char == ":" or char == "@"):
            return (False, format_error_message(
                field_description,
                "can only contain alphanumeric, hyphen, underscore, dot, slash, colon, and @ characters",
            ))

    if not has_alphanumeric:
        return (False, format_error_message(field_description, "must contain at least one alphanumeric character"))

    return (True, None)

def validate_chart_name(name):
    """Validates Helm chart name or Bazel label.

    Pure function that checks if a chart name is valid. Recognizes both
    repository chart names and Bazel labels.

    Args:
        name: Chart name or Bazel label to validate

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    # Check empty
    is_valid, error = check_empty(name, "chart name")
    if not is_valid:
        return (False, error)

    # If it's a Bazel label, validate as a Bazel target
    if is_bazel_label(name):
        return _validate_bazel_target_name(name, "chart name")

    # Otherwise, validate as a repository chart name
    return _validate_repository_chart_name(name)

def _validate_repository_chart_name(name):
    """Validates repository chart name format.

    Pure function that validates traditional Helm repository chart names.

    Args:
        name: Repository chart name to validate

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    # Chart names can contain organization prefix
    parts = name.split("/")
    if len(parts) > 2:
        return (False, format_error_message(
            "chart name",
            "can only have one '/' separator",
        ))

    for part in parts:
        if not part:
            return (False, format_error_message(
                "chart name parts",
                "cannot be empty",
            ))

        # Each part should follow similar rules to release names
        for i in range(len(part)):
            char = part[i]
            if not (char.isalnum() or char == "-" or char == "_" or char == "."):
                return (False, format_error_message(
                    "chart name",
                    "can only contain alphanumeric, hyphen, underscore, and dot characters",
                ))

    return (True, None)

def validate_timeout(timeout):
    """Validates timeout format.

    Pure function that checks if a timeout string is valid.

    Args:
        timeout: Timeout string (e.g., "10m", "1h", "300s")

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    # Check empty
    is_valid, error = check_empty(timeout, "timeout")
    if not is_valid:
        return (False, error)

    # Check if last character is a valid unit
    unit = timeout[len(timeout) - 1]
    if unit not in ["s", "m", "h"]:
        return (False, format_error_message(
            "timeout",
            "must end with 's' (seconds), 'm' (minutes), or 'h' (hours)",
        ))

    # Check if everything before the unit is a number
    number_part = timeout[:len(timeout) - 1]
    if not number_part:
        return (False, format_error_message(
            "timeout",
            "must have a numeric value",
        ))

    is_valid, error = validate_numeric_part(number_part, 0, len(number_part))
    if not is_valid:
        return (False, format_error_message(
            "timeout value",
            "must be numeric",
        ))

    return (True, None)

def validate_repository_url(url):
    """Validates Helm repository URL.

    Pure function that checks if a repository URL is valid.
    Note: HTTP/HTTPS URLs are only valid when used with helm_repository macro,
    not with repo_url parameter directly.

    Args:
        url: Repository URL to validate

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    # Check empty
    is_valid, error = check_empty(url, "repository URL")
    if not is_valid:
        return (False, error)

    # Check for common URL schemes
    valid_schemes = ("http://", "https://", "oci://", "file://")
    if not starts_with_any(url, valid_schemes):
        return (False, format_error_message(
            "repository URL",
            "must start with http://, https://, oci://, or file://",
        ))

    return (True, None)

def validate_repo_url_direct(url):
    """Validates repository URL for direct use with repo_url parameter.

    Pure function that checks if a repository URL can be used directly
    with repo_url parameter (only OCI and file URLs are supported).

    Args:
        url: Repository URL to validate for direct use

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    # Check empty
    is_valid, error = check_empty(url, "repo_url")
    if not is_valid:
        return (False, error)

    # Only OCI and file URLs can be used directly with repo_url
    if url.startswith("http://") or url.startswith("https://"):
        return (False, format_error_message(
            "repo_url",
            "cannot use HTTP/HTTPS URLs directly. Use helm_repository() macro to define the repository, then reference it with repo_name parameter",
        ))

    # Check for valid direct schemes
    valid_direct_schemes = ("oci://", "file://")
    if not starts_with_any(url, valid_direct_schemes):
        return (False, format_error_message(
            "repo_url",
            "must start with oci:// or file:// for direct use. For HTTP/HTTPS repositories, use helm_repository() macro",
        ))

    return (True, None)

def validate_chart_version(version):
    """Validates chart version string.

    Pure function that checks if a chart version is valid.
    Can be semantic version or other version formats used by Helm.

    Args:
        version: Version string to validate

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    if not version:
        # Empty version is valid (means latest)
        return (True, None)

    # Allow any non-empty string as Helm supports various version formats
    # including semantic versions, dates, commit hashes, etc.
    return (True, None)

def validate_repository_configuration(repo_url, chart_version):
    """Validates complete repository configuration.

    Pure function that validates all repository-related parameters.

    Args:
        repo_url: Repository URL (optional)
        chart_version: Chart version (optional)

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """

    # If repo_url is provided, validate it
    if repo_url:
        url_valid, url_error = validate_repository_url(repo_url)
        if not url_valid:
            return (False, url_error)

    # Validate chart version if provided
    if chart_version:
        version_valid, version_error = validate_chart_version(chart_version)
        if not version_valid:
            return (False, version_error)

    return (True, None)
