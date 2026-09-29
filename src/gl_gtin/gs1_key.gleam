//// Internal module implementing the F5/F6/F7 GS1-key features: the per-key
//// specification table plus the shared validate/generate driver and the
//// SSCC/GSIN specializations.
////
//// This module owns the single source of truth for each key's length, charset,
//// and structural-format rules — the `key_spec` table. The generic driver reads
//// a `KeySpec` generically and never hard-codes a length or charset, so
//// correcting a boundary is a one-line edit to `key_spec`.
////
//// The public `Gs1Key` type lives in `gl_gtin/gtin_types` (re-exported by the
//// `gl_gtin` facade); this module imports it and its variants. All check-digit
//// work routes through the F0 generalized engine in `gl_gtin/check_digit`.

import gl_gtin/check_digit
import gl_gtin/gtin_types.{
  type Gs1Key, Gcn, Gdti, Giai, Gln, Grai, Gsin, Gsrn, Gtin, Sscc,
}
import gl_gtin/internal/utils
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// Internal error type for the key validate/generate machinery.
///
/// Mapped to the public `GtinError` at the `gl_gtin` facade boundary
/// (`InvalidLength` → `InvalidLength`, `InvalidCheckDigit` →
/// `InvalidCheckDigit`, `InvalidCharacters` → `InvalidCharacters`,
/// `InvalidKeyFormat` → `InvalidKeyFormat`).
pub type KeyError {
  InvalidLength(got: Int)
  InvalidCheckDigit
  InvalidCharacters
  InvalidKeyFormat
}

/// The character set permitted in a variable-serial key's optional serial.
///
/// - `NumericSerial` — digits `0`–`9` only (GCN's `N..12` serial).
/// - `AlphanumericSerial` — GS1 CSET 82. The exact CSET 82 punctuation subset is
///   defined by the GS1 General Specifications; per the confirmation notes it is
///   treated here as a charset-membership predicate, and the practical set the
///   library enforces is ASCII `A`–`Z`, `a`–`z`, `0`–`9` (GRAI/GDTI serials).
pub type SerialCharset {
  NumericSerial
  AlphanumericSerial
}

/// The per-key specification. This is an internal representation and is NOT part
/// of the public API, so it may change freely.
///
/// - `NumericKey(lengths)` — a full numeric key that carries the mod-10 check on
///   its FULL length, whose total length is one of `lengths`. Covers GTIN
///   (8/12/13/14), GLN (13), SSCC (18), GSIN (17), GSRN (18).
/// - `BaseSerialKey(base_total, serial_max, serial_charset)` — a numeric
///   `base_total`-digit base carrying the mod-10 check on its LAST (base) digit,
///   followed by an OPTIONAL serial of `0..serial_max` characters drawn from
///   `serial_charset`. Covers GRAI (13 / 16 / alphanumeric), GDTI
///   (13 / 17 / alphanumeric), GCN (13 / 12 / numeric).
/// - `FreeformKey(min_total, max_total)` — a freeform alphanumeric key of total
///   length `min_total..max_total` with NO key-level check digit. Covers GIAI
///   (1..30 alphanumeric).
pub type KeySpec {
  NumericKey(lengths: List(Int))
  BaseSerialKey(base_total: Int, serial_max: Int, serial_charset: SerialCharset)
  FreeformKey(min_total: Int, max_total: Int)
}

