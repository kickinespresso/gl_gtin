//// Shared property-test generators for the gl_gtin Tier 2 GS1-key features
//// (F5 / F6 / F7).
////
//// These helpers back the `qcheck` property tests for the SSCC, GSIN, and
//// generic-key (`Gs1Key`) driver. Each generator produces a *body* string
//// (the digits/characters a generator function is handed, i.e. everything
//// before the mod-10 check digit that `generate_*` appends), so the property
//// tests can round-trip `generate → validate`.
////
//// - `gen_sscc_body` — random 17-digit numeric string (SSCC body). (F5)
//// - `gen_gsin_body` — random 16-digit numeric string (GSIN body). (F6)
//// - `gen_key_body(kind)` — random body of the correct body length for `kind`,
////   respecting the confirmed key boundaries from task 1.1: single-length
////   numeric keys emit a fixed-length numeric body; `Gtin` emits one of the
////   valid GTIN body lengths (7/11/12/13); the variable-serial keys
////   (`Grai`/`Giai`/`Gdti`/`Gcn`) emit a numeric base plus an optional serial
////   in the confirmed charset and length range. (F7)
////
//// Boundaries hard-coded below come from the task 1.1 confirmation notes
//// (`.kiro/specs/gl-gtin-gs1-keys/key-spec-confirmation-notes.md`):
////
//// | Key    | Body (numeric base) | Serial max | Serial charset  |
//// |--------|--------------------:|-----------:|-----------------|
//// | `Gln`  | 12                  | —          | —               |
//// | `Sscc` | 17                  | —          | —               |
//// | `Gsin` | 16                  | —          | —               |
//// | `Gsrn` | 17                  | —          | —               |
//// | `Gtin` | 7 / 11 / 12 / 13    | —          | —               |
//// | `Grai` | 12                  | 16         | alphanumeric    |
//// | `Giai` | 1..30 total         | (whole)    | alphanumeric    |
//// | `Gdti` | 12                  | 17         | alphanumeric    |
//// | `Gcn`  | 12                  | 12         | numeric         |
////
//// A single row is a one-line edit if a boundary is later corrected.

import gl_gtin/gtin_types.{
  type Gs1Key, Gcn, Gdti, Giai, Gln, Grai, Gsin, Gsrn, Gtin, Sscc,
}
import gleam/int
import gleam/list
import gleam/string
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

/// Generate a fixed-length numeric string of `length` digits (0..9).
fn gen_numeric_string(length: Int) -> qcheck.Generator(String) {
  use digits <- qcheck.map(qcheck.fixed_length_list_from(gen_digit(), length))
  digits_to_string(digits)
}

/// The alphanumeric character set used for variable serials (a practical
/// subset of GS1 CSET 82: digits and upper/lower-case ASCII letters). The exact
/// CSET 82 punctuation subset does not change any length/boundary the property
/// tests exercise (see the confirmation notes' "remaining genuinely-open item"),
/// so a digits-plus-letters set is sufficient for generating well-formed bodies.
fn alnum_chars() -> List(String) {
  string.to_graphemes(
    "0123456789" <> "ABCDEFGHIJKLMNOPQRSTUVWXYZ" <> "abcdefghijklmnopqrstuvwxyz",
  )
}

/// Generate a single alphanumeric character (as a one-grapheme string).
///
/// Picks by index into `alnum_chars`; the fallback keeps the generator total
/// for the (unreachable) out-of-range index case.
fn gen_alnum_char() -> qcheck.Generator(String) {
  let chars = alnum_chars()
  let max = list.length(chars) - 1
  use index <- qcheck.map(qcheck.bounded_int(0, max))
  case list.drop(chars, index) {
    [c, ..] -> c
    [] -> "0"
  }
}

/// Generate an alphanumeric string of exactly `length` characters.
fn gen_alnum_string(length: Int) -> qcheck.Generator(String) {
  use chars <- qcheck.map(qcheck.fixed_length_list_from(
    gen_alnum_char(),
    length,
  ))
  string.concat(chars)
}

