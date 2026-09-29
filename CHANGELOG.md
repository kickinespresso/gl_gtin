# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.3.0] - 2026-09-30

Additive Tier 2 feature release (F5, F6, F7) adding GS1 identification-key
support to the public facade (`gl_gtin`). The `Gtin` type stays opaque and no
existing public function signature or return type changes. One new error variant
is added to `GtinError` (`InvalidKeyFormat`), which is a source-compatibility
consideration for downstream callers — see the compatibility note below.

### Added

- **F5** — SSCC (Serial Shipping Container Code) support on the facade. Two new
  functions validate and build the fixed 18-digit mod-10 key:
  - `gl_gtin.validate_sscc/1` — validates an 18-digit SSCC string
    (characters → length → check digit ordering).
  - `gl_gtin.generate_sscc/1` — appends the mod-10 check digit to a 17-digit
    body to produce a complete 18-digit SSCC.
- **F6** — GSIN (Global Shipment Identification Number) support on the facade.
  Two new functions validate and build the fixed 17-digit mod-10 key:
  - `gl_gtin.validate_gsin/1` — validates a 17-digit GSIN string.
  - `gl_gtin.generate_gsin/1` — appends the mod-10 check digit to a 16-digit
    body to produce a complete 17-digit GSIN.
- **F7** — Generic GS1-key driver on the facade, parameterized by the new public
  `Gs1Key` type:
  - `gl_gtin.validate_key/2` — validates a code string against a specified
    `Gs1Key` kind, reading that kind's length and format rules internally.
  - `gl_gtin.generate_key/2` — appends the mod-10 check digit to a body for a
    specified `Gs1Key` kind.
  - The public `Gs1Key` type (variants `Gtin`, `Gln`, `Sscc`, `Gsin`, `Grai`,
    `Giai`, `Gsrn`, `Gdti`, `Gcn`) is re-exported from `gl_gtin` as
    `gl_gtin.Gs1Key`, but its variant constructors are defined in and imported
    from `gl_gtin/gtin_types`, e.g. `import gl_gtin/gtin_types.{Sscc, Gsin}`.
    This mirrors the `GtinError`/`GtinFormat` convention introduced in [3.1.0].
  - `validate_key`/`generate_key` cover all nine kinds, including the
    variable-serial keys with a numeric base plus an optional typed serial: `Grai`
    (13-digit base + serial up to 16 alphanumeric), `Gdti` (13-digit base + serial
    up to 17 alphanumeric), `Gcn` (13-digit base + serial up to 12 numeric), and
    `Giai` (1–30 alphanumeric, no key-level check digit). The mod-10 check applies
    to the 13-digit base for the base-plus-serial keys; `InvalidKeyFormat` is
    returned when a base-plus-serial key's numeric base region contains a
    non-digit character.

### Changed

- A new `InvalidKeyFormat` variant is added to the public `GtinError` type
  (defined in `gl_gtin/gtin_types`, re-exported as `gl_gtin.GtinError`). It
  signals a key-specific structural failure and is distinct from `InvalidFormat`
  (reserved for GTIN format-conversion failures).

  **Compatibility note:** adding a variant is source-additive, so this is a minor
  bump. Downstream callers that exhaustively `case` over `GtinError` will need to
  add an `InvalidKeyFormat` arm to remain exhaustive; code that does not pattern
  match all variants of `GtinError` is unaffected.

## [3.2.0] - 2026-09-29

Additive Tier 2 feature release (F9). Both new public functions are additive:
no new types or error variants, no existing public signature or return type
changes, and the `Gtin` type stays opaque.

### Added

- **F9** — String-first batch helpers on the public facade (`gl_gtin`). Two new
  total functions compose the existing `validate` engine:
  - `gl_gtin.validate_all/1` — applies `validate` to every element of a list and
    returns `#(original_code, result)` pairs in input order. Keys are the
    byte-for-byte untrimmed inputs, and duplicates and empty lists are preserved.
  - `gl_gtin.partition/1` — splits a list of codes into a `#(valid, invalid)`
    tuple by validation outcome, preserving relative order within each list and
    conserving every input element exactly once.

## [3.1.0] - 2026-09-26

Additive Tier 1 feature release (F0–F4). All new public functions are additive:
no existing public signature or return type changes, and the `Gtin` type stays
opaque.

### Added

- **F0** — Generalized the check-digit engine (`gl_gtin/check_digit`). The
  `check_digit.calculate` length cap is lifted so any non-empty digit body of
  length 1–20 is accepted (existing check digits are unchanged), and two new
  engine helpers are added: `check_digit.valid/1` (verify a body's trailing
  check digit) and `check_digit.append/1` (compute and append the check digit).
- **F1** — UPC-E ⇄ UPC-A conversion (new module `gl_gtin/upc`). New public
  functions `gl_gtin.upce_to_upca/1` and `gl_gtin.upca_to_upce/1` expand a
  compressed 8-digit UPC-E to its 12-digit UPC-A form and compress a
  compressible UPC-A back to UPC-E.
