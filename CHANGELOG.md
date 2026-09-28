# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
