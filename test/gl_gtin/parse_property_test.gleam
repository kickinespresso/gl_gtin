//// Property-based tests for the F4 structured `parse` -> `GtinInfo` module.
////
//// These tests use `qcheck` with the shared generators (`gen_gtin13`,
//// `gen_upca`), a locally derived GTIN-14 generator (via
//// `normalize_with_indicator`), and a small local GTIN-8 generator (7 random
//// data digits + a computed check digit via `gl_gtin.generate`). Each property
//// runs at least 100 iterations and verifies the universal invariants of
//// `parse` described in the design's Properties 11 and 12.

import gl_gtin
import gl_gtin/generators
import gl_gtin/gs1_prefix
import gl_gtin/gtin_types.{
  type GtinFormat, Gtin12, Gtin13, Gtin14, Gtin8, NoGs1PrefixFound,
}
import gl_gtin/parse.{GtinInfo}
import gleam/int
import gleam/string
import gleeunit/should
import qcheck

/// Run each property for at least 100 iterations.
fn config() -> qcheck.Config {
  qcheck.default_config() |> qcheck.with_test_count(100)
}

/// Generate a single decimal digit (0..9).
fn gen_digit() -> qcheck.Generator(Int) {
  qcheck.bounded_int(0, 9)
}

/// Generate a valid 8-digit GTIN-8 string.
///
/// Seven random data digits are rendered to a string and the GS1 check digit is
/// appended via `gl_gtin.generate` (which accepts a 7-digit body and yields an
/// 8-digit code). If generation ever fails (it should not for these inputs) the
/// candidate falls back to a fixed valid GTIN-8 so the generator stays total.
fn gen_gtin8() -> qcheck.Generator(String) {
  use data <- qcheck.map(qcheck.fixed_length_list_from(gen_digit(), 7))
  let body =
    data
    |> list_to_string
  case gl_gtin.generate(body) {
    Ok(code) -> code
    Error(_) -> "00000000"
  }
}

/// Generate a valid 14-digit GTIN-14 string derived from a GTIN-13 basis and an
/// indicator in 0..9 via `normalize_with_indicator`. Falls back to the untouched
/// GTIN-13-derived code only if normalization fails (it should not here).
fn gen_gtin14() -> qcheck.Generator(String) {
  use gtin13, indicator <- qcheck.map2(
    generators.gen_gtin13(),
    qcheck.bounded_int(0, 9),
  )
  case gl_gtin.normalize_with_indicator(gtin13, indicator) {
    Ok(gtin14) -> gtin14
    Error(_) -> gtin13
  }
}

/// Render a list of single digits to a decimal string.
fn list_to_string(digits: List(Int)) -> String {
  digits
  |> list_fold("")
}

/// Fold helper: concatenate the decimal form of each digit.
fn list_fold(digits: List(Int), acc: String) -> String {
  case digits {
    [] -> acc
    [head, ..tail] -> list_fold(tail, acc <> int.to_string(head))
  }
}

/// Compute the expected `gs1_prefix` for a code of a given format: the leading
/// three characters of the format-normalized 13-digit basis. Mirrors `parse`'s
/// (and `gs1_prefix`'s) own normalization rule so the assertion is independent
/// of the implementation under test.
fn expected_prefix(code: String, format: GtinFormat) -> String {
  let basis = case format {
    Gtin12 -> "0" <> code
    Gtin14 -> string.slice(code, 1, 13)
    _ -> code
  }
  string.slice(basis, 0, 3)
}

/// The expected integer value of a code's final digit.
fn expected_check_digit(code: String) -> Int {
  case int.parse(string.slice(code, string.length(code) - 1, 1)) {
    Ok(n) -> n
    Error(_) -> -1
  }
}

/// The expected indicator field for a code of a given format.
fn expected_indicator(code: String, format: GtinFormat) -> Result(Int, Nil) {
  case format {
    Gtin14 -> int.parse(string.slice(code, 0, 1))
    _ -> Error(Nil)
  }
}

