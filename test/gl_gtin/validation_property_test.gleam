//// Property-based tests for the F2 configurable GTIN-14 indicator digit.
////
//// These tests use `qcheck` with the shared `gen_gtin13` generator and run at
//// least 100 iterations each. They verify the universal invariants of the
//// indicator-aware normalization functions (`normalize_with_indicator`,
//// `normalize`) described in the design's Properties 6, 7, and 8.

import gl_gtin
import gl_gtin/generators
import gl_gtin/gtin_types.{Gtin14}
import gleam/int
import gleam/string
import gleeunit/should
import qcheck

/// Run each property for at least 100 iterations.
fn config() -> qcheck.Config {
  qcheck.default_config() |> qcheck.with_test_count(100)
}

/// Generate a valid GTIN-13 paired with an indicator digit in 0..9. Backs the
/// combined `gen_gtin13 × indicator 0..9` input space for Property 6.
fn gen_gtin13_with_indicator() -> qcheck.Generator(#(String, Int)) {
  use gtin13, indicator <- qcheck.map2(
    generators.gen_gtin13(),
    qcheck.bounded_int(0, 9),
  )
  #(gtin13, indicator)
}

// Feature: gl-gtin-tier1-features, Property 6: indicator normalization produces a valid GTIN-14 led by the indicator
//
// For any valid GTIN-13 code and any indicator in 0..9,
// `normalize_with_indicator` returns a 14-digit string whose first digit equals
// the supplied indicator and which validates as `Ok(Gtin14)`.
pub fn indicator_normalization_produces_valid_gtin14_test() {
  use pair <- qcheck.run(config(), gen_gtin13_with_indicator())
  let #(gtin13, indicator) = pair
  let assert Ok(gtin14) = gl_gtin.normalize_with_indicator(gtin13, indicator)
  // Exactly 14 digits.
  string.length(gtin14) |> should.equal(14)
  // Leading digit equals the supplied indicator.
  string.first(gtin14) |> should.equal(Ok(int.to_string(indicator)))
  // Validates as a GTIN-14.
  gl_gtin.validate(gtin14) |> should.equal(Ok(Gtin14))
}

// Feature: gl-gtin-tier1-features, Property 7: whitespace invariance of indicator normalization
//
// For any valid GTIN-13 code and any indicator in 0..9, surrounding the code
// with leading/trailing whitespace produces the same result as the untrimmed
// code.
pub fn whitespace_invariance_of_indicator_normalization_test() {
  use pair <- qcheck.run(config(), gen_gtin13_with_indicator())
  let #(gtin13, indicator) = pair
  let padded = "  \t" <> gtin13 <> " \n "
  gl_gtin.normalize_with_indicator(padded, indicator)
  |> should.equal(gl_gtin.normalize_with_indicator(gtin13, indicator))
}

// Feature: gl-gtin-tier1-features, Property 8: normalize equals indicator-1 normalization
//
// For any GTIN-13 input, `normalize(x)` equals
// `normalize_with_indicator(x, 1)`.
pub fn normalize_equals_indicator_one_normalization_test() {
  use gtin13 <- qcheck.run(config(), generators.gen_gtin13())
  gl_gtin.normalize(gtin13)
  |> should.equal(gl_gtin.normalize_with_indicator(gtin13, 1))
}
