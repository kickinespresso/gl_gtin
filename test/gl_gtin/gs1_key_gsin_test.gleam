//// F6 (GSIN) unit and doc-comment example tests.
////
//// Mirrors the F5 (SSCC) shape at GSIN lengths 17 (validate) / 16 (generate),
//// exercising the public `gl_gtin.validate_gsin` / `gl_gtin.generate_gsin`
//// facade. Covers the defect-ordering rule (characters → length → check digit),
//// the SSCC-vs-GSIN length cross-rejection, and every doc-comment example.
////
//// Requirements: 3.1-3.7, 4.1-4.3, 8.7, 8.8

import gl_gtin
import gl_gtin/gtin_types.{InvalidCharacters, InvalidCheckDigit, InvalidLength}
import gleam/string
import gleeunit/should

// --- validate_gsin: success --------------------------------------------------

// A valid 17-digit GSIN (16-digit body + engine check digit) validates.
// _Requirements: 3.1_
pub fn validate_gsin_valid_test() {
  gl_gtin.validate_gsin("10614141543210986")
  |> should.equal(Ok("GSIN"))
}

// Leading/trailing whitespace is trimmed before validation.
// _Requirements: 3.1_
pub fn validate_gsin_trims_surrounding_whitespace_test() {
  gl_gtin.validate_gsin("  10614141543210986  ")
  |> should.equal(Ok("GSIN"))
}

// --- validate_gsin: wrong check digit ---------------------------------------

// A 17-digit numeric code whose final digit is not the computed check digit.
// _Requirements: 3.4_
pub fn validate_gsin_wrong_check_digit_test() {
  gl_gtin.validate_gsin("10614141543210987")
  |> should.equal(Error(InvalidCheckDigit))
}

// --- validate_gsin: length ---------------------------------------------------

// A numeric code shorter than 17 digits is rejected with the trimmed count.
// _Requirements: 3.3_
pub fn validate_gsin_too_short_test() {
  gl_gtin.validate_gsin("1061414154321098")
  |> should.equal(Error(InvalidLength(got: 16)))
}

// A numeric code longer than 17 digits is rejected with the trimmed count.
// _Requirements: 3.3_
pub fn validate_gsin_too_long_test() {
  gl_gtin.validate_gsin("106141415432109860")
  |> should.equal(Error(InvalidLength(got: 18)))
}

// A valid 18-digit SSCC fails the 17-digit length rule, never Ok("GSIN").
// _Requirements: 3.7_
pub fn validate_gsin_rejects_valid_sscc_by_length_test() {
  gl_gtin.validate_gsin("106141415432109873")
  |> should.equal(Error(InvalidLength(got: 18)))
}

// --- validate_gsin: characters ----------------------------------------------

// An interior space is a non-digit character and is rejected before length.
// _Requirements: 3.2, 3.5_
pub fn validate_gsin_interior_space_test() {
  gl_gtin.validate_gsin("1061414154321 986")
  |> should.equal(Error(InvalidCharacters))
}

// A non-digit character anywhere yields InvalidCharacters.
// _Requirements: 3.2_
pub fn validate_gsin_non_digit_test() {
  gl_gtin.validate_gsin("1061414154321098X")
  |> should.equal(Error(InvalidCharacters))
}

// --- validate_gsin: empty / whitespace --------------------------------------

// An empty string trims to zero digits.
// _Requirements: 3.6_
pub fn validate_gsin_empty_test() {
  gl_gtin.validate_gsin("")
  |> should.equal(Error(InvalidLength(got: 0)))
}

// A whitespace-only string trims to zero digits.
// _Requirements: 3.6_
pub fn validate_gsin_whitespace_only_test() {
  gl_gtin.validate_gsin("     ")
  |> should.equal(Error(InvalidLength(got: 0)))
}

// --- validate_gsin: defect ordering -----------------------------------------

// When both a non-digit and a length defect are present, characters win.
// _Requirements: 3.5_
pub fn validate_gsin_characters_before_length_test() {
  // 5 characters, one non-digit: character validity is reported first.
  gl_gtin.validate_gsin("1234X")
  |> should.equal(Error(InvalidCharacters))
}

// --- generate_gsin: success --------------------------------------------------

// A 16-digit body yields the 17-digit key with the appended check digit.
// _Requirements: 4.1_
pub fn generate_gsin_success_test() {
  gl_gtin.generate_gsin("1061414154321098")
  |> should.equal(Ok("10614141543210986"))
}

// generate_gsin then validate_gsin round-trips to Ok("GSIN").
// _Requirements: 4.1_
pub fn generate_gsin_then_validate_test() {
  let assert Ok(gsin) = gl_gtin.generate_gsin("1061414154321098")
  gl_gtin.validate_gsin(gsin)
  |> should.equal(Ok("GSIN"))
}

// The generated key is exactly 17 characters long.
// _Requirements: 4.1_
pub fn generate_gsin_result_length_test() {
  let assert Ok(gsin) = gl_gtin.generate_gsin("1061414154321098")
  gsin
  |> string.length
  |> should.equal(17)
}

// --- generate_gsin: length ---------------------------------------------------

// A body shorter than 16 digits is rejected with the trimmed count.
// _Requirements: 4.2_
pub fn generate_gsin_body_too_short_test() {
  gl_gtin.generate_gsin("106141415432109")
  |> should.equal(Error(InvalidLength(got: 15)))
}

// A body longer than 16 digits is rejected with the trimmed count.
// _Requirements: 4.2_
pub fn generate_gsin_body_too_long_test() {
  gl_gtin.generate_gsin("10614141543210986")
  |> should.equal(Error(InvalidLength(got: 17)))
}

// --- generate_gsin: characters ----------------------------------------------

// A 16-character body with a non-digit yields InvalidCharacters.
// _Requirements: 4.3_
pub fn generate_gsin_non_digit_body_test() {
  gl_gtin.generate_gsin("106141415432109X")
  |> should.equal(Error(InvalidCharacters))
}

// An interior space in the body is a non-digit character.
// _Requirements: 4.3_
pub fn generate_gsin_interior_space_body_test() {
  gl_gtin.generate_gsin("10614141543 1098")
  |> should.equal(Error(InvalidCharacters))
}

// --- doc-comment example assertions -----------------------------------------

// Mirror of the `validate_gsin` doc-comment examples in src/gl_gtin.gleam.
// _Requirements: 8.8_
pub fn validate_gsin_doc_examples_test() {
  gl_gtin.validate_gsin("10614141543210986")
  |> should.equal(Ok("GSIN"))

  gl_gtin.validate_gsin("106141415432109873")
  |> should.equal(Error(InvalidLength(got: 18)))
}

// Mirror of the `generate_gsin` doc-comment examples in src/gl_gtin.gleam.
// _Requirements: 8.8_
pub fn generate_gsin_doc_examples_test() {
  gl_gtin.generate_gsin("1061414154321098")
  |> should.equal(Ok("10614141543210986"))

  gl_gtin.generate_gsin("106141415432109")
  |> should.equal(Error(InvalidLength(got: 15)))
}
