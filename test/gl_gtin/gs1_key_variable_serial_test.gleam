//// Variable-serial key (`Grai`/`Gdti`/`Gcn`/`Giai`) behavior tests for the F7
//// key driver (Requirements 6.7, 7.4).
////
//// The driver splits a variable-serial key into a numeric BASE (carrying the
//// mod-10 check on its last digit) and an OPTIONAL typed SERIAL:
////
//// | Key    | Base | Serial max | Serial charset |
//// |--------|-----:|-----------:|----------------|
//// | `Grai` | 13   | 16         | alphanumeric   |
//// | `Gdti` | 13   | 17         | alphanumeric   |
//// | `Gcn`  | 13   | 12         | numeric        |
//// | `Giai` | 1..30 total (freeform alphanumeric, NO base/serial split, NO check digit) |
////
//// `InvalidKeyFormat` is now genuinely REACHABLE for the alphanumeric-serial
//// keys (`Grai`/`Gdti`): a string that passes the union charset AND the length
//// rule but carries a NON-DIGIT (letter) inside the numeric base region has a
//// malformed base even though characters/length are otherwise plausible. That
//// is distinct from `InvalidCharacters` (a character outside the union charset)
//// and `InvalidCheckDigit` (an all-digit base whose 13th digit is wrong).
////
//// `Gcn`'s serial charset is NUMERIC, so its union charset is digits only:
//// there is no non-digit character that passes the union charset yet fails the
//// numeric-base check, so a letter anywhere is caught earlier as
//// `InvalidCharacters` and `InvalidKeyFormat` is not reachable for `Gcn`.
//// `Giai` is freeform with no base/serial split, so it has no
//// `InvalidKeyFormat` path either.
////
//// Tests use the public `gl_gtin` facade so the public `InvalidKeyFormat`
//// `GtinError` variant is the thing under test. Error variants and `Gs1Key`
//// variants are imported from `gl_gtin/gtin_types` (their owning module).
////
//// The valid 13-digit base `"0614141000012"` (12-digit body `"061414100001"`)
//// is a known-good mod-10 key reused across these cases.

import gl_gtin
import gl_gtin/gtin_types.{
  Gcn, Gdti, Giai, Grai, InvalidCharacters, InvalidCheckDigit, InvalidKeyFormat,
  InvalidLength,
}
import gleeunit/should

// ============================================================================
// Grai — base 13, serial 0..16 alphanumeric
// ============================================================================

// A valid 13-digit base with no serial validates as Grai.
pub fn validate_grai_valid_base_succeeds_test() {
  gl_gtin.validate_key(Grai, "0614141000012")
  |> should.equal(Ok(Grai))
}

// A valid base plus an alphanumeric serial (<=16) validates as Grai.
pub fn validate_grai_valid_base_and_serial_succeeds_test() {
  gl_gtin.validate_key(Grai, "0614141000012ABCD")
  |> should.equal(Ok(Grai))
}

// A valid base + alphanumeric serial round-trips: generate the key from a
// 12-digit base body + serial, then validate the generated code back to Grai.
pub fn generate_then_validate_grai_round_trips_test() {
  let assert Ok(code) = gl_gtin.generate_key(Grai, "061414100001ABCD")
  gl_gtin.validate_key(Grai, code)
  |> should.equal(Ok(Grai))
}

// A 12-digit base body with an empty serial also round-trips.
pub fn generate_then_validate_grai_empty_serial_round_trips_test() {
  let assert Ok(code) = gl_gtin.generate_key(Grai, "061414100001")
  gl_gtin.validate_key(Grai, code)
  |> should.equal(Ok(Grai))
}

// An all-digit base whose 13th (check) digit is wrong is a check-digit defect.
pub fn validate_grai_wrong_base_check_digit_test() {
  gl_gtin.validate_key(Grai, "0614141000013")
  |> should.equal(Error(InvalidCheckDigit))
}

