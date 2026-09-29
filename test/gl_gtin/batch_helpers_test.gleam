//// Tests for the F9 batch helpers (`validate_all` and `partition`) added to the
//// public facade `gl_gtin`.
////
//// This module is auto-discovered by gleeunit. It hosts the shared property-test
//// generators for the batch helpers as well as the unit, doc-comment example, and
//// property-based tests that consume them.
////
//// Generators (backed by `qcheck`, consistent with the sibling `gl_gtin` specs):
////
//// - `gen_valid_code` — samples known-valid GTINs of each length, optionally
////   wrapped in surrounding whitespace to exercise the untrimmed-key requirement
////   (Req 1.2, 2.4).
//// - `gen_invalid_code` — samples wrong-check-digit, wrong-length, non-digit,
////   whitespace-only, and empty strings.
//// - `gen_code_list` — builds a list of 0..N elements drawn independently from
////   either the valid or invalid generator, deliberately mixing validity and
////   allowing duplicates so the order, duplicate, and conservation properties are
////   meaningfully exercised.

import qcheck

/// Generate a known-valid GTIN string, sampled uniformly from the known-valid
/// GTINs (one per length: GTIN-8, GTIN-12, GTIN-13, GTIN-14) and then optionally
/// wrapped in surrounding whitespace. The whitespace variants
/// still validate `Ok` (the engine trims internally) while their stored
/// key/value remains the byte-for-byte original, exercising the untrimmed-key /
/// untrimmed-original requirements (Req 1.2, 2.4).
pub fn gen_valid_code() -> qcheck.Generator(String) {
  let base =
    qcheck.from_generators(qcheck.constant("12345670"), [
      qcheck.constant("012345678905"),
      qcheck.constant("6291041500213"),
      qcheck.constant("12345678901231"),
    ])
  use code, wrap <- qcheck.map2(base, qcheck.bounded_int(0, 2))
  case wrap {
    0 -> code
    1 -> " " <> code
    _ -> "  \t" <> code <> " \n "
  }
}

/// Generate a representative invalid code string, sampled uniformly from
/// `invalid_codes` (wrong check digit, wrong length, non-digit, whitespace-only,
/// and empty). Each validates `Error(...)`.
pub fn gen_invalid_code() -> qcheck.Generator(String) {
  qcheck.from_generators(qcheck.constant("6291041500214"), [
    qcheck.constant("123"),
    qcheck.constant("629104150021A"),
    qcheck.constant("abc"),
    qcheck.constant("   "),
    qcheck.constant(""),
  ])
}

/// Generate a list of 0..N code strings, drawing each element independently from
/// either `gen_valid_code` or `gen_invalid_code`. Because elements are drawn
/// independently and both generators sample from small fixed pools, the
/// resulting lists deliberately mix valid and invalid codes and commonly include
/// duplicates, so the order-, duplicate-, and conservation-preservation
/// properties are meaningfully exercised.
pub fn gen_code_list() -> qcheck.Generator(List(String)) {
  let element = qcheck.from_generators(gen_valid_code(), [gen_invalid_code()])
  qcheck.generic_list(
    elements_from: element,
    length_from: qcheck.bounded_int(0, 12),
  )
}

import gl_gtin
import gl_gtin/gtin_types.{Gtin13, InvalidCheckDigit, InvalidLength}
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should

// --- validate_all unit and doc-comment example tests (Task 2.2) ---

// Mixed valid/invalid list yields the expected pairs (Req 1.1, 1.3, 1.7).
pub fn validate_all_mixed_list_yields_expected_pairs_test() {
  gl_gtin.validate_all(["6291041500213", "123", "012345678905"])
  |> should.equal([
    #("6291041500213", Ok(Gtin13)),
    #("123", Error(InvalidLength(got: 3))),
    #("012345678905", Ok(gtin_types.Gtin12)),
  ])
}

// Empty list yields an empty list (Req 1.5).
pub fn validate_all_empty_list_test() {
  gl_gtin.validate_all([])
  |> should.equal([])
}

// Order is preserved: the keys appear in the same order as the input (Req 1.4).
pub fn validate_all_preserves_order_test() {
  let input = ["6291041500213", "123", "012345678905", "abc"]
  gl_gtin.validate_all(input)
  |> list.map(fn(pair) { pair.0 })
  |> should.equal(input)
}

