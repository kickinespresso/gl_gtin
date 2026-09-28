import gl_gtin/validation
import gleam/list
import gleam/string
import gleeunit/should

// Valid GTINs Pass Validation
//
// For any valid GTIN string (8, 12, 13, or 14 digits with correct check digit),
// the validate function SHALL return Ok with the correct GtinFormat.
pub fn valid_gtins_pass_validation_test() {
  // GTIN-8 example
  let assert Ok(format) = validation.validate("96385074")
  format |> should.equal(validation.Gtin8)

  // GTIN-12 example
  let assert Ok(format) = validation.validate("012345678905")
  format |> should.equal(validation.Gtin12)

  // GTIN-13 example
  let assert Ok(format) = validation.validate("6291041500213")
  format |> should.equal(validation.Gtin13)

  // GTIN-14 example
  let assert Ok(format) = validation.validate("12345678901231")
  format |> should.equal(validation.Gtin14)

  // All zeros GTIN-8
  let assert Ok(format) = validation.validate("00000000")
  format |> should.equal(validation.Gtin8)

  // All zeros GTIN-13
  let assert Ok(format) = validation.validate("0000000000000")
  format |> should.equal(validation.Gtin13)
}

// Invalid Check Digits Fail Validation
//
// For any GTIN string with an incorrect check digit,
// the validate function SHALL return Error(InvalidCheckDigit).
pub fn invalid_check_digits_fail_validation_test() {
  // Valid GTIN-13 with wrong check digit
  let result = validation.validate("6291041500214")
  result |> should.be_error()

  // Valid GTIN-12 with wrong check digit
  let result = validation.validate("012345678906")
  result |> should.be_error()

  // Valid GTIN-8 with wrong check digit
  let result = validation.validate("96385075")
  result |> should.be_error()

  // Valid GTIN-14 with wrong check digit
  let result = validation.validate("12345678901232")
  result |> should.be_error()
}

// Invalid Lengths Fail Validation
//
// For any string with length not in {8, 12, 13, 14},
// the validate function SHALL return Error(InvalidLength(got: length)).
pub fn invalid_lengths_fail_validation_test() {
  // Too short
  let result = validation.validate("123")
  case result {
    Error(validation.InvalidLength(got)) -> got |> should.equal(3)
    _ -> should.fail()
  }

  // 7 digits (too short)
  let result = validation.validate("1234567")
  case result {
    Error(validation.InvalidLength(got)) -> got |> should.equal(7)
    _ -> should.fail()
  }

  // 9 digits (invalid)
  let result = validation.validate("123456789")
  case result {
    Error(validation.InvalidLength(got)) -> got |> should.equal(9)
    _ -> should.fail()
  }

  // 15 digits (too long)
  let result = validation.validate("123456789012345")
  case result {
    Error(validation.InvalidLength(got)) -> got |> should.equal(15)
    _ -> should.fail()
  }

  // Empty string
  let result = validation.validate("")
  case result {
    Error(validation.InvalidLength(got)) -> got |> should.equal(0)
    _ -> should.fail()
  }
}

// Non-Numeric Characters Fail Validation
//
// For any string containing non-numeric characters,
// the validate function SHALL return Error(InvalidCharacters).
pub fn non_numeric_characters_fail_validation_test() {
  // Letters
  let result = validation.validate("629104150021A")
  result |> should.be_error()

  // Special characters
  let result = validation.validate("629104150021!")
  result |> should.be_error()

  // Hyphens
  let result = validation.validate("629-104-150-021")
  result |> should.be_error()

  // Mixed
  let result = validation.validate("629A04150021B")
  result |> should.be_error()
}

// Whitespace is Trimmed Before Validation
//
// For any valid GTIN string with leading or trailing whitespace,
// the validate function SHALL trim the whitespace and return Ok with the correct GtinFormat.
pub fn whitespace_is_trimmed_before_validation_test() {
  // Leading whitespace
  let assert Ok(format) = validation.validate("  6291041500213")
  format |> should.equal(validation.Gtin13)

  // Trailing whitespace
  let assert Ok(format) = validation.validate("6291041500213  ")
  format |> should.equal(validation.Gtin13)

  // Both leading and trailing
  let assert Ok(format) = validation.validate("  6291041500213  ")
  format |> should.equal(validation.Gtin13)

  // Tabs and newlines
  let assert Ok(format) = validation.validate("\t6291041500213\n")
  format |> should.equal(validation.Gtin13)

  // Multiple spaces
  let assert Ok(format) = validation.validate("   012345678905   ")
  format |> should.equal(validation.Gtin12)
}

