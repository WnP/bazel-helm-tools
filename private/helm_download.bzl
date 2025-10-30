"""Repository rule for downloading Helm binary."""

def _get_platform(repository_ctx):
    """Detects the current platform.

    Args:
        repository_ctx: Repository context

    Returns:
        Tuple of (os, arch) strings
    """
    os_name = repository_ctx.os.name.lower()

    # Normalize OS name
    if "linux" in os_name:
        os = "linux"
    elif "mac" in os_name or "darwin" in os_name:
        os = "darwin"
    elif "windows" in os_name:
        os = "windows"
    else:
        fail("Unsupported operating system: {}".format(os_name))

    # Get architecture
    arch = repository_ctx.os.arch
    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"
    elif arch != "amd64" and arch != "arm64":
        fail("Unsupported architecture: {}".format(arch))

    return (os, arch)

def _helm_download_impl(repository_ctx):
    """Implementation of the helm_download repository rule.

    Downloads the appropriate Helm binary for the current platform.

    Args:
        repository_ctx: Repository context
    """
    version = repository_ctx.attr.version
    sha256 = repository_ctx.attr.sha256

    # Get platform information
    os, arch = _get_platform(repository_ctx)

    # Construct download URL
    base_url = "https://get.helm.sh"
    file_ext = "zip" if os == "windows" else "tar.gz"
    archive_name = "helm-{}-{}-{}.{}".format(version, os, arch, file_ext)
    url = "{}/{}".format(base_url, archive_name)

    # Download and extract
    repository_ctx.report_progress("Downloading Helm {} for {}-{}".format(version, os, arch))

    if file_ext == "zip":
        repository_ctx.download_and_extract(
            url = url,
            sha256 = sha256,
            stripPrefix = "{}-{}".format(os, arch),
        )
    else:
        repository_ctx.download_and_extract(
            url = url,
            sha256 = sha256,
            stripPrefix = "{}-{}".format(os, arch),
        )

    # Create BUILD file
    # Export the helm binary directly so it can be used as srcs in sh_binary
    repository_ctx.file("BUILD.bazel", """
package(default_visibility = ["//visibility:public"])

exports_files(
    ["helm{ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "helm_binary",
    srcs = ["helm{ext}"],
    visibility = ["//visibility:public"],
)
""".format(ext = ".exe" if os == "windows" else ""))

helm_download = repository_rule(
    implementation = _helm_download_impl,
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "Helm version to download (e.g., 'v3.13.3')",
        ),
        "sha256": attr.string(
            doc = "SHA256 checksum of the archive (optional but recommended)",
        ),
    },
    doc = """Downloads Helm binary for the current platform.

    This rule automatically detects the operating system and architecture,
    downloads the appropriate Helm binary, and makes it available for use.

    Example:
        ```
        helm_download(
            name = "helm_binary",
            version = "v3.13.3",
            sha256 = "...",
        )
        ```
    """,
)
