# Implementation Plan: gl-gtin-gs1-keys (F5 / F6 / F7)

## Overview

This plan implements the Tier 2 GS1-key features additively on top of the
`gl_gtin` 3.0.0 codebase, in the dependency order the design mandates:

1. **Public surface first** — add the public `Gs1Key` type (9 variants) and the
   new `InvalidKeyFormat` variant to `GtinError` in `src/gl_gtin.gleam`, then
   create the new internal module `src/gl_gtin/gs1_key.gleam` with its
   `KeyError`, `KeySpec`/`LengthRule`/`FormatRule` types and the `key_spec`
   table. Everything downstream reads the table generically.
2. **Generic driver** — implement the shared `validate_key` / `generate_key`
   machinery plus the private helpers (`parse_body_digits`, `check_length`,
   `check_format`), routing all check-digit work through the F0 engine.
3. **F5 / F6 specializations** — `validate_sscc` / `generate_sscc` /
   `validate_gsin` / `generate_gsin` as thin wrappers over the generic driver.
4. **Facade wrappers** — thin public functions in `src/gl_gtin.gleam` mapping the
   internal `KeyError` up to `GtinError`.
5. **Tests** — gleeunit unit tests (success + failure per feature), doc-comment
   example assertions, and property-based tests for the 8 design properties.
6. **Release discipline** — CHANGELOG entry and final verification.

Every task is test-driven and keeps all library functions **total** (no
`let assert`, `panic`, or `todo`); the source must pass `gleam format --check`.

**Prerequisite dependency (NOT a task here):** The **F0 generalized check-digit
engine** delivered by `.kiro/specs/gl-gtin-tier1-features/` (the `len > 13` cap
lifted, plus the `valid`/`append` helpers on `src/gl_gtin/check_digit.gleam`) is a
prerequisite. This plan **consumes** `check_digit.calculate` / `check_digit.valid`
/ `check_digit.append` as-is and MUST NOT modify `check_digit.gleam`
(Requirement 9.1, 9.2, 9.3).

**Key lengths — mostly confirmed:** The design's Key Specification Table now
records the single-length keys `Gln`=13, `Sscc`=18, `Gsin`=17, `Gsrn`=18 as
**confirmed** against the **GS1 General Specifications**. The variable-serial keys
carry confirmed core figures — `Grai` (AI 8003) = 13-digit base + serial up to 16
alphanumeric; `Giai` (AI 8004) = up to 30 chars, no key-level check; `Gdti`
(AI 253) = 13-digit base + serial up to 17; `Gcn` (AI 255) = 13-digit base +
serial up to 12; the `Gdti`/`Gcn` check digit applies to the 13-digit base only —
and remain flagged "open question" only for the residual serial-charset and exact
component-boundary details. Task 1.1 confirms those residual items against the
authoritative GS1 General Specifications before the `key_spec` values are
finalized; the variable-serial (`Grai`/`Giai`) format tests are marked pending
that confirmation (Requirement 10).

## Tasks

