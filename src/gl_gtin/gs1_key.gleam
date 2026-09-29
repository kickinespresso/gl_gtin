//// Internal module implementing the F5/F6/F7 GS1-key features: the per-key
//// specification table and (in later tasks) the shared validate/generate
//// driver plus the SSCC/GSIN specializations.
////
//// This module owns the single source of truth for each key's length and
//// structural-format rules — the `key_spec` table. The generic driver reads a
//// `KeySpec` generically and never hard-codes a length, so correcting a length
//// or boundary is a one-line edit to `key_spec`.
////
//// The public `Gs1Key` type lives in the `gl_gtin` facade (so it is part of the
//// public API surface); this module imports it and its variants. All check-digit
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

/// Length rule for a key.
///
/// - `FixedLen` — single-length keys (e.g. GLN=13, SSCC=18).
/// - `OneOf` — the multi-length GTIN (8/12/13/14).
/// - `BasePlusSerial` — a fixed numeric base carrying the mod-10 check on its
///   last base digit, followed by an optional variable serial (GRAI/GDTI/GCN).
/// - `VariableLen` — a variable-length key with no fixed component boundary the
///   library can assert positionally (GIAI).
pub type LengthRule {
  FixedLen(total: Int)
  OneOf(totals: List(Int))
  BasePlusSerial(base_total: Int, serial_min: Int, serial_max: Int)
  VariableLen(min_total: Int, max_total: Int)
}

/// Optional key-specific structural format rule, evaluated only after the
/// character/length/check-digit rules pass.
///
/// - `NoFormatRule` — length + mod-10 check fully validate the key.
/// - `GraiRule` — GRAI: 13-digit numeric base with a valid mod-10 check on the
///   13th digit, plus an optional serial (up to 16 alphanumeric chars).
/// - `GiaiRule` — GIAI: total length 1–30 alphanumeric, NO key-level mod-10
///   check digit (see the driver note in `key_spec` for `Giai`).
pub type FormatRule {
  NoFormatRule
  GraiRule
  GiaiRule
}

/// The per-key specification: a length rule plus an optional structural format
/// rule. This is an internal representation and is not part of the public API.
pub type KeySpec {
  KeySpec(length: LengthRule, format: FormatRule)
}

/// The single source of truth mapping each `Gs1Key` to its `KeySpec`.
///
/// One exhaustive `case`, one row per variant. Each row carries a comment with
/// the value confirmed in task 1.1 (see
/// `.kiro/specs/gl-gtin-gs1-keys/key-spec-confirmation-notes.md`) so a later
/// correction is a one-line edit. The generic validate/generate driver reads
/// this `KeySpec` and never hard-codes a length.
pub fn key_spec(key: Gs1Key) -> KeySpec {
  case key {
    // GTIN — the only multi-length variant; spec is a length *set*. Numeric,
    // mod-10 on full length. Confirmed: totals 8/12/13/14.
    Gtin ->
      KeySpec(length: OneOf(totals: [8, 12, 13, 14]), format: NoFormatRule)

    // GLN — 13-digit numeric key (12-digit body + mod-10 check on full length).
    // Confirmed against GS1 General Specifications (task 1.1).
    Gln -> KeySpec(length: FixedLen(total: 13), format: NoFormatRule)

    // SSCC — AI (00). 18-digit numeric key (17-digit body + mod-10 check on
    // full length). Confirmed (task 1.1).
    Sscc -> KeySpec(length: FixedLen(total: 18), format: NoFormatRule)

    // GSIN — AI (402). 17-digit numeric key (16-digit body + mod-10 check on
    // full length). Confirmed (task 1.1).
    Gsin -> KeySpec(length: FixedLen(total: 17), format: NoFormatRule)

    // GRAI — AI (8003). 13-digit numeric base carrying the mod-10 check on its
    // 13th digit, followed by an OPTIONAL serial of up to 16 alphanumeric
    // (CSET 82) characters. The check applies to the 13-digit base only; total
    // length alone is insufficient (GraiRule enforces the structural split).
    // Confirmed: base 13, serial 0..16 alphanumeric (task 1.1).
    Grai ->
      KeySpec(
        length: BasePlusSerial(base_total: 13, serial_min: 0, serial_max: 16),
        format: GraiRule,
      )

    // GIAI — AI (8004). 1..30 alphanumeric characters total. NO key-level
    // mod-10 check digit and NO fixed internal boundary the library can assert
    // positionally (GS1 company prefix length varies and is not encoded).
    // DRIVER DIVERGENCE: the generic validate flow (char → length → check digit
    // → format) must SKIP the check-digit step for GIAI — GIAI has no mod-10
    // key check. GiaiRule asserts only length 1..30 and charset membership; it
    // MUST NOT run a mod-10 check. See task 4.2 for the driver handling.
    // Confirmed: max 30 alphanumeric, no key-level check digit (task 1.1).
    Giai ->
      KeySpec(
        length: VariableLen(min_total: 1, max_total: 30),
        format: GiaiRule,
      )

    // GSRN — AI (8018). 18-digit numeric key (17-digit body + mod-10 check on
    // full length). Confirmed (task 1.1). Same length as SSCC but distinguished
    // by its `Gs1Key` value, not by length.
    Gsrn -> KeySpec(length: FixedLen(total: 18), format: NoFormatRule)

    // GDTI — AI (253). 13-digit numeric base carrying the mod-10 check on its
    // 13th digit, followed by an OPTIONAL serial of up to 17 ALPHANUMERIC
    // (CSET 82) characters (charset corrected from numeric → alphanumeric in
    // task 1.1). The check applies to the 13-digit base only.
    // Confirmed: base 13, serial 0..17 alphanumeric (task 1.1).
    Gdti ->
      KeySpec(
        length: BasePlusSerial(base_total: 13, serial_min: 0, serial_max: 17),
        format: NoFormatRule,
      )

    // GCN — AI (255). 13-digit numeric base carrying the mod-10 check on its
    // 13th digit, followed by an OPTIONAL serial of up to 12 NUMERIC digits.
    // The check applies to the 13-digit base only.
    // Confirmed: base 13, serial 0..12 numeric (task 1.1).
    Gcn ->
      KeySpec(
        length: BasePlusSerial(base_total: 13, serial_min: 0, serial_max: 12),
        format: NoFormatRule,
      )
  }
}