/// Assert that `parse(code)` populates every `GtinInfo` field per its format.
fn assert_fields(code: String, format: GtinFormat) -> Nil {
  case gl_gtin.parse(code) {
    Error(_) -> should.fail()
    Ok(info) -> {
      let GtinInfo(
        format: got_format,
        digits: got_digits,
        indicator: got_indicator,
        gs1_prefix: got_prefix,
        gs1_region: _,
        check_digit: got_check,
      ) = info
      got_format |> should.equal(format)
      got_digits |> should.equal(code)
      got_indicator |> should.equal(expected_indicator(code, format))
      got_prefix |> should.equal(expected_prefix(code, format))
      got_check |> should.equal(expected_check_digit(code))
    }
  }
}

// Feature: gl-gtin-tier1-features, Property 11: parse populates every field per format
//
// For any valid code of a given format, `parse` returns `Ok(GtinInfo(...))`
// whose `format` matches the digit count, `digits` equals the (whitespace-free)
// input, `indicator` is `Ok(leading)` for a GTIN-14 and `Error(Nil)` otherwise,
// `gs1_prefix` is the leading three characters of the format-normalized 13-digit
// basis, and `check_digit` is the integer value of the final digit. Exercised
// across GTIN-13, UPC-A (GTIN-12), GTIN-8, and GTIN-14.
pub fn parse_populates_every_field_gtin13_test() {
  use code <- qcheck.run(config(), generators.gen_gtin13())
  assert_fields(code, Gtin13)
}

pub fn parse_populates_every_field_upca_test() {
  use code <- qcheck.run(config(), generators.gen_upca())
  assert_fields(code, Gtin12)
}

pub fn parse_populates_every_field_gtin8_test() {
  use code <- qcheck.run(config(), gen_gtin8())
  assert_fields(code, Gtin8)
}

pub fn parse_populates_every_field_gtin14_test() {
  use code <- qcheck.run(config(), gen_gtin14())
  assert_fields(code, Gtin14)
}

/// Map a `gs1_prefix` lookup result to the public `GtinError` region result,
/// mirroring `parse`'s own mapping so the comparison is independent of the
/// implementation under test.
fn expected_region(code: String) -> Result(String, gtin_types.GtinError) {
  case gs1_prefix.lookup(code) {
    Ok(region) -> Ok(region)
    Error(gs1_prefix.NoGs1PrefixFound) -> Error(NoGs1PrefixFound)
  }
}

/// Assert that `parse(code).gs1_region` equals the prefix subsystem's lookup.
fn assert_region(code: String) -> Nil {
  case gl_gtin.parse(code) {
    Error(_) -> should.fail()
    Ok(info) -> info.gs1_region |> should.equal(expected_region(code))
  }
}

// Feature: gl-gtin-tier1-features, Property 12: parse region derives solely from the prefix subsystem
//
// For any valid code across formats, `parse(code).gs1_region` equals
// `gs1_prefix.lookup(code)` mapped into `GtinError` (`Ok(region)` on a hit,
// `Error(NoGs1PrefixFound)` on a miss). Exercised across GTIN-13, UPC-A
// (GTIN-12), GTIN-8, and GTIN-14.
pub fn parse_region_from_prefix_gtin13_test() {
  use code <- qcheck.run(config(), generators.gen_gtin13())
  assert_region(code)
}

pub fn parse_region_from_prefix_upca_test() {
  use code <- qcheck.run(config(), generators.gen_upca())
  assert_region(code)
}

pub fn parse_region_from_prefix_gtin8_test() {
  use code <- qcheck.run(config(), gen_gtin8())
  assert_region(code)
}

pub fn parse_region_from_prefix_gtin14_test() {
  use code <- qcheck.run(config(), gen_gtin14())
  assert_region(code)
}
