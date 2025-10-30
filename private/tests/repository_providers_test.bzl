"""Unit tests for repository-related provider functions.

Tests the creation, immutability, and validation of providers that support
repository chart operations.
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "@helm_tools//private:providers.bzl",
    "HelmChartInfo",
    "HelmValidationResultInfo",
    "create_helm_chart_info",
    "create_validation_result",
)

# HelmChartInfo provider tests with repository support
def _create_helm_chart_info_repository_test_impl(ctx):
    """Test creating HelmChartInfo with repository information."""
    env = unittest.begin(ctx)

    # Test chart with repository URL
    chart_info = create_helm_chart_info(
        name = "postgresql",
        version = "13.2.10",
        repository = "https://charts.bitnami.com/bitnami",
        dependencies = ["common", "metrics"],
        values_schema = {"replicaCount": "int", "image": "dict"},
    )

    # Verify provider fields
    asserts.equals(env, "postgresql", chart_info.name)
    asserts.equals(env, "13.2.10", chart_info.version)
    asserts.equals(env, "https://charts.bitnami.com/bitnami", chart_info.repository)

    # Test dependencies are converted to tuple (immutable)
    asserts.equals(env, ("common", "metrics"), chart_info.dependencies)
    asserts.equals(env, "tuple", type(chart_info.dependencies))

    # Test values schema
    asserts.equals(env, {"replicaCount": "int", "image": "dict"}, chart_info.values_schema)

    return unittest.end(env)

create_helm_chart_info_repository_test = unittest.make(_create_helm_chart_info_repository_test_impl)

def _create_helm_chart_info_local_test_impl(ctx):
    """Test creating HelmChartInfo for local charts."""
    env = unittest.begin(ctx)

    # Test local chart (no repository)
    local_chart = create_helm_chart_info(
        name = "my-app",
        version = "1.0.0",
        # No repository URL for local charts
        dependencies = [],
        values_schema = {},
    )

    asserts.equals(env, "my-app", local_chart.name)
    asserts.equals(env, "1.0.0", local_chart.version)
    asserts.equals(env, None, local_chart.repository)  # Should be None for local
    asserts.equals(env, (), local_chart.dependencies)  # Empty tuple
    asserts.equals(env, {}, local_chart.values_schema)  # Empty dict

    return unittest.end(env)

create_helm_chart_info_local_test = unittest.make(_create_helm_chart_info_local_test_impl)

def _create_helm_chart_info_immutability_test_impl(ctx):
    """Test immutability of HelmChartInfo provider."""
    env = unittest.begin(ctx)

    # Test that dependencies list is converted to tuple
    dependencies_list = ["dep1", "dep2", "dep3"]
    chart_info = create_helm_chart_info(
        name = "test-chart",
        dependencies = dependencies_list,
    )

    # Verify conversion to tuple
    asserts.equals(env, ("dep1", "dep2", "dep3"), chart_info.dependencies)
    asserts.equals(env, "tuple", type(chart_info.dependencies))

    # Modify original list and verify chart_info is not affected
    dependencies_list.append("dep4")
    asserts.equals(env, ("dep1", "dep2", "dep3"), chart_info.dependencies)
    asserts.true(env, "dep4" not in chart_info.dependencies)

    return unittest.end(env)

create_helm_chart_info_immutability_test = unittest.make(_create_helm_chart_info_immutability_test_impl)

# Validation result tests for repository scenarios
def _create_validation_result_repository_success_test_impl(ctx):
    """Test validation result for successful repository validation."""
    env = unittest.begin(ctx)

    chart_info = create_helm_chart_info(
        name = "nginx",
        version = "1.2.3",
        repository = "https://charts.example.com",
    )

    validation_result = create_validation_result(
        valid = True,
        errors = [],
        warnings = ["Chart version may be outdated"],
        validated_chart = chart_info,
    )

    asserts.true(env, validation_result.valid)
    asserts.equals(env, (), validation_result.errors)  # Should be tuple
    asserts.equals(env, ("Chart version may be outdated",), validation_result.warnings)
    asserts.equals(env, chart_info, validation_result.validated_chart)
    asserts.equals(env, None, validation_result.validated_release)

    return unittest.end(env)

create_validation_result_repository_success_test = unittest.make(_create_validation_result_repository_success_test_impl)

def _create_validation_result_repository_failure_test_impl(ctx):
    """Test validation result for failed repository validation."""
    env = unittest.begin(ctx)

    validation_result = create_validation_result(
        valid = False,
        errors = [
            "Repository URL is invalid",
            "Chart version not found",
            "Authentication failed",
        ],
        warnings = ["Repository may be slow to respond"],
    )

    asserts.false(env, validation_result.valid)
    asserts.equals(env, (
        "Repository URL is invalid",
        "Chart version not found",
        "Authentication failed",
    ), validation_result.errors)
    asserts.equals(env, ("Repository may be slow to respond",), validation_result.warnings)
    asserts.equals(env, None, validation_result.validated_chart)
    asserts.equals(env, None, validation_result.validated_release)

    return unittest.end(env)

create_validation_result_repository_failure_test = unittest.make(_create_validation_result_repository_failure_test_impl)

def _create_validation_result_immutability_test_impl(ctx):
    """Test immutability of validation result collections."""
    env = unittest.begin(ctx)

    # Test that lists are converted to tuples
    errors_list = ["error1", "error2"]
    warnings_list = ["warning1"]

    validation_result = create_validation_result(
        valid = False,
        errors = errors_list,
        warnings = warnings_list,
    )

    # Verify conversion to tuples
    asserts.equals(env, ("error1", "error2"), validation_result.errors)
    asserts.equals(env, ("warning1",), validation_result.warnings)
    asserts.equals(env, "tuple", type(validation_result.errors))
    asserts.equals(env, "tuple", type(validation_result.warnings))

    # Modify original lists and verify validation_result is not affected
    errors_list.append("error3")
    warnings_list.append("warning2")

    asserts.equals(env, ("error1", "error2"), validation_result.errors)
    asserts.equals(env, ("warning1",), validation_result.warnings)
    asserts.true(env, "error3" not in validation_result.errors)
    asserts.true(env, "warning2" not in validation_result.warnings)

    return unittest.end(env)

create_validation_result_immutability_test = unittest.make(_create_validation_result_immutability_test_impl)

# Provider type verification tests
def _provider_type_verification_test_impl(ctx):
    """Test that providers return correct types."""
    env = unittest.begin(ctx)

    # Test chart info provider type by checking expected fields
    chart_info = create_helm_chart_info(name = "test")
    asserts.true(env, hasattr(chart_info, "name"))
    asserts.true(env, hasattr(chart_info, "version"))
    asserts.true(env, hasattr(chart_info, "repository"))
    asserts.true(env, hasattr(chart_info, "dependencies"))
    asserts.true(env, hasattr(chart_info, "values_schema"))

    # Test validation result provider type by checking expected fields
    validation_result = create_validation_result(valid = True)
    asserts.true(env, hasattr(validation_result, "valid"))
    asserts.true(env, hasattr(validation_result, "errors"))
    asserts.true(env, hasattr(validation_result, "warnings"))

    return unittest.end(env)

provider_type_verification_test = unittest.make(_provider_type_verification_test_impl)

def repository_providers_test_suite(name = "repository_providers_tests"):
    """Test suite for repository-related provider functions."""
    unittest.suite(        name,
        create_helm_chart_info_repository_test,
        create_helm_chart_info_local_test,
        create_helm_chart_info_immutability_test,
        create_validation_result_repository_success_test,
        create_validation_result_repository_failure_test,
        create_validation_result_immutability_test,
        provider_type_verification_test)