// --- private helpers ---

/// Trim the code and parse every remaining character to a decimal digit.
///
/// Mirrors the existing `validation.validate` character-first ordering: after
/// `string.trim`, each character is mapped through `utils.parse_digit`. Any
/// non-digit character — including interior whitespace, which `string.trim` does
/// not remove — makes the whole parse fail with `Error(InvalidCharacters)`.
///
/// An empty or whitespace-only input trims to the empty string, which
/// `string.split(_, "")` yields as an empty character list, so this returns
/// `Ok([])`. The caller's `check_length` then turns that length-0 body into
/// `Error(InvalidLength(got: 0))` (Req 6.3, and the empty cases in 1.6/3.6).
///
/// This helper is digit-only by design. The variable-serial keys
/// (`Grai`/`Giai`/`Gdti`/`Gcn`) may carry alphanumeric serials; their
/// alphanumeric handling belongs to the driver (tasks 4.2/4.3), not here — see
/// `.kiro/specs/gl-gtin-gs1-keys/key-spec-confirmation-notes.md`.
///
/// # Examples
///
/// ```gleam
/// parse_body_digits(" 123 ")
/// // -> Ok([1, 2, 3])
///
/// parse_body_digits("12a3")
/// // -> Error(InvalidCharacters)
///
/// parse_body_digits("   ")
/// // -> Ok([])
/// ```
fn parse_body_digits(code: String) -> Result(List(Int), KeyError) {
  let trimmed = string.trim(code)
  let chars = string.split(trimmed, "")
  case
    list.try_map(chars, fn(char) {
      case utils.parse_digit(char) {
        Ok(digit) -> Ok(digit)
        Error(_) -> Error(Nil)
      }
    })
  {
    Ok(digits) -> Ok(digits)
    Error(_) -> Error(InvalidCharacters)
  }
}

/// Evaluate a trimmed digit `count` against a `LengthRule`.
///
/// Returns `Ok(Nil)` on a match and `Error(InvalidLength(got: count))` otherwise,
/// where `count` is the trimmed digit count (so an empty body yields
/// `InvalidLength(got: 0)`). All four `LengthRule` variants are handled:
///
/// - `FixedLen(total)` — matches `count == total`.
/// - `OneOf(totals)` — matches when `count` is one of `totals`.
/// - `BasePlusSerial(base_total, serial_min, serial_max)` — matches when `count`
///   is in `[base_total + serial_min .. base_total + serial_max]`.
/// - `VariableLen(min_total, max_total)` — matches `count` in
///   `[min_total .. max_total]`.
///
/// # Examples
///
/// ```gleam
/// check_length(FixedLen(total: 18), 18)
/// // -> Ok(Nil)
///
/// check_length(FixedLen(total: 18), 14)
/// // -> Error(InvalidLength(got: 14))
/// ```
fn check_length(rule: LengthRule, count: Int) -> Result(Nil, KeyError) {
  let matches = case rule {
    FixedLen(total) -> count == total
    OneOf(totals) -> list.contains(totals, count)
    BasePlusSerial(base_total, serial_min, serial_max) ->
      count >= base_total + serial_min && count <= base_total + serial_max
    VariableLen(min_total, max_total) ->
      count >= min_total && count <= max_total
  }
  case matches {
    True -> Ok(Nil)
    False -> Error(InvalidLength(got: count))
  }
}

