//// Property-based tests for the F5 (SSCC) and F6 (GSIN) validate/generate
//// helpers in `gl_gtin/gs1_key`.
////
//// These tests use `qcheck` with the shared generators in
//// `gl_gtin/gs1_key_generators` and run at least 100 iterations each. They
//// cover the design's Properties 1, 2, 5, and 6:
////
//// - Property 1: SSCC generate → validate round-trip (Req 2.4).
//// - Property 2: GSIN generate → validate round-trip (Req 4.4).
//// - Property 5: SSCC validation rejects a valid GTIN-14 by length (Req 1.7).
//// - Property 6: GSIN validation rejects a valid SSCC by length (Req 3.7).

import gl_gtin/gs1_key.{InvalidLength}
import gl_gtin/gs1_key_generators
import gl_gtin/gtin_types.{Gtin}
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import qcheck

/// Run each property for at least 100 iterations.
fn config() -> qcheck.Config {
  qcheck.default_config() |> qcheck.with_test_count(100)
}

/// Generate a 13-digit numeric GTIN-14 body (the 13 data digits before the
/// mod-10 check digit), so `generate_key(Gtin, _)` always yields a 14-digit
/// GTIN-14. `gen_key_body(Gtin)` yields bodies of 7/11/12/13, so a dedicated
/// 13-digit body is used here to guarantee the 14-digit length that Property 5
/// exercises.
fn gen_gtin14_body() -> qcheck.Generator(String) {
  use digits <- qcheck.map(qcheck.fixed_length_list_from(
    qcheck.bounded_int(0, 9),
    13,
  ))
  digits |> list.map(int.to_string) |> string.concat
}

// Feature: gl-gtin-gs1-keys, Property 1: SSCC generate → validate round-trip
//
// For any well-formed 17-digit SSCC body `b`, generating an SSCC and then
// validating it round-trips cleanly: `validate_sscc(generate_sscc(b))` returns
// `Ok("SSCC")`. (Req 2.4)
pub fn sscc_generate_validate_round_trip_test() {
  use body <- qcheck.run(config(), gs1_key_generators.gen_sscc_body())
  let assert Ok(code) = gs1_key.generate_sscc(body)
  gs1_key.validate_sscc(code) |> should.equal(Ok("SSCC"))
}

// Feature: gl-gtin-gs1-keys, Property 2: GSIN generate → validate round-trip
//
// For any well-formed 16-digit GSIN body `b`, generating a GSIN and then
// validating it round-trips cleanly: `validate_gsin(generate_gsin(b))` returns
// `Ok("GSIN")`. (Req 4.4)
pub fn gsin_generate_validate_round_trip_test() {
  use body <- qcheck.run(config(), gs1_key_generators.gen_gsin_body())
  let assert Ok(code) = gs1_key.generate_gsin(body)
  gs1_key.validate_gsin(code) |> should.equal(Ok("GSIN"))
}

// Feature: gl-gtin-gs1-keys, Property 5: SSCC validation rejects a valid GTIN-14 by length
//
// A valid 14-digit GTIN-14 is never accepted as an SSCC: because SSCC is a
// fixed 18-digit key, `validate_sscc(gtin14)` returns
// `Error(InvalidLength(got: 14))` and never `Ok("SSCC")`. (Req 1.7)
pub fn sscc_rejects_valid_gtin14_by_length_test() {
  use body <- qcheck.run(config(), gen_gtin14_body())
  let assert Ok(gtin14) = gs1_key.generate_key(Gtin, body)
  // Sanity: the generated code is a 14-digit GTIN-14.
  string.length(gtin14) |> should.equal(14)
  gs1_key.validate_sscc(gtin14)
  |> should.equal(Error(InvalidLength(got: 14)))
}

// Feature: gl-gtin-gs1-keys, Property 6: GSIN validation rejects a valid SSCC by length
//
// A valid 18-digit SSCC is never accepted as a GSIN: because GSIN is a fixed
// 17-digit key, `validate_gsin(sscc)` returns `Error(InvalidLength(got: 18))`
// and never `Ok("GSIN")`. (Req 3.7)
pub fn gsin_rejects_valid_sscc_by_length_test() {
  use body <- qcheck.run(config(), gs1_key_generators.gen_sscc_body())
  let assert Ok(sscc) = gs1_key.generate_sscc(body)
  // Sanity: the generated code is an 18-digit SSCC.
  string.length(sscc) |> should.equal(18)
  gs1_key.validate_gsin(sscc)
  |> should.equal(Error(InvalidLength(got: 18)))
}
