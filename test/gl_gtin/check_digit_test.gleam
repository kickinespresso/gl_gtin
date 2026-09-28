import gl_gtin/check_digit
import gleam/string
import gleeunit/should

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

  // Length cap lifted (F0): a 14-digit body is now accepted
  let result = check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4])
  result |> should.be_ok()
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

// F0: calculate rejects an empty body
//
// Requirement 1.2: WHEN calculate is called with an empty list, THE
// Check_Digit_Engine SHALL return Error(InvalidLength(got: 0)).
pub fn f0_calculate_empty_body_test() {
  check_digit.calculate([])
  |> should.equal(Error(check_digit.InvalidLength(got: 0)))
}

// F0: calculate rejects an out-of-range element
//
// Requirement 1.3: IF calculate is called with a non-empty list containing any
// element outside the range 0 through 9, THEN THE Check_Digit_Engine SHALL
// return Error(InvalidCharacters).
pub fn f0_calculate_out_of_range_element_test() {
  // Element greater than 9
  check_digit.calculate([1, 2, 10, 4])
  |> should.equal(Error(check_digit.InvalidCharacters))

  // Negative element
  check_digit.calculate([1, -1, 3])
  |> should.equal(Error(check_digit.InvalidCharacters))
}

// F0: regression vectors for lengths 1..13 produce unchanged check digits
//
// Requirement 1.4: WHEN calculate is called with any digit body of length 1
// through 13 that was accepted before this change, THE Check_Digit_Engine SHALL
// return the same check digit as before this change.
pub fn f0_calculate_regression_lengths_1_to_13_test() {
  // Length 1
  check_digit.calculate([5]) |> should.equal(Ok(5))
  // Length 2
  check_digit.calculate([1, 2]) |> should.equal(Ok(3))
  // Length 3
  check_digit.calculate([1, 2, 3]) |> should.equal(Ok(6))
  // Length 4
  check_digit.calculate([1, 2, 3, 4]) |> should.equal(Ok(8))
  // Length 5
  check_digit.calculate([1, 2, 3, 4, 5]) |> should.equal(Ok(7))
  // Length 6
  check_digit.calculate([1, 2, 3, 4, 5, 6]) |> should.equal(Ok(5))
  // Length 7 (all zeros -> 0)
  check_digit.calculate([0, 0, 0, 0, 0, 0, 0]) |> should.equal(Ok(0))
  // Length 7 (all nines -> 5)
  check_digit.calculate([9, 9, 9, 9, 9, 9, 9]) |> should.equal(Ok(5))
  // Length 8
  check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8]) |> should.equal(Ok(4))
  // Length 9
  check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8, 9]) |> should.equal(Ok(5))
  // Length 10
  check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
  |> should.equal(Ok(5))
  // Length 11 (known GTIN-12 body -> 5)
  check_digit.calculate([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
  |> should.equal(Ok(5))
  // Length 12 (known GTIN-13 body -> 3)
  check_digit.calculate([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
  |> should.equal(Ok(3))
  // Length 13
  check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3])
  |> should.equal(Ok(1))
}

// F0: a 17-digit SSCC-shaped body now returns a check digit
//
// Requirement 1.1: the length cap is lifted so longer GS1 keys can reuse the
// mod-10 routine. An SSCC has 17 data digits followed by a check digit.
pub fn f0_calculate_sscc_body_test() {
  // 17-digit body (SSCC data digits, without check digit)
  let result =
    check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 6, 7])
  result |> should.be_ok()

  // The returned check digit is a single digit 0..9
  let assert Ok(digit) =
    check_digit.calculate([1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 6, 7])
  { digit >= 0 && digit <= 9 } |> should.be_true()
}

// F0: valid rejects an empty list
//
// Requirement 1.7: IF valid is called with an empty list, THEN THE
// Check_Digit_Engine SHALL return False.
pub fn f0_valid_empty_list_test() {
  check_digit.valid([]) |> should.be_false()
}

// F0: valid accepts a body appended with its check digit
//
// Requirements 1.5, 1.8: a valid body via append then valid == True.
pub fn f0_valid_after_append_test() {
  let assert Ok(appended) =
    check_digit.append([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
  check_digit.valid(appended) |> should.be_true()
}

// F0: valid rejects a wrong check digit
//
// Requirement 1.6: WHEN valid is called with a non-empty digit list whose last
// element does not equal the computed check digit, THE Check_Digit_Engine SHALL
// return False.
pub fn f0_valid_wrong_check_digit_test() {
  // Body 629104150021 has check digit 3; use 4 instead.
  check_digit.valid([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 4])
  |> should.be_false()
}

// F0: append rejects an empty list
//
// Requirement 1.9: IF append is called with an empty list, THEN THE
// Check_Digit_Engine SHALL return Error(InvalidLength(got: 0)).
pub fn f0_append_empty_list_test() {
  check_digit.append([])
  |> should.equal(Error(check_digit.InvalidLength(got: 0)))
}

// F0: append rejects an out-of-range element
//
// Requirement 1.10: IF append is called with a non-empty list containing any
// element outside the range 0 through 9, THEN THE Check_Digit_Engine SHALL
// return Error(InvalidCharacters).
pub fn f0_append_out_of_range_element_test() {
  check_digit.append([1, 2, 10, 4])
  |> should.equal(Error(check_digit.InvalidCharacters))

  check_digit.append([1, -1, 3])
  |> should.equal(Error(check_digit.InvalidCharacters))
}

// F0: append returns the body with the computed check digit as final element
//
// Requirement 1.8: append returns Ok(list) where the returned list equals the
// input list with the computed check digit appended as its final element.
pub fn f0_append_appends_check_digit_test() {
  check_digit.append([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
  |> should.equal(Ok([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]))
}

// F0 doc-comment examples
//
// Requirement 8.8: every doc-comment example on the new public functions is
// mirrored as an assertion so the stated outputs are exercised with zero
// failures.
pub fn f0_doc_comment_examples_test() {
  // calculate doc example
  check_digit.calculate([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
  |> should.equal(Ok(3))

  // valid doc examples
  check_digit.valid([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
  |> should.be_true()
  check_digit.valid([]) |> should.be_false()

  // append doc examples
  check_digit.append([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
  |> should.equal(Ok([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]))
  check_digit.append([])
  |> should.equal(Error(check_digit.InvalidLength(got: 0)))
}