/// Generate a 17-digit numeric SSCC body (the 17 body digits before the mod-10
/// check digit, producing an 18-digit SSCC once `generate_sscc` appends it).
///
/// Backs the F5 round-trip property (Property 1).
pub fn gen_sscc_body() -> qcheck.Generator(String) {
  gen_numeric_string(17)
}

/// Generate a 16-digit numeric GSIN body (the 16 body digits before the mod-10
/// check digit, producing a 17-digit GSIN once `generate_gsin` appends it).
///
/// Backs the F6 round-trip property (Property 2).
pub fn gen_gsin_body() -> qcheck.Generator(String) {
  gen_numeric_string(16)
}

/// Generate a random body of the correct body length for the given `Gs1Key`
/// kind, matching the confirmed boundaries from task 1.1.
///
/// The returned string is a *body* (everything before the appended check
/// digit), suitable for `generate_key(kind, _)`:
///
/// - Single-length numeric keys emit a fixed-length numeric body: `Gln` (12),
///   `Sscc` (17), `Gsin` (16), `Gsrn` (17).
/// - `Gtin` emits one of the valid GTIN body lengths (7 / 11 / 12 / 13).
/// - `Grai`, `Gdti`, `Gcn` emit a 12-digit numeric base (13-digit base minus its
///   check digit) followed by an optional variable serial: `Grai`/`Gdti` serials
///   are alphanumeric (≤16 / ≤17), `Gcn` serials are numeric (≤12).
/// - `Giai` emits a whole-string alphanumeric body of total length 1..30 (no
///   base/serial split and no key-level check digit).
///
/// Backs the F7 generic round-trip and same-length properties (Properties 3, 4).
pub fn gen_key_body(kind: Gs1Key) -> qcheck.Generator(String) {
  case kind {
    Gln -> gen_numeric_string(12)
    Sscc -> gen_numeric_string(17)
    Gsin -> gen_numeric_string(16)
    Gsrn -> gen_numeric_string(17)
    Gtin -> gen_gtin_body()
    Grai -> gen_base_plus_alnum_serial(16)
    Gdti -> gen_base_plus_alnum_serial(17)
    Gcn -> gen_base_plus_numeric_serial(12)
    Giai -> gen_giai_body()
  }
}

/// Generate a valid GTIN body: one of the four data-digit lengths (7, 11, 12,
/// 13) that produce 8/12/13/14-digit GTINs once the check digit is appended.
fn gen_gtin_body() -> qcheck.Generator(String) {
  use choice <- qcheck.bind(qcheck.bounded_int(0, 3))
  let length = case choice {
    0 -> 7
    1 -> 11
    2 -> 12
    _ -> 13
  }
  gen_numeric_string(length)
}

/// Generate a 12-digit numeric base followed by an optional alphanumeric serial
/// of length 0..`serial_max`. A zero-length serial yields just the 12-digit
/// base, exercising the "serial optional" boundary.
fn gen_base_plus_alnum_serial(serial_max: Int) -> qcheck.Generator(String) {
  use base <- qcheck.bind(gen_numeric_string(12))
  use serial_len <- qcheck.bind(qcheck.bounded_int(0, serial_max))
  use serial <- qcheck.map(gen_alnum_string(serial_len))
  base <> serial
}

/// Generate a 12-digit numeric base followed by an optional numeric serial of
/// length 0..`serial_max` (used by `Gcn`, whose serial is numeric).
fn gen_base_plus_numeric_serial(serial_max: Int) -> qcheck.Generator(String) {
  use base <- qcheck.bind(gen_numeric_string(12))
  use serial_len <- qcheck.bind(qcheck.bounded_int(0, serial_max))
  use serial <- qcheck.map(gen_numeric_string(serial_len))
  base <> serial
}

/// Generate a GIAI body: a whole-string alphanumeric value of total length
/// 1..30, with no base/serial split and no key-level check digit.
fn gen_giai_body() -> qcheck.Generator(String) {
  use length <- qcheck.bind(qcheck.bounded_int(1, 30))
  gen_alnum_string(length)
}
