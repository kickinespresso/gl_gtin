//// Check digit calculation module for GTIN codes.
////
//// Implements the GS1 Modulo 10 algorithm for calculating and validating
//// GTIN check digits.

import gl_gtin/internal/utils
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// Error type for check digit operations
pub type CheckDigitError {
  InvalidLength(got: Int)
  InvalidCharacters
}

/// Calculate the weighted sum of digits using alternating weights (3, 1, 3, 1, ...).
///
/// This is a recursive helper function that processes digits from right to left,
/// applying alternating weights of 3 and 1.
///
/// # Arguments
///
/// * `digits` - List of digits to process (should be reversed for right-to-left processing)
/// * `weight` - Current weight (3 or 1), alternates with each digit
/// * `accumulator` - Running sum of weighted products
///
/// # Returns
///
/// The total weighted sum of all digits.
fn calculate_weighted_sum(
  digits: List(Int),
  weight: Int,
  accumulator: Int,
) -> Int {
  case digits {
    [] -> accumulator
    [digit, ..rest] -> {
      let product = digit * weight
      let next_weight = case weight {
        3 -> 1
        _ -> 3
      }
      calculate_weighted_sum(rest, next_weight, accumulator + product)
    }
  }
}

/// Calculate the check digit for a list of digits.
///
/// Implements the GS1 Modulo 10 algorithm:
/// 1. Multiply digits alternately by 3 and 1 from right to left
/// 2. Sum all products
/// 3. Calculate modulo 10 of the sum
/// 4. If result is 0, check digit is 0; otherwise check digit is (10 - result)
///
/// # Arguments
///
/// * `digits` - List of digits (without check digit)
///
/// # Returns
///
/// Ok(check_digit) if successful, Error if the digit list is invalid.
///
/// # Examples
///
/// ```gleam
/// calculate([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
/// // -> Ok(3)
/// ```
pub fn calculate(digits: List(Int)) -> Result(Int, CheckDigitError) {
  use _ <- result.try(validate_body(digits))
  // Reverse the list to process from right to left
  let reversed = list.reverse(digits)
  // Calculate weighted sum starting with weight 3
  let weighted_sum = calculate_weighted_sum(reversed, 3, 0)
  // Calculate modulo 10
  let modulo = weighted_sum % 10
  // Determine check digit
  let check_digit = case modulo {
    0 -> 0
    _ -> 10 - modulo
  }
  Ok(check_digit)
}

/// Validate a digit list whose final element is its check digit.
///
/// Splits the list into its leading body and final element, computes the
/// check digit for the body via the GS1 Modulo 10 algorithm, and returns
/// `True` only when the final element equals that computed check digit.
/// An empty list has no body to check against and returns `False`; any
/// input for which `calculate` errors (for example a body containing an
/// out-of-range element) also returns `False`.
///
/// # Arguments
///
/// * `digits` - List of digits whose last element is treated as the check digit
///
/// # Returns
///
/// `True` if the last element matches the computed check digit, `False` otherwise.
///
/// # Examples
///
/// ```gleam
/// valid([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
/// // -> True
///
/// valid([])
/// // -> False
/// ```
pub fn valid(digits: List(Int)) -> Bool {
  case list.reverse(digits) {
    [] -> False
    [check, ..reversed_body] -> {
      let body = list.reverse(reversed_body)
      case calculate(body) {
        Ok(expected) -> expected == check
        Error(_) -> False
      }
    }
  }
}

/// Append the computed check digit to a digit body.
///
/// Validates the body via the same guard as `calculate` (non-empty and every
/// element in 0..9), computes the check digit with the GS1 Modulo 10 algorithm,
/// and returns the original body with that check digit appended as its final
/// element. This is the inverse of `valid`: `valid(append(body))` is always
/// `True` for any well-formed body.
///
/// # Arguments
///
/// * `digits` - List of body digits (without a check digit)
///
/// # Returns
///
/// Ok(digits ++ [check_digit]) if the body is well-formed,
/// Error(InvalidLength(got: 0)) for an empty list, or
/// Error(InvalidCharacters) if any element is outside 0..9.
///
/// # Examples
///
/// ```gleam
/// append([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
/// // -> Ok([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
///
/// append([])
/// // -> Error(InvalidLength(got: 0))
/// ```
pub fn append(digits: List(Int)) -> Result(List(Int), CheckDigitError) {
  use _ <- result.try(validate_body(digits))
  use check <- result.try(calculate(digits))
  Ok(list.append(digits, [check]))
}

/// Validate that a digit body is well-formed for check digit calculation.
///
/// A valid body is non-empty and every element is a single decimal digit
/// in the range 0 through 9. Unlike the previous length cap, any non-empty
/// body is accepted so that longer GS1 keys (such as SSCC and GSIN) can reuse
/// the same mod-10 routine.
///
/// # Arguments
///
/// * `digits` - List of digits to validate
///
/// # Returns
///
/// Ok(Nil) if the body is non-empty and every element is in 0..9,
/// Error(InvalidLength(got: 0)) for an empty list, or
/// Error(InvalidCharacters) if any element is outside 0..9.
fn validate_body(digits: List(Int)) -> Result(Nil, CheckDigitError) {
  case digits {
    [] -> Error(InvalidLength(got: 0))
    _ ->
      case list.all(digits, fn(digit) { digit >= 0 && digit <= 9 }) {
        True -> Ok(Nil)
        False -> Error(InvalidCharacters)
      }
  }
}

/// Parse a string to a list of digits.
///
/// Converts each character in the string to an integer digit.
/// Returns an error if any character is not a digit.
/// Used internally during check digit generation.
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
fn parse_digits(code: String) -> Result(List(Int), CheckDigitError) {
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

/// Validate that a string has a valid length for GTIN generation.
///
/// Valid lengths for generation are 7, 11, 12, and 13 digits
/// (which produce 8, 12, 13, and 14 digit GTINs respectively).
/// This ensures we only generate GTINs in the standard formats.
///
/// # Arguments
///
/// * `length` - Length to validate
///
/// # Returns
///
/// Ok(Nil) if valid, Error(InvalidLength(got: length)) otherwise.
///
/// # Examples
///
/// ```gleam
/// validate_generation_length(7)
/// // -> Ok(Nil)
///
/// validate_generation_length(12)
/// // -> Ok(Nil)
///
/// validate_generation_length(10)
/// // -> Error(InvalidLength(got: 10))
/// ```
fn validate_generation_length(length: Int) -> Result(Nil, CheckDigitError) {
  case length {
    7 | 11 | 12 | 13 -> Ok(Nil)
    _ -> Error(InvalidLength(got: length))
  }
}

/// Generate a complete GTIN with calculated check digit.
///
/// Takes an incomplete GTIN (7, 11, 12, or 13 digits) and calculates the check digit
/// to produce a complete GTIN (8, 12, 13, or 14 digits respectively).
///
/// # Arguments
///
/// * `code` - Incomplete GTIN string
///
/// # Returns
///
/// Ok(complete_gtin) if successful, Error otherwise.
///
/// # Examples
///
/// ```gleam
/// generate("629104150021")
/// // -> Ok("6291041500213")
///
/// generate("123456789012")
/// // -> Ok("1234567890128")
/// ```
pub fn generate(code: String) -> Result(String, CheckDigitError) {
  use digits <- result.try(parse_digits(code))
  use _ <- result.try(validate_generation_length(list.length(digits)))
  use check_digit <- result.try(calculate(digits))

  // Append check digit to the original code
  let complete = code <> int.to_string(check_digit)
  Ok(complete)
}
