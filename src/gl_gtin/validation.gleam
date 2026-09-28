//// Validation module for GTIN codes.
////
//// Implements core validation logic for GTIN codes including format detection,
//// check digit verification, and GTIN normalization.

import gl_gtin/check_digit
import gl_gtin/internal/utils
import gleam/int
import gleam/list
import gleam/result
import gleam/string

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

/// Convert a GTIN-13 to GTIN-14 format using a configurable indicator digit.
///
/// Prepends the supplied indicator digit (0 through 9) to the 12 data digits of
/// the GTIN-13 and recalculates the check digit. Leading and trailing whitespace
/// is trimmed before validation. Only works with GTIN-13 codes; other formats
/// return an error, and an indicator outside 0 through 9 returns
/// `Error(InvalidFormat)`.
///
/// # Arguments
///
/// * `code` - GTIN-13 string to normalize
/// * `indicator` - Indicator digit for the GTIN-14 packaging level (0 through 9)
///
/// # Returns
///
/// Ok(gtin_14) if successful, Error otherwise.
///
/// # Examples
///
/// ```gleam
/// normalize_with_indicator("6291041500213", 1)
/// // -> Ok("16291041500210")
///
/// normalize_with_indicator("6291041500213", 2)
/// // -> Ok("26291041500217")
///
/// normalize_with_indicator("6291041500213", 10)
/// // -> Error(InvalidFormat)
/// ```
pub fn normalize_with_indicator(
  code: String,
  indicator: Int,
) -> Result(String, ValidationError) {
  // Trim once up front and validate the trimmed value.
  let trimmed = string.trim(code)

  // First validate that it's a valid GTIN
  use format <- result.try(validate(trimmed))

  // Check that it's GTIN-13 and that the indicator is a single digit 0..9.
  case format, indicator {
    Gtin13, indicator if indicator >= 0 && indicator <= 9 -> {
      // Prepend the indicator to the 12 data digits (drop the check digit).
      let without_check = string.slice(trimmed, 0, string.length(trimmed) - 1)
      let with_indicator = int.to_string(indicator) <> without_check

      // Generate the new check digit, preserving the existing error surface
      check_digit.generate(with_indicator)
      |> result.map_error(fn(_) { InvalidFormat })
    }
    _, _ -> Error(InvalidFormat)
  }
}

/// Validate that a trimmed code is a GTIN-14 and return its digit list.
///
/// Trims leading and trailing whitespace, parses the input to digits, and
/// checks that it is exactly 14 digits with a correct check digit. The error
/// ordering mirrors `validate` (characters, then length, then check digit) so
/// that the down-conversion functions surface the same invalid-input errors.
///
/// # Arguments
///
/// * `code` - Candidate GTIN-14 string
///
/// # Returns
///
/// Ok(digits) with the 14 parsed digits if the code is a valid GTIN-14,
/// Error(InvalidCharacters) if any character is non-numeric,
/// Error(InvalidLength(got: n)) if the trimmed digit count is not 14, or
/// Error(InvalidCheckDigit) if the check digit is incorrect.
fn require_gtin14(code: String) -> Result(List(Int), ValidationError) {
  // Trim whitespace to mirror `validate`.
  let trimmed = string.trim(code)

  // Parse to digits (characters checked first, matching `validate`).
  use digits <- result.try(parse_digits(trimmed))

  // Require exactly 14 digits.
  case list.length(digits) {
    14 -> {
      // Validate the check digit last, matching `validate`.
      use _ <- result.try(validate_check_digit(digits))
      Ok(digits)
    }
    other -> Error(InvalidLength(got: other))
  }
}