- [x] 1. Confirm key specifications and set up property-testing infrastructure
  - [x] 1.1 Confirm the residual open-question key boundaries against the GS1 General Specifications
    - The single-length keys are already confirmed and hard-coded as such in
      `key_spec`: `Gln`=13, `Sscc`=18, `Gsin`=17, `Gsrn`=18
    - Confirm the residual variable-serial details before they are hard-coded in
      `key_spec`: the `Grai` (13-digit base + serial up to 16 alphanumeric) and
      `Giai` (up to 30 chars, no key-level check) component boundaries and serial
      charsets; the `Gdti` (base 13 + serial up to 17) and `Gcn` (base 13 + serial
      up to 12) serial charsets; and that the `Gdti`/`Gcn` check digit applies to
      the 13-digit base only (confirmed in design — verify against the spec text)
    - Record each confirmed value (or the remaining open item) as a code comment
      on the corresponding `key_spec` row so a later correction is a one-line edit
    - The GS1 General Specifications is reference material, not a runtime service;
      no network/runtime lookup is added
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_
    - _Design: Key Specification Table_

  - [x] 1.2 Add the `qcheck` dev-dependency and generator helper module
    - Add `qcheck` to `[dev-dependencies]` in `gleam.toml` and run the build to
      update `manifest.toml` (it may already be present if the sibling Tier 1
      spec added it — if so, reuse it and skip the edit)
    - Create `test/gl_gtin/gs1_key_generators.gleam` with the design's generators:
      `gen_sscc_body` (random 17-digit numeric string), `gen_gsin_body` (random
      16-digit numeric string), and `gen_key_body(kind)` (random body of the
      correct body length for `kind`, respecting `BasePlusSerial`/`VariableLen`
      for the variable-serial kinds using the confirmed boundaries from 1.1)
    - If `qcheck` cannot be added, implement the same generators as deterministic
      seeded loops producing ≥100 sampled cases; property tests consume them
      either way
    - _Requirements: 8.7_
    - _Design: Testing Strategy — generators_

- [x] 2. Public surface — `Gs1Key` type and `GtinError` extension (`src/gl_gtin.gleam`)
  - [x] 2.1 Add the public `Gs1Key` type and the `InvalidKeyFormat` error variant
    - Add `pub type Gs1Key { Gtin Gln Sscc Gsin Grai Giai Gsrn Gdti Gcn }` (exactly
      nine variants) to `src/gl_gtin.gleam`
    - Add the new `InvalidKeyFormat` variant to the existing `GtinError` type,
      leaving `InvalidFormat` reserved for the existing GTIN format-conversion
      failures; do not remove, rename, or change any existing variant
    - Update the `validate`, `normalize`, and `generate` error-mapping `case`
      expressions only if the compiler requires exhaustiveness for the new variant
      (the existing wrappers map from `validation`/`check_digit` errors, which do
      not produce `InvalidKeyFormat`, so no behavioral change)
    - _Requirements: 5.1, 8.1, 8.3, 8.5_
    - _Design: Public facade — `Gs1Key`, `GtinError` extension_

- [x] 3. Internal module scaffold — `src/gl_gtin/gs1_key.gleam` (new)
  - [x] 3.1 Define the internal types and the `key_spec` table
    - Create `src/gl_gtin/gs1_key.gleam`; define `pub type KeyError` with
      `InvalidLength(got: Int)`, `InvalidCheckDigit`, `InvalidCharacters`,
      `InvalidKeyFormat`
    - Define `LengthRule` (`FixedLen`, `OneOf`, `BasePlusSerial`, `VariableLen`),
      `FormatRule` (`NoFormatRule`, `GraiRule`, `GiaiRule`), and
      `KeySpec(length, format)`
    - Implement `pub fn key_spec(key: Gs1Key) -> KeySpec` as a single exhaustive
      `case`, one row per variant, using the values confirmed in task 1.1 (single
      source of truth; the driver never hard-codes a length)
    - Import `Gs1Key` and its variants from `gl_gtin`
    - _Requirements: 5.2_
    - _Design: `KeySpec` representation, Key Specification Table, `key_spec`_

