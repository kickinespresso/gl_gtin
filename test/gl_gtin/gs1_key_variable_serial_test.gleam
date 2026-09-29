//// Variable-serial (`Grai`/`Giai`) `InvalidKeyFormat` tests for the F7 key
//// driver — Task 8.4 (Requirements 6.7, 7.4).
////
//// ============================================================================
//// PENDING GS1 CONFIRMATION — READ BEFORE EDITING
//// ============================================================================
////
//// The `Grai`/`Giai` structural boundaries these tests exercise are marked
//// "pending GS1 confirmation" in the spec (task 1.1 →
//// `.kiro/specs/gl-gtin-gs1-keys/key-spec-confirmation-notes.md`, and the design
//// "Key Specification Table (open questions)"). This file therefore documents
//// the *current implemented behavior* of `gl_gtin/gs1_key`'s `check_format`
//// (`GraiRule`/`GiaiRule`) as it is wired into the generic driver. If the
//// confirmed structural rule changes, the fix should touch ONLY:
////   1. the relevant `key_spec` row (and `check_format` rule) in
////      `src/gl_gtin/gs1_key.gleam`, and
////   2. this test file.
//// The tests are deliberately isolated here (own file, exact name to avoid
//// collisions) so a boundary correction has a small, contained blast radius.
////
//// KEY FINDING (what the current implementation actually produces):
////
//// * `validate_key` CANNOT return `InvalidKeyFormat` for `Grai` or `Giai` with
////   any digit-only input:
////   - The driver order is character → length → check-digit → format
////     (`check_digit_target` runs BEFORE `check_format`).
////   - GRAI: `check_digit_target` takes the first 13 digits as the mod-10 base —
////     the SAME 13 digits `GraiRule` re-checks. So a 13-digit code with a bad
////     base check digit fails at the check-digit step (`InvalidCheckDigit`)
////     before `GraiRule` runs, and a code shorter than 13 fails the length step
////     (`InvalidLength`) first. There is no digit-only code that passes length +
////     check-digit yet fails `GraiRule` → `InvalidKeyFormat` is unreachable on
////     the validate path.
////   - GIAI: `GiaiRule`'s only assertion is total length 1..30, which is exactly
////     the `VariableLen(1, 30)` length rule already enforced one step earlier.
////     So any GIAI defect surfaces as `InvalidLength`/`InvalidCharacters` and
////     `GiaiRule` → `InvalidKeyFormat` is likewise unreachable on validate.
////   These validate-path tests therefore assert the error the code DOES produce
////   (with a per-test note), pending the confirmed rule that would give the
////   structural check independent teeth.
////
//// * `generate_key(Grai, body)` CAN return `InvalidKeyFormat`: `generate_key`
////   runs `check_format(GraiRule, body)` on the PRE-check-digit body (the task
////   4.3 format-check tension). A body that meets the body-length rule
////   (`BasePlusSerial(base_total: 12, 0..16)` → 12..28 digits) but whose first 13
////   digits are not a valid mod-10 base fails `GraiRule` → `InvalidKeyFormat`.
////   This is the one path that genuinely exercises the public `InvalidKeyFormat`
////   `GtinError` variant for a variable-serial key, so it is asserted directly.
////
//// * `generate_key(Giai, body)`: like validate, `GiaiRule` only asserts 1..30,
////   redundant with the `VariableLen` body-length rule, so it surfaces
////   `InvalidLength`/`InvalidCharacters`, not `InvalidKeyFormat`.
////
//// Tests use the public `gl_gtin` facade so the public `InvalidKeyFormat`
//// `GtinError` variant is the thing under test. Error variants and `Gs1Key`
//// variants are imported from `gl_gtin/gtin_types` (their owning module).

import gl_gtin
import gl_gtin/gtin_types.{
  Giai, Grai, InvalidCharacters, InvalidCheckDigit, InvalidKeyFormat,
  InvalidLength,
}
import gleeunit/should

// ============================================================================
// generate_key(Grai, _) — the confirmed-reachable InvalidKeyFormat path
// ============================================================================

// PENDING GS1 CONFIRMATION (task 1.1 / key-spec-confirmation-notes.md).
//
// A `Grai` BODY that satisfies the body-length rule (12..28 digits) but violates
// the assumed structural rule (its first 13 digits do not form a valid mod-10
// base) → `Error(InvalidKeyFormat)` from `generate_key`. This is Requirement 7.4
// for the `Grai` variable-serial key, exercised via `check_format(GraiRule, _)`
// on the pre-check-digit body (the task 4.3 format-check tension).
//
// Case A: a 12-digit body. It matches the minimum body length (base_total-1 = 12)
// but has fewer than 13 digits, so `GraiRule` cannot assemble a 13-digit base and
// reports the structural failure.
pub fn generate_grai_short_base_body_is_invalid_key_format_test() {
  gl_gtin.generate_key(Grai, "061414100001")
  |> should.equal(Error(InvalidKeyFormat))
}

// PENDING GS1 CONFIRMATION (task 1.1 / key-spec-confirmation-notes.md).
//
// Case B: a 13-digit body whose first 13 digits are NOT a valid mod-10 base.
// The body length is valid, but the assumed GRAI structural rule (13-digit base
// carrying a valid mod-10 check on its 13th digit) is violated →
// `Error(InvalidKeyFormat)`. "0614141000010" reuses the known-valid GLN base
// "0614141000012" with its final base digit corrupted to break the mod-10 check.
pub fn generate_grai_bad_base_check_body_is_invalid_key_format_test() {
  gl_gtin.generate_key(Grai, "0614141000010")
  |> should.equal(Error(InvalidKeyFormat))
}