/// Convert a GTIN-14 with indicator digit 0 to its base GTIN-13.
///
/// Requires a valid GTIN-14 (14 digits, correct check digit). When the leading
/// indicator digit is 0, the leading `0` is dropped and the existing check
/// digit is preserved without recomputation, yielding a 13-digit string. A
/// non-zero indicator returns `Error(InvalidFormat)`. Leading and trailing
/// whitespace is trimmed before validation, and the invalid-input error
/// ordering matches `validate`.
///
/// # Arguments
///
/// * `code` - GTIN-14 string to down-convert
///
/// # Returns
///
/// Ok(gtin_13) if the indicator digit is 0, Error otherwise.
///
/// # Examples
///
/// ```gleam
/// to_gtin13("06291041500213")
/// // -> Ok("6291041500213")
///
/// to_gtin13("16291041500210")
/// // -> Error(InvalidFormat)
/// ```
pub fn to_gtin13(code: String) -> Result(String, ValidationError) {
  use digits <- result.try(require_gtin14(code))

  // Inspect the indicator (first digit): only 0 may be stripped.
  case digits {
    [0, ..] -> {
      let trimmed = string.trim(code)
      // Drop the leading indicator `0`, keeping the existing check digit.
      Ok(string.slice(trimmed, 1, string.length(trimmed) - 1))
    }
    _ -> Error(InvalidFormat)
  }
}

/// Convert a GTIN-14 with indicator digit 0 to its base GTIN-12 (UPC-A).
///
/// Requires a valid GTIN-14 (14 digits, correct check digit). The indicator
/// digit (first digit) must be 0; a non-zero indicator returns
/// `Error(InvalidFormat)`. When the indicator is 0, the base 13-digit code
/// (after dropping the indicator) must itself be a UPC-A padded with an
/// implicit leading zero — that is, the second digit of the GTIN-14 must also
/// be 0. In that case both leading zeros are dropped to yield the 12-digit
/// UPC-A, preserving the existing check digit without recomputation. When the
/// base code cannot be represented as a GTIN-12, `Error(InvalidFormat)` is
/// returned. Leading and trailing whitespace is trimmed before validation, and
/// the invalid-input error ordering matches `validate`.
///
/// # Arguments
///
/// * `code` - GTIN-14 string to down-convert
///
/// # Returns
///
/// Ok(gtin_12) if the indicator digit is 0 and the base code is a UPC-A with an
/// implicit leading zero, Error otherwise.
///
/// # Examples
///
/// ```gleam
/// to_gtin12("00042100005264")
/// // -> Ok("042100005264")
///
/// to_gtin12("00629104150021") // base is EAN-13, not a UPC-A
/// // -> Error(InvalidFormat)
/// ```
pub fn to_gtin12(code: String) -> Result(String, ValidationError) {
  use digits <- result.try(require_gtin14(code))

  // Inspect the indicator and the implicit UPC-A leading-zero digit.
  // A GTIN-14 shaped "0" <> ("0" <> gtin12) is a UPC-A padded to 13 with a
  // leading zero, so both leading digits must be 0 to strip down to a GTIN-12.
  case digits {
    [0, 0, ..] -> {
      let trimmed = string.trim(code)
      // Drop both leading zeros, keeping the existing check digit, to yield the
      // 12-digit UPC-A.
      let gtin12 = string.slice(trimmed, 2, string.length(trimmed) - 2)

      // Confirm the result validates as a GTIN-12 (Requirement 6.7).
      case validate(gtin12) {
        Ok(Gtin12) -> Ok(gtin12)
        _ -> Error(InvalidFormat)
      }
    }
    [0, ..] -> Error(InvalidFormat)
    _ -> Error(InvalidFormat)
  }
}

/// Convert a GTIN-13 to GTIN-14 format.
///
/// Prepends the indicator digit "1" and recalculates the check digit.
/// Only works with GTIN-13 codes; other formats return an error. This is
/// equivalent to `normalize_with_indicator(code, 1)`.
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
/// // -> Ok("16291041500210")
///
/// normalize("012345678905")
/// // -> Error(InvalidFormat)
/// ```
pub fn normalize(code: String) -> Result(String, ValidationError) {
  normalize_with_indicator(code, 1)
}
