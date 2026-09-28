//// Shared property-test generators for the gl_gtin Tier 1 features.
////
//// These helpers back the `qcheck` property tests for F0–F4. Each generator
//// produces well-formed inputs for a specific feature:
////
//// - `gen_digit_body` — random `List(Int)` of length 1..20 with elements 0..9
////   (F0 check-digit engine).
//// - `gen_upce` — a valid 8-digit UPC-E string (number-system digit 0 or 1,
////   six random body digits, and a computed UPC-E check digit) (F1).
//// - `gen_gtin13` — a valid 13-digit GTIN string (12 random data digits plus a
////   computed check digit) (F2/F3).
//// - `gen_upca` — a valid 12-digit GTIN (UPC-A) string (11 random data digits
////   plus a computed check digit) (F3 base, F1 compression).
////
//// The check-digit generators route their check digits through the shared
//// `check_digit.calculate` engine so the produced codes validate.

import gl_gtin/check_digit
import gl_gtin/upc
import gleam/int
import gleam/list
import qcheck

/// Generator for a single decimal digit (0..9).
fn gen_digit() -> qcheck.Generator(Int) {
  qcheck.bounded_int(0, 9)
}

/// Render a list of digits as a string by concatenating their decimal forms.
///
/// Each element is assumed to be a single digit (0..9), so the rendered string
/// has one character per element.
fn digits_to_string(digits: List(Int)) -> String {
  digits
  |> list.map(int.to_string)
  |> list.fold("", fn(acc, digit) { acc <> digit })
}

/// Compute the GS1 check digit for a body of digits, returning 0 on the
/// (unreachable, for these generators) error case so the generator stays total.
fn check_digit_of(body: List(Int)) -> Int {
  case check_digit.calculate(body) {
    Ok(digit) -> digit
    Error(_) -> 0
  }
}

/// Generate a random digit body: a `List(Int)` of length 1..20 whose elements
/// are each in the range 0..9. Backs the F0 engine properties (P1–P3).
pub fn gen_digit_body() -> qcheck.Generator(List(Int)) {
  qcheck.generic_list(
    elements_from: gen_digit(),
    length_from: qcheck.bounded_int(1, 20),
  )
}

/// Generate a valid 8-digit UPC-E code as a string.
///
/// The number-system digit is 0 or 1, followed by six random body digits, with
/// a UPC-E check digit appended. The check digit follows the GS1 (and this
/// library's) definition: it equals the check digit of the expanded 12-digit
/// UPC-A. The six body digits are expanded to the 10-digit manufacturer+item
/// block (same zero-suppression table as `upc.expand_body`), prepended with the
/// number-system digit to form the 11-digit UPC-A body, and the check digit is
/// computed over that body.
///
/// Because the GS1 zero-suppression table is not injective (distinct UPC-E
/// bodies can expand to the same UPC-A block, which then compresses back to a
/// single canonical UPC-E), the candidate is canonicalized by expanding it to
/// UPC-A and compressing back. Using that fixed point guarantees the
/// `upca_to_upce(upce_to_upca(x)) == Ok(x)` round-trip (Property 5) and that
/// `validate(upce_to_upca(x)) == Ok(Gtin12)` (Property 4). If canonicalization
/// ever fails (it should not for these inputs), the candidate is returned as-is,
/// keeping the generator total. Backs the F1 properties (P4, P5).
pub fn gen_upce() -> qcheck.Generator(String) {
  let ns_gen = qcheck.bounded_int(0, 1)
  let body_gen = qcheck.fixed_length_list_from(gen_digit(), 6)
  use ns, body <- qcheck.map2(ns_gen, body_gen)
  // Expand to the 11-digit UPC-A body (NS + 10-digit manufacturer+item block)
  // and derive the check digit from it, matching the library's definition of a
  // valid UPC-E check digit.
  let upca_body = [ns, ..expand_body(body)]
  let check = check_digit_of(upca_body)
  let candidate = digits_to_string(list.append([ns, ..body], [check]))
  // Canonicalize through the library's own conversion so the produced code is a
  // round-trip fixed point (the zero-suppression table is not injective).
  case upc.upce_to_upca(candidate) {
    Ok(upca) ->
      case upc.upca_to_upce(upca) {
        Ok(canonical) -> canonical
        Error(_) -> candidate
      }
    Error(_) -> candidate
  }
}

/// Apply the GS1 zero-suppression expansion rule keyed on the 6th body digit,
/// reconstructing the 10-digit manufacturer+item block of the UPC-A from the six
/// UPC-E body digits.
///
/// This mirrors `expand_body` in `src/gl_gtin/upc.gleam` so the generator can
/// derive the canonical UPC-E check digit (the check digit of the expanded
/// UPC-A). Any input that is not a list of exactly six digits returns the empty
/// list, keeping the function total; callers pass exactly six digits.
fn expand_body(body: List(Int)) -> List(Int) {
  case body {
    [x1, x2, x3, x4, x5, x6] ->
      case x6 {
        0 | 1 | 2 -> [x1, x2, x6, 0, 0, 0, 0, x3, x4, x5]
        3 -> [x1, x2, x3, 0, 0, 0, 0, 0, x4, x5]
        4 -> [x1, x2, x3, x4, 0, 0, 0, 0, 0, x5]
        _ -> [x1, x2, x3, x4, x5, 0, 0, 0, 0, x6]
      }
    _ -> []
  }
}

/// Generate a valid 13-digit GTIN code as a string.
///
/// Twelve random data digits followed by a computed check digit. Backs the
/// F2/F3 properties (P6–P9).
pub fn gen_gtin13() -> qcheck.Generator(String) {
  use data <- qcheck.map(qcheck.fixed_length_list_from(gen_digit(), 12))
  let check = check_digit_of(data)
  digits_to_string(list.append(data, [check]))
}

/// Generate a valid 12-digit GTIN (UPC-A) code as a string.
///
/// Eleven random data digits followed by a computed check digit. Backs the F3
/// down-conversion property (P10) and F1 compression tests.
pub fn gen_upca() -> qcheck.Generator(String) {
  use data <- qcheck.map(qcheck.fixed_length_list_from(gen_digit(), 11))
  let check = check_digit_of(data)
  digits_to_string(list.append(data, [check]))
}
