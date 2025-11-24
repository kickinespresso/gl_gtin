import gleam/string
import gleeunit/should
import gtin/check_digit

// Check Digit Algorithm Correctness
//
// For any GTIN, the check digit SHALL be calculated by: multiplying digits 
// alternately by 3 and 1 from right to left, summing products, taking modulo 10, 
// and setting check digit to 0 if result is 0, otherwise (10 - result).
pub fn check_digit_algorithm_correctness_test() {
  // Test case 1: GTIN-13 example from requirements
  // 629104150021 should produce check digit 3
  let assert Ok(digit) =
    check_digit.calculate([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
  digit |> should.equal(3)

  // Test case 2: All zeros should produce check digit 0
  let assert Ok(digit) = check_digit.calculate([0, 0, 0, 0, 0, 0, 0])
  digit |> should.equal(0)

  // Test case 3: Verify algorithm with known GTIN-12
  // 012345678905 has check digit 5
  let assert Ok(digit) =
    check_digit.calculate([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
  digit |> should.equal(5)

  // Test case 4: Single digit
  let assert Ok(digit) = check_digit.calculate([5])
  digit |> should.equal(5)

  // Test case 5: Two digits
  let assert Ok(digit) = check_digit.calculate([1, 2])
  digit |> should.equal(3)
}

// Generated GTINs Are Valid
//
// For any valid incomplete GTIN string (7, 11, 12, or 13 digits), 
// the generate function SHALL produce a complete GTIN that passes validation.
pub fn generated_gtins_are_valid_test() {
  // Test 7-digit input produces 8-digit output
  let assert Ok(result) = check_digit.generate("1234567")
  string.length(result) |> should.equal(8)

  // Test 11-digit input produces 12-digit output
  let assert Ok(result) = check_digit.generate("12345678901")
  string.length(result) |> should.equal(12)

  // Test 12-digit input produces 13-digit output
  let assert Ok(result) = check_digit.generate("123456789012")
  string.length(result) |> should.equal(13)

  // Test 13-digit input produces 14-digit output
  let assert Ok(result) = check_digit.generate("1234567890123")
  string.length(result) |> should.equal(14)

  // Test known example
  let assert Ok(result) = check_digit.generate("629104150021")
  result |> should.equal("6291041500213")
}

// Check Digit Generation Round Trip
//
// For any valid GTIN string, if we remove the check digit and regenerate it, 
// the result SHALL equal the original GTIN.
pub fn check_digit_generation_round_trip_test() {
  // Test with GTIN-13
  let original = "6291041500213"
  let without_check = string.slice(original, 0, string.length(original) - 1)
  let assert Ok(regenerated) = check_digit.generate(without_check)
  regenerated |> should.equal(original)

  // Test with GTIN-12
  let original = "012345678905"
  let without_check = string.slice(original, 0, string.length(original) - 1)
  let assert Ok(regenerated) = check_digit.generate(without_check)
  regenerated |> should.equal(original)

  // Test with GTIN-8
  let original = "96385074"
  let without_check = string.slice(original, 0, string.length(original) - 1)
  let assert Ok(regenerated) = check_digit.generate(without_check)
  regenerated |> should.equal(original)
}

// Invalid Lengths Rejected in Generation
//
// For any string with length not in {7, 11, 12, 13}, 
// the generate function SHALL return Error(InvalidLength(got: length)).
pub fn invalid_lengths_rejected_in_generation_test() {
  // Too short
  let result = check_digit.generate("123")
  result |> should.be_error()

  // Too long
  let result = check_digit.generate("123456789012345")
  result |> should.be_error()

  // Empty string
  let result = check_digit.generate("")
  result |> should.be_error()

  // 6 digits (invalid)
  let result = check_digit.generate("123456")
  result |> should.be_error()

  // 8 digits (invalid)
  let result = check_digit.generate("12345678")
  result |> should.be_error()

  // 10 digits (invalid)
  let result = check_digit.generate("1234567890")
  result |> should.be_error()
}

// Non-Numeric Characters Rejected in Generation
//
// For any string containing non-numeric characters, 
// the generate function SHALL return Error(InvalidCharacters).
pub fn non_numeric_characters_rejected_in_generation_test() {
  // Letters
  let result = check_digit.generate("12345a7")
  result |> should.be_error()

  // Special characters
  let result = check_digit.generate("1234567!")
  result |> should.be_error()

  // Spaces
  let result = check_digit.generate("1234 567")
  result |> should.be_error()

  // Hyphens
  let result = check_digit.generate("1234-567")
  result |> should.be_error()

  // Mixed
  let result = check_digit.generate("123A567B")
  result |> should.be_error()
}

// Check Digit Calculation Edge Cases
//
// Tests for edge cases in check digit calculation
pub fn check_digit_calculation_edge_cases_test() {
  // Single digit
  let assert Ok(digit) = check_digit.calculate([5])
  digit |> should.equal(5)

  // Two digits
  let assert Ok(digit) = check_digit.calculate([1, 2])
  digit |> should.equal(3)

  // All zeros
  let assert Ok(digit) = check_digit.calculate([0, 0, 0, 0, 0, 0, 0])
  digit |> should.equal(0)

  // All nines - verify it calculates correctly
  let assert Ok(digit) = check_digit.calculate([9, 9, 9, 9, 9, 9, 9])
  // 9*3 + 9*1 + 9*3 + 9*1 + 9*3 + 9*1 + 9*3 = 27+9+27+9+27+9+27 = 135
  // 135 % 10 = 5, so check digit = 10 - 5 = 5
  digit |> should.equal(5)

  // Maximum length (13 digits)
  let assert Ok(_digit) =
    check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3])

  // Empty list should fail
  let result = check_digit.calculate([])
  result |> should.be_error()

  // Too long (14 digits)
  let result = check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4])
  result |> should.be_error()
}

