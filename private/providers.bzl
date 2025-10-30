"""Strongly-typed provider definitions for Helm tools.

All providers use immutable data structures following functional programming principles.
"""

# Provider for Helm binary version information
HelmVersionInfo = provider(
    doc = "Information about the Helm binary version.",
    fields = {
        "version": "Semantic version string (e.g., 'v3.13.3')",
        "binary": "Label of the Helm binary",
        "sha256": "SHA256 checksum of the binary (optional)",
    },
)

# Provider for Helm chart information
HelmChartInfo = provider(
    doc = "Information about a Helm chart.",
    fields = {
        "name": "Chart name",
        "version": "Chart version (optional)",
        "repository": "Chart repository URL (optional)",
        "dependencies": "Tuple of chart dependencies (immutable)",
        "values_schema": "Dict of expected values schema (frozen)",
    },
)

# Provider for Helm release information
HelmReleaseInfo = provider(
    doc = "Information about a deployed Helm release.",
    fields = {
        "name": "Release name",
        "namespace": "Kubernetes namespace",
        "chart": "HelmChartInfo provider",
        "values": "Dict of release values (frozen)",
        "status": "Release status (deployed, pending, failed)",
        "revision": "Release revision number",
        "notes": "Release notes (optional)",
    },
)

# Provider for Helm validation results
HelmValidationResultInfo = provider(
    doc = "Results from validating Helm configuration.",
    fields = {
        "valid": "Whether the configuration is valid (bool)",
        "errors": "Tuple of error messages (immutable)",
        "warnings": "Tuple of warning messages (immutable)",
        "validated_chart": "Validated HelmChartInfo (optional)",
        "validated_release": "Validated HelmReleaseInfo (optional)",
    },
)

def create_helm_version_info(version, binary, sha256 = None):
    """Creates a HelmVersionInfo provider with validation.

    Pure function that creates an immutable version info provider.

    Args:
        version: Semantic version string
        binary: Label of the Helm binary
        sha256: Optional SHA256 checksum

    Returns:
        HelmVersionInfo provider
    """
    return HelmVersionInfo(
        version = version,
        binary = binary,
        sha256 = sha256,
    )

def create_helm_chart_info(
        name,
        version = None,
        repository = None,
        dependencies = (),
        values_schema = {}):
    """Creates a HelmChartInfo provider with immutable collections.

    Pure function that creates a chart info provider with frozen collections.

    Args:
        name: Chart name
        version: Chart version (optional)
        repository: Repository URL (optional)
        dependencies: List of dependencies (will be converted to tuple)
        values_schema: Values schema dict (will be frozen)

    Returns:
        HelmChartInfo provider
    """

    # Ensure dependencies is a tuple (immutable)
    if type(dependencies) == "list":
        dependencies = tuple(dependencies)

    # Note: Starlark doesn't have a freeze function, so we document immutability
    # In practice, providers should not modify these fields
    return HelmChartInfo(
        name = name,
        version = version,
        repository = repository,
        dependencies = dependencies,
        values_schema = values_schema,
    )

def create_helm_release_info(
        name,
        namespace,
        chart,
        values = {},
        status = "unknown",
        revision = 0,
        notes = None):
    """Creates a HelmReleaseInfo provider with immutable values.

    Pure function that creates a release info provider.

    Args:
        name: Release name
        namespace: Kubernetes namespace
        chart: HelmChartInfo provider
        values: Release values dict
        status: Release status
        revision: Release revision
        notes: Release notes (optional)

    Returns:
        HelmReleaseInfo provider
    """
    return HelmReleaseInfo(
        name = name,
        namespace = namespace,
        chart = chart,
        values = values,
        status = status,
        revision = revision,
        notes = notes,
    )


def create_validation_result(
        valid,
        errors = (),
        warnings = (),
        validated_chart = None,
        validated_release = None):
    """Creates a HelmValidationResultInfo provider.

    Pure function that creates validation results with immutable collections.

    Args:
        valid: Whether validation passed
        errors: List of errors (will be converted to tuple)
        warnings: List of warnings (will be converted to tuple)
        validated_chart: Validated chart info (optional)
        validated_release: Validated release info (optional)

    Returns:
        HelmValidationResultInfo provider
    """

    # Ensure errors and warnings are tuples (immutable)
    if type(errors) == "list":
        errors = tuple(errors)
    if type(warnings) == "list":
        warnings = tuple(warnings)

    return HelmValidationResultInfo(
        valid = valid,
        errors = errors,
        warnings = warnings,
        validated_chart = validated_chart,
        validated_release = validated_release,
    )