- [x] 4. Generic validate/generate driver (`src/gl_gtin/gs1_key.gleam`)
  - [x] 4.1 Implement the private helpers
    - `parse_body_digits(code) -> Result(List(Int), KeyError)`: `string.trim`, then
      map every character via `utils.parse_digit`; any non-digit (interior
      whitespace included) → `Error(InvalidCharacters)`; empty/whitespace-only
      trims to an empty list and returns `Ok([])`
    - `check_length(rule, count) -> Result(Nil, KeyError)`: evaluate the
      `LengthRule`; mismatch → `Error(InvalidLength(got: count))` (`count` = the
      trimmed digit count, so empty → `InvalidLength(got: 0)`)
    - `check_format(rule, digits) -> Result(Nil, KeyError)`: `NoFormatRule` →
      `Ok(Nil)`; `GraiRule`/`GiaiRule` → structural checks against the confirmed
      boundaries, else `Error(InvalidKeyFormat)`
    - _Requirements: 6.3, 6.4, 6.7, 7.2, 7.3, 7.4_
    - _Design: private helpers `parse_body_digits`, `check_length`, `check_format`_

  - [x] 4.2 Implement the generic `validate_key`
    - `pub fn validate_key(key, code) -> Result(Gs1Key, KeyError)` with defect
      ordering: characters (`parse_body_digits`) → digit count
      (`check_length(spec.length, count)`) → check digit (F0 `check_digit.valid`,
      `False` → `InvalidCheckDigit`) → key-specific format
      (`check_format(spec.format, digits)`); return only the first failing rule
    - On all rules passing, return `Ok(key)` (the supplied `Gs1Key`), so two
      identical-length codes for different kinds are each judged solely against
      the supplied kind
    - _Requirements: 6.1, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 9.3_
    - _Design: `validate_key` flow_

  - [x] 4.3 Implement the generic `generate_key`
    - `pub fn generate_key(key, body) -> Result(String, KeyError)` with ordering:
      characters (`parse_body_digits`, evaluated **before** the length check) →
      body length (`check_length` against the derived body length: `total - 1` for
      fixed keys, or the `BasePlusSerial`/`VariableLen` body derivation) →
      key-specific format (`check_format`); then append the check digit via F0
      `check_digit.append`, mapping any engine error into `KeyError`, and render
      the digit list to a string
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 9.3_
    - _Design: `generate_key` flow_

  - [x] 4.4 Write generic-key property tests
    - `// Feature: gl-gtin-gs1-keys, Property 3: Generic key generate → validate round-trip` —
      `validate_key(k, generate_key(k, b)) == Ok(k)` over all kinds (`gen_key_body`)
    - `// Feature: gl-gtin-gs1-keys, Property 4: Same-length keys are judged only against the supplied kind` —
      pair `Sscc`/`Gsrn` codes; each validated only under its supplied kind
      (`gen_key_body`)
    - `// Feature: gl-gtin-gs1-keys, Property 7: Wrong length is reported with the trimmed digit count` —
      `validate_key(k, n-digit) == Error(InvalidLength(got: n))` (random-length numeric)
    - `// Feature: gl-gtin-gs1-keys, Property 8: Non-digit input is rejected before length` —
      inject a non-digit → `Error(InvalidCharacters)` regardless of length
    - ≥100 iterations each
    - _Requirements: 6.4, 6.8, 7.5, 6.3, 7.2_
    - _Design: Properties 3, 4, 7, 8_

