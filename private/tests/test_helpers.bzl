"""Shared test utilities for Helm tools tests.

Provides helper functions for creating test data and assertions.
"""

load(
    "@helm_tools//private:providers.bzl",
    "create_helm_chart_info",
    "create_helm_release_info",
    "create_helm_version_info",
)

def create_test_version_info(version = "v3.13.3", binary = "test_binary"):
    """Creates a test HelmVersionInfo provider.

    Args:
        version: Version string (default: v3.13.3)
        binary: Binary label (default: test_binary)

    Returns:
        HelmVersionInfo provider for testing
    """
    return create_helm_version_info(
        version = version,
        binary = binary,
        sha256 = "test_sha256",
    )

def create_test_chart_info(name = "test-chart"):
    """Creates a test HelmChartInfo provider.

    Args:
        name: Chart name (default: test-chart)

    Returns:
        HelmChartInfo provider for testing
    """
    return create_helm_chart_info(
        name = name,
        version = "1.0.0",
        repository = "https://test.example.com",
        dependencies = ("dep1", "dep2"),
        values_schema = {"key": "value"},
    )

def create_test_release_info(name = "test-release"):
    """Creates a test HelmReleaseInfo provider.

    Args:
        name: Release name (default: test-release)

    Returns:
        HelmReleaseInfo provider for testing
    """
    return create_helm_release_info(
        name = name,
        namespace = "test-namespace",
        chart = create_test_chart_info(),
        values = {"test": "value"},
        status = "deployed",
        revision = 1,
        notes = "Test notes",
    )

def assert_validation_success(env, asserts, result):
    """Asserts that validation succeeded.

    Args:
        env: Test environment
        asserts: Assertions module
        result: Validation result tuple (is_valid, error)
    """
    asserts.true(env, result[0], "Validation should succeed")
    asserts.equals(env, None, result[1], "Error should be None")

def assert_validation_failure(env, asserts, result, expected_error_substring = None):
    """Asserts that validation failed.

    Args:
        env: Test environment
        asserts: Assertions module
        result: Validation result tuple (is_valid, error)
        expected_error_substring: Expected substring in error message
    """
    asserts.false(env, result[0], "Validation should fail")
    asserts.true(env, result[1] != None, "Error should not be None")
    if expected_error_substring:
        asserts.true(
            env,
            expected_error_substring in result[1],
            "Error should contain '{}', got: {}".format(expected_error_substring, result[1]),
        )


def create_test_cases_for_validation():
    """Creates standard test cases for validation functions.

    Returns:
        Struct with valid and invalid test cases
    """
    return struct(
        valid_release_names = ["myapp", "web-server", "app-123", "x" * 53],
        invalid_release_names = [
            ("", "cannot be empty"),
            ("MyApp", "must be lowercase"),
            ("app_name", "can only contain"),
            ("-app", "must start with"),
            ("app-", "cannot end with"),
            ("x" * 54, "53 characters or less"),
        ],
        valid_namespaces = ["default", "kube-system", "my-namespace"],
        invalid_namespaces = [
            ("", "cannot be empty"),
            ("_invalid", "must start with"),
            ("invalid_", "can only contain"),
            ("x" * 64, "63 characters or less"),
        ],
        valid_timeouts = ["10s", "5m", "1h", "999m"],
        invalid_timeouts = [
            ("", "cannot be empty"),
            ("10", "must end with"),
            ("10x", "must end with"),
            ("m10", "must have a numeric"),
        ],
        valid_chart_names = [
            "nginx",
            "bitnami/postgresql",
            "my-chart",
            "chart_v2",
            "app.chart",
        ],
        invalid_chart_names = [
            ("", "cannot be empty"),
            ("org/repo/chart", "can only have one"),
            ("/chart", "cannot be empty"),
            ("chart/", "cannot be empty"),
        ],
        valid_repository_urls = [
            "https://charts.bitnami.com/bitnami",
            "http://charts.example.com",
            "oci://registry.example.com/charts",
            "file:///path/to/charts",
        ],
        invalid_repository_urls = [
            ("", "cannot be empty"),
            ("charts.example.com", "must start with"),
            ("ftp://charts.example.com", "must start with"),
        ],
    )

def create_mock_helm_config():
    """Creates a mock Helm configuration for testing.

    Returns:
        Struct with mock configuration data
    """
    return struct(
        release_name = "test-release",
        namespace = "test-namespace",
        chart = "./charts/test-chart",
        values_file = "values.yaml",
        timeout = "5m",
        create_namespace = True,
        wait = True,
        atomic = True,
        force = False,
    )

def assert_struct_fields(env, asserts, actual, expected_fields):
    """Asserts that a struct has expected fields with correct values.

    Args:
        env: Test environment
        asserts: Assertions module
        actual: Actual struct to test
        expected_fields: Dict of field names to expected values
    """
    for field_name, expected_value in expected_fields.items():
        actual_value = getattr(actual, field_name, None)
        asserts.equals(
            env,
            expected_value,
            actual_value,
            "Field '{}' should equal '{}', got '{}'".format(
                field_name,
                expected_value,
                actual_value,
            ),
        )

def create_test_local_chart_path(chart_name = "test-chart"):
    """Creates a test path for a local Helm chart.

    Args:
        chart_name: Name of the chart (default: test-chart)

    Returns:
        String path to the chart
    """
    return "./charts/{}".format(chart_name)