// Generate with All Zeros
//
// Tests that generation works with all zeros
pub fn generate_with_all_zeros_test() {
  // 7 zeros -> 8 digit GTIN
  let assert Ok(result) = check_digit.generate("0000000")
  string.length(result) |> should.equal(8)
  result |> should.equal("00000000")

  // 11 zeros -> 12 digit GTIN
  let assert Ok(result) = check_digit.generate("00000000000")
  string.length(result) |> should.equal(12)
  result |> should.equal("000000000000")

  // 12 zeros -> 13 digit GTIN
  let assert Ok(result) = check_digit.generate("000000000000")
  string.length(result) |> should.equal(13)
  result |> should.equal("0000000000000")

  // 13 zeros -> 14 digit GTIN
  let assert Ok(result) = check_digit.generate("0000000000000")
  string.length(result) |> should.equal(14)
  result |> should.equal("00000000000000")
}

// Generate with All Nines
//
// Tests that generation works with all nines
pub fn generate_with_all_nines_test() {
  // 7 nines -> 8 digit GTIN
  let assert Ok(result) = check_digit.generate("9999999")
  string.length(result) |> should.equal(8)

  // 11 nines -> 12 digit GTIN
  let assert Ok(result) = check_digit.generate("99999999999")
  string.length(result) |> should.equal(12)

  // 12 nines -> 13 digit GTIN
  let assert Ok(result) = check_digit.generate("999999999999")
  string.length(result) |> should.equal(13)

  // 13 nines -> 14 digit GTIN
  let assert Ok(result) = check_digit.generate("9999999999999")
  string.length(result) |> should.equal(14)
}

// Generate with Mixed Digits
//
// Tests generation with various digit patterns
pub fn generate_with_mixed_digits_test() {
  // Alternating pattern
  let assert Ok(result) = check_digit.generate("1010101")
  string.length(result) |> should.equal(8)

  // Ascending pattern
  let assert Ok(result) = check_digit.generate("1234567")
  string.length(result) |> should.equal(8)

  // Descending pattern
  let assert Ok(result) = check_digit.generate("7654321")
  string.length(result) |> should.equal(8)

  // Random pattern
  let assert Ok(result) = check_digit.generate("3141592")
  string.length(result) |> should.equal(8)
}
