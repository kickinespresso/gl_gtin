//// UPC-E ⇄ UPC-A conversion module (F1).
////
//// Implements the GS1 zero-suppression rules that expand a compressed 8-digit
//// UPC-E code to its full 12-digit UPC-A form (and, in a later task, compress a
//// UPC-A back to UPC-E). These functions work directly in the public
//// `GtinError` type because their failure conditions are exactly the public
//// error variants and they compose the shared check-digit engine.

import gl_gtin/check_digit
import gl_gtin/gtin_types.{
  type GtinError, InvalidCharacters, InvalidCheckDigit, InvalidFormat,
  InvalidLength,
}
import gl_gtin/internal/utils
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// Expand a compressed 8-digit UPC-E code to its full 12-digit UPC-A form.
///
/// A UPC-E code is 8 digits: a number-system digit (`NS`, which must be 0 or 1),
/// six body digits `X1 X2 X3 X4 X5 X6`, and a UPC-E check digit. The 6th body
/// digit `X6` selects the zero-suppression expansion that reconstructs the
/// 10-digit manufacturer-plus-item block of the UPC-A. The `NS` digit is
/// prepended, the check digit is recomputed via the GS1 Modulo 10 algorithm, and
/// the resulting 12-digit UPC-A string is returned.
///
/// Defects are evaluated in the order length, then character validity, then
/// number-system validity, and only the first matching error is returned with no
/// partial UPC-A produced.
///
/// # Arguments
///
/// * `code` - The UPC-E string to expand (leading/trailing whitespace is trimmed)
///
/// # Returns
///
/// Ok(upca) as a 12-digit string if the code is a valid UPC-E,
/// Error(InvalidLength(got: n)) if the trimmed length is not 8,
/// Error(InvalidCharacters) if any character is non-numeric,
/// Error(InvalidFormat) if the number-system digit is not 0 or 1.
///
/// # Examples
///
/// ```gleam
/// upce_to_upca("04252614")
/// // -> Ok("042100005264")
///
/// upce_to_upca("12345")
/// // -> Error(InvalidLength(got: 5))
///
/// upce_to_upca("24252614")
/// // -> Error(InvalidFormat)
/// ```
pub fn upce_to_upca(code: String) -> Result(String, GtinError) {
  // 1. Trim leading/trailing whitespace.
  let trimmed = string.trim(code)

  // 2. Length must be exactly 8.
  let length = string.length(trimmed)
  use _ <- result.try(case length {
    8 -> Ok(Nil)
    n -> Error(InvalidLength(got: n))
  })

  // 3. Every character must be numeric.
  use digits <- result.try(parse_digits(trimmed))

  // 4. Number-system digit (first digit) must be 0 or 1.
  case digits {
    [ns, x1, x2, x3, x4, x5, x6, _check] ->
      case ns {
        0 | 1 -> {
          // 5. Apply the expansion table to build the 10-digit
          //    manufacturer+item block, then prepend NS for the 11-digit body.
          let mfr_item = expand_body([x1, x2, x3, x4, x5, x6])
          let body = [ns, ..mfr_item]

          // 6. Recompute the check digit via the shared engine and render the
          //    12-digit UPC-A string.
          check_digit.append(body)
          |> result.map(digits_to_string)
          |> result.map_error(map_check_digit_error)
        }
        _ -> Error(InvalidFormat)
      }
    // parse_digits already guaranteed 8 digits; this branch is unreachable but
    // keeps the function total without `let assert`.
    _ -> Error(InvalidFormat)
  }
}

/// Compress a full 12-digit UPC-A code to its 8-digit UPC-E form when possible.
///
/// A UPC-A code is 12 digits: a number-system digit (`NS`), a 10-digit
/// manufacturer-plus-item block, and a UPC-A check digit. Compression to UPC-E
/// is only possible when `NS` is 0 or 1 and the manufacturer-plus-item block
/// matches one of the GS1 zero-suppression patterns (the exact inverse of the
/// expansion table used by `upce_to_upca`). When it matches, the six UPC-E body
/// digits are reconstructed and the resulting 8-digit UPC-E string is returned.
/// The UPC-E check digit is the same as the UPC-A check digit (the code is
/// validated first, so its final digit is already the correct check digit),
/// which keeps the `upca_to_upce`/`upce_to_upca` round-trip exact.
///
/// Defects are evaluated in the order character validity, then digit count, then
/// check-digit correctness, then compressibility, and only the first matching
/// error is returned with no partial UPC-E produced.
///
/// # Arguments
///
/// * `code` - The UPC-A string to compress (leading/trailing whitespace is trimmed)
///
/// # Returns
///
/// Ok(upce) as an 8-digit string if the code is a compressible UPC-A,
/// Error(InvalidCharacters) if any character is non-numeric,
/// Error(InvalidLength(got: n)) if the trimmed digit count is not 12,
/// Error(InvalidCheckDigit) if the check digit does not match,
/// Error(InvalidFormat) if the number-system digit is not 0 or 1 or the code is
/// not zero-suppressible.
///
/// # Examples
///
/// ```gleam
/// upca_to_upce("042100005264")
/// // -> Ok("04252614")
///
/// upca_to_upce("012345678905")
/// // -> Error(InvalidFormat)
/// ```
pub fn upca_to_upce(code: String) -> Result(String, GtinError) {
  // 1. Trim leading/trailing whitespace.
  let trimmed = string.trim(code)

  // 2. Every character must be numeric (checked before length per the ordering).
  use digits <- result.try(parse_digits(trimmed))

  // 3. Digit count must be exactly 12.
  use _ <- result.try(case list.length(digits) {
    12 -> Ok(Nil)
    n -> Error(InvalidLength(got: n))
  })

  // 4. The 12th digit must match the check digit of the first 11.
  use _ <- result.try(case check_digit.valid(digits) {
    True -> Ok(Nil)
    False -> Error(InvalidCheckDigit)
  })

  // 5. Split into NS + 10-digit manufacturer+item block + UPC-A check digit,
  //    then attempt to compress. NS must be 0 or 1 and the block must match a
  //    suppression pattern; either failure is reported as InvalidFormat.
  case digits {
    [ns, ..rest] ->
      case ns {
        0 | 1 -> {
          let mfr_item = list.take(rest, 10)
          // The UPC-E check digit is the same as the UPC-A check digit (already
          // validated in step 4 as the final of the 12 digits).
          let upca_check = case list.last(digits) {
            Ok(digit) -> digit
            Error(_) -> 0
          }
          case compress_body(mfr_item) {
            Ok(body) ->
              // 6. Build the 8-digit UPC-E: NS + 6 body digits + the UPC-E check
              //    digit (equal to the UPC-A check digit), then render it.
              Ok(digits_to_string(list.flatten([[ns], body, [upca_check]])))
            Error(_) -> Error(InvalidFormat)
          }
        }
        _ -> Error(InvalidFormat)
      }
    // parse_digits and the length guard already guaranteed 12 digits; this
    // branch is unreachable but keeps the function total without `let assert`.
    _ -> Error(InvalidFormat)
  }
}