// GTIN-13 Normalizes to Valid GTIN-14

//
// For any valid GTIN-13, the normalize function SHALL return Ok with a valid
// 14-digit GTIN-14 that passes validation.
pub fn gtin_13_normalizes_to_valid_gtin_14_test() {
  // Test with known GTIN-13
  let assert Ok(result) = validation.normalize("6291041500213")
  string.length(result) |> should.equal(14)

  // Verify the result is a valid GTIN-14
  let assert Ok(format) = validation.validate(result)
  format |> should.equal(validation.Gtin14)

  // Test with another GTIN-13
  let assert Ok(result) = validation.normalize("5901234123457")
  string.length(result) |> should.equal(14)
  let assert Ok(format) = validation.validate(result)
  format |> should.equal(validation.Gtin14)

  // Test with all zeros
  let assert Ok(result) = validation.normalize("0000000000000")
  string.length(result) |> should.equal(14)
  let assert Ok(format) = validation.validate(result)
  format |> should.equal(validation.Gtin14)
}

// Non-GTIN-13 Formats Fail Normalization
//
// For any GTIN that is not GTIN-13 format,
// the normalize function SHALL return Error(InvalidFormat).
pub fn non_gtin_13_formats_fail_normalization_test() {
  // GTIN-8
  let result = validation.normalize("96385074")
  case result {
    Error(validation.InvalidFormat) -> Nil
    _ -> should.fail()
  }

  // GTIN-12
  let result = validation.normalize("012345678905")
  case result {
    Error(validation.InvalidFormat) -> Nil
    _ -> should.fail()
  }

  // GTIN-14
  let result = validation.normalize("12345678901231")
  case result {
    Error(validation.InvalidFormat) -> Nil
    _ -> should.fail()
  }

  // Invalid length
  let result = validation.normalize("123456789")
  case result {
    Error(_) -> Nil
    _ -> should.fail()
  }
}

// Edge Cases for Validation
//
// Tests for edge cases like very large numbers, special characters, etc.
pub fn edge_cases_for_validation_test() {
  // Very large number string
  let result = validation.validate("999999999999999999999999999999")
  result |> should.be_error()

  // All zeros GTIN-8
  let assert Ok(format) = validation.validate("00000000")
  format |> should.equal(validation.Gtin8)

  // All zeros GTIN-12
  let assert Ok(format) = validation.validate("000000000000")
  format |> should.equal(validation.Gtin12)

  // All zeros GTIN-13
  let assert Ok(format) = validation.validate("0000000000000")
  format |> should.equal(validation.Gtin13)

  // All zeros GTIN-14
  let assert Ok(format) = validation.validate("00000000000000")
  format |> should.equal(validation.Gtin14)

  // All nines GTIN-8
  let result = validation.validate("99999999")
  result |> should.be_error()

  // All nines GTIN-13
  let result = validation.validate("9999999999999")
  result |> should.be_error()
}

// Whitespace Handling Edge Cases
//
// Tests for various whitespace scenarios
pub fn whitespace_handling_edge_cases_test() {
  // Multiple leading spaces
  let assert Ok(format) = validation.validate("   6291041500213")
  format |> should.equal(validation.Gtin13)

  // Multiple trailing spaces
  let assert Ok(format) = validation.validate("6291041500213   ")
  format |> should.equal(validation.Gtin13)

  // Mixed whitespace (spaces, tabs, newlines)
  let assert Ok(format) = validation.validate(" \t 6291041500213 \n ")
  format |> should.equal(validation.Gtin13)

  // Only whitespace
  let result = validation.validate("   \t\n   ")
  result |> should.be_error()
}