// Duplicates are preserved: one pair per occurrence, no dedup (Req 1.6).
pub fn validate_all_preserves_duplicates_test() {
  gl_gtin.validate_all(["6291041500213", "6291041500213", "123"])
  |> should.equal([
    #("6291041500213", Ok(Gtin13)),
    #("6291041500213", Ok(Gtin13)),
    #("123", Error(InvalidLength(got: 3))),
  ])
}

// Doc-comment example mirrored as an assertion (Req 5.5).
pub fn validate_all_doc_comment_example_test() {
  gl_gtin.validate_all(["6291041500213", "6291041500214"])
  |> should.equal([
    #("6291041500213", Ok(Gtin13)),
    #("6291041500214", Error(InvalidCheckDigit)),
  ])
}

// A whitespace-padded-but-valid element validates Ok, yet the stored key is the
// untrimmed byte-for-byte original (Req 1.2).
pub fn validate_all_stores_untrimmed_original_key_test() {
  gl_gtin.validate_all(["  6291041500213 "])
  |> should.equal([#("  6291041500213 ", Ok(Gtin13))])
}

// --- partition unit and doc-comment example tests (Task 3.2) ---

// Mixed valid/invalid list splits correctly into #(valid, invalid) with the
// originals routed by validation outcome (Req 2.1, 2.2, 2.3).
pub fn partition_mixed_list_splits_correctly_test() {
  gl_gtin.partition(["6291041500213", "123", "012345678905", "abc"])
  |> should.equal(#(["6291041500213", "012345678905"], ["123", "abc"]))
}

// Empty list yields a 2-tuple of two empty lists (Req 2.6).
pub fn partition_empty_list_test() {
  gl_gtin.partition([])
  |> should.equal(#([], []))
}

// Relative order is preserved within each output list (Req 2.5).
pub fn partition_preserves_order_within_each_list_test() {
  gl_gtin.partition(["6291041500213", "123", "012345678905", "abc", "12345670"])
  |> should.equal(
    #(["6291041500213", "012345678905", "12345670"], ["123", "abc"]),
  )
}

// Duplicates are preserved: one entry per occurrence in the appropriate list,
// with no dedup (Req 2.7).
pub fn partition_preserves_duplicates_test() {
  gl_gtin.partition(["6291041500213", "6291041500213", "123", "123"])
  |> should.equal(#(["6291041500213", "6291041500213"], ["123", "123"]))
}

// Concatenation / count invariant on a fixed list: every input element appears
// across the two output lists exactly as many times as in the input, so the
// combined length equals the input length (Req 2.8).
pub fn partition_conserves_element_count_test() {
  let input = ["6291041500213", "123", "012345678905", "abc", "6291041500213"]
  let #(valid, invalid) = gl_gtin.partition(input)
  list.length(valid) + list.length(invalid)
  |> should.equal(list.length(input))
}

// Doc-comment example mirrored as an assertion (Req 5.5).
pub fn partition_doc_comment_example_test() {
  gl_gtin.partition(["6291041500213", "6291041500214"])
  |> should.equal(#(["6291041500213"], ["6291041500214"]))
}

// A whitespace-padded-but-valid element validates Ok, so it is routed to the
// valid list, yet the stored value is the untrimmed byte-for-byte original
// (Req 2.4).
pub fn partition_stores_untrimmed_original_test() {
  gl_gtin.partition(["  6291041500213 ", "123"])
  |> should.equal(#(["  6291041500213 "], ["123"]))
}

// --- validate_all property tests (Task 5.1) ---

/// Run each property for at least 100 iterations.
fn config() -> qcheck.Config {
  qcheck.default_config() |> qcheck.with_test_count(100)
}

// Feature: gl-gtin-batch-helpers, Property 1: validate_all keys are the original inputs, positionally
//
// For any list of strings `xs` from `gen_code_list()`, the list of first tuple
// elements produced by `validate_all(xs)` equals `xs` element-for-element in the
// same positions — same length, same order, same duplicates, each string
// byte-for-byte unmodified (untrimmed).
pub fn validate_all_keys_are_original_inputs_positionally_test() {
  use xs <- qcheck.run(config(), gen_code_list())
  list.map(gl_gtin.validate_all(xs), fn(p) { p.0 })
  |> should.equal(xs)
}

// Feature: gl-gtin-batch-helpers, Property 2: validate_all value equals validate of its key
//
// For any list of strings `xs` from `gen_code_list()`, every pair `#(c, r)` in
// `validate_all(xs)` satisfies `r == validate(c)`. In particular, an `Error(e)`
// from `validate` is captured verbatim as the pair value.
pub fn validate_all_value_equals_validate_of_key_test() {
  use xs <- qcheck.run(config(), gen_code_list())
  gl_gtin.validate_all(xs)
  |> list.all(fn(pair) {
    let #(c, r) = pair
    r == gl_gtin.validate(c)
  })
  |> should.be_true()
}

// --- partition property tests (Task 5.2) ---

// Feature: gl-gtin-batch-helpers, Property 3: partition membership agrees with validate
//
// For any list of strings `xs` from `gen_code_list()`, with
// `#(v, i) = partition(xs)`, every element of `v` validates `Ok` and every
// element of `i` validates `Error`.
pub fn partition_membership_agrees_with_validate_test() {
  use xs <- qcheck.run(config(), gen_code_list())
  let #(v, i) = gl_gtin.partition(xs)
  let valid_ok = list.all(v, fn(e) { result.is_ok(gl_gtin.validate(e)) })
  let invalid_error =
    list.all(i, fn(e) { result.is_error(gl_gtin.validate(e)) })
  { valid_ok && invalid_error }
  |> should.be_true()
}

// Feature: gl-gtin-batch-helpers, Property 4: partition preserves relative order within each list
//
// For any list of strings `xs` from `gen_code_list()`, with
// `#(v, i) = partition(xs)`, `v` equals `xs` order-preservingly filtered to the
// elements that validate `Ok`, and `i` equals `xs` filtered to those that
// validate `Error`.
pub fn partition_preserves_relative_order_within_each_list_test() {
  use xs <- qcheck.run(config(), gen_code_list())
  let #(v, i) = gl_gtin.partition(xs)
  let expected_valid =
    list.filter(xs, fn(e) { result.is_ok(gl_gtin.validate(e)) })
  let expected_invalid =
    list.filter(xs, fn(e) { result.is_error(gl_gtin.validate(e)) })
  { v == expected_valid && i == expected_invalid }
  |> should.be_true()
}

// Feature: gl-gtin-batch-helpers, Property 5: partition conserves elements
//
// For any list of strings `xs` from `gen_code_list()`, with
// `#(v, i) = partition(xs)`, the combined length equals the input length and
// `v ++ i` is a permutation of `xs` (multiset equality via sorting).
pub fn partition_conserves_elements_test() {
  use xs <- qcheck.run(config(), gen_code_list())
  let #(v, i) = gl_gtin.partition(xs)
  let count_ok = list.length(v) + list.length(i) == list.length(xs)
  let multiset_ok =
    list.sort(list.append(v, i), string.compare)
    == list.sort(xs, string.compare)
  { count_ok && multiset_ok }
  |> should.be_true()
}

// --- totality and cross-helper agreement property tests (Task 5.3) ---

// Feature: gl-gtin-batch-helpers, Property 6: both helpers are total over arbitrary strings
//
// For any list of arbitrary strings `xs` from `gen_code_list()` — including
// non-digit, whitespace, and empty elements — both `validate_all` and
// `partition` evaluate to fully-defined results without raising. Forcing full
// evaluation and reaching the assertions proves no panic occurred:
// `list.length(validate_all(xs)) == list.length(xs)` and, for
// `#(v, i) = partition(xs)`, `list.length(v) + list.length(i) == list.length(xs)`.
pub fn both_helpers_are_total_over_arbitrary_strings_test() {
  use xs <- qcheck.run(config(), gen_code_list())
  let validate_all_total =
    list.length(gl_gtin.validate_all(xs)) == list.length(xs)
  let #(v, i) = gl_gtin.partition(xs)
  let partition_total = list.length(v) + list.length(i) == list.length(xs)
  { validate_all_total && partition_total }
  |> should.be_true()
}

// Feature: gl-gtin-batch-helpers, Property 7: partition classification agrees with validate_all
//
// For any list of strings `xs` from `gen_code_list()`, with
// `#(v, _) = partition(xs)`, the multiset of `v` equals the multiset of keys `c`
// in `validate_all(xs)` whose result is `Ok(_)` (multiset equality via sorting).
pub fn partition_classification_agrees_with_validate_all_test() {
  use xs <- qcheck.run(config(), gen_code_list())
  let #(v, _) = gl_gtin.partition(xs)
  let validate_all_oks =
    gl_gtin.validate_all(xs)
    |> list.filter(fn(pair) { result.is_ok(pair.1) })
    |> list.map(fn(pair) { pair.0 })
  {
    list.sort(v, string.compare) == list.sort(validate_all_oks, string.compare)
  }
  |> should.be_true()
}
