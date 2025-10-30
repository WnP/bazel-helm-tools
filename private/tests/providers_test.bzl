"""Unit tests for provider definitions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "@helm_tools//private:providers.bzl",
    "create_helm_chart_info",
    "create_helm_release_info",
    "create_helm_version_info",
    "create_validation_result",
)
load(":test_helpers.bzl", "create_test_chart_info")

def _helm_version_info_test_impl(ctx):
    """Test HelmVersionInfo provider creation."""
    env = unittest.begin(ctx)

    # Create provider
    info = create_helm_version_info(
        version = "v3.13.3",
        binary = "test_binary",
        sha256 = "abc123",
    )

    # Test field access
    asserts.equals(env, "v3.13.3", info.version)
    asserts.equals(env, "test_binary", info.binary)
    asserts.equals(env, "abc123", info.sha256)

    # Test without sha256
    info2 = create_helm_version_info(
        version = "v3.14.0",
        binary = "binary2",
    )
    asserts.equals(env, None, info2.sha256)

    return unittest.end(env)

helm_version_info_test = unittest.make(_helm_version_info_test_impl)

def _helm_chart_info_test_impl(ctx):
    """Test HelmChartInfo provider creation."""
    env = unittest.begin(ctx)

    # Create provider with all fields
    info = create_helm_chart_info(
        name = "test-chart",
        version = "1.2.3",
        repository = "https://example.com",
        dependencies = ["dep1", "dep2"],  # Will be converted to tuple
        values_schema = {"key": "value"},
    )

    # Test field access
    asserts.equals(env, "test-chart", info.name)
    asserts.equals(env, "1.2.3", info.version)
    asserts.equals(env, "https://example.com", info.repository)
    asserts.equals(env, ("dep1", "dep2"), info.dependencies)  # Should be tuple
    asserts.true(env, type(info.dependencies) == type(()))  # Verify it's a tuple

    return unittest.end(env)

helm_chart_info_test = unittest.make(_helm_chart_info_test_impl)

def _helm_release_info_test_impl(ctx):
    """Test HelmReleaseInfo provider creation."""
    env = unittest.begin(ctx)

    chart = create_test_chart_info()

    # Create provider
    info = create_helm_release_info(
        name = "my-release",
        namespace = "default",
        chart = chart,
        values = {"replicas": 3},
        status = "deployed",
        revision = 1,
        notes = "Installation complete",
    )

    # Test field access
    asserts.equals(env, "my-release", info.name)
    asserts.equals(env, "default", info.namespace)
    asserts.equals(env, chart, info.chart)
    asserts.equals(env, {"replicas": 3}, info.values)
    asserts.equals(env, "deployed", info.status)
    asserts.equals(env, 1, info.revision)
    asserts.equals(env, "Installation complete", info.notes)

    return unittest.end(env)

helm_release_info_test = unittest.make(_helm_release_info_test_impl)

def _validation_result_info_test_impl(ctx):
    """Test HelmValidationResultInfo provider creation."""
    env = unittest.begin(ctx)

    # Test valid result
    valid_result = create_validation_result(
        valid = True,
        errors = [],
        warnings = ["Consider using latest version"],
    )
    asserts.true(env, valid_result.valid)
    asserts.equals(env, (), valid_result.errors)
    asserts.equals(env, ("Consider using latest version",), valid_result.warnings)

    # Test invalid result
    invalid_result = create_validation_result(
        valid = False,
        errors = ["Invalid name", "Missing namespace"],
        warnings = [],
    )
    asserts.false(env, invalid_result.valid)
    asserts.equals(env, ("Invalid name", "Missing namespace"), invalid_result.errors)
    asserts.equals(env, (), invalid_result.warnings)

    # Verify tuples are immutable
    asserts.true(env, type(valid_result.warnings) == type(()))
    asserts.true(env, type(invalid_result.errors) == type(()))

    return unittest.end(env)

validation_result_info_test = unittest.make(_validation_result_info_test_impl)


def _provider_immutability_test_impl(ctx):
    """Test that provider fields use immutable data structures."""
    env = unittest.begin(ctx)

    # Test HelmChartInfo dependencies are tuples
    chart_info = create_helm_chart_info(
        name = "test",
        dependencies = ["dep1", "dep2"],  # Pass list
    )
    asserts.true(env, type(chart_info.dependencies) == type(()))
    asserts.equals(env, ("dep1", "dep2"), chart_info.dependencies)

    # Test validation result collections are tuples
    result = create_validation_result(
        valid = False,
        errors = ["error1", "error2"],  # Pass list
        warnings = ["warn1"],  # Pass list
    )
    asserts.true(env, type(result.errors) == type(()))
    asserts.true(env, type(result.warnings) == type(()))
    asserts.equals(env, ("error1", "error2"), result.errors)
    asserts.equals(env, ("warn1",), result.warnings)

    return unittest.end(env)

provider_immutability_test = unittest.make(_provider_immutability_test_impl)

def _provider_with_nested_providers_test_impl(ctx):
    """Test providers that contain other providers."""
    env = unittest.begin(ctx)

    # Create nested providers
    chart = create_helm_chart_info(
        name = "nginx",
        version = "1.0.0",
        repository = "https://charts.example.com",
    )

    release = create_helm_release_info(
        name = "my-nginx",
        namespace = "web",
        chart = chart,  # Nested provider
        values = {"replicas": 3},
        status = "deployed",
        revision = 2,
    )

    # Test access to nested provider
    asserts.equals(env, "my-nginx", release.name)
    asserts.equals(env, chart, release.chart)
    asserts.equals(env, "nginx", release.chart.name)
    asserts.equals(env, "1.0.0", release.chart.version)

    # Test validation result with nested providers
    validation_result = create_validation_result(
        valid = True,
        errors = (),
        warnings = (),
        validated_chart = chart,
        validated_release = release,
    )

    asserts.true(env, validation_result.valid)
    asserts.equals(env, chart, validation_result.validated_chart)
    asserts.equals(env, release, validation_result.validated_release)
    asserts.equals(env, "nginx", validation_result.validated_chart.name)
    asserts.equals(env, "my-nginx", validation_result.validated_release.name)

    return unittest.end(env)

provider_with_nested_providers_test = unittest.make(_provider_with_nested_providers_test_impl)

def providers_test_suite(name = "providers_tests"):
    """Test suite for provider definitions."""
    unittest.suite(        name,
        helm_version_info_test,
        helm_chart_info_test,
        helm_release_info_test,
        validation_result_info_test,
        provider_immutability_test,
        provider_with_nested_providers_test)