/// Apply a `FormatRule` to an already length-and-check-valid digit list.
///
/// Evaluated last in the validate ordering (Req 6.7, 7.4). `NoFormatRule` keys
/// are fully validated by length + mod-10, so this returns `Ok(Nil)`. The
/// variable-serial rules perform the structural checks the library can express
/// from a digit list; anything that violates the confirmed boundaries yields
/// `Error(InvalidKeyFormat)`.
///
/// - `GraiRule` — GRAI's mod-10 check applies to the 13-digit numeric base only
///   (see the confirmation notes). This asserts there are at least 13 leading
///   digits and that those first 13 form a valid mod-10 key via the F0 engine
///   (`check_digit.valid`). The optional serial (up to 16 alphanumeric chars) is
///   not present in this digit-only list; its charset handling lives in the
///   driver (tasks 4.2/4.3).
/// - `GiaiRule` — GIAI has NO key-level mod-10 check digit and no fixed internal
///   boundary the library can assert positionally (confirmation notes). The only
///   library-enforceable rule is total length 1..30, so this is a conservative
///   check: a digit count in `[1 .. 30]` passes, anything else is
///   `InvalidKeyFormat`. A mod-10 check is deliberately NOT run.
///
/// # Examples
///
/// ```gleam
/// check_format(NoFormatRule, [1, 2, 3])
/// // -> Ok(Nil)
/// ```
fn check_format(rule: FormatRule, digits: List(Int)) -> Result(Nil, KeyError) {
  case rule {
    NoFormatRule -> Ok(Nil)
    GraiRule -> {
      // GRAI: mod-10 check applies to the 13-digit numeric base only. Take the
      // first 13 digits and confirm both that they exist (a shorter list has no
      // valid base) and that they form a valid mod-10 key. Any optional serial
      // (alphanumeric, handled by the driver) sits after this base.
      let base = list.take(digits, 13)
      case list.length(base) == 13 && check_digit.valid(base) {
        True -> Ok(Nil)
        False -> Error(InvalidKeyFormat)
      }
    }
    GiaiRule -> {
      // GIAI: no key-level mod-10 check and no library-enforceable internal
      // boundary; only total length 1..30 can be asserted here (conservative
      // check per the confirmation notes). Do NOT run a mod-10 check.
      let count = list.length(digits)
      case count >= 1 && count <= 30 {
        True -> Ok(Nil)
        False -> Error(InvalidKeyFormat)
      }
    }
  }
}

// --- generic validate driver ---

/// Select the digit list the key-level mod-10 check applies to, if any.
///
/// The generic `validate_key` flow (char → length → check digit → format) runs
/// its check-digit step against whatever this helper returns:
///
/// - `Ok(digits)` — a fixed-length numeric key (`FixedLen`/`OneOf`, i.e. GTIN,
///   GLN, SSCC, GSIN, GSRN): the mod-10 check covers the full digit list.
/// - `Ok(base)` — a `BasePlusSerial` key (GRAI/GDTI/GCN): the mod-10 check covers
///   the fixed numeric BASE only (its first `base_total` digits), never the
///   optional serial (see `key-spec-confirmation-notes.md`).
/// - `Error(Nil)` — a `VariableLen` key (GIAI): NO key-level mod-10 check digit;
///   the driver SKIPS the check-digit step entirely for these keys.
///
/// Reading the target from the `LengthRule` (rather than hard-coding it in the
/// driver) keeps the GIAI divergence and the GRAI/GDTI/GCN base-only rule a
/// property of the `key_spec` table, so a boundary correction is a one-line edit.
fn check_digit_target(
  rule: LengthRule,
  digits: List(Int),
) -> Result(List(Int), Nil) {
  case rule {
    FixedLen(_) -> Ok(digits)
    OneOf(_) -> Ok(digits)
    BasePlusSerial(base_total, _, _) -> Ok(list.take(digits, base_total))
    VariableLen(_, _) -> Error(Nil)
  }
}