// A serial longer than 16 overflows the length rule (base 13 + 17 = 30 > 29).
pub fn validate_grai_serial_over_max_is_invalid_length_test() {
  gl_gtin.validate_key(Grai, "0614141000012ABCDEFGHIJKLMNOPQ")
  |> should.equal(Error(InvalidLength(got: 30)))
}

// A character outside the alphanumeric union charset (here "-") is rejected at
// the character stage.
pub fn validate_grai_out_of_charset_is_invalid_characters_test() {
  gl_gtin.validate_key(Grai, "0614141000012-")
  |> should.equal(Error(InvalidCharacters))
}

// Feature: gl-gtin-gs1-keys, variable-serial InvalidKeyFormat (Req 6.7, 7.4)
//
// A 13-char code that passes the alphanumeric union charset and the length rule
// but carries a letter WITHIN the 13-digit base region has a malformed numeric
// base -> InvalidKeyFormat (validate path).
pub fn validate_grai_letter_in_base_is_invalid_key_format_test() {
  gl_gtin.validate_key(Grai, "061414100001X")
  |> should.equal(Error(InvalidKeyFormat))
}

// Feature: gl-gtin-gs1-keys, variable-serial InvalidKeyFormat (Req 6.7, 7.4)
//
// A 12-char generate body with a letter inside the first 12 (base-body)
// positions has a malformed numeric base -> InvalidKeyFormat (generate path).
pub fn generate_grai_letter_in_base_body_is_invalid_key_format_test() {
  gl_gtin.generate_key(Grai, "06141410000X")
  |> should.equal(Error(InvalidKeyFormat))
}

// ============================================================================
// Gdti — base 13, serial 0..17 alphanumeric (analogous to Grai)
// ============================================================================

pub fn validate_gdti_valid_base_succeeds_test() {
  gl_gtin.validate_key(Gdti, "0614141000012")
  |> should.equal(Ok(Gdti))
}

pub fn validate_gdti_valid_base_and_serial_succeeds_test() {
  gl_gtin.validate_key(Gdti, "0614141000012ABCDE")
  |> should.equal(Ok(Gdti))
}

pub fn generate_then_validate_gdti_round_trips_test() {
  let assert Ok(code) = gl_gtin.generate_key(Gdti, "061414100001ABCDE")
  gl_gtin.validate_key(Gdti, code)
  |> should.equal(Ok(Gdti))
}

pub fn validate_gdti_wrong_base_check_digit_test() {
  gl_gtin.validate_key(Gdti, "0614141000013")
  |> should.equal(Error(InvalidCheckDigit))
}

// A serial longer than 17 overflows the length rule (base 13 + 18 = 31 > 30).
pub fn validate_gdti_serial_over_max_is_invalid_length_test() {
  gl_gtin.validate_key(Gdti, "0614141000012ABCDEFGHIJKLMNOPQR")
  |> should.equal(Error(InvalidLength(got: 31)))
}

pub fn validate_gdti_out_of_charset_is_invalid_characters_test() {
  gl_gtin.validate_key(Gdti, "0614141000012-")
  |> should.equal(Error(InvalidCharacters))
}

// Feature: gl-gtin-gs1-keys, variable-serial InvalidKeyFormat (Req 6.7, 7.4)
pub fn validate_gdti_letter_in_base_is_invalid_key_format_test() {
  gl_gtin.validate_key(Gdti, "061414100001X")
  |> should.equal(Error(InvalidKeyFormat))
}

// Feature: gl-gtin-gs1-keys, variable-serial InvalidKeyFormat (Req 6.7, 7.4)
pub fn generate_gdti_letter_in_base_body_is_invalid_key_format_test() {
  gl_gtin.generate_key(Gdti, "06141410000X")
  |> should.equal(Error(InvalidKeyFormat))
}

// ============================================================================
// Gcn — base 13, serial 0..12 NUMERIC
// ============================================================================

pub fn validate_gcn_valid_base_succeeds_test() {
  gl_gtin.validate_key(Gcn, "0614141000012")
  |> should.equal(Ok(Gcn))
}

