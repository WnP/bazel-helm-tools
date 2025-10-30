"""Unit tests for validation functions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "@helm_tools//private:validation.bzl",
    "validate_chart_name",
    "validate_chart_version",
    "validate_helm_release_name",
    "validate_namespace",
    "validate_repo_url_direct",
    "validate_repository_configuration",
    "validate_repository_url",
    "validate_semantic_version",
    "validate_timeout",
)

def _validate_semantic_version_success_test_impl(ctx):
    """Test successful semantic version validation."""
    env = unittest.begin(ctx)

    # Test valid versions
    valid_versions = [
        "v1.0.0",
        "v2.3.4",
        "v10.20.30",
        "1.0.0",  # Without v prefix
    ]

    for version in valid_versions:
        is_valid, error = validate_semantic_version(version)
        asserts.true(env, is_valid, "Version {} should be valid".format(version))
        asserts.equals(env, None, error)

    return unittest.end(env)

validate_semantic_version_success_test = unittest.make(_validate_semantic_version_success_test_impl)

def _validate_semantic_version_failure_test_impl(ctx):
    """Test semantic version validation failures."""
    env = unittest.begin(ctx)

    # Test invalid versions
    invalid_cases = [
        ("", "Version cannot be empty"),
        ("1.0", "Version must have exactly 3 parts"),
        ("v1.0.0.0", "Version must have exactly 3 parts"),
        ("v1.a.0", "contains non-digit characters"),
    ]

    for version, expected_error in invalid_cases:
        is_valid, error = validate_semantic_version(version)
        asserts.false(env, is_valid, "Version {} should be invalid".format(version))
        asserts.true(env, expected_error in error if error else False)

    return unittest.end(env)

validate_semantic_version_failure_test = unittest.make(_validate_semantic_version_failure_test_impl)

def _validate_helm_release_name_test_impl(ctx):
    """Test Helm release name validation."""
    env = unittest.begin(ctx)

    # Valid names
    valid_names = ["myapp", "web-server", "app-123"]
    for name in valid_names:
        is_valid, _ = validate_helm_release_name(name)
        asserts.true(env, is_valid, "Name {} should be valid".format(name))

    # Invalid names
    invalid_names = ["MyApp", "app_name", "app.name", "-app", "app-"]
    for name in invalid_names:
        is_valid, error = validate_helm_release_name(name)
        asserts.false(env, is_valid, "Name {} should be invalid".format(name))

    return unittest.end(env)

validate_helm_release_name_test = unittest.make(_validate_helm_release_name_test_impl)

def _validate_namespace_test_impl(ctx):
    """Test namespace validation."""
    env = unittest.begin(ctx)

    # Valid namespaces
    valid_namespaces = ["default", "kube-system", "my-namespace", "app-123"]
    for ns in valid_namespaces:
        is_valid, error = validate_namespace(ns)
        asserts.true(env, is_valid, "Namespace {} should be valid".format(ns))
        asserts.equals(env, None, error)

    # Invalid namespaces
    invalid_cases = [
        ("", "cannot be empty"),
        ("_invalid", "can only contain alphanumeric"),  # Updated to match actual error
        ("invalid_", "can only contain alphanumeric"),  # Updated to match actual error
        ("x" * 64, "63 characters or less"),
        ("-namespace", "must start with"),
        ("namespace-", "cannot end with"),
    ]
    for ns, expected_error in invalid_cases:
        is_valid, error = validate_namespace(ns)
        asserts.false(env, is_valid, "Namespace '{}' should be invalid".format(ns))
        asserts.true(
            env,
            expected_error in error if error else False,
            "Expected error to contain '{}' for namespace '{}', got '{}'".format(expected_error, ns, error),
        )

    return unittest.end(env)

validate_namespace_test = unittest.make(_validate_namespace_test_impl)

def _validate_timeout_test_impl(ctx):
    """Test timeout validation."""
    env = unittest.begin(ctx)

    # Valid timeouts
    valid_timeouts = ["10s", "5m", "1h", "999m", "1000s"]
    for timeout in valid_timeouts:
        is_valid, error = validate_timeout(timeout)
        asserts.true(env, is_valid, "Timeout {} should be valid".format(timeout))
        asserts.equals(env, None, error)

    # Invalid timeouts
    invalid_cases = [
        ("", "cannot be empty"),
        ("10", "must end with"),
        ("10x", "must end with"),
        ("m10", "must end with"),  # Changed: 'm10' starts with 'm' so the error is about format
        ("10ms", "value must be numeric"),  # Changed: '10ms' has 'ms' where 's' is after digits
        ("s", "must have a numeric"),
    ]
    for timeout, expected_error in invalid_cases:
        is_valid, error = validate_timeout(timeout)
        asserts.false(env, is_valid, "Timeout '{}' should be invalid".format(timeout))
        asserts.true(
            env,
            expected_error in error if error else False,
            "Expected error to contain '{}' for timeout '{}', got '{}'".format(expected_error, timeout, error),
        )

    return unittest.end(env)

validate_timeout_test = unittest.make(_validate_timeout_test_impl)

def _validate_chart_name_test_impl(ctx):
    """Test chart name validation."""
    env = unittest.begin(ctx)

    # Valid chart names
    valid_names = [
        "nginx",
        "bitnami/postgresql",
        "my-chart",
        "chart_v2",
        "app.chart",
        "org/my-app_v2.1",
    ]
    for name in valid_names:
        is_valid, error = validate_chart_name(name)
        asserts.true(env, is_valid, "Chart name {} should be valid".format(name))
        asserts.equals(env, None, error)

    # Invalid chart names
    invalid_cases = [
        ("", "cannot be empty"),
        ("org/repo/chart", "can only have one"),
        ("/chart", "cannot be empty"),
        ("chart/", "cannot be empty"),
        ("my@chart", "can only contain"),
        ("chart name", "can only contain"),
    ]
    for name, expected_error in invalid_cases:
        is_valid, error = validate_chart_name(name)
        asserts.false(env, is_valid, "Chart name {} should be invalid".format(name))
        asserts.true(env, expected_error in error if error else False)

    return unittest.end(env)

validate_chart_name_test = unittest.make(_validate_chart_name_test_impl)

def _validate_repository_url_test_impl(ctx):
    """Test repository URL validation."""
    env = unittest.begin(ctx)

    # Valid URLs
    valid_urls = [
        "https://charts.bitnami.com/bitnami",
        "http://charts.example.com",
        "oci://registry.example.com/charts",
        "file:///path/to/charts",
    ]
    for url in valid_urls:
        is_valid, error = validate_repository_url(url)
        asserts.true(env, is_valid, "URL {} should be valid".format(url))
        asserts.equals(env, None, error)

    # Invalid URLs
    invalid_cases = [
        ("", "cannot be empty"),
        ("charts.example.com", "must start with"),
        ("ftp://charts.example.com", "must start with"),
        ("example.com/charts", "must start with"),
    ]
    for url, expected_error in invalid_cases:
        is_valid, error = validate_repository_url(url)
        asserts.false(env, is_valid, "URL {} should be invalid".format(url))
        asserts.true(env, expected_error in error if error else False)

    return unittest.end(env)

validate_repository_url_test = unittest.make(_validate_repository_url_test_impl)

def _validate_chart_version_test_impl(ctx):
    """Test chart version validation."""
    env = unittest.begin(ctx)

    # All versions should be valid (including empty)
    valid_versions = [
        "",  # Empty means latest
        "1.0.0",
        "v1.0.0",
        "1.2.3-alpha.1",
        "2021-03-01",
        "abc123def",  # Commit hash
        "feature-branch-123",
    ]
    for version in valid_versions:
        is_valid, error = validate_chart_version(version)
        asserts.true(env, is_valid, "Version {} should be valid".format(version))
        asserts.equals(env, None, error)

    return unittest.end(env)

validate_chart_version_test = unittest.make(_validate_chart_version_test_impl)

def _validate_repository_configuration_test_impl(ctx):
    """Test complete repository configuration validation."""
    env = unittest.begin(ctx)

    # Valid configurations
    valid_configs = [
        (None, None),  # All empty is valid
        ("https://charts.bitnami.com/bitnami", None),
        ("https://charts.bitnami.com/bitnami", "13.2.10"),
    ]
    for repo_url, chart_version in valid_configs:
        is_valid, error = validate_repository_configuration(repo_url, chart_version)
        asserts.true(env, is_valid, "Configuration should be valid")
        asserts.equals(env, None, error)

    # Invalid configurations
    invalid_configs = [
        ("not-a-url", None),  # Invalid URL
    ]
    for repo_url, chart_version in invalid_configs:
        is_valid, error = validate_repository_configuration(repo_url, chart_version)
        asserts.false(env, is_valid, "Configuration should be invalid")
        asserts.true(env, error != None)

    return unittest.end(env)

validate_repository_configuration_test = unittest.make(_validate_repository_configuration_test_impl)

def _validate_chart_name_with_labels_test_impl(ctx):
    """Test chart name validation including Bazel labels."""
    env = unittest.begin(ctx)

    # Valid Bazel labels should be accepted
    bazel_labels = [
        ":cilium_charts",
        ":prometheus_charts/charts/prometheus",
        "//charts/nginx:chart",
        "@external_repo//charts:prometheus",
    ]

    for chart in bazel_labels:
        is_valid, error = validate_chart_name(chart)
        asserts.true(env, is_valid, "Chart {} should be valid".format(chart))
        asserts.equals(env, None, error)

    # Valid repository chart names should still work
    repo_charts = [
        "nginx",
        "bitnami/nginx",
        "prometheus/prometheus",
        "stable/mysql",
    ]

    for chart in repo_charts:
        is_valid, error = validate_chart_name(chart)
        asserts.true(env, is_valid, "Chart {} should be valid".format(chart))
        asserts.equals(env, None, error)

    # Invalid cases
    invalid_charts = [
        "",  # Empty
        ":",  # Empty target after colon
        "//",  # Empty package path
        "invalid!/chart",  # Invalid character
    ]

    for chart in invalid_charts:
        is_valid, error = validate_chart_name(chart)
        asserts.false(env, is_valid, "Chart {} should be invalid".format(chart))
        asserts.true(env, error != None, "Error should be provided for {}".format(chart))

    return unittest.end(env)

validate_chart_name_with_labels_test = unittest.make(_validate_chart_name_with_labels_test_impl)

def _validate_repo_url_direct_test_impl(ctx):
    """Test direct repo_url validation."""
    env = unittest.begin(ctx)

    # Valid direct URLs (OCI and file)
    valid_urls = [
        "oci://registry.example.com/charts",
        "oci://ghcr.io/org/charts",
        "file:///path/to/charts",
    ]
    for url in valid_urls:
        is_valid, error = validate_repo_url_direct(url)
        asserts.true(env, is_valid, "Direct URL {} should be valid".format(url))
        asserts.equals(env, None, error)

    # Invalid direct URLs (HTTP/HTTPS not allowed)
    invalid_cases = [
        ("https://charts.bitnami.com/bitnami", "cannot use HTTP/HTTPS URLs directly"),
        ("http://charts.example.com", "cannot use HTTP/HTTPS URLs directly"),
        ("ftp://charts.example.com", "must start with oci:// or file://"),
        ("s3://bucket/charts", "must start with oci:// or file://"),
    ]
    for url, expected_error in invalid_cases:
        is_valid, error = validate_repo_url_direct(url)
        asserts.false(env, is_valid, "Direct URL {} should be invalid".format(url))
        asserts.true(env, expected_error in error if error else False)

    return unittest.end(env)

validate_repo_url_direct_test = unittest.make(_validate_repo_url_direct_test_impl)

def validation_test_suite(name = "validation_tests"):
    """Test suite for validation functions."""
    unittest.suite(        name,
        validate_semantic_version_success_test,
        validate_semantic_version_failure_test,
        validate_helm_release_name_test,
        validate_namespace_test,
        validate_timeout_test,
        validate_chart_name_test,
        validate_chart_name_with_labels_test,
        validate_repository_url_test,
        validate_repo_url_direct_test,
        validate_chart_version_test,
        validate_repository_configuration_test)