/// Invert the zero-suppression expansion table to recover the six UPC-E body
/// digits from a 10-digit manufacturer-plus-item block.
///
/// This is the exact inverse of `expand_body`. Given the 10-digit block, it
/// matches one of the GS1 suppression patterns and reconstructs the body
/// `X1 X2 X3 X4 X5 X6`:
///
/// | 10-digit block                          | body                    |
/// |-----------------------------------------|-------------------------|
/// | `X1 X2 m 0 0 0 0 X3 X4 X5` (m∈{0,1,2})  | `X1 X2 X3 X4 X5 m`      |
/// | `X1 X2 X3 0 0 0 0 0 X4 X5`              | `X1 X2 X3 X4 X5 3`      |
/// | `X1 X2 X3 X4 0 0 0 0 0 X5`              | `X1 X2 X3 X4 X5 4`      |
/// | `X1 X2 X3 X4 X5 0 0 0 0 X6` (X6∈{5..9}) | `X1 X2 X3 X4 X5 X6`     |
///
/// Any block that does not match one of these patterns (or is not exactly ten
/// digits) returns `Error(Nil)`, signalling that the UPC-A is not compressible.
fn compress_body(mfr_item: List(Int)) -> Result(List(Int), Nil) {
  case mfr_item {
    [x1, x2, m, 0, 0, 0, 0, x3, x4, x5] if m == 0 || m == 1 || m == 2 ->
      Ok([x1, x2, x3, x4, x5, m])
    [x1, x2, x3, 0, 0, 0, 0, 0, x4, x5] -> Ok([x1, x2, x3, x4, x5, 3])
    [x1, x2, x3, x4, 0, 0, 0, 0, 0, x5] -> Ok([x1, x2, x3, x4, x5, 4])
    [x1, x2, x3, x4, x5, 0, 0, 0, 0, x6] if x6 >= 5 && x6 <= 9 ->
      Ok([x1, x2, x3, x4, x5, x6])
    _ -> Error(Nil)
  }
}

/// Apply the zero-suppression expansion rule keyed on the 6th body digit.
///
/// Given the six UPC-E body digits `X1 X2 X3 X4 X5 X6`, reconstruct the 10-digit
/// manufacturer-plus-item block of the UPC-A according to the GS1 expansion
/// table:
///
/// | `X6`          | 10-digit block                |
/// |---------------|-------------------------------|
/// | 0, 1, 2       | `X1 X2 X6 0 0 0 0 X3 X4 X5`    |
/// | 3             | `X1 X2 X3 0 0 0 0 0 X4 X5`     |
/// | 4             | `X1 X2 X3 X4 0 0 0 0 0 X5`     |
/// | 5, 6, 7, 8, 9 | `X1 X2 X3 X4 X5 0 0 0 0 X6`    |
///
/// Any input that is not a list of exactly six digits returns the empty list,
/// keeping the function total; callers pass exactly six digits.
fn expand_body(body: List(Int)) -> List(Int) {
  case body {
    [x1, x2, x3, x4, x5, x6] ->
      case x6 {
        0 | 1 | 2 -> [x1, x2, x6, 0, 0, 0, 0, x3, x4, x5]
        3 -> [x1, x2, x3, 0, 0, 0, 0, 0, x4, x5]
        4 -> [x1, x2, x3, x4, 0, 0, 0, 0, 0, x5]
        _ -> [x1, x2, x3, x4, x5, 0, 0, 0, 0, x6]
      }
    _ -> []
  }
}

/// Parse a string to a list of digits, returning Error(InvalidCharacters) if any
/// character is not a decimal digit.
fn parse_digits(code: String) -> Result(List(Int), GtinError) {
  string.split(code, "")
  |> list.try_map(fn(char) {
    case utils.parse_digit(char) {
      Ok(digit) -> Ok(digit)
      Error(_) -> Error(InvalidCharacters)
    }
  })
}

/// Render a list of digits as a string.
fn digits_to_string(digits: List(Int)) -> String {
  digits
  |> list.map(int.to_string)
  |> string.concat
}

/// Map a `check_digit.CheckDigitError` to the public `GtinError`.
fn map_check_digit_error(error: check_digit.CheckDigitError) -> GtinError {
  case error {
    check_digit.InvalidLength(got) -> InvalidLength(got)
    check_digit.InvalidCharacters -> InvalidCharacters
  }
}