/// The single source of truth mapping each `Gs1Key` to its `KeySpec`.
///
/// One exhaustive `case`, one row per variant. Each row carries a comment with
/// the value confirmed in task 1.1 (see
/// `.kiro/specs/gl-gtin-gs1-keys/key-spec-confirmation-notes.md`) so a later
/// correction is a one-line edit. The generic validate/generate driver reads
/// this `KeySpec` and never hard-codes a length or charset.
pub fn key_spec(key: Gs1Key) -> KeySpec {
  case key {
    // GTIN — the only multi-length variant. Numeric, mod-10 on full length.
    // Confirmed: totals 8/12/13/14.
    Gtin -> NumericKey(lengths: [8, 12, 13, 14])

    // GLN — 13-digit numeric key (12-digit body + mod-10 on full length).
    // Confirmed (task 1.1).
    Gln -> NumericKey(lengths: [13])

    // SSCC — AI (00). 18-digit numeric key, mod-10 on full length.
    // Confirmed (task 1.1).
    Sscc -> NumericKey(lengths: [18])

    // GSIN — AI (402). 17-digit numeric key, mod-10 on full length.
    // Confirmed (task 1.1).
    Gsin -> NumericKey(lengths: [17])

    // GRAI — AI (8003). 13-digit numeric base carrying the mod-10 check on its
    // 13th digit, followed by an OPTIONAL serial of up to 16 ALPHANUMERIC
    // (CSET 82) characters. Confirmed: base 13, serial 0..16 alphanumeric.
    Grai ->
      BaseSerialKey(
        base_total: 13,
        serial_max: 16,
        serial_charset: AlphanumericSerial,
      )

    // GIAI — AI (8004). 1..30 ALPHANUMERIC characters total. NO key-level mod-10
    // check digit and no fixed internal boundary the library can assert
    // positionally (GS1 company prefix length varies and is not encoded).
    // Confirmed: max 30 alphanumeric, no key-level check digit.
    Giai -> FreeformKey(min_total: 1, max_total: 30)

    // GSRN — AI (8018). 18-digit numeric key, mod-10 on full length. Confirmed.
    // Same length as SSCC but distinguished by its `Gs1Key` value, not length.
    Gsrn -> NumericKey(lengths: [18])

    // GDTI — AI (253). 13-digit numeric base carrying the mod-10 check on its
    // 13th digit, followed by an OPTIONAL serial of up to 17 ALPHANUMERIC
    // (CSET 82) characters (charset corrected from numeric → alphanumeric in
    // task 1.1). Confirmed: base 13, serial 0..17 alphanumeric.
    Gdti ->
      BaseSerialKey(
        base_total: 13,
        serial_max: 17,
        serial_charset: AlphanumericSerial,
      )

    // GCN — AI (255). 13-digit numeric base carrying the mod-10 check on its
    // 13th digit, followed by an OPTIONAL serial of up to 12 NUMERIC digits.
    // Confirmed: base 13, serial 0..12 numeric.
    Gcn ->
      BaseSerialKey(
        base_total: 13,
        serial_max: 12,
        serial_charset: NumericSerial,
      )
  }
}

// --- character / charset helpers ---
//
// All helpers here are total: no `let assert`, `panic`, or `todo`. Graphemes are
// obtained with `string.to_graphemes` after `string.trim`.

/// Split a code into its graphemes after trimming leading/trailing whitespace.
///
/// Interior whitespace is NOT removed by `string.trim`, so it survives as a
/// grapheme and is later rejected by the charset predicates. An empty or
/// whitespace-only input trims to `""`, whose grapheme list is `[]`.
fn graphemes_of(code: String) -> List(String) {
  code
  |> string.trim
  |> string.to_graphemes
}

