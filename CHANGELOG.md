# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
