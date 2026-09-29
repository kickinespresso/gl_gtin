//// F5 (SSCC) unit and doc-comment example tests for the `gl_gtin` facade.
////
//// Covers `gl_gtin.validate_sscc` and `gl_gtin.generate_sscc`:
//// valid/invalid check digit, wrong-length numeric, interior spaces,
//// empty/whitespace input, a valid GTIN-14 rejected by length, and the
//// generator's success and body-length failure paths. Every doc-comment
//// example on `validate_sscc`/`generate_sscc` in `src/gl_gtin.gleam` is
//// mirrored here as an assertion.

import gl_gtin
import gl_gtin/gtin_types.{InvalidCharacters, InvalidCheckDigit, InvalidLength}
import gleam/string
import gleeunit/should

// --- validate_sscc: success -------------------------------------------------

// Requirement 1.1: a valid 18-digit SSCC with a correct check digit validates
// to Ok("SSCC").
pub fn validate_sscc_valid_18_digit_test() {
  gl_gtin.validate_sscc("106141415432109873")
  |> should.equal(Ok("SSCC"))
}

// --- validate_sscc: check digit ---------------------------------------------

// Requirement 1.4: an 18-digit numeric code whose final digit is not the
// computed check digit fails with InvalidCheckDigit. Derived by taking the
// known-valid code (ending in 3) and changing the last digit to 4.
pub fn validate_sscc_wrong_check_digit_test() {
  gl_gtin.validate_sscc("106141415432109874")
  |> should.equal(Error(InvalidCheckDigit))
}

// --- validate_sscc: length --------------------------------------------------

// Requirement 1.3: a 17-digit numeric code (one short of 18) fails the length
// check reporting the trimmed digit count.
pub fn validate_sscc_seventeen_digits_test() {
  gl_gtin.validate_sscc("10614141543210987")
  |> should.equal(Error(InvalidLength(got: 17)))
}

// Requirement 1.3: a 19-digit numeric code (one over 18) fails the length
// check reporting the trimmed digit count.
pub fn validate_sscc_nineteen_digits_test() {
  gl_gtin.validate_sscc("1061414154321098730")
  |> should.equal(Error(InvalidLength(got: 19)))
}

// --- validate_sscc: characters ----------------------------------------------

// Requirement 1.2: interior whitespace is a non-digit character and is
// rejected before the length check.
pub fn validate_sscc_interior_space_test() {
  gl_gtin.validate_sscc("10614141543 2109873")
  |> should.equal(Error(InvalidCharacters))
}

// --- validate_sscc: empty / whitespace --------------------------------------

// Requirement 1.6: an empty string trims to zero digits and reports
// InvalidLength(got: 0).
pub fn validate_sscc_empty_test() {
  gl_gtin.validate_sscc("")
  |> should.equal(Error(InvalidLength(got: 0)))
}

// Requirement 1.6: a whitespace-only string trims to zero digits and reports
// InvalidLength(got: 0).
pub fn validate_sscc_whitespace_only_test() {
  gl_gtin.validate_sscc("   ")
  |> should.equal(Error(InvalidLength(got: 0)))
}

// --- validate_sscc: valid GTIN-14 rejected by length ------------------------

// Requirement 1.7: a valid 14-digit GTIN-14 is rejected by the 18-digit length
// rule with InvalidLength(got: 14) and never returns Ok("SSCC"). The GTIN-14 is
// produced by the engine from a 13-digit body so its check digit is exact.
pub fn validate_sscc_valid_gtin14_rejected_by_length_test() {
  let assert Ok(gtin14) = gl_gtin.generate("1234567890123")
  gl_gtin.validate(gtin14)
  |> should.equal(Ok(gtin_types.Gtin14))

  gl_gtin.validate_sscc(gtin14)
  |> should.equal(Error(InvalidLength(got: 14)))
}

// --- generate_sscc: success -------------------------------------------------

// Requirements 2.1, 2.4: a 17-digit body generates an 18-digit SSCC that then
// validates as Ok("SSCC").
pub fn generate_sscc_17_digit_body_test() {
  let assert Ok(sscc) = gl_gtin.generate_sscc("10614141543210987")
  should.equal(sscc, "106141415432109873")
  should.equal(string.length(sscc), 18)

  gl_gtin.validate_sscc(sscc)
  |> should.equal(Ok("SSCC"))
}

// --- generate_sscc: body length --------------------------------------------

// Requirement 2.2: a 16-digit body (one short of 17) fails the body-length
// check reporting the trimmed digit count.
pub fn generate_sscc_16_digit_body_test() {
  gl_gtin.generate_sscc("1061414154321098")
  |> should.equal(Error(InvalidLength(got: 16)))
}

// --- Doc-comment example mirrors --------------------------------------------

// Mirrors the validate_sscc doc-comment examples in src/gl_gtin.gleam.
// Requirement 8.8: doc-comment examples are exercised as assertions.
pub fn validate_sscc_doc_examples_test() {
  gl_gtin.validate_sscc("106141415432109873")
  |> should.equal(Ok("SSCC"))

  gl_gtin.validate_sscc("00000000000000")
  |> should.equal(Error(InvalidLength(got: 14)))
}

// Mirrors the generate_sscc doc-comment examples in src/gl_gtin.gleam.
// Requirement 8.8: doc-comment examples are exercised as assertions.
pub fn generate_sscc_doc_examples_test() {
  gl_gtin.generate_sscc("10614141543210987")
  |> should.equal(Ok("106141415432109873"))

  gl_gtin.generate_sscc("1061414154321098")
  |> should.equal(Error(InvalidLength(got: 16)))
}