// Invalid Character Edge Cases
//
// Tests for various invalid character scenarios
pub fn invalid_character_edge_cases_test() {
  // Lowercase letters
  let result = validation.validate("629104150021a")
  result |> should.be_error()

  // Uppercase letters
  let result = validation.validate("629104150021A")
  result |> should.be_error()

  // Mixed case
  let result = validation.validate("629104150021aB")
  result |> should.be_error()

  // Punctuation
  let result = validation.validate("629104150021.")
  result |> should.be_error()

  // Hyphens
  let result = validation.validate("629-104-150-021")
  result |> should.be_error()

  // Spaces in middle
  let result = validation.validate("629 104 150 021")
  result |> should.be_error()

  // Plus sign
  let result = validation.validate("+6291041500213")
  result |> should.be_error()

  // Equals sign
  let result = validation.validate("6291041500213=")
  result |> should.be_error()
}

// Normalize with Invalid Input
//
// Tests for normalize function with invalid inputs
pub fn normalize_with_invalid_input_test() {
  // Invalid GTIN-13 (wrong check digit)
  let result = validation.normalize("6291041500214")
  result |> should.be_error()

  // Non-numeric characters
  let result = validation.normalize("629104150021A")
  result |> should.be_error()

  // Empty string
  let result = validation.normalize("")
  result |> should.be_error()

  // Too short
  let result = validation.normalize("123")
  result |> should.be_error()

  // Too long
  let result = validation.normalize("123456789012345")
  result |> should.be_error()
}

// Normalize Preserves Validity
//
// Tests that normalized GTINs are always valid
pub fn normalize_preserves_validity_test() {
  // Multiple valid GTIN-13 examples
  let test_cases = [
    "6291041500213",
    "5901234123457",
    "0000000000000",
    "9780201379624",
  ]

  list.each(test_cases, fn(code) {
    let assert Ok(normalized) = validation.normalize(code)
    // Verify normalized is valid GTIN-14
    let assert Ok(format) = validation.validate(normalized)
    format |> should.equal(validation.Gtin14)
    // Verify length is 14
    string.length(normalized) |> should.equal(14)
  })
}

// Normalize With Indicator - Worked Examples
//
// normalize_with_indicator prepends the supplied indicator digit (0..9) to the
// 12 data digits of a GTIN-13 and recomputes the check digit.
// _Requirements: 4.3, 4.4, 4.7, 8.8_
pub fn normalize_with_indicator_worked_examples_test() {
  // Indicator 1 (also mirrors the doc-comment example)
  validation.normalize_with_indicator("6291041500213", 1)
  |> should.equal(Ok("16291041500210"))

  // Indicator 2 (also mirrors the doc-comment example)
  validation.normalize_with_indicator("6291041500213", 2)
  |> should.equal(Ok("26291041500217"))

  // Indicator 3
  validation.normalize_with_indicator("6291041500213", 3)
  |> should.equal(Ok("36291041500214"))

  // Indicator 9
  validation.normalize_with_indicator("6291041500213", 9)
  |> should.equal(Ok("96291041500216"))
}

// Normalize With Indicator - Out-of-Range Indicators
//
// An indicator outside 0..9 returns Error(InvalidFormat).
// _Requirements: 4.5, 4.6_
pub fn normalize_with_indicator_out_of_range_test() {
  // Negative indicator
  validation.normalize_with_indicator("6291041500213", -1)
  |> should.equal(Error(validation.InvalidFormat))

  // Indicator 10 (also mirrors the doc-comment example)
  validation.normalize_with_indicator("6291041500213", 10)
  |> should.equal(Error(validation.InvalidFormat))

  // Indicator 99 (well above range)
  validation.normalize_with_indicator("6291041500213", 99)
  |> should.equal(Error(validation.InvalidFormat))
}

// Normalize With Indicator - Invalid GTIN-13 Error Parity
//
// For an input that is not a valid GTIN-13, normalize_with_indicator(x, k)
// returns the same Error as normalize(x).
// _Requirements: 4.7, 4.8_
pub fn normalize_with_indicator_invalid_gtin13_parity_test() {
  // GTIN-13 with a wrong check digit
  validation.normalize_with_indicator("6291041500214", 1)
  |> should.equal(validation.normalize("6291041500214"))

  // Non-GTIN-13 format (GTIN-12)
  validation.normalize_with_indicator("012345678905", 3)
  |> should.equal(validation.normalize("012345678905"))

  // Non-GTIN-13 format (GTIN-8)
  validation.normalize_with_indicator("96385074", 5)
  |> should.equal(validation.normalize("96385074"))

  // Non-GTIN-13 format (GTIN-14)
  validation.normalize_with_indicator("12345678901231", 2)
  |> should.equal(validation.normalize("12345678901231"))

  // Non-numeric characters
  validation.normalize_with_indicator("629104150021A", 1)
  |> should.equal(validation.normalize("629104150021A"))

  // Empty string
  validation.normalize_with_indicator("", 1)
  |> should.equal(validation.normalize(""))

  // Invalid length (too short)
  validation.normalize_with_indicator("123", 1)
  |> should.equal(validation.normalize("123"))

  // Invalid length (too long)
  validation.normalize_with_indicator("123456789012345", 1)
  |> should.equal(validation.normalize("123456789012345"))
}

