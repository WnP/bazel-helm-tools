"""Module extension for configuring Helm integration."""

load("@helm_tools//private:helm_download.bzl", "helm_download")
load("@helm_tools//private:validation.bzl", "validate_semantic_version")

# Default Helm version if not specified
_DEFAULT_HELM_VERSION = "v3.13.3"


def _helm_extension_impl(module_ctx):
    """Implementation of the Helm module extension.

    Processes configuration from all modules and creates necessary repositories.

    Args:
        module_ctx: Module extension context.
    """

    # Collect all Helm configurations from modules
    helm_configs = []

    for mod in module_ctx.modules:
        for configure_tag in mod.tags.configure:
            # Validate version
            version = configure_tag.version or _DEFAULT_HELM_VERSION
            is_valid, error_msg = validate_semantic_version(version)
            if not is_valid:
                fail("Module '{}' specified invalid Helm version '{}': {}".format(
                    mod.name,
                    version,
                    error_msg,
                ))

            config = struct(
                name = configure_tag.name or "helm",
                version = version,
                sha256 = configure_tag.sha256 or "",
            )
            helm_configs.append(config)

    # If no configuration provided, use defaults
    if not helm_configs:
        helm_configs = [struct(
            name = "helm",
            version = _DEFAULT_HELM_VERSION,
            sha256 = "",
        )]

    # Create repository for each unique configuration
    seen_names = {}
    for config in helm_configs:
        if config.name in seen_names:
            if seen_names[config.name].version != config.version:
                fail("Conflicting Helm versions for '{}': {} vs {}".format(
                    config.name,
                    seen_names[config.name].version,
                    config.version,
                ))
        else:
            helm_download(
                name = config.name + "_binary",
                version = config.version,
                sha256 = config.sha256,
            )
            seen_names[config.name] = config

helm = module_extension(
    implementation = _helm_extension_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "name": attr.string(
                    default = "helm",
                    doc = "Name for the Helm instance (default: 'helm'). " +
                          "Used as prefix for repository name.",
                ),
                "version": attr.string(
                    default = _DEFAULT_HELM_VERSION,
                    doc = "Version of Helm to use (default: {}). ".format(_DEFAULT_HELM_VERSION) +
                          "Must follow semantic versioning.",
                ),
                "sha256": attr.string(
                    doc = "Optional SHA256 checksum for the Helm binary.",
                ),
            },
            doc = """Configure a Helm binary for use in the project.

            Example:
                ```
                helm = use_extension("@helm_tools//:extensions.bzl", "helm")
                helm.configure(
                    version = "v3.13.3",
                )
                use_repo(helm, "helm_binary")
                ```
            """,
        ),
    },
    doc = """Module extension for configuring Helm chart management.

    This extension allows projects to specify which version of Helm they want
    to use. It handles downloading the appropriate binary for the current platform
    and makes it available for use by the helm_release macro.

    The extension supports multiple Helm configurations if needed, though typically
    a project will only need one.
    """,
)