/// Validate a code string against a specific `Gs1Key` kind.
///
/// The single generic validator behind F5/F6/F7. It reads the kind's `KeySpec`
/// from `key_spec` and applies the defect rules in this fixed order, returning
/// only the FIRST failing rule (Req 6.6):
///
/// 1. **Characters** — `parse_body_digits` trims then maps every character to a
///    digit; any non-digit (interior whitespace included) → `InvalidCharacters`.
///    An empty/whitespace-only input trims to length 0 and continues to the
///    length check. (Req 6.3)
/// 2. **Digit count** — `check_length(spec.length, count)`; a mismatch →
///    `InvalidLength(got: count)` with `count` the trimmed digit count (so empty
///    → `InvalidLength(got: 0)`). (Req 6.4)
/// 3. **Check digit** — for mod-10 keys, the F0 engine `check_digit.valid` must
///    return `True`, else `InvalidCheckDigit`. The check runs on the full digit
///    list for fixed-length keys (GTIN/GLN/SSCC/GSIN/GSRN) and on the 13-digit
///    BASE only for the `BasePlusSerial` keys (GRAI/GDTI/GCN). GIAI has NO
///    key-level check digit, so this step is SKIPPED for it entirely (the target
///    is derived from the spec via `check_digit_target`). (Req 6.5, 9.3)
/// 4. **Key-specific format** — `check_format(spec.format, digits)`; a
///    variable-serial structural failure → `InvalidKeyFormat`. (Req 6.7)
///
/// On all rules passing, returns `Ok(key)` — the supplied `Gs1Key` value.
/// Because each call validates only against the kind passed in, two codes of the
/// same length valid for different kinds are each judged solely against their
/// supplied kind. (Req 6.1, 6.8)
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
  let spec = key_spec(key)
  use digits <- result.try(parse_body_digits(code))
  let count = list.length(digits)
  use _ <- result.try(check_length(spec.length, count))
  use _ <- result.try(case check_digit_target(spec.length, digits) {
    // Mod-10 key: run the F0 engine over the target digits (full list for
    // fixed-length keys, the base only for BasePlusSerial keys).
    Ok(target) ->
      case check_digit.valid(target) {
        True -> Ok(Nil)
        False -> Error(InvalidCheckDigit)
      }
    // VariableLen key (GIAI): no key-level check digit — skip this step.
    Error(Nil) -> Ok(Nil)
  })
  use _ <- result.try(check_format(spec.format, digits))
  Ok(key)
}

// --- generic generate driver ---

/// Derive the BODY-length rule (excluding the appended check digit) from a key's
/// total-length `LengthRule`.
///
/// The generic `generate_key` accepts a *body* — the key without its check digit
/// — and appends the mod-10 check via the F0 engine. So the length it enforces on
/// its input is the *body* length, which is one shorter than the total for every
/// mod-10 key:
///
/// - `FixedLen(total)` → `FixedLen(total - 1)` (e.g. SSCC 18 → body 17).
/// - `OneOf(totals)` → `OneOf(each total - 1)` (GTIN 8/12/13/14 → 7/11/12/13).
/// - `BasePlusSerial(base_total, min, max)` → `BasePlusSerial(base_total - 1, min,
///   max)`: the base carries the check digit on its last position, so the body
///   base is `base_total - 1`; the optional serial range is unchanged (it sits
///   after the check digit and is not part of the mod-10 base).
/// - `VariableLen(min, max)` → unchanged: GIAI has NO key-level check digit, so
///   its body *is* the full key and no digit is appended (see the driver note in
///   `key_spec` for `Giai`). The range is passed through as-is.
///
/// Reading the body rule from the total rule keeps every length a property of the
/// `key_spec` table; correcting a boundary is a one-line edit there.
fn body_length_rule(rule: LengthRule) -> LengthRule {
  case rule {
    FixedLen(total) -> FixedLen(total: total - 1)
    OneOf(totals) -> OneOf(totals: list.map(totals, fn(total) { total - 1 }))
    BasePlusSerial(base_total, serial_min, serial_max) ->
      BasePlusSerial(
        base_total: base_total - 1,
        serial_min: serial_min,
        serial_max: serial_max,
      )
    VariableLen(min_total, max_total) ->
      VariableLen(min_total: min_total, max_total: max_total)
  }
}

