import gleam/list
import gleam/string
import gleeunit/should
import gtin/validation

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
