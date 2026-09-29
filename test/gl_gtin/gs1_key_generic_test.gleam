//// Unit and doc-comment example tests for the F7 generic-key public surface
//// (`gl_gtin.validate_key` / `gl_gtin.generate_key`).
////
//// These exercise the facade wrappers that map the internal `KeyError` to the
//// public `GtinError`. They cover the worked GLN example, the wrong-check-digit
//// case, same-length keys judged only against their supplied kind (SSCC vs
//// GSRN), non-digit and wrong-length rejection ordering, the
//// `generate_key(Sscc, body) == generate_sscc(body)` delegation equality, and
//// mirror every `validate_key`/`generate_key` doc-comment example as an
//// assertion.

import gl_gtin
import gl_gtin/gtin_types.{
  Gln, Gsin, Gsrn, InvalidCharacters, InvalidCheckDigit, InvalidLength, Sscc,
}
import gleeunit/should

// --- validate_key: worked GLN examples ---

// validate_key with a valid GLN returns Ok(Gln).
//
// Worked example (Requirements 5.1, 6.1, 6.6): the 13-digit GLN
// "0614141000012" is a valid mod-10 key, so validating it under the Gln kind
// returns the supplied kind.
pub fn validate_key_valid_gln_test() {
  gl_gtin.validate_key(Gln, "0614141000012")
  |> should.equal(Ok(Gln))
}

// validate_key with a wrong check digit returns Error(InvalidCheckDigit).
//
// "0614141000013" has the correct length and characters but a wrong check
// digit, so the check-digit rule fails (Requirements 6.5).
pub fn validate_key_gln_wrong_check_digit_test() {
  gl_gtin.validate_key(Gln, "0614141000013")
  |> should.equal(Error(InvalidCheckDigit))
}

// --- validate_key: same-length keys judged only against the supplied kind ---

// A single 18-digit code valid under both Sscc and Gsrn is judged only against
// the kind passed in (Requirements 5.2, 6.6, 6.8).
//
// SSCC and GSRN are both 18-digit mod-10 keys, so one generated code validates
// under both — each call returns exactly its supplied kind, never the other.
pub fn validate_key_same_length_sscc_vs_gsrn_test() {
  // Build a valid 18-digit code from a 17-digit body via generate_sscc.
  let assert Ok(code) = gl_gtin.generate_sscc("10614141543210987")

  gl_gtin.validate_key(Sscc, code)
  |> should.equal(Ok(Sscc))

  gl_gtin.validate_key(Gsrn, code)
  |> should.equal(Ok(Gsrn))
}

// --- validate_key: defect ordering ---

// A non-digit character is rejected with Error(InvalidCharacters) before the
// length check (Requirements 6.3).
pub fn validate_key_non_digit_test() {
  gl_gtin.validate_key(Gln, "06141410000X2")
  |> should.equal(Error(InvalidCharacters))
}

// A numeric code of the wrong length is rejected with
// Error(InvalidLength(got: n)) where n is the trimmed digit count
// (Requirements 6.4).
pub fn validate_key_wrong_length_test() {
  // 12 digits instead of the GLN's 13.
  gl_gtin.validate_key(Gln, "061414100001")
  |> should.equal(Error(InvalidLength(got: 12)))

  // 14 digits instead of the GLN's 13.
  gl_gtin.validate_key(Gln, "06141410000123")
  |> should.equal(Error(InvalidLength(got: 14)))
}

// --- generate_key: delegation equality ---

// generate_key(Sscc, body) equals generate_sscc(body) — the generic driver and
// the SSCC specialization produce the same result (Requirements 7.1, 7.2, 7.3).
pub fn generate_key_sscc_equals_generate_sscc_test() {
  let body = "10614141543210987"
  gl_gtin.generate_key(Sscc, body)
  |> should.equal(gl_gtin.generate_sscc(body))
}

// --- Doc-comment example mirrors ---

// Mirror of the validate_key doc-comment examples in src/gl_gtin.gleam:
//   validate_key(Gln, "0614141000012") // -> Ok(Gln)
//   validate_key(Gln, "0614141000013") // -> Error(InvalidCheckDigit)
pub fn validate_key_doc_examples_test() {
  gl_gtin.validate_key(Gln, "0614141000012")
  |> should.equal(Ok(Gln))

  gl_gtin.validate_key(Gln, "0614141000013")
  |> should.equal(Error(InvalidCheckDigit))
}

// Mirror of the generate_key doc-comment examples in src/gl_gtin.gleam:
//   generate_key(Sscc, "10614141543210987") // -> Ok("106141415432109873")
//   generate_key(Gsin, "1061414154321098")  // -> Ok("10614141543210986")
pub fn generate_key_doc_examples_test() {
  gl_gtin.generate_key(Sscc, "10614141543210987")
  |> should.equal(Ok("106141415432109873"))

  gl_gtin.generate_key(Gsin, "1061414154321098")
  |> should.equal(Ok("10614141543210986"))
}