- [x] 5. Checkpoint - generic key driver
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. F5 / F6 specializations (`src/gl_gtin/gs1_key.gleam`)
  - [x] 6.1 Implement the SSCC specializations
    - `pub fn validate_sscc(code) -> Result(String, KeyError)` = `validate_key(Sscc, code)`
      then map `Ok(Sscc) -> Ok("SSCC")` (a valid GTIN-14 fails the 18-digit length
      check → `InvalidLength(got: 14)`, never `Ok("SSCC")`)
    - `pub fn generate_sscc(body) -> Result(String, KeyError)` = `generate_key(Sscc, body)`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 2.1, 2.2, 2.3_
    - _Design: `validate_sscc`, `generate_sscc`_

  - [x] 6.2 Implement the GSIN specializations
    - `pub fn validate_gsin(code) -> Result(String, KeyError)` = `validate_key(Gsin, code)`
      then map `Ok(Gsin) -> Ok("GSIN")` (a valid 18-digit SSCC fails the 17-digit
      length check → `InvalidLength(got: 18)`, never `Ok("GSIN")`)
    - `pub fn generate_gsin(body) -> Result(String, KeyError)` = `generate_key(Gsin, body)`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.1, 4.2, 4.3_
    - _Design: `validate_gsin`, `generate_gsin`_

  - [x] 6.3 Write SSCC/GSIN round-trip and length-rejection property tests
    - `// Feature: gl-gtin-gs1-keys, Property 1: SSCC generate → validate round-trip` —
      `validate_sscc(generate_sscc(b)) == Ok("SSCC")` (`gen_sscc_body`)
    - `// Feature: gl-gtin-gs1-keys, Property 2: GSIN generate → validate round-trip` —
      `validate_gsin(generate_gsin(b)) == Ok("GSIN")` (`gen_gsin_body`)
    - `// Feature: gl-gtin-gs1-keys, Property 5: SSCC validation rejects a valid GTIN-14 by length` —
      `validate_sscc(gtin14) == Error(InvalidLength(got: 14))`, never `Ok("SSCC")`
    - `// Feature: gl-gtin-gs1-keys, Property 6: GSIN validation rejects a valid SSCC by length` —
      `validate_gsin(sscc) == Error(InvalidLength(got: 18))`, never `Ok("GSIN")`
    - ≥100 iterations each
    - _Requirements: 2.4, 4.4, 1.7, 3.7_
    - _Design: Properties 1, 2, 5, 6_

- [x] 7. Public facade wrappers (`src/gl_gtin.gleam`)
  - [x] 7.1 Add the F5/F6/F7 facade wrappers mapping `KeyError` → `GtinError`
    - Add `validate_sscc`, `generate_sscc`, `validate_gsin`, `generate_gsin`,
      `validate_key`, `generate_key` as thin wrappers delegating to `gs1_key.*`
      and mapping the internal `KeyError` to `GtinError` via `result.map_error`
      (`InvalidLength`→`InvalidLength`, `InvalidCheckDigit`→`InvalidCheckDigit`,
      `InvalidCharacters`→`InvalidCharacters`, `InvalidKeyFormat`→`InvalidKeyFormat`)
    - Signatures: `validate_sscc/validate_gsin(code) -> Result(String, GtinError)`;
      `generate_sscc/generate_gsin(body) -> Result(String, GtinError)`;
      `validate_key(key, code) -> Result(Gs1Key, GtinError)`;
      `generate_key(key, body) -> Result(String, GtinError)`
    - Add doc-comment examples to every new public function (SSCC/GSIN examples
      must use bodies whose check digits are computed by the engine so the stated
      output strings are exact; include the `validate_key(Gln, "0614141000012")`
      worked example)
    - _Requirements: 8.1, 8.2, 8.4, 8.6_
    - _Design: Public facade — F5/F6/F7 wrappers, `KeyError → GtinError` mapping_

