//// Property-based tests for the F7 generic-key validate/generate driver
//// (`gl_gtin/gs1_key`).
////
//// These tests use `qcheck` with the shared generators in
//// `gl_gtin/gs1_key_generators` and run at least 100 iterations each. They
//// verify the universal invariants of the generic `validate_key`/`generate_key`
//// machinery described in the design's Properties 3, 4, 7, and 8.

import gl_gtin/gs1_key.{InvalidCharacters, InvalidLength}
import gl_gtin/gs1_key_generators
import gl_gtin/gtin_types.{
  type Gs1Key, Gcn, Gdti, Giai, Gln, Grai, Gsin, Gsrn, Gtin, Sscc,
}
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import qcheck

/// Run each property for at least 100 iterations.
fn config() -> qcheck.Config {
  qcheck.default_config() |> qcheck.with_test_count(100)
}

// --- Property 3 helpers ---

/// The kinds that round-trip cleanly through `generate_key → validate_key`.
///
/// ALL nine kinds now round-trip. The reworked driver splits the variable-serial
/// keys into a numeric base (carrying the mod-10 check on its last digit) and an
/// optional typed serial, so `gen_key_body(kind)` produces a body every kind can
/// round-trip:
///
/// - GTIN / GLN / SSCC / GSIN / GSRN: fixed numeric keys — the body is all
///   digits and the mod-10 check is appended over the full length.
/// - GRAI / GDTI: a 12-digit base body plus an ALPHANUMERIC serial; the check is
///   appended over the base body and the serial is carried through verbatim.
/// - GCN: a 12-digit base body plus a NUMERIC serial (same base handling).
/// - GIAI: a freeform 1..30 alphanumeric body returned verbatim (no check digit).
fn round_trip_kinds() -> List(Gs1Key) {
  [Gtin, Gln, Sscc, Gsin, Gsrn, Grai, Giai, Gdti, Gcn]
}

/// Generate a `(kind, body)` pair whose `kind` is one of the clean round-trip
/// kinds and whose `body` is a well-formed body for that kind.
fn gen_kind_and_body() -> qcheck.Generator(#(Gs1Key, String)) {
  let kinds = round_trip_kinds()
  let max = list.length(kinds) - 1
  use index <- qcheck.bind(qcheck.bounded_int(0, max))
  let kind = case list.drop(kinds, index) {
    [k, ..] -> k
    [] -> Gtin
  }
  use body <- qcheck.map(gs1_key_generators.gen_key_body(kind))
  #(kind, body)
}

// Feature: gl-gtin-gs1-keys, Property 3: Generic key generate → validate round-trip
//
// For any supported kind `k` and any well-formed body `b` for that kind,
// generating a key and validating it under the same kind returns the kind:
// `validate_key(k, generate_key(k, b)) == Ok(k)`.
//
// Covered kinds: all nine — Gtin, Gln, Sscc, Gsin, Gsrn, Grai, Giai, Gdti, Gcn.
// The reworked base/serial driver lets the variable-serial kinds round-trip via
// `gen_key_body` (see `round_trip_kinds`).
pub fn generic_key_generate_validate_round_trip_test() {
  use pair <- qcheck.run(config(), gen_kind_and_body())
  let #(kind, body) = pair
  let assert Ok(code) = gs1_key.generate_key(kind, body)
  gs1_key.validate_key(kind, code) |> should.equal(Ok(kind))
}

// Feature: gl-gtin-gs1-keys, Property 4: Same-length keys are judged only against the supplied kind
//
// SSCC and GSRN are both 18-digit mod-10 keys, so a single generated code is
// valid under both. Validating that code under each kind returns exactly the
// supplied kind — never the other — confirming a code is judged solely against
// the kind passed in, not inferred from its length.
pub fn same_length_keys_judged_only_against_supplied_kind_test() {
  // A body valid for Sscc is equally valid for Gsrn (both 17-digit bodies).
  use body <- qcheck.run(config(), gs1_key_generators.gen_key_body(Sscc))
  let assert Ok(code) = gs1_key.generate_key(Sscc, body)
  // Each validation is judged only against its supplied kind.
  gs1_key.validate_key(Sscc, code) |> should.equal(Ok(Sscc))
  gs1_key.validate_key(Gsrn, code) |> should.equal(Ok(Gsrn))
}

// --- Property 7 helper ---

/// Generate a numeric string whose length is NOT 13 (the GLN total length), so
/// it always fails the GLN length check. Length is drawn from 0..25 excluding
/// 13; the digit content is irrelevant because the length rule is evaluated
/// before the check digit.
fn gen_wrong_length_numeric() -> qcheck.Generator(String) {
  use raw_len <- qcheck.bind(qcheck.bounded_int(0, 24))
  // Map any draw that would hit 13 onto 25 to keep the length off the GLN total.
  let length = case raw_len {
    13 -> 25
    other -> other
  }
  use digits <- qcheck.map(qcheck.fixed_length_list_from(
    qcheck.bounded_int(0, 9),
    length,
  ))
  digits |> list.map(int.to_string) |> string.concat
}

// Feature: gl-gtin-gs1-keys, Property 7: Wrong length is reported with the trimmed digit count
//
// For any numeric string of length `n` that does not match the GLN total (13),
// `validate_key(Gln, code)` reports `Error(InvalidLength(got: n))` with `n` the
// trimmed digit count.
pub fn wrong_length_reported_with_trimmed_digit_count_test() {
  use code <- qcheck.run(config(), gen_wrong_length_numeric())
  let n = string.length(code)
  gs1_key.validate_key(Gln, code)
  |> should.equal(Error(InvalidLength(got: n)))
}

// --- Property 8 helpers ---

/// Generate a `(kind, code)` pair whose `code` is a digit string of arbitrary
/// length with a single non-digit character injected at an arbitrary position,
/// so `parse_body_digits` must fail with `InvalidCharacters` regardless of the
/// resulting length or the kind.
fn gen_non_digit_code() -> qcheck.Generator(#(Gs1Key, String)) {
  let kinds = [Gtin, Gln, Sscc, Gsin, Gsrn]
  let kind_max = list.length(kinds) - 1
  use kind_index <- qcheck.bind(qcheck.bounded_int(0, kind_max))
  let kind = case list.drop(kinds, kind_index) {
    [k, ..] -> k
    [] -> Gtin
  }
  use length <- qcheck.bind(qcheck.bounded_int(0, 24))
  use digits <- qcheck.bind(qcheck.fixed_length_list_from(
    qcheck.bounded_int(0, 9),
    length,
  ))
  let base = digits |> list.map(int.to_string) |> string.concat
  // Insert a non-digit at an arbitrary position within the digit string.
  use pos <- qcheck.map(qcheck.bounded_int(0, length))
  let code =
    string.slice(base, 0, pos) <> "X" <> string.slice(base, pos, length - pos)
  #(kind, code)
}

// Feature: gl-gtin-gs1-keys, Property 8: Non-digit input is rejected before length
//
// For any kind and any input containing a non-digit character, `validate_key`
// returns `Error(InvalidCharacters)` regardless of the input's length — the
// character check runs before the length check.
pub fn non_digit_input_rejected_before_length_test() {
  use pair <- qcheck.run(config(), gen_non_digit_code())
  let #(kind, code) = pair
  gs1_key.validate_key(kind, code)
  |> should.equal(Error(InvalidCharacters))
}
