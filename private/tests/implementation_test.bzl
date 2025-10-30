"""Tests for Helm tools implementation functions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//private:implementation.bzl", "create_helm_release_targets", "testable")

def _validate_inputs_test_impl(ctx):
    """Test input validation function."""
    env = unittest.begin(ctx)

    # Valid inputs - using OCI URL which can be used directly
    result = testable.validate_inputs(
        release_name = "valid-name",
        namespace = "default",
        timeout = "10m",
        chart = "nginx",
        repo_url = "oci://registry.example.com/charts",
        repo_name = None,
        chart_version = "1.0.0",
    )
    asserts.true(env, result.valid, "Valid inputs should pass")

    # Invalid release name
    result = testable.validate_inputs(
        release_name = "Invalid Name!",
        namespace = "default",
        timeout = "10m",
        chart = "nginx",
        repo_url = None,
        repo_name = None,
        chart_version = None,
    )
    asserts.false(env, result.valid, "Invalid release name should fail")
    asserts.true(env, "release name" in result.error.lower())

    # Invalid namespace
    result = testable.validate_inputs(
        release_name = "valid",
        namespace = "Invalid Namespace",
        timeout = "10m",
        chart = "nginx",
        repo_url = None,
        repo_name = None,
        chart_version = None,
    )
    asserts.false(env, result.valid, "Invalid namespace should fail")
    asserts.true(env, "namespace" in result.error.lower())

    # Invalid timeout format
    result = testable.validate_inputs(
        release_name = "valid",
        namespace = "default",
        timeout = "invalid",
        chart = "nginx",
        repo_url = None,
        repo_name = None,
        chart_version = None,
    )
    asserts.false(env, result.valid, "Invalid timeout should fail")
    asserts.true(env, "timeout" in result.error.lower())

    return unittest.end(env)

validate_inputs_test = unittest.make(_validate_inputs_test_impl)

def _build_configuration_test_impl(ctx):
    """Test configuration building function."""
    env = unittest.begin(ctx)

    # Test basic configuration
    config = testable.build_configuration(
        release_name = "test-release",
        namespace = "test-namespace",
        chart = "test-chart",
        timeout = "10m",
        repo_url = "https://example.com",
        repo_name = None,
        chart_version = "1.0.0",
    )

    asserts.equals(env, "test-release", config.release_name)
    asserts.equals(env, "test-namespace", config.namespace)
    asserts.equals(env, "test-chart", config.chart)
    asserts.equals(env, "10m", config.timeout)
    asserts.equals(env, "https://example.com", config.repo_url)
    asserts.equals(env, "1.0.0", config.chart_version)
    asserts.true(env, config.is_repository_chart)

    # Test with repo_name
    config_with_repo_name = testable.build_configuration(
        release_name = "test",
        namespace = "default",
        chart = "nginx",
        timeout = "",
        repo_url = "",
        repo_name = ":prometheus_repo",
        chart_version = "",
    )

    asserts.equals(env, ":prometheus_repo", config_with_repo_name.repo_name)
    asserts.true(env, config_with_repo_name.is_repository_chart)

    # Test without repository (local chart)
    config_local = testable.build_configuration(
        release_name = "local",
        namespace = "default",
        chart = "//charts/local",
        timeout = "",
        repo_url = "",
        repo_name = None,
        chart_version = "",
    )

    asserts.false(env, config_local.is_repository_chart)

    return unittest.end(env)

build_configuration_test = unittest.make(_build_configuration_test_impl)

def _create_target_definitions_test_impl(ctx):
    """Test target definitions creation."""
    env = unittest.begin(ctx)

    config = struct(
        release_name = "test",
        namespace = "default",
        chart = "test-chart",
        timeout = "5m",
        repo_url = "",
        repo_name = "",
        chart_version = "",
        is_repository_chart = False,
    )

    targets = testable.create_target_definitions(
        name = "test",
        config = config,
        helm_args = "--wait",
        values_file = None,
        repo_name = None,
        visibility = None,
        tags = None,
        kwargs = {},
    )

    # Should create 5 targets
    asserts.equals(env, 5, len(targets))

    # Check target names
    target_names = [t.name for t in targets]
    asserts.true(env, "test_install" in target_names)
    asserts.true(env, "test_upgrade" in target_names)
    asserts.true(env, "test_uninstall" in target_names)
    asserts.true(env, "test_status" in target_names)
    asserts.true(env, "test_values" in target_names)

    # All should use wrapper type now
    for target in targets:
        asserts.equals(env, "sh_binary_with_wrapper", target.type)

    return unittest.end(env)

create_target_definitions_test = unittest.make(_create_target_definitions_test_impl)

def implementation_test_suite(name):
    """Test suite for implementation functions."""
    return unittest.suite(        name,
        validate_inputs_test,
        build_configuration_test,
        create_target_definitions_test)

# Test targets are created by the test suite itself