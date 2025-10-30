"""Unit tests for repository-specific validation functions.

Focuses on testing the enhanced validation functions that support repository charts,
including URL validation, authentication scenarios, and version resolution.
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "@helm_tools//private:validation.bzl",
    "validate_chart_name",
    "validate_chart_version",
    "validate_repository_configuration",
    "validate_repository_url",
)

# Repository URL validation tests
def _validate_repository_url_comprehensive_test_impl(ctx):
    """Test comprehensive repository URL validation scenarios."""
    env = unittest.begin(ctx)

    # Test valid repository URLs with different schemes
    valid_urls = [
        "https://charts.bitnami.com/bitnami",
        "http://internal.charts.company.com",
        "oci://registry.example.com/charts",
        "file:///path/to/local/charts",
        "https://helm.nginx.com/stable",
        "oci://public.ecr.aws/bitnami/charts",
    ]

    for url in valid_urls:
        is_valid, error = validate_repository_url(url)
        asserts.true(env, is_valid, "Repository URL {} should be valid".format(url))
        asserts.equals(env, None, error)

    return unittest.end(env)

validate_repository_url_comprehensive_test = unittest.make(_validate_repository_url_comprehensive_test_impl)

def _validate_repository_url_edge_cases_test_impl(ctx):
    """Test edge cases for repository URL validation."""
    env = unittest.begin(ctx)

    # Test invalid URLs
    invalid_cases = [
        ("", "cannot be empty"),
        ("charts.bitnami.com", "must start with"),
        ("ftp://charts.example.com", "must start with"),
        ("git://github.com/charts", "must start with"),
        ("s3://bucket/charts", "must start with"),
        ("hdfs://cluster/charts", "must start with"),
        ("ssh://user@host/charts", "must start with"),
    ]

    for url, expected_error in invalid_cases:
        is_valid, error = validate_repository_url(url)
        asserts.false(env, is_valid, "Repository URL '{}' should be invalid".format(url))
        asserts.true(
            env,
            expected_error in error if error else False,
            "Expected error to contain '{}' for URL '{}', got '{}'".format(expected_error, url, error),
        )

    return unittest.end(env)

validate_repository_url_edge_cases_test = unittest.make(_validate_repository_url_edge_cases_test_impl)

# Repository configuration validation tests
def _validate_repository_configuration_comprehensive_test_impl(ctx):
    """Test comprehensive repository configuration validation."""
    env = unittest.begin(ctx)

    # Test valid configuration combinations
    valid_configs = [
        # Local chart only (no repository)
        (None, None),
        # Repository URL with chart
        ("https://charts.bitnami.com/bitnami", None),
        # Full repository configuration
        ("https://charts.bitnami.com/bitnami", "13.2.10"),
        # Repository with semantic versioning
        ("https://charts.example.com", "v2.1.3"),
        # Repository with pre-release version
        ("https://charts.example.com", "1.0.0-alpha.1"),
        # OCI registry configuration
        ("oci://registry.example.com/charts", "latest"),
    ]

    for repo_url, chart_version in valid_configs:
        is_valid, error = validate_repository_configuration(repo_url, chart_version)
        asserts.true(
            env,
            is_valid,
            "Configuration (url={}, version={}) should be valid".format(repo_url, chart_version),
        )
        asserts.equals(env, None, error)

    return unittest.end(env)

validate_repository_configuration_comprehensive_test = unittest.make(_validate_repository_configuration_comprehensive_test_impl)

def _validate_repository_configuration_invalid_test_impl(ctx):
    """Test invalid repository configuration combinations."""
    env = unittest.begin(ctx)

    # Test invalid configurations
    invalid_configs = [
        # Invalid repository URL
        ("not-a-valid-url", "1.0.0"),
        # Invalid scheme
        ("grpc://charts.example.com", "1.0.0"),
    ]

    for repo_url, chart_version in invalid_configs:
        is_valid, error = validate_repository_configuration(repo_url, chart_version)
        asserts.false(
            env,
            is_valid,
            "Configuration (url={}, version={}) should be invalid".format(repo_url, chart_version),
        )
        asserts.true(env, error != None, "Error message should not be None for invalid configuration")

    return unittest.end(env)

validate_repository_configuration_invalid_test = unittest.make(_validate_repository_configuration_invalid_test_impl)

# Chart version validation tests for repository scenarios
def _validate_chart_version_repository_scenarios_test_impl(ctx):
    """Test chart version validation for various repository scenarios."""
    env = unittest.begin(ctx)

    # Test various version formats supported by Helm repositories
    valid_versions = [
        "",  # Empty (latest)
        "1.0.0",  # Semantic version
        "v1.0.0",  # Semantic version with v prefix
        "1.2.3-alpha.1",  # Pre-release
        "1.2.3+build.123",  # Build metadata
        "0.1.0-rc1",  # Release candidate
        "2.0.0-beta.2+exp.sha.abc123",  # Complex version
        "latest",  # Common alias
        "stable",  # Common alias
        "main",  # Branch reference
        "feature-branch",  # Branch with hyphen
        "2021.03.15",  # Date-based version
        "abc123def",  # Git commit hash
        "1.0",  # Short version
        "1",  # Major only
    ]

    for version in valid_versions:
        is_valid, error = validate_chart_version(version)
        asserts.true(
            env,
            is_valid,
            "Chart version '{}' should be valid for repository scenarios".format(version),
        )
        asserts.equals(env, None, error)

    return unittest.end(env)

validate_chart_version_repository_scenarios_test = unittest.make(_validate_chart_version_repository_scenarios_test_impl)


# Chart name validation for repository contexts
def _validate_chart_name_repository_context_test_impl(ctx):
    """Test chart name validation in repository contexts."""
    env = unittest.begin(ctx)

    # Test valid chart names for repositories
    valid_names = [
        "nginx",
        "postgresql",
        "bitnami/postgresql",  # Org/chart format
        "my-app",
        "web_server",
        "app.v2",
        "microservice-auth",
        "service_mesh_gateway",
        "monitoring.grafana",
        "data-pipeline_v2.1",
    ]

    for name in valid_names:
        is_valid, error = validate_chart_name(name)
        asserts.true(env, is_valid, "Chart name '{}' should be valid for repository".format(name))
        asserts.equals(env, None, error)

    # Test invalid chart names
    invalid_cases = [
        ("", "cannot be empty"),
        ("org/repo/chart", "can only have one"),
        ("/chart", "cannot be empty"),
        ("chart/", "cannot be empty"),
        ("my@chart", "can only contain"),
        ("chart name", "can only contain"),
        ("chart#name", "can only contain"),
        ("chart%name", "can only contain"),
    ]

    for name, expected_error in invalid_cases:
        is_valid, error = validate_chart_name(name)
        asserts.false(env, is_valid, "Chart name '{}' should be invalid".format(name))
        asserts.true(
            env,
            expected_error in error if error else False,
            "Expected error to contain '{}' for name '{}', got '{}'".format(expected_error, name, error),
        )

    return unittest.end(env)

validate_chart_name_repository_context_test = unittest.make(_validate_chart_name_repository_context_test_impl)


def repository_validation_test_suite(name = "repository_validation_tests"):
    """Test suite for repository-specific validation functions."""
    unittest.suite(        name,
        validate_repository_url_comprehensive_test,
        validate_repository_url_edge_cases_test,
        validate_repository_configuration_comprehensive_test,
        validate_repository_configuration_invalid_test,
        validate_chart_version_repository_scenarios_test,
        validate_chart_name_repository_context_test)
