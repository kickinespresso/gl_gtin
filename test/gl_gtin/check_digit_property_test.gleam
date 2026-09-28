//// Property-based tests for the F0 check-digit engine.
////
//// These tests use `qcheck` with the shared `gen_digit_body` generator and run
//// at least 100 iterations each. They verify the universal invariants of the
//// generalized check-digit engine (`calculate`, `valid`, `append`) described in
//// the design's Properties 1, 2, and 3.

import gl_gtin/check_digit
import gl_gtin/generators
import gleam/list
import gleeunit/should
import qcheck

/// Run each property for at least 100 iterations.
fn config() -> qcheck.Config {
  qcheck.default_config() |> qcheck.with_test_count(100)
}

// Feature: gl-gtin-tier1-features, Property 1: append then valid round-trip
//
// For any well-formed digit body, appending the computed check digit yields a
// list that `valid` accepts: `valid(append(body)) == True`.
pub fn append_then_valid_round_trip_test() {
  use body <- qcheck.run(config(), generators.gen_digit_body())
  let assert Ok(with_check) = check_digit.append(body)
  check_digit.valid(with_check) |> should.be_true
}

// Feature: gl-gtin-tier1-features, Property 2: append appends exactly the computed check digit
//
// For any well-formed digit body, `append(body)` returns the body with exactly
// the computed check digit appended: `append(body) == Ok(body ++ [calculate(body)])`.
pub fn append_appends_computed_check_digit_test() {
  use body <- qcheck.run(config(), generators.gen_digit_body())
  let assert Ok(check) = check_digit.calculate(body)
  check_digit.append(body)
  |> should.equal(Ok(list.append(body, [check])))
}

// Feature: gl-gtin-tier1-features, Property 3: valid rejects a wrong check digit
//
// For any well-formed digit body, perturbing the appended check digit (replacing
// it with any other digit) makes the resulting list invalid: `valid == False`.
pub fn valid_rejects_wrong_check_digit_test() {
  use body <- qcheck.run(config(), generators.gen_digit_body())
  let assert Ok(check) = check_digit.calculate(body)
  // Perturb the check digit to a different value in 0..9.
  let wrong = { check + 1 } % 10
  check_digit.valid(list.append(body, [wrong])) |> should.be_false
}