// A valid base plus a NUMERIC serial (<=12) validates as Gcn.
pub fn validate_gcn_valid_base_and_numeric_serial_succeeds_test() {
  gl_gtin.validate_key(Gcn, "0614141000012123")
  |> should.equal(Ok(Gcn))
}

// A valid base + numeric serial round-trips.
pub fn generate_then_validate_gcn_round_trips_test() {
  let assert Ok(code) = gl_gtin.generate_key(Gcn, "061414100001123")
  gl_gtin.validate_key(Gcn, code)
  |> should.equal(Ok(Gcn))
}

pub fn validate_gcn_wrong_base_check_digit_test() {
  gl_gtin.validate_key(Gcn, "0614141000013")
  |> should.equal(Error(InvalidCheckDigit))
}

// A LETTER in the serial is OUTSIDE Gcn's numeric union charset, so it is
// rejected at the character stage as InvalidCharacters (not InvalidKeyFormat).
pub fn validate_gcn_letter_in_serial_is_invalid_characters_test() {
  gl_gtin.validate_key(Gcn, "0614141000012A")
  |> should.equal(Error(InvalidCharacters))
}

// A serial longer than 12 overflows the length rule (base 13 + 13 = 26 > 25).
pub fn validate_gcn_serial_over_max_is_invalid_length_test() {
  gl_gtin.validate_key(Gcn, "06141410000121234567890123")
  |> should.equal(Error(InvalidLength(got: 26)))
}

// Gcn has NO reachable InvalidKeyFormat path: its serial charset is numeric, so
// its union charset is digits only. A letter inside the base region is caught
// earlier as InvalidCharacters (there is no non-digit that passes the union
// charset yet fails the numeric-base check).
pub fn validate_gcn_letter_in_base_is_invalid_characters_test() {
  gl_gtin.validate_key(Gcn, "061414100001X")
  |> should.equal(Error(InvalidCharacters))
}

// Same reasoning on the generate path: a letter in the base body is rejected as
// InvalidCharacters, never InvalidKeyFormat, for the numeric-serial Gcn.
pub fn generate_gcn_letter_in_base_body_is_invalid_characters_test() {
  gl_gtin.generate_key(Gcn, "06141410000X")
  |> should.equal(Error(InvalidCharacters))
}

// ============================================================================
// Giai — freeform 1..30 alphanumeric, NO check digit, NO InvalidKeyFormat path
// ============================================================================

// Alphanumeric bodies are accepted now: "ABC123" validates as Giai.
pub fn validate_giai_alphanumeric_succeeds_test() {
  gl_gtin.validate_key(Giai, "ABC123")
  |> should.equal(Ok(Giai))
}

// A freeform body (1..30 alphanumeric) generates verbatim (no check digit
// appended) and round-trips back to Giai.
pub fn generate_then_validate_giai_round_trips_test() {
  gl_gtin.generate_key(Giai, "ABC123")
  |> should.equal(Ok("ABC123"))

  let assert Ok(code) = gl_gtin.generate_key(Giai, "ABC123")
  gl_gtin.validate_key(Giai, code)
  |> should.equal(Ok(Giai))
}

// An over-length body (31 chars) overflows the 1..30 length rule.
// Giai has NO InvalidKeyFormat path — it is freeform with no base/serial split.
pub fn validate_giai_over_length_is_invalid_length_test() {
  gl_gtin.validate_key(Giai, "0000000000000000000000000000000")
  |> should.equal(Error(InvalidLength(got: 31)))
}

pub fn generate_giai_over_length_is_invalid_length_test() {
  gl_gtin.generate_key(Giai, "0000000000000000000000000000000")
  |> should.equal(Error(InvalidLength(got: 31)))
}

// A non-alphanumeric character (here "-") is rejected as InvalidCharacters.
pub fn validate_giai_out_of_charset_is_invalid_characters_test() {
  gl_gtin.validate_key(Giai, "ABC-123")
  |> should.equal(Error(InvalidCharacters))
}
