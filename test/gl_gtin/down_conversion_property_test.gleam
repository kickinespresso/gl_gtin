//// Property-based tests for the F3 GTIN-14 down-conversion functions.
////
//// These tests use `qcheck` with the shared `gen_gtin13` and `gen_upca`
//// generators and run at least 100 iterations each. They verify the universal
//// round-trip invariants of the down-conversion functions (`to_gtin13`,
//// `to_gtin12`) described in the design's Properties 9 and 10.

import gl_gtin
import gl_gtin/generators
import gl_gtin/gtin_types.{Gtin12, Gtin13}
import gleeunit/should
import qcheck

/// Run each property for at least 100 iterations.
fn config() -> qcheck.Config {
  qcheck.default_config() |> qcheck.with_test_count(100)
}

// Feature: gl-gtin-tier1-features, Property 9: GTIN-14 → GTIN-13 down-conversion round-trip
//
// For any valid GTIN-13 code `x`, building a GTIN-14 with indicator 0 via
// `normalize_with_indicator(x, 0)` and then down-converting with `to_gtin13`
// returns `Ok(x)`. The recovered GTIN-13 validates as `Ok(Gtin13)` and its
// check digit is preserved (the round-trip reproduces the original string).
pub fn gtin14_to_gtin13_round_trip_test() {
  use gtin13 <- qcheck.run(config(), generators.gen_gtin13())
  let assert Ok(gtin14) = gl_gtin.normalize_with_indicator(gtin13, 0)
  // Down-conversion recovers the original GTIN-13 exactly (check digit preserved).
  gl_gtin.to_gtin13(gtin14) |> should.equal(Ok(gtin13))
  // The recovered GTIN-13 validates as a GTIN-13.
  gl_gtin.validate(gtin13) |> should.equal(Ok(Gtin13))
}

// Feature: gl-gtin-tier1-features, Property 10: GTIN-14 → GTIN-12 down-conversion round-trip
//
// For any valid UPC-A (GTIN-12) code `u`, its GTIN-13 basis is `"0" <> u`
// (leading-zero padding preserves the mod-10 check digit). Building the GTIN-14
// with indicator 0 from that basis and applying `to_gtin12` returns `Ok(u)`,
// and the result validates as `Ok(Gtin12)`.
pub fn gtin14_to_gtin12_round_trip_test() {
  use upca <- qcheck.run(config(), generators.gen_upca())
  // The GTIN-13 basis is the UPC-A padded with a leading zero.
  let gtin13_basis = "0" <> upca
  let assert Ok(gtin14) = gl_gtin.normalize_with_indicator(gtin13_basis, 0)
  // Down-conversion recovers the original UPC-A exactly.
  gl_gtin.to_gtin12(gtin14) |> should.equal(Ok(upca))
  // The recovered UPC-A validates as a GTIN-12.
  gl_gtin.validate(upca) |> should.equal(Ok(Gtin12))
}