// Contrast (not an InvalidKeyFormat case, kept to pin the boundary): a 13-digit
// body whose first 13 digits ARE a valid mod-10 base passes `GraiRule` and
// generates a complete key. If the confirmed GRAI rule changes, this expectation
// is the neighbor to re-check alongside the two failing cases above.
pub fn generate_grai_valid_base_body_succeeds_test() {
  gl_gtin.generate_key(Grai, "0614141000012")
  |> should.equal(Ok("06141410000122"))
}

// ============================================================================
// validate_key(Grai, _) — InvalidKeyFormat is UNREACHABLE (asserts actual error)
// ============================================================================

// PENDING GS1 CONFIRMATION (task 1.1 / key-spec-confirmation-notes.md).
//
// Requirement 6.7 asks for `InvalidKeyFormat` when a variable-serial key meets
// length + check digit but violates its structural rule. For `Grai` on the
// validate path this is CURRENTLY UNREACHABLE with a digit-only code: the driver
// runs the check-digit step (over the first 13 digits — the same digits
// `GraiRule` inspects) BEFORE `check_format`. A 13-digit code with a corrupted
// base check digit therefore fails the check-digit step first.
//
// This asserts the behavior the code DOES produce today (`InvalidCheckDigit`),
// pending the confirmed structural rule that would make `GraiRule` independently
// reachable on validate.
pub fn validate_grai_bad_base_check_is_invalid_check_digit_pending_test() {
  gl_gtin.validate_key(Grai, "0614141000013")
  |> should.equal(Error(InvalidCheckDigit))
}

// PENDING GS1 CONFIRMATION (task 1.1 / key-spec-confirmation-notes.md).
//
// A `Grai` code shorter than the 13-digit base (12 digits) fails the length step
// before `check_format` can run, so it surfaces `InvalidLength`, not
// `InvalidKeyFormat`. Documents that the structural rule sits behind the length
// gate for GRAI on validate.
pub fn validate_grai_too_short_is_invalid_length_pending_test() {
  gl_gtin.validate_key(Grai, "061414100001")
  |> should.equal(Error(InvalidLength(got: 12)))
}

// A valid 13-digit GRAI base (serial absent) validates. Kept as the boundary
// neighbor of the two negative cases above.
pub fn validate_grai_valid_base_succeeds_test() {
  gl_gtin.validate_key(Grai, "0614141000012")
  |> should.equal(Ok(Grai))
}

// ============================================================================
// validate_key(Giai, _) / generate_key(Giai, _) — InvalidKeyFormat UNREACHABLE
// ============================================================================

// PENDING GS1 CONFIRMATION (task 1.1 / key-spec-confirmation-notes.md).
//
// GIAI has NO key-level check digit and no library-enforceable internal
// boundary; `GiaiRule` asserts ONLY total length 1..30 — the very same bound the
// `VariableLen(1, 30)` length rule already enforces one step earlier. So a GIAI
// input that overshoots the length surfaces `InvalidLength` (here 31 digits),
// never `InvalidKeyFormat`. Requirement 6.7's `InvalidKeyFormat` outcome is thus
// unreachable for GIAI on validate today, pending a confirmed structural rule
// distinct from the length bound.
pub fn validate_giai_over_length_is_invalid_length_pending_test() {
  gl_gtin.validate_key(Giai, "0000000000000000000000000000000")
  |> should.equal(Error(InvalidLength(got: 31)))
}

// PENDING GS1 CONFIRMATION (task 1.1 / key-spec-confirmation-notes.md).
//
// A GIAI code carrying a non-digit character fails the character step first
// (the driver's `parse_body_digits` is digit-only). This documents that GIAI
// alphanumeric serial handling is not yet wired into the driver, so an
// alphanumeric body is rejected as `InvalidCharacters` rather than reaching any
// structural (`InvalidKeyFormat`) decision — pending the confirmed CSET 82
// serial rule.
pub fn validate_giai_alphanumeric_is_invalid_characters_pending_test() {
  gl_gtin.validate_key(Giai, "ABC123")
  |> should.equal(Error(InvalidCharacters))
}

// PENDING GS1 CONFIRMATION (task 1.1 / key-spec-confirmation-notes.md).
//
// Requirement 7.4 for GIAI: `generate_key(Giai, body)` over-length body. Because
// `GiaiRule` only asserts 1..30 (redundant with the `VariableLen` body-length
// rule), an over-length body surfaces `InvalidLength`, not `InvalidKeyFormat`.
pub fn generate_giai_over_length_is_invalid_length_pending_test() {
  gl_gtin.generate_key(Giai, "0000000000000000000000000000000")
  |> should.equal(Error(InvalidLength(got: 31)))
}

// A well-formed GIAI body (30 digits, within 1..30, all digits) generates the
// body verbatim — GIAI appends no check digit. Boundary neighbor for the
// negative GIAI cases above.
pub fn generate_giai_valid_body_succeeds_test() {
  gl_gtin.generate_key(Giai, "000000000000000000000000000000")
  |> should.equal(Ok("000000000000000000000000000000"))
}