- **F2** — Configurable GTIN-14 indicator digit. New
  `gl_gtin.normalize_with_indicator/2` prepends a caller-supplied indicator
  (0–9) and recomputes the check digit; `gl_gtin.normalize/1` now delegates to
  it with indicator 1 (behavior unchanged).
- **F3** — GTIN-14 down-conversion. New `gl_gtin.to_gtin13/1` and
  `gl_gtin.to_gtin12/1` reduce an indicator-0 GTIN-14 back to its base GTIN-13
  or (when the base is a UPC-A) GTIN-12 trade item.
- **F4** — Structured parse. New `gl_gtin.parse/1` returns the new `GtinInfo`
  record (new module `gl_gtin/parse`) decomposing a GTIN into `format`,
  `digits`, `indicator`, `gs1_prefix`, `gs1_region`, and `check_digit`.

### Changed

- Internal refactor: the public `GtinError` and `GtinFormat` types are now
  defined in `gl_gtin/gtin_types` and re-exported from `gl_gtin`. The types
  `gl_gtin.GtinError` and `gl_gtin.GtinFormat` are unchanged (type identity is
  preserved), but their variant constructors are now imported from
  `gl_gtin/gtin_types`. Downstream code that constructs or pattern-matches these
  error/format VARIANT CONSTRUCTORS may need to import them from
  `gl_gtin/gtin_types`; code that only refers to the types themselves is
  unaffected.

## [3.0.0] - 2026-09-26

Bugfix release for the GS1 prefix and normalization subsystem. The prefix
lookup corrections change public output for many inputs, so this is a breaking
change under Semantic Versioning (Issues 1-8).

### Changed

- **BREAKING** (Issues 1, 2): GS1 prefix lookup now uses GS1's real 3-digit
  allocation ranges (ported from `ex_gtin`) instead of the previous 2-digit
  "decade" table. The country/region returned by `gs1_prefix_country` /
  `gs1_prefix.lookup` changes for many inputs (e.g. `871..` now resolves to
  `GS1 Netherlands`, `690..` to `GS1 China`, `620..` to `GS1 Tanzania`).
- **BREAKING** (Issue 2): prefix lookup is now format-aware. GTIN-12 gets its
  implicit leading zero prepended and GTIN-14 drops its indicator digit before
  the 3-digit prefix is read, so normalized GTIN-14 codes resolve correctly
  (e.g. Emirates `16291041500210` -> `GS1 Emirates`).
- **Changed** (Issue 7): README capability claims corrected to match actual
  behavior; the GTIN-8 GS1-8 limitation is now documented and ISBN-10 handling
  is noted as out of scope. (Issue 8: `lookup/1` length leniency is documented
  in the module docs.)

### Fixed

- **Fixed** (Issue 4): `normalize/1` now trims once up front and uses the
  trimmed value throughout, so a whitespace-padded valid GTIN-13 normalizes
  correctly (e.g. `" 6291041500213 "` -> `Ok("16291041500210")`).
- **Fixed** (Issue 5): corrected the documented `normalize("6291041500213")`
  example from the wrong `Ok("16291041500214")` to `Ok("16291041500210")` in
  the README, `gl_gtin.gleam`, and `validation.gleam`.
- **Fixed** (Issues 3, 6): reworked the prefix test suite to assert GS1's real
  3-digit ranges (with negative cases for unassigned ranges), and replaced the
  assertion-free `case ... -> Nil` "property" tests with direct assertions so
  the suite can fail when behavior regresses.

## [2.0.0] - 2025-12-03

### Changed

- **BREAKING**: Package renamed from `gtin` to `gl_gtin` for Hex publication
- All imports updated from `import gtin` to `import gl_gtin`
- Module structure reorganized to align with new package name

## [1.0.0] - 2025-11-24

### Added

- Initial release of GTIN Gleam library
- GTIN validation for all formats (GTIN-8, GTIN-12, GTIN-13, GTIN-14)
- Check digit generation using GS1 Modulo 10 algorithm
- GS1 country prefix lookup with 100+ countries supported
- GTIN-13 to GTIN-14 normalization
- Type-safe opaque Gtin type to prevent invalid construction
- Comprehensive error handling with specific error types
- Full module documentation with practical examples
- Property-based test suite with 19+ correctness properties
- Unit tests covering all modules and edge cases
- Integration tests for end-to-end workflows

### Features

- `validate/1` - Validate GTIN codes and determine format
- `generate/1` - Generate complete GTINs with calculated check digits
- `gs1_prefix_country/1` - Look up country of origin from GTIN prefix
- `normalize/1` - Convert GTIN-13 to GTIN-14 format
- `from_string/1` - Create opaque Gtin type from validated string
- `to_string/1` - Extract string value from Gtin
- `format/1` - Get the format of a Gtin

### Documentation

- Comprehensive README with quick start guide
- Module-level documentation for all public modules
- Function-level documentation with 2-3 examples per function
- Examples showing both success and error cases
- Edge case explanations and special handling notes
- API overview and error handling guide
- GS1 specification compliance documentation

### Testing

- 19 property-based tests covering all correctness properties
- Unit tests for validation, check digit calculation, and prefix lookup
- Integration tests for end-to-end workflows
- > 95% code coverage
- Minimum 100 iterations per property-based test