- [x] 8. Feature tests — unit and doc-comment examples (`test/gl_gtin/gs1_key_test.gleam`, new)
  - [x] 8.1 Write F5 (SSCC) unit and doc-comment example tests
    - Valid 18-digit SSCC → `Ok("SSCC")`; wrong check digit →
      `Error(InvalidCheckDigit)`; 17/19-digit numeric →
      `Error(InvalidLength(got: n))`; interior space → `Error(InvalidCharacters)`;
      empty/whitespace → `Error(InvalidLength(got: 0))`; valid GTIN-14 →
      `Error(InvalidLength(got: 14))`; `generate_sscc` of a 17-digit body →
      18-digit result; 16-digit body → `Error(InvalidLength(got: 16))`
    - Mirror every `validate_sscc`/`generate_sscc` doc-comment example as an assertion
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 2.1, 2.2, 2.3, 8.7, 8.8_

  - [x] 8.2 Write F6 (GSIN) unit and doc-comment example tests
    - Mirror of F5 at lengths 17/16, including a valid SSCC →
      `Error(InvalidLength(got: 18))`; wrong check digit, interior space,
      empty/whitespace, and `generate_gsin` success/length cases
    - Mirror every `validate_gsin`/`generate_gsin` doc-comment example as an assertion
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.1, 4.2, 4.3, 8.7, 8.8_

  - [x] 8.3 Write F7 (generic key) unit and doc-comment example tests
    - `validate_key(Gln, "0614141000012") == Ok(Gln)` (worked example);
      `validate_key(Gln, "0614141000013") == Error(InvalidCheckDigit)`; a
      same-length pair (`Sscc` vs `Gsrn`) each validated under its own kind;
      non-digit → `Error(InvalidCharacters)`; wrong length →
      `Error(InvalidLength(got: n))`; `generate_key(Sscc, body)` equals
      `generate_sscc(body)`
    - Mirror every `validate_key`/`generate_key` doc-comment example as an assertion
    - _Requirements: 5.1, 5.2, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.8, 7.1, 7.2, 7.3, 8.7, 8.8_

  - [x] 8.4 Write variable-serial `InvalidKeyFormat` tests (pending GS1 confirmation)
    - A `Grai`/`Giai` body/code that meets length but violates the assumed
      structural rule → `Error(InvalidKeyFormat)` for `validate_key`, and the
      matching `generate_key` format failure
    - Mark these tests as **pending confirmation** of the `Grai`/`Giai`
      boundaries from task 1.1; keep them isolated so a boundary correction only
      touches this test and the `key_spec` row
    - _Requirements: 6.7, 7.4_
    - _Design: `check_format`, Key Specification Table (open questions)_

- [x] 9. Checkpoint - features and tests
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Release discipline — CHANGELOG and full verification
  - Add one `CHANGELOG.md` entry naming each of the F5 (SSCC), F6 (GSIN), and F7
    (generic keys) additions and the new `InvalidKeyFormat` `GtinError` variant,
    including the compatibility note that downstream callers exhaustively `case`-ing
    over `GtinError` must add an `InvalidKeyFormat` arm (additive → minor bump)
  - Run `gleam test` and confirm all unit, doc-example, and property tests pass
  - Run `gleam format --check` and confirm a zero exit status with no files
    needing reformatting; reformat any offending source
  - Confirm no library function uses `let assert`, `panic`, or `todo`
  - _Requirements: 8.4, 8.9, 8.10_

- [x] 11. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP. The
  optional sub-tasks here are the property-based tests (4.4, 6.3, 8.4); the
  required unit and doc-comment example tests (Requirement 8.7, 8.8) in tasks
  8.1–8.3 are **NOT** optional.
- The **F0 generalized check-digit engine** (`.kiro/specs/gl-gtin-tier1-features/`)
  is a prerequisite dependency; `src/gl_gtin/check_digit.gleam` MUST NOT be
  modified here. All check-digit work routes through `check_digit.valid` /
  `check_digit.append` / `check_digit.calculate` (Requirement 9).
- The `key_spec` table is the single source of truth for lengths and boundaries;
  correcting an open-question value confirmed in task 1.1 is a one-line edit that
  the generic driver reads without change.
- Property tests use `qcheck` at ≥100 iterations, each tagged with a
  `// Feature: gl-gtin-gs1-keys, Property N: ...` comment; a deterministic
  seeded-generator fallback (≥100 cases) applies if `qcheck` cannot be added.
- All new public functions are additive; existing signatures are unchanged and
  the `Gtin` type remains opaque (Requirement 8.1, 8.5).

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["1.2", "3.1"] },
    { "id": 2, "tasks": ["4.1"] },
    { "id": 3, "tasks": ["4.2", "4.3"] },
    { "id": 4, "tasks": ["4.4", "6.1", "6.2"] },
    { "id": 5, "tasks": ["6.3", "7.1"] },
    { "id": 6, "tasks": ["8.1", "8.2", "8.3", "8.4"] }
  ]
}
```