/// `True` when `char` is a single decimal digit `0`–`9`.
fn is_digit(char: String) -> Bool {
  case utils.parse_digit(char) {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// `True` when `char` is a single ASCII alphanumeric character.
///
/// The permitted set is `A`–`Z`, `a`–`z`, `0`–`9`. The exact GS1 CSET 82
/// punctuation subset is defined by the GS1 General Specifications; per the
/// confirmation notes it is treated as a charset-membership predicate, and this
/// digits+letters set is the practical membership rule the library enforces.
fn is_alphanumeric(char: String) -> Bool {
  is_digit(char) || is_ascii_letter(char)
}

/// `True` when `char` is a single ASCII letter `A`–`Z` or `a`–`z`.
fn is_ascii_letter(char: String) -> Bool {
  case char {
    "A"
    | "B"
    | "C"
    | "D"
    | "E"
    | "F"
    | "G"
    | "H"
    | "I"
    | "J"
    | "K"
    | "L"
    | "M"
    | "N"
    | "O"
    | "P"
    | "Q"
    | "R"
    | "S"
    | "T"
    | "U"
    | "V"
    | "W"
    | "X"
    | "Y"
    | "Z" -> True
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z" -> True
    _ -> False
  }
}

/// The membership predicate for a `SerialCharset`.
fn in_serial_charset(charset: SerialCharset, char: String) -> Bool {
  case charset {
    NumericSerial -> is_digit(char)
    AlphanumericSerial -> is_alphanumeric(char)
  }
}

/// Convert a list of digit graphemes to their `Int` values.
///
/// Every element is assumed to already be a digit grapheme (guaranteed by the
/// caller's charset check); a non-digit grapheme maps to `Error(Nil)` so the
/// function stays total.
fn digits_of(chars: List(String)) -> Result(List(Int), Nil) {
  list.try_map(chars, utils.parse_digit)
}

/// Render a digit list to its decimal string, one character per digit.
fn digits_to_string(digits: List(Int)) -> String {
  digits
  |> list.map(int.to_string)
  |> string.concat
}

// --- generic validate driver ---

/// Validate a code string against a specific `Gs1Key` kind.
///
/// The single generic validator behind F5/F6/F7. It reads the kind's `KeySpec`
/// from `key_spec`, trims the input, and applies the defect rules in the fixed
/// order character validity → digit count → check digit → key-specific
/// structural format, returning only the FIRST failing rule (Req 6.6). On all
/// rules passing it returns `Ok(key)` — the supplied `Gs1Key` value (Req 6.1).
///
/// Per-kind behaviour:
///
/// - `NumericKey(lengths)` — every grapheme must be a digit (else
///   `InvalidCharacters`); the digit count must be one of `lengths` (else
///   `InvalidLength(got: count)`); the full digit list must pass the F0 engine
///   `check_digit.valid` (else `InvalidCheckDigit`). No structural format rule.
/// - `BaseSerialKey(base_total, serial_max, charset)` — see `validate_base_serial`.
/// - `FreeformKey(min, max)` — every grapheme must be alphanumeric (else
///   `InvalidCharacters`); the count must be in `[min .. max]` (else
///   `InvalidLength(got: count)`); NO check digit and NO structural format rule
///   (GIAI has none — documented in `key_spec`).
///
/// # Examples
///
/// ```gleam
/// validate_key(Gln, "0614141000012")
/// // -> Ok(Gln)
///
/// validate_key(Gln, "0614141000013")
/// // -> Error(InvalidCheckDigit)
/// ```
pub fn validate_key(key: Gs1Key, code: String) -> Result(Gs1Key, KeyError) {
  let chars = graphemes_of(code)
  case key_spec(key) {
    NumericKey(lengths) -> validate_numeric(chars, lengths)
    BaseSerialKey(base_total, serial_max, charset) ->
      validate_base_serial(chars, base_total, serial_max, charset)
    FreeformKey(min_total, max_total) ->
      validate_freeform(chars, min_total, max_total)
  }
  |> result.map(fn(_) { key })
}

/// Validate a full numeric key: characters → length → mod-10 on full length.
fn validate_numeric(
  chars: List(String),
  lengths: List(Int),
) -> Result(Nil, KeyError) {
  // 1. Characters — every grapheme must be a digit.
  use _ <- result.try(case list.all(chars, is_digit) {
    True -> Ok(Nil)
    False -> Error(InvalidCharacters)
  })
  // 2. Length — the digit count must be one of the allowed totals.
  let count = list.length(chars)
  use _ <- result.try(case list.contains(lengths, count) {
    True -> Ok(Nil)
    False -> Error(InvalidLength(got: count))
  })
  // 3. Check digit — the F0 engine validates the full digit list.
  case digits_of(chars) {
    Ok(digits) ->
      case check_digit.valid(digits) {
        True -> Ok(Nil)
        False -> Error(InvalidCheckDigit)
      }
    // Unreachable given the digit check above, but keeps the function total.
    Error(_) -> Error(InvalidCharacters)
  }
}

/// Validate a `BaseSerialKey` (GRAI/GDTI/GCN).
///
/// Ordering (Req 6.6): character validity → digit count → check digit →
/// key-specific structural format.
///
/// 1. **Characters** — every grapheme must belong to the UNION charset, i.e. a
///    digit OR a member of the serial `charset`. Because the serial charset for
///    GRAI/GDTI is alphanumeric, a letter anywhere in the string passes this
///    stage; a character outside the union (e.g. `!`, interior whitespace, or a
///    letter in a NUMERIC-serial key like GCN) → `InvalidCharacters`.
/// 2. **Length** — the total must be in `[base_total .. base_total + serial_max]`
///    → else `InvalidLength(got: total)`. A total below `base_total` cannot form
///    a base; a serial longer than `serial_max` overflows — both are length
///    defects, not format defects.
/// 3. **Check digit** — the mod-10 check applies to the BASE only (the first
///    `base_total` graphemes). This step runs ONLY when the base region is all
///    digits; if it is, `check_digit.valid(base_digits)` must hold, else
///    `InvalidCheckDigit`. When the base region contains a non-digit the check is
///    not computable and is deferred to the format stage.
/// 4. **Structural format (`InvalidKeyFormat`)** — the numeric base must be
///    exactly `base_total` digits. The one reachable structural violation is a
///    string that passes the union charset and length yet carries a non-digit
///    (alphanumeric) character WITHIN the first `base_total` positions, so the
///    numeric base is malformed even though characters/length/check are otherwise
///    plausible. This is distinct from `InvalidCharacters` (a character outside
///    the union charset) and from `InvalidCheckDigit` (a numeric base whose 13th
///    digit is wrong). Generators never emit a non-digit base, so this branch is
///    unreachable on round-trips (Req 6.7, 7.4).
fn validate_base_serial(
  chars: List(String),
  base_total: Int,
  serial_max: Int,
  charset: SerialCharset,
) -> Result(Nil, KeyError) {
  // 1. Characters — union charset: digit OR serial-charset member.
  use _ <- result.try(
    case
      list.all(chars, fn(c) { is_digit(c) || in_serial_charset(charset, c) })
    {
      True -> Ok(Nil)
      False -> Error(InvalidCharacters)
    },
  )
  // 2. Length — total in [base_total .. base_total + serial_max].
  let total = list.length(chars)
  use _ <- result.try(
    case total >= base_total && total <= base_total + serial_max {
      True -> Ok(Nil)
      False -> Error(InvalidLength(got: total))
    },
  )
  // Split into the base region (first base_total graphemes) and the serial.
  let base_chars = list.take(chars, base_total)
  // 3. Check digit — only computable when the base region is all digits.
  //    Otherwise defer to the structural-format stage below.
  case digits_of(base_chars) {
    Ok(base_digits) ->
      case check_digit.valid(base_digits) {
        True -> Ok(Nil)
        // A malformed but all-digit base is a check-digit defect.
        False -> Error(InvalidCheckDigit)
      }
    // 4. Structural format — the base carries a non-digit, so the numeric base
    //    is malformed even though the union charset and length passed.
    Error(_) -> Error(InvalidKeyFormat)
  }
}

/// Validate a freeform alphanumeric key (GIAI): characters → length. No check
/// digit and no structural format rule.
fn validate_freeform(
  chars: List(String),
  min_total: Int,
  max_total: Int,
) -> Result(Nil, KeyError) {
  // 1. Characters — every grapheme must be alphanumeric.
  use _ <- result.try(case list.all(chars, is_alphanumeric) {
    True -> Ok(Nil)
    False -> Error(InvalidCharacters)
  })
  // 2. Length — the count must be within [min_total .. max_total].
  let count = list.length(chars)
  case count >= min_total && count <= max_total {
    True -> Ok(Nil)
    False -> Error(InvalidLength(got: count))
  }
}

// --- generic generate driver ---

/// Generate a complete key string from a body, appending the mod-10 check digit.
///
/// The single generic generator behind F5/F6/F7. It reads the kind's `KeySpec`
/// from `key_spec`, trims the body, and applies the defect rules in the fixed
/// order character validity → body length → key-specific structural format,
/// returning only the FIRST failing rule (Req 7.2, 7.3, 7.4). Per-kind:
///
/// - `NumericKey(lengths)` — body must be all digits (else `InvalidCharacters`);
///   body length must be one of `[l - 1 for l in lengths]` (else
///   `InvalidLength(got: count)`); the F0 engine `check_digit.append` appends the
///   check digit over the whole body, mapping any engine error into `KeyError`.
/// - `BaseSerialKey(base_total, serial_max, charset)` — see `generate_base_serial`.
/// - `FreeformKey(min, max)` — body must be alphanumeric (else
///   `InvalidCharacters`); length in `[min .. max]` (else `InvalidLength`); NO
///   check digit is appended — the trimmed body is returned verbatim (GIAI).
///
/// Round-trip guarantee (Req 7.5): for every kind and every body valid for that
/// kind, `validate_key(key, generate_key(key, body))` returns `Ok(key)`.
///
/// # Examples
///
/// ```gleam
/// generate_key(Sscc, "10614141543210987")
/// // -> Ok("106141415432109873")
///
/// generate_key(Sscc, "1061414154321098")
/// // -> Error(InvalidLength(got: 16))
/// ```
pub fn generate_key(key: Gs1Key, body: String) -> Result(String, KeyError) {
  let chars = graphemes_of(body)
  case key_spec(key) {
    NumericKey(lengths) -> generate_numeric(chars, lengths)
    BaseSerialKey(base_total, serial_max, charset) ->
      generate_base_serial(chars, base_total, serial_max, charset)
    FreeformKey(min_total, max_total) ->
      generate_freeform(chars, min_total, max_total)
  }
}

/// Map a `check_digit.CheckDigitError` into the local `KeyError`.
fn map_check_error(err: check_digit.CheckDigitError) -> KeyError {
  case err {
    check_digit.InvalidLength(got) -> InvalidLength(got: got)
    check_digit.InvalidCharacters -> InvalidCharacters
  }
}

/// Generate a full numeric key: characters → body length → append mod-10.
fn generate_numeric(
  chars: List(String),
  lengths: List(Int),
) -> Result(String, KeyError) {
  // 1. Characters — the body must be all digits.
  use _ <- result.try(case list.all(chars, is_digit) {
    True -> Ok(Nil)
    False -> Error(InvalidCharacters)
  })
  // 2. Body length — one shorter than each total (the check digit is appended).
  let count = list.length(chars)
  let body_lengths = list.map(lengths, fn(total) { total - 1 })
  use _ <- result.try(case list.contains(body_lengths, count) {
    True -> Ok(Nil)
    False -> Error(InvalidLength(got: count))
  })
  // 3. Append the check digit over the whole body via the F0 engine.
  case digits_of(chars) {
    Ok(digits) ->
      check_digit.append(digits)
      |> result.map(digits_to_string)
      |> result.map_error(map_check_error)
    Error(_) -> Error(InvalidCharacters)
  }
}

/// Generate a `BaseSerialKey` (GRAI/GDTI/GCN).
///
/// The body is `base_body` (the first `base_total - 1` graphemes, all digits)
/// followed by an optional serial (the remaining graphemes, all in `charset`).
/// The check digit is appended AFTER the base body to form the `base_total`-digit
/// base, and the serial follows that check digit. Ordering (Req 7.2/7.3/7.4):
///
/// 1. **Characters** — union charset (digit OR serial-charset member) over the
///    whole body → else `InvalidCharacters`.
/// 2. **Body length** — total in
///    `[base_total - 1 .. base_total - 1 + serial_max]` → else
///    `InvalidLength(got: count)`.
/// 3. **Structural format (`InvalidKeyFormat`)** — the base body (first
///    `base_total - 1` graphemes) must be all digits; a non-digit within the base
///    body region is a structural defect → `InvalidKeyFormat` (the same
///    reachable structural invariant enforced by `validate_base_serial`).
///
/// Then the mod-10 check digit is appended over the base body and the serial is
/// concatenated after it.
fn generate_base_serial(
  chars: List(String),
  base_total: Int,
  serial_max: Int,
  charset: SerialCharset,
) -> Result(String, KeyError) {
  let base_body_len = base_total - 1
  // 1. Characters — union charset over the whole body.
  use _ <- result.try(
    case
      list.all(chars, fn(c) { is_digit(c) || in_serial_charset(charset, c) })
    {
      True -> Ok(Nil)
      False -> Error(InvalidCharacters)
    },
  )
  // 2. Body length — [base_body_len .. base_body_len + serial_max].
  let count = list.length(chars)
  use _ <- result.try(
    case count >= base_body_len && count <= base_body_len + serial_max {
      True -> Ok(Nil)
      False -> Error(InvalidLength(got: count))
    },
  )
  // Split the body into the base-body region and the serial.
  let base_body_chars = list.take(chars, base_body_len)
  let serial_chars = list.drop(chars, base_body_len)
  // 3. Structural format — the base body must be all digits.
  case digits_of(base_body_chars) {
    Ok(base_body_digits) -> {
      // Append the mod-10 check over the base body, then re-attach the serial.
      use with_check <- result.try(
        check_digit.append(base_body_digits)
        |> result.map_error(map_check_error),
      )
      Ok(digits_to_string(with_check) <> string.concat(serial_chars))
    }
    // A non-digit within the base body is a structural defect.
    Error(_) -> Error(InvalidKeyFormat)
  }
}

/// Generate a freeform alphanumeric key (GIAI): characters → length. No check
/// digit is appended; the trimmed body is returned verbatim.
fn generate_freeform(
  chars: List(String),
  min_total: Int,
  max_total: Int,
) -> Result(String, KeyError) {
  // 1. Characters — every grapheme must be alphanumeric.
  use _ <- result.try(case list.all(chars, is_alphanumeric) {
    True -> Ok(Nil)
    False -> Error(InvalidCharacters)
  })
  // 2. Length — the count must be within [min_total .. max_total].
  let count = list.length(chars)
  use _ <- result.try(case count >= min_total && count <= max_total {
    True -> Ok(Nil)
    False -> Error(InvalidLength(got: count))
  })
  // 3. No check digit — return the body verbatim.
  Ok(string.concat(chars))
}

// --- F5 (SSCC) specializations ---

/// Validate an 18-digit SSCC (Serial Shipping Container Code) string.
///
/// A thin specialization over the generic `validate_key` driver for the `Sscc`
/// kind. On success it maps the `Ok(Sscc)` result to the string tag `Ok("SSCC")`;
/// any failure propagates unchanged from `validate_key`.
///
/// The defect ordering is inherited from `validate_key`: characters → digit count
/// (must be 18) → check digit (Req 1.5). Because SSCC is a fixed 18-digit mod-10
/// key, a valid 14-digit GTIN-14 fails the length check and returns
/// `Error(InvalidLength(got: 14))`, never `Ok("SSCC")` (Req 1.7). An
/// empty/whitespace-only input trims to length 0 and returns
/// `Error(InvalidLength(got: 0))` (Req 1.6).
///
/// # Examples
///
/// ```gleam
/// validate_sscc("106141415432109873")
/// // -> Ok("SSCC")
///
/// validate_sscc("00000000000000")
/// // -> Error(InvalidLength(got: 14))
/// ```
pub fn validate_sscc(code: String) -> Result(String, KeyError) {
  validate_key(Sscc, code)
  |> result.map(fn(_) { "SSCC" })
}

/// Generate a complete 18-digit SSCC from a 17-digit body.
///
/// A thin specialization over the generic `generate_key` driver for the `Sscc`
/// kind: it appends the mod-10 check digit computed by the F0 engine. The defect
/// ordering is inherited from `generate_key`: characters → body length (must be
/// 17) (Req 2.2, 2.3). A body of the wrong length returns
/// `Error(InvalidLength(got: n))`.
///
/// # Examples
///
/// ```gleam
/// generate_sscc("10614141543210987")
/// // -> Ok("106141415432109873")
///
/// generate_sscc("1061414154321098")
/// // -> Error(InvalidLength(got: 16))
/// ```
pub fn generate_sscc(body: String) -> Result(String, KeyError) {
  generate_key(Sscc, body)
}

// --- F6 (GSIN) specializations ---

/// Validate a 17-digit GSIN (Global Shipment Identification Number) string.
///
/// A thin specialization over the generic `validate_key` driver for the `Gsin`
/// kind. On success it maps the `Ok(Gsin)` result to the string tag
/// `Ok("GSIN")`; any failure propagates unchanged from `validate_key`.
///
/// The defect ordering is inherited from `validate_key`: characters → digit count
/// (must be 17) → check digit (Req 3.5). Because GSIN is a fixed 17-digit mod-10
/// key, a valid 18-digit SSCC fails the length check and returns
/// `Error(InvalidLength(got: 18))`, never `Ok("GSIN")` (Req 3.7). An
/// empty/whitespace-only input trims to length 0 and returns
/// `Error(InvalidLength(got: 0))` (Req 3.6).
///
/// # Examples
///
/// ```gleam
/// validate_gsin("10614141543210986")
/// // -> Ok("GSIN")
///
/// validate_gsin("106141415432109873")
/// // -> Error(InvalidLength(got: 18))
/// ```
pub fn validate_gsin(code: String) -> Result(String, KeyError) {
  validate_key(Gsin, code)
  |> result.map(fn(_) { "GSIN" })
}

/// Generate a complete 17-digit GSIN from a 16-digit body.
///
/// A thin specialization over the generic `generate_key` driver for the `Gsin`
/// kind: it appends the mod-10 check digit computed by the F0 engine. The defect
/// ordering is inherited from `generate_key`: characters → body length (must be
/// 16) (Req 4.2, 4.3). A body of the wrong length returns
/// `Error(InvalidLength(got: n))`.
///
/// # Examples
///
/// ```gleam
/// generate_gsin("1061414154321098")
/// // -> Ok("10614141543210986")
///
/// generate_gsin("106141415432109")
/// // -> Error(InvalidLength(got: 15))
/// ```
pub fn generate_gsin(body: String) -> Result(String, KeyError) {
  generate_key(Gsin, body)
}