// to_gtin13 - Worked Examples (mirrors doc-comment examples)
//
// to_gtin13 requires a valid GTIN-14. When the leading indicator digit is 0,
// the leading `0` is dropped and the existing check digit is preserved,
// yielding the base GTIN-13. A non-zero indicator returns
// Error(InvalidFormat).
// _Requirements: 5.2, 5.4, 8.8_
pub fn to_gtin13_worked_examples_test() {
  // Indicator 0 strips the leading zero (mirrors the doc-comment example)
  validation.to_gtin13("06291041500213")
  |> should.equal(Ok("6291041500213"))

  // Non-zero indicator cannot be stripped (mirrors the doc-comment example)
  validation.to_gtin13("16291041500210")
  |> should.equal(Error(validation.InvalidFormat))

  // Another indicator-0 example: all zeros round-trips to a 13-digit basis
  validation.to_gtin13("00000000000000")
  |> should.equal(Ok("0000000000000"))
}

// to_gtin13 - Invalid Input Error Ordering
//
// to_gtin13 surfaces the same invalid-input errors as validate: non-numeric
// characters first, then length, then check digit.
// _Requirements: 5.5, 5.6, 5.7_
pub fn to_gtin13_invalid_input_test() {
  // Non-numeric characters
  validation.to_gtin13("0629104150021A")
  |> should.equal(Error(validation.InvalidCharacters))

  // Wrong length (13 digits, not a GTIN-14)
  validation.to_gtin13("6291041500213")
  |> should.equal(Error(validation.InvalidLength(got: 13)))

  // Wrong length (empty)
  validation.to_gtin13("")
  |> should.equal(Error(validation.InvalidLength(got: 0)))

  // Correct length but wrong check digit
  validation.to_gtin13("06291041500214")
  |> should.equal(Error(validation.InvalidCheckDigit))
}

// to_gtin12 - Worked Examples (mirrors doc-comment examples)
//
// to_gtin12 requires a valid GTIN-14 whose base is a UPC-A padded with an
// implicit leading zero (both leading digits 0). It drops both leading zeros
// to yield the 12-digit UPC-A. A base that is a genuine EAN-13 (non-zero
// second digit) is not representable and returns Error(InvalidFormat).
// _Requirements: 6.2, 6.3, 6.4, 6.5_
pub fn to_gtin12_worked_examples_test() {
  // UPC-A-based GTIN-14 strips both leading zeros (mirrors the doc-comment
  // example)
  validation.to_gtin12("00042100005264")
  |> should.equal(Ok("042100005264"))

  // Base is a genuine EAN-13 (second digit non-zero) -> not representable
  validation.to_gtin12("06291041500213")
  |> should.equal(Error(validation.InvalidFormat))

  // Non-zero indicator -> not representable
  validation.to_gtin12("16291041500210")
  |> should.equal(Error(validation.InvalidFormat))
}

// to_gtin12 - Invalid Input Error Ordering
//
// to_gtin12 surfaces the same invalid-input errors as validate before any
// down-conversion: non-numeric characters, then length, then check digit.
// _Requirements: 6.6_
pub fn to_gtin12_invalid_input_test() {
  // Non-numeric characters
  validation.to_gtin12("0004210000526A")
  |> should.equal(Error(validation.InvalidCharacters))

  // Wrong length (12 digits, not a GTIN-14)
  validation.to_gtin12("042100005264")
  |> should.equal(Error(validation.InvalidLength(got: 12)))

  // Correct length but wrong check digit
  validation.to_gtin12("00042100005265")
  |> should.equal(Error(validation.InvalidCheckDigit))
}
