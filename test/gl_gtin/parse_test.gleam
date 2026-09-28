import gl_gtin
import gl_gtin/gtin_types.{
  Gtin13, Gtin14, InvalidCharacters, InvalidCheckDigit, InvalidLength,
}
import gl_gtin/parse.{GtinInfo}
import gleeunit/should

// F4 — parse (task 9.3)

// Worked example (Requirement 7.9): a GTIN-13 populates every field, with no
// indicator (Error(Nil)), the true GS1 prefix "629", its region, and the final
// digit as the check digit.
pub fn parse_gtin13_worked_example_test() {
  gl_gtin.parse("6291041500213")
  |> should.equal(
    Ok(GtinInfo(
      format: Gtin13,
      digits: "6291041500213",
      indicator: Error(Nil),
      gs1_prefix: "629",
      gs1_region: Ok("GS1 Emirates"),
      check_digit: 3,
    )),
  )
}

// GTIN-14 example (Requirement 7.4): the leading indicator digit is exposed as
// Ok(n). "16291041500210" is normalize_with_indicator("6291041500213", 1); its
// indicator is 1, the prefix drops the indicator to yield "629", and the check
// digit is the final digit 0.
pub fn parse_gtin14_indicator_test() {
  gl_gtin.parse("16291041500210")
  |> should.equal(
    Ok(GtinInfo(
      format: Gtin14,
      digits: "16291041500210",
      indicator: Ok(1),
      gs1_prefix: "629",
      gs1_region: Ok("GS1 Emirates"),
      check_digit: 0,
    )),
  )
}

// A GTIN-14's indicator field is Ok(n) rather than Error(Nil) (Requirement 7.4).
pub fn parse_gtin14_indicator_is_ok_test() {
  let assert Ok(info) = gl_gtin.parse("16291041500210")
  info.indicator
  |> should.equal(Ok(1))
}

// Invalid length (Requirement 7.10): a 3-digit code returns Error and never a
// GtinInfo.
pub fn parse_invalid_length_test() {
  gl_gtin.parse("123")
  |> should.equal(Error(InvalidLength(got: 3)))
}

// Invalid characters (Requirement 7.11): a non-numeric code returns Error and
// never a GtinInfo.
pub fn parse_invalid_characters_test() {
  gl_gtin.parse("629104150021A")
  |> should.equal(Error(InvalidCharacters))
}

// Invalid check digit (Requirement 7.12): a correct-length numeric code with a
// wrong check digit returns Error and never a GtinInfo. "6291041500213" is the
// valid code; flipping the final digit to 4 breaks the check digit.
pub fn parse_invalid_check_digit_test() {
  gl_gtin.parse("6291041500214")
  |> should.equal(Error(InvalidCheckDigit))
}

// F4 — doc-comment example mirror (Requirement 8.8)

// Mirrors the gl_gtin.parse doc example: the "6291041500213" worked example.
pub fn parse_doc_example_ok_test() {
  gl_gtin.parse("6291041500213")
  |> should.equal(
    Ok(GtinInfo(
      format: Gtin13,
      digits: "6291041500213",
      indicator: Error(Nil),
      gs1_prefix: "629",
      gs1_region: Ok("GS1 Emirates"),
      check_digit: 3,
    )),
  )
}

// Mirrors the gl_gtin.parse doc example: the invalid-character error case.
pub fn parse_doc_example_error_test() {
  gl_gtin.parse("invalid")
  |> should.equal(Error(InvalidCharacters))
}
