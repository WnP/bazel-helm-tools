"""Unit tests for utility functions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "@helm_tools//private:utils.bzl",
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
    "join_errors",
    "starts_with_any",
    "validate_characters",
    "validate_numeric_part",
)

def _check_empty_test_impl(ctx):
    """Test empty value checking."""
    env = unittest.begin(ctx)

    # Empty value
    is_valid, error = check_empty("", "field")
    asserts.false(env, is_valid)
    asserts.equals(env, "Field cannot be empty", error)

    # Non-empty value
    is_valid, error = check_empty("value", "field")
    asserts.true(env, is_valid)
    asserts.equals(env, None, error)

    return unittest.end(env)

check_empty_test = unittest.make(_check_empty_test_impl)

def _check_string_length_test_impl(ctx):
    """Test string length validation."""
    env = unittest.begin(ctx)

    # Within limit
    is_valid, error = check_string_length("hello", "field", 10)
    asserts.true(env, is_valid)
    asserts.equals(env, None, error)

    # Exceeds limit
    is_valid, error = check_string_length("hello world", "field", 5)
    asserts.false(env, is_valid)
    asserts.equals(env, "Field must be 5 characters or less", error)

    return unittest.end(env)

check_string_length_test = unittest.make(_check_string_length_test_impl)

def _format_error_message_test_impl(ctx):
    """Test error message formatting."""
    env = unittest.begin(ctx)

    # Simple field name
    msg = format_error_message("namespace", "cannot be empty")
    asserts.equals(env, "Namespace cannot be empty", msg)

    # Field name with underscore
    msg = format_error_message("release_name", "is invalid")
    asserts.equals(env, "Release Name is invalid", msg)

    # Field name already capitalized
    msg = format_error_message("URL", "must be valid")
    asserts.equals(env, "URL must be valid", msg)

    return unittest.end(env)

format_error_message_test = unittest.make(_format_error_message_test_impl)

def _aggregate_validation_errors_test_impl(ctx):
    """Test error aggregation."""
    env = unittest.begin(ctx)

    # All valid
    all_valid, errors = aggregate_validation_errors([
        (True, None),
        (True, None),
    ])
    asserts.true(env, all_valid)
    asserts.equals(env, (), errors)

    # Some invalid
    all_valid, errors = aggregate_validation_errors([
        (True, None),
        (False, "Error 1"),
        (False, "Error 2"),
    ])
    asserts.false(env, all_valid)
    asserts.equals(env, ("Error 1", "Error 2"), errors)

    # Invalid with None error
    all_valid, errors = aggregate_validation_errors([
        (False, None),
        (False, "Error 1"),
    ])
    asserts.false(env, all_valid)
    asserts.equals(env, ("Error 1",), errors)

    return unittest.end(env)

aggregate_validation_errors_test = unittest.make(_aggregate_validation_errors_test_impl)

def _join_errors_test_impl(ctx):
    """Test error joining."""
    env = unittest.begin(ctx)

    # No errors
    result = join_errors([])
    asserts.equals(env, None, result)

    # Single error
    result = join_errors(["Error 1"])
    asserts.equals(env, "Error 1", result)

    # Multiple errors with default separator
    result = join_errors(["Error 1", "Error 2", "Error 3"])
    asserts.equals(env, "Error 1; Error 2; Error 3", result)

    # Custom separator
    result = join_errors(["Error 1", "Error 2"], " | ")
    asserts.equals(env, "Error 1 | Error 2", result)

    return unittest.end(env)

join_errors_test = unittest.make(_join_errors_test_impl)

def _character_validator_helpers_test_impl(ctx):
    """Test character validation helper functions."""
    env = unittest.begin(ctx)

    # is_alphanumeric_or_hyphen
    asserts.true(env, is_alphanumeric_or_hyphen("a"))
    asserts.true(env, is_alphanumeric_or_hyphen("Z"))
    asserts.true(env, is_alphanumeric_or_hyphen("5"))
    asserts.true(env, is_alphanumeric_or_hyphen("-"))
    asserts.false(env, is_alphanumeric_or_hyphen("_"))
    asserts.false(env, is_alphanumeric_or_hyphen("."))

    # is_alphanumeric_hyphen_or_underscore
    asserts.true(env, is_alphanumeric_hyphen_or_underscore("a"))
    asserts.true(env, is_alphanumeric_hyphen_or_underscore("-"))
    asserts.true(env, is_alphanumeric_hyphen_or_underscore("_"))
    asserts.false(env, is_alphanumeric_hyphen_or_underscore("."))

    # is_lowercase_letter
    asserts.true(env, is_lowercase_letter("a"))
    asserts.true(env, is_lowercase_letter("z"))
    asserts.false(env, is_lowercase_letter("A"))
    asserts.false(env, is_lowercase_letter("1"))
    asserts.false(env, is_lowercase_letter("-"))

    return unittest.end(env)

character_validator_helpers_test = unittest.make(_character_validator_helpers_test_impl)

def _validate_characters_test_impl(ctx):
    """Test character validation."""
    env = unittest.begin(ctx)

    # Valid characters
    is_valid, error = validate_characters(
        "hello-world",
        "field",
        "alphanumeric or hyphen",
        is_alphanumeric_or_hyphen,
    )
    asserts.true(env, is_valid)
    asserts.equals(env, None, error)

    # Invalid characters
    is_valid, error = validate_characters(
        "hello_world",
        "field",
        "alphanumeric or hyphen",
        is_alphanumeric_or_hyphen,
    )
    asserts.false(env, is_valid)
    asserts.equals(env, "Field can only contain alphanumeric or hyphen", error)

    return unittest.end(env)

validate_characters_test = unittest.make(_validate_characters_test_impl)

def _check_first_character_test_impl(ctx):
    """Test first character validation."""
    env = unittest.begin(ctx)

    # Valid first character
    is_valid, error = check_first_character(
        "hello",
        "field",
        "a lowercase letter",
        is_lowercase_letter,
    )
    asserts.true(env, is_valid)
    asserts.equals(env, None, error)

    # Invalid first character
    is_valid, error = check_first_character(
        "Hello",
        "field",
        "a lowercase letter",
        is_lowercase_letter,
    )
    asserts.false(env, is_valid)
    asserts.equals(env, "Field must start with a lowercase letter", error)

    # Empty string
    is_valid, error = check_first_character(
        "",
        "field",
        "a lowercase letter",
        is_lowercase_letter,
    )
    asserts.true(env, is_valid)  # Empty values handled elsewhere
    asserts.equals(env, None, error)

    return unittest.end(env)

check_first_character_test = unittest.make(_check_first_character_test_impl)

def _check_last_character_test_impl(ctx):
    """Test last character validation."""
    env = unittest.begin(ctx)

    # Valid last character
    is_valid, error = check_last_character(
        "hello",
        "field",
        "a hyphen",
        lambda c: c == "-",
    )
    asserts.true(env, is_valid)
    asserts.equals(env, None, error)

    # Invalid last character
    is_valid, error = check_last_character(
        "hello-",
        "field",
        "a hyphen",
        lambda c: c == "-",
    )
    asserts.false(env, is_valid)
    asserts.equals(env, "Field cannot end with a hyphen", error)

    # Empty string
    is_valid, error = check_last_character(
        "",
        "field",
        "a hyphen",
        lambda c: c == "-",
    )
    asserts.true(env, is_valid)  # Empty values handled elsewhere
    asserts.equals(env, None, error)

    return unittest.end(env)

check_last_character_test = unittest.make(_check_last_character_test_impl)

def _starts_with_any_test_impl(ctx):
    """Test prefix checking."""
    env = unittest.begin(ctx)

    # Match found
    asserts.true(env, starts_with_any("https://example.com", ("http://", "https://")))
    asserts.true(env, starts_with_any("http://example.com", ("http://", "https://")))

    # No match
    asserts.false(env, starts_with_any("ftp://example.com", ("http://", "https://")))
    asserts.false(env, starts_with_any("example.com", ("http://", "https://")))

    return unittest.end(env)

starts_with_any_test = unittest.make(_starts_with_any_test_impl)

def _validate_numeric_part_test_impl(ctx):
    """Test numeric validation."""
    env = unittest.begin(ctx)

    # Valid numeric
    is_valid, error = validate_numeric_part("12345", 0, 5)
    asserts.true(env, is_valid)
    asserts.equals(env, None, error)

    # Valid numeric substring
    is_valid, error = validate_numeric_part("abc123def", 3, 6)
    asserts.true(env, is_valid)
    asserts.equals(env, None, error)

    # Contains non-numeric
    is_valid, error = validate_numeric_part("12a45", 0, 5)
    asserts.false(env, is_valid)
    asserts.true(env, "non-digit" in error if error else False)

    # Empty substring
    is_valid, error = validate_numeric_part("abc", 1, 1)
    asserts.false(env, is_valid)
    asserts.true(env, "Invalid index range" in error if error else False)

    return unittest.end(env)

validate_numeric_part_test = unittest.make(_validate_numeric_part_test_impl)

def _is_bazel_label_test_impl(ctx):
    """Test Bazel label detection."""
    env = unittest.begin(ctx)

    # Relative labels (start with ":")
    asserts.true(env, is_bazel_label(":my_target"))
    asserts.true(env, is_bazel_label(":chart_target"))
    asserts.true(env, is_bazel_label(":cilium_charts"))
    asserts.true(env, is_bazel_label(":path/to/chart"))

    # Absolute labels (contain "//")
    asserts.true(env, is_bazel_label("//path/to:target"))
    asserts.true(env, is_bazel_label("@repo//path:target"))
    asserts.true(env, is_bazel_label("//charts/nginx"))
    asserts.true(env, is_bazel_label("@external_repo//charts/prometheus:chart"))

    # Repository chart names (not Bazel labels)
    asserts.false(env, is_bazel_label("nginx"))
    asserts.false(env, is_bazel_label("bitnami/nginx"))
    asserts.false(env, is_bazel_label("prometheus/prometheus"))
    asserts.false(env, is_bazel_label("stable/mysql"))

    # URL-like strings (not Bazel labels)
    asserts.false(env, is_bazel_label("https://charts.bitnami.com/bitnami"))
    asserts.false(env, is_bazel_label("oci://registry.example.com/charts"))

    # Empty or invalid inputs
    asserts.false(env, is_bazel_label(""))
    asserts.false(env, is_bazel_label("plain-string"))
    asserts.false(env, is_bazel_label("path/without/double/slash"))

    return unittest.end(env)

is_bazel_label_test = unittest.make(_is_bazel_label_test_impl)

def utils_test_suite(name = "utils_tests"):
    """Test suite for utility functions."""
    unittest.suite(        name,
        check_empty_test,
        check_string_length_test,
        format_error_message_test,
        aggregate_validation_errors_test,
        join_errors_test,
        character_validator_helpers_test,
        validate_characters_test,
        check_first_character_test,
        check_last_character_test,
        starts_with_any_test,
        validate_numeric_part_test,
        is_bazel_label_test)