/// Select the BODY digits the appended check digit is computed over, if any.
///
/// The mirror of `check_digit_target` for generation. Where `check_digit_target`
/// operates on a full key (its `BasePlusSerial` base *includes* the check digit,
/// so it takes `base_total` digits), this operates on a *body* (no check digit
/// yet), so its base is one shorter — `base_total - 1` — and the F0 engine
/// appends the check digit onto it:
///
/// - `FixedLen`/`OneOf` (GTIN, GLN, SSCC, GSIN, GSRN): the check digit is appended
///   over the whole body → `Ok(digits)`.
/// - `BasePlusSerial(base_total, ..)` (GRAI/GDTI/GCN): the check digit is appended
///   over the body BASE only — the first `base_total - 1` digits — with the
///   optional serial following the appended check digit → `Ok(base)`.
/// - `VariableLen` (GIAI): NO key-level check digit → `Error(Nil)`; the caller
///   renders the body as-is.
///
/// Deriving the base from `base_total - 1` (rather than reusing
/// `check_digit_target`) keeps the "the check applies to the 13-digit base, whose
/// 13th digit is the appended check" rule correct: a 12-digit body base plus the
/// appended check yields the 13-digit base ahead of any serial.
fn append_target(
  rule: LengthRule,
  digits: List(Int),
) -> Result(List(Int), Nil) {
  case rule {
    FixedLen(_) -> Ok(digits)
    OneOf(_) -> Ok(digits)
    BasePlusSerial(base_total, _, _) -> Ok(list.take(digits, base_total - 1))
    VariableLen(_, _) -> Error(Nil)
  }
}

/// Render a digit list to its decimal string, one character per digit.
fn digits_to_string(digits: List(Int)) -> String {
  digits
  |> list.map(int.to_string)
  |> string.concat
}

/// Generate a complete key string from a body, appending the mod-10 check digit.
///
/// The generic generator behind F5/F6/F7. It reads the kind's `KeySpec` from
/// `key_spec`, derives the BODY-length rule from the total-length rule via
/// `body_length_rule`, and applies the defect rules in this fixed order, returning
/// only the FIRST failing rule (Req 7.2, 7.3, 7.4):
///
/// 1. **Characters** — `parse_body_digits` trims then maps every character to a
///    digit; any non-digit (interior whitespace included) → `InvalidCharacters`.
///    Evaluated BEFORE the length check. (Req 7.2)
/// 2. **Body length** — `check_length(body_length_rule(spec.length), count)`; a
///    mismatch → `InvalidLength(got: count)` with `count` the trimmed digit count.
///    (Req 7.3)
/// 3. **Key-specific format** — `check_format(spec.format, digits)`; a
///    variable-serial structural failure → `InvalidKeyFormat`. (Req 7.4)
///
/// Then the check digit is appended:
///
/// - Mod-10 keys (`FixedLen`/`OneOf`/`BasePlusSerial`, derived via
///   `append_target`): the F0 engine `check_digit.append` computes and
///   appends the check digit over the target (full body for fixed-length keys,
///   the base for `BasePlusSerial`); any engine error maps into `KeyError`
///   (`InvalidLength` → `InvalidLength`, `InvalidCharacters` → `InvalidCharacters`).
///   The result is rendered to a string. (Req 7.1, 9.3)
/// - GIAI (`VariableLen`): has NO key-level check digit, so NO digit is appended —
///   the trimmed body itself, rendered to a string, is the generated key (see the
///   driver note in `key_spec` for `Giai`).
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
  let spec = key_spec(key)
  use digits <- result.try(parse_body_digits(body))
  let count = list.length(digits)
  use _ <- result.try(check_length(body_length_rule(spec.length), count))
  use _ <- result.try(check_format(spec.format, digits))
  case append_target(spec.length, digits) {
    // Mod-10 key: append the check digit over the target digits (full body for
    // fixed-length keys, the base for BasePlusSerial keys), mapping any F0 engine
    // error into KeyError. The target equals the full body for FixedLen/OneOf; for
    // BasePlusSerial the base is the first base_total-1 body digits, and the rest
    // of the body is the serial that follows the appended check digit.
    Ok(target) -> {
      let serial = list.drop(digits, list.length(target))
      case check_digit.append(target) {
        Ok(with_check) -> Ok(digits_to_string(list.append(with_check, serial)))
        Error(check_digit.InvalidLength(got)) -> Error(InvalidLength(got: got))
        Error(check_digit.InvalidCharacters) -> Error(InvalidCharacters)
      }
    }
    // VariableLen key (GIAI): no key-level check digit — the body itself is the
    // generated key; render it to a string with no appended digit.
    Error(Nil) -> Ok(digits_to_string(digits))
  }
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
