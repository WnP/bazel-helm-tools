"""Utility functions for Helm tools following functional programming principles.

All functions are pure with no side effects and return immutable data structures.
"""

def check_empty(value, field_name):
    """Checks if a value is empty and returns appropriate error.

    Pure function for consistent empty value validation.

    Args:
        value: Value to check
        field_name: Name of the field being validated

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    if not value:
        return (False, format_error_message(field_name, "cannot be empty"))
    return (True, None)

def check_string_length(value, field_name, max_length):
    """Validates string length against maximum.

    Pure function for consistent length validation.

    Args:
        value: String value to check
        field_name: Name of the field being validated
        max_length: Maximum allowed length

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    if len(value) > max_length:
        return (False, format_error_message(
            field_name,
            "must be {} characters or less".format(max_length),
        ))
    return (True, None)

def validate_characters(value, field_name, allowed_chars_description, char_validator):
    """Validates each character in a string using a validator function.

    Pure function for character-by-character validation.

    Args:
        value: String to validate
        field_name: Name of the field being validated
        allowed_chars_description: Human-readable description of allowed characters
        char_validator: Function that takes a character and returns True if valid

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    for i in range(len(value)):
        char = value[i]
        if not char_validator(char):
            return (False, format_error_message(
                field_name,
                "can only contain {}".format(allowed_chars_description),
            ))
    return (True, None)

def check_first_character(value, field_name, description, validator):
    """Validates the first character of a string.

    Pure function for first character validation.

    Args:
        value: String to check
        field_name: Name of the field being validated
        description: Description of valid first character
        validator: Function that validates the first character

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    if not value:
        return (True, None)  # Empty values handled elsewhere

    if not validator(value[0]):
        return (False, format_error_message(
            field_name,
            "must start with {}".format(description),
        ))
    return (True, None)

def check_last_character(value, field_name, invalid_description, is_invalid):
    """Validates the last character of a string.

    Pure function for last character validation.

    Args:
        value: String to check
        field_name: Name of the field being validated
        invalid_description: Description of invalid last character
        is_invalid: Function that returns True if character is invalid

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    if not value:
        return (True, None)  # Empty values handled elsewhere

    if is_invalid(value[len(value) - 1]):
        return (False, format_error_message(
            field_name,
            "cannot end with {}".format(invalid_description),
        ))
    return (True, None)

def format_error_message(field_name, problem):
    """Creates a consistent error message format.

    Pure function for error message formatting.

    Args:
        field_name: Name of the field with the error
        problem: Description of the problem

    Returns:
        Formatted error message string
    """
    # Handle field name formatting
    if "_" in field_name:
        # Replace underscores with spaces and title case
        display_name = field_name.replace("_", " ").title()
    else:
        # Check if it's already all caps (like "URL")
        is_all_caps = True
        for i in range(len(field_name)):
            if field_name[i].isalpha() and field_name[i].islower():
                is_all_caps = False
                break

        if is_all_caps and len(field_name) > 1:
            # Keep all caps field names as-is
            display_name = field_name
        else:
            # Capitalize first letter only
            display_name = field_name.capitalize()

    return "{} {}".format(display_name, problem)

def aggregate_validation_errors(validations):
    """Aggregates multiple validation results into a single result.

    Pure function that combines validation results.

    Args:
        validations: List of (is_valid, error_message) tuples

    Returns:
        Tuple of (all_valid: bool, errors: tuple of error messages)
    """
    errors = []
    all_valid = True

    for is_valid, error in validations:
        if not is_valid:
            all_valid = False
            if error:
                errors.append(error)

    return (all_valid, tuple(errors))

def join_errors(errors, separator = "; "):
    """Joins error messages into a single string.

    Pure function for consistent error joining.

    Args:
        errors: Tuple or list of error messages
        separator: String to use between errors (default: "; ")

    Returns:
        Joined error string or None if no errors
    """
    if not errors:
        return None
    return separator.join(errors)

def is_alphanumeric_or_hyphen(char):
    """Checks if character is alphanumeric or hyphen.

    Pure helper function for common character validation.

    Args:
        char: Character to check

    Returns:
        True if character is alphanumeric or hyphen
    """
    return char.isalnum() or char == "-"

def is_alphanumeric_hyphen_or_underscore(char):
    """Checks if character is alphanumeric, hyphen, or underscore.

    Pure helper function for common character validation.

    Args:
        char: Character to check

    Returns:
        True if character is alphanumeric, hyphen, or underscore
    """
    return char.isalnum() or char == "-" or char == "_"

def is_lowercase_letter(char):
    """Checks if character is a lowercase letter.

    Pure helper function for character validation.

    Args:
        char: Character to check

    Returns:
        True if character is a lowercase letter
    """
    return char.isalpha() and char.islower()

def starts_with_any(value, prefixes):
    """Checks if a string starts with any of the given prefixes.

    Pure function for prefix checking.

    Args:
        value: String to check
        prefixes: Tuple of prefix strings

    Returns:
        True if value starts with any prefix
    """
    for prefix in prefixes:
        if value.startswith(prefix):
            return True
    return False

def validate_numeric_part(value, start_index, end_index):
    """Validates that a substring contains only digits.

    Pure function for numeric validation.

    Args:
        value: String containing the substring
        start_index: Starting index (inclusive)
        end_index: Ending index (exclusive)

    Returns:
        Tuple of (is_valid: bool, error_message: string or None)
    """
    if end_index <= start_index:
        return (False, "Invalid index range for numeric validation")

    substring = value[start_index:end_index] if end_index < len(value) else value[start_index:]

    if not substring:
        return (False, "Numeric part cannot be empty")

    for i in range(len(substring)):
        if not substring[i].isdigit():
            return (False, "Value '{}' contains non-digit characters".format(substring))

    return (True, None)

def is_bazel_label(value):
    """Determines if a string is a Bazel label reference.

    Pure function that checks if a string follows Bazel label patterns:
    - Starts with ":" for relative labels (e.g., ":chart_target")
    - Contains "//" but not as part of a URL scheme for absolute labels (e.g., "//path/to:target")

    Args:
        value: String to check

    Returns:
        True if value appears to be a Bazel label, False otherwise
    """
    if not value:
        return False

    # Check for relative label pattern (starts with ":")
    if value.startswith(":"):
        return True

    # Check for URL schemes first to exclude them
    url_schemes = ("http://", "https://", "oci://", "file://", "ftp://", "ssh://", "git://")
    for scheme in url_schemes:
        if value.startswith(scheme):
            return False

    # Check for absolute label pattern (contains "//" but not as URL)
    if "//" in value:
        return True

    return False
