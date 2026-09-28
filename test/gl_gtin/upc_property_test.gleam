//// Property-based tests for the F1 UPC-E ⇄ UPC-A conversion.
////
//// These tests use `qcheck` with the shared `gen_upce` generator and run at
//// least 100 iterations each. They verify the universal invariants of the
//// UPC conversion functions (`upce_to_upca`, `upca_to_upce`) described in the
//// design's Properties 4 and 5.

import gl_gtin
import gl_gtin/generators
import gl_gtin/gtin_types.{Gtin12}
import gleeunit/should
import qcheck

/// Run each property for at least 100 iterations.
fn config() -> qcheck.Config {
  qcheck.default_config() |> qcheck.with_test_count(100)
}

// Feature: gl-gtin-tier1-features, Property 4: UPC-E expansion always yields a valid UPC-A
//
// For any valid UPC-E code (number-system digit 0 or 1, correct check digit),
// expanding it produces a 12-digit UPC-A that validates as a GTIN-12:
// `validate(upce_to_upca(x)) == Ok(Gtin12)`.
pub fn upce_expansion_yields_valid_upca_test() {
  use upce <- qcheck.run(config(), generators.gen_upce())
  let assert Ok(upca) = gl_gtin.upce_to_upca(upce)
  gl_gtin.validate(upca) |> should.equal(Ok(Gtin12))
}

// Feature: gl-gtin-tier1-features, Property 5: UPC-E ⇄ UPC-A round-trip
//
// For any valid UPC-E code (number-system digit 0 or 1, correct check digit),
// expanding to UPC-A and compressing back returns the original UPC-E:
// `upca_to_upce(upce_to_upca(x)) == Ok(x)`.
pub fn upce_upca_round_trip_test() {
  use upce <- qcheck.run(config(), generators.gen_upce())
  let assert Ok(upca) = gl_gtin.upce_to_upca(upce)
  gl_gtin.upca_to_upce(upca) |> should.equal(Ok(upce))
}
