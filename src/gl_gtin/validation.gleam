//// Validation module for GTIN codes.
////
//// Implements core validation logic for GTIN codes including format detection,
//// check digit verification, and GTIN normalization.

import gleam/list
import gleam/result
import gleam/string
import gl_gtin/check_digit
import gl_gtin/internal/utils

/// GTIN format type
pub type GtinFormat {
  Gtin8
  Gtin12
  Gtin13
  Gtin14
}

/// Error type for validation operations
pub type ValidationError {
  InvalidLength(got: Int)
  InvalidCheckDigit
  InvalidCharacters
  InvalidFormat
}

/// Determine the GTIN format from a digit count.
///
/// Maps digit counts to their corresponding GTIN format types.
/// Valid lengths are 8, 12, 13, and 14 digits.
///
/// # Arguments
///
/// * `length` - Number of digits
///
/// # Returns
///
/// Ok(GtinFormat) if the length is valid (8, 12, 13, or 14), Error otherwise.
///
/// # Examples
///
/// ```gleam
/// validate_length(8)
/// // -> Ok(Gtin8)
///
/// validate_length(13)
/// // -> Ok(Gtin13)
///
/// validate_length(10)
/// // -> Error(InvalidLength(got: 10))
/// ```
fn validate_length(length: Int) -> Result(GtinFormat, ValidationError) {
  case length {
    8 -> Ok(Gtin8)
    12 -> Ok(Gtin12)
    13 -> Ok(Gtin13)
    14 -> Ok(Gtin14)
    _ -> Error(InvalidLength(got: length))
  }
}

/// Parse a string to a list of digits.
///
/// Converts each character in the string to an integer digit.
/// Returns an error if any character is not a digit.
/// This is used internally during validation to convert the input string.
///
/// # Arguments
///
/// * `code` - String to parse
///
/// # Returns
///
/// Ok(digit_list) if all characters are digits, Error(InvalidCharacters) otherwise.
///
/// # Examples
///
/// ```gleam
/// parse_digits("12345")
/// // -> Ok([1, 2, 3, 4, 5])
///
/// parse_digits("123a5")
/// // -> Error(InvalidCharacters)
/// ```
fn parse_digits(code: String) -> Result(List(Int), ValidationError) {
  let chars = string.split(code, "")
  let parsed =
    list.try_map(chars, fn(char) {
      case utils.parse_digit(char) {
        Ok(digit) -> Ok(digit)
        Error(_) -> Error(InvalidCharacters)
      }
    })
  parsed
}

/// Validate the check digit of a GTIN.
///
/// Extracts all digits except the last one, calculates what the check digit
/// should be using the GS1 Modulo 10 algorithm, and compares it to the actual check digit.
/// This is a critical validation step that ensures data integrity.
///
/// # Arguments
///
/// * `digits` - List of all digits including check digit
///
/// # Returns
///
/// Ok(Nil) if check digit is valid, Error(InvalidCheckDigit) otherwise.
///
/// # Examples
///
/// ```gleam
/// validate_check_digit([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
/// // -> Ok(Nil)
///
/// validate_check_digit([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 4])
/// // -> Error(InvalidCheckDigit)
/// ```
fn validate_check_digit(digits: List(Int)) -> Result(Nil, ValidationError) {
  case list.length(digits) {
    0 -> Error(InvalidLength(got: 0))
    len -> {
      // Get all digits except the last one
      let digits_without_check = list.take(digits, len - 1)
      // Get the actual check digit (last digit)
      let actual_check = utils.last_digit(digits)

      // Calculate what the check digit should be
      case check_digit.calculate(digits_without_check) {
        Ok(expected_check) -> {
          case actual_check == expected_check {
            True -> Ok(Nil)
            False -> Error(InvalidCheckDigit)
          }
        }
        Error(_) -> Error(InvalidCheckDigit)
      }
    }
  }
}

/// Validate a GTIN code string.
///
/// Checks that the input is a valid GTIN (8, 12, 13, or 14 digits) with a correct check digit.
/// Automatically trims leading and trailing whitespace before validation.
///
/// # Arguments
///
/// * `code` - GTIN string to validate
///
/// # Returns
///
/// Ok(GtinFormat) if valid, Error otherwise.
///
/// # Examples
///
/// ```gleam
/// validate("6291041500213")
/// // -> Ok(Gtin13)
///
/// validate("012345678905")
/// // -> Ok(Gtin12)
///
/// validate("invalid")
/// // -> Error(InvalidCharacters)
/// ```
pub fn validate(code: String) -> Result(GtinFormat, ValidationError) {
  // Trim whitespace
  let trimmed = string.trim(code)

  // Parse to digits
  use digits <- result.try(parse_digits(trimmed))

  // Validate length
  use format <- result.try(validate_length(list.length(digits)))

  // Validate check digit
  use _ <- result.try(validate_check_digit(digits))

  Ok(format)
}

/// Convert a GTIN-13 to GTIN-14 format.
///
/// Prepends the indicator digit "1" and recalculates the check digit.
/// Only works with GTIN-13 codes; other formats return an error.
///
/// # Arguments
///
/// * `code` - GTIN-13 string to normalize
///
/// # Returns
///
/// Ok(gtin_14) if successful, Error otherwise.
///
/// # Examples
///
/// ```gleam
/// normalize("6291041500213")
/// // -> Ok("16291041500214")
///
/// normalize("012345678905")
/// // -> Error(InvalidFormat)
/// ```
pub fn normalize(code: String) -> Result(String, ValidationError) {
  // First validate that it's a valid GTIN
  use format <- result.try(validate(code))

  // Check that it's GTIN-13
  case format {
    Gtin13 -> {
      // Prepend "1" to the code (without the check digit)
      let without_check = string.slice(code, 0, string.length(code) - 1)
      let with_indicator = "1" <> without_check

      // Generate the new check digit
      case check_digit.generate(with_indicator) {
        Ok(gtin_14) -> Ok(gtin_14)
        Error(_) -> Error(InvalidFormat)
      }
    }
    _ -> Error(InvalidFormat)
  }
}
