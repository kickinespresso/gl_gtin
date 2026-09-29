# GL GTIN

[![Package Version](https://img.shields.io/hexpm/v/gl_gtin)](https://hex.pm/packages/gl_gtin)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gl_gtin/)
[![Packagist](https://img.shields.io/packagist/l/doctrine/orm.svg)](LICENSE.md)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/kickinespresso/gl_gtin/issues)

A production-ready Gleam library for validating and generating GTIN (Global Trade Item Number) codes according to the GS1 specification. This library provides type-safe, idiomatic Gleam implementations. Its GS1 3-digit prefix allocation table is ported from the Elixir [ex_gtin](https://github.com/kickinespresso/ex_gtin) library; it is inspired by ex_gtin rather than a full feature-parity port (see [Limitations](#limitations)).

## Features

- **GTIN Validation**: Validate GTIN-8, GTIN-12, GTIN-13, and GTIN-14 codes
- **Batch Validation**: Validate a list of codes at once and partition them into valid/invalid groups
- **Check Digit Generation**: Generate complete GTINs with calculated check digits using the GS1 Modulo 10 algorithm
- **GS1 Country/Region Prefix Lookup**: Identify the country or region of origin using GS1's real 3-digit allocation ranges (a broad set of countries and regions, plus ISBN/ISSN and restricted-circulation/coupon ranges)
- **GTIN Normalization**: Convert GTIN-13 codes to GTIN-14 format for logistics applications, with a configurable indicator digit
- **GTIN-14 Down-Conversion**: Reduce an indicator-0 GTIN-14 back to its base GTIN-13 or GTIN-12
- **UPC-E ⇄ UPC-A Conversion**: Expand a compressed 8-digit UPC-E to 12-digit UPC-A and compress back again
- **Structured Parsing**: Decompose a GTIN into its format, digits, indicator, GS1 prefix/region, and check digit
- **GS1 Identification Keys**: Validate and generate SSCC, GSIN, and other GS1 keys (GLN, GRAI, GIAI, GSRN, GDTI, GCN) via a shared `Gs1Key`-parameterized API
- **Type-Safe API**: Leverage Gleam's strong type system to prevent invalid GTINs
- **Comprehensive Error Handling**: Specific error types for different failure modes
- **Well-Documented**: Extensive documentation with practical examples for all functions

## Installation

```sh
gleam add gl_gtin
```

## Quick Start

### Validating a GTIN

```gleam
import gl_gtin

pub fn main() {
  // Validate a GTIN-13
  case gl_gtin.validate("6291041500213") {
    Ok(format) -> io.println("Valid GTIN: " <> format_to_string(format))
    Error(err) -> io.println("Invalid GTIN: " <> error_to_string(err))
  }
}
```

### Generating a GTIN with Check Digit

```gleam
import gl_gtin

pub fn main() {
  // Generate a GTIN-13 from 12 digits
  case gl_gtin.generate("629104150021") {
    Ok(complete_gtin) -> io.println("Generated: " <> complete_gtin)
    Error(err) -> io.println("Error: " <> error_to_string(err))
  }
}
```

### Looking Up Country of Origin

```gleam
import gl_gtin

pub fn main() {
  // Find the country for a GTIN
  case gl_gtin.gs1_prefix_country("6291041500213") {
    Ok(country) -> io.println("Country: " <> country)
    Error(_) -> io.println("Country not found")
  }
}
```

### Normalizing GTIN-13 to GTIN-14

```gleam
import gl_gtin

pub fn main() {
  // Convert GTIN-13 to GTIN-14
  case gl_gtin.normalize("6291041500213") {
    Ok(gtin14) -> io.println("GTIN-14: " <> gtin14)
    Error(err) -> io.println("Error: " <> error_to_string(err))
  }
}
```

### Validating and Generating GS1 Keys

```gleam
import gl_gtin
import gl_gtin/gtin_types.{Sscc}

pub fn main() {
  // Validate an 18-digit SSCC
  case gl_gtin.validate_sscc("106141415432109873") {
    Ok(kind) -> io.println("Valid key: " <> kind)
    Error(err) -> io.println("Invalid SSCC: " <> error_to_string(err))
  }

  // Generate an SSCC from a 17-digit body
  case gl_gtin.generate_sscc("10614141543210987") {
    Ok(sscc) -> io.println("Generated SSCC: " <> sscc)
    Error(err) -> io.println("Error: " <> error_to_string(err))
  }

  // Validate against a specific Gs1Key kind
  case gl_gtin.validate_key(Sscc, "106141415432109873") {
    Ok(_key) -> io.println("Valid SSCC key")
    Error(err) -> io.println("Invalid key: " <> error_to_string(err))
  }
}
```

## Limitations

A few behaviors are worth calling out so the library's scope is clear:

- **GTIN-8 prefix lookup**: A GTIN-8 is used as-is for the prefix basis, so it reads its own leading digits against the GTIN-13 range table. This library does **not** implement true GS1-8 prefix semantics; the result for a GTIN-8 reflects the GTIN-13 table lookup rather than a dedicated GS1-8 allocation.
- **ISBN-10 handling**: `normalize` does not perform any ISBN-10 handling. This is considered out of scope (optional future work).

## Supported GTIN Formats

| Format  | Length    | Use Case                                                 |
| ------- | --------- | -------------------------------------------------------- |
| GTIN-8  | 8 digits  | Small packages outside North America                     |
| GTIN-12 | 12 digits | UPC-A, primarily used in North America                   |
| GTIN-13 | 13 digits | EAN-13, used internationally                             |
| GTIN-14 | 14 digits | ITF-14, used for trade items at various packaging levels |

## Error Handling

The library uses Gleam's `Result` type for explicit error handling:

```gleam
pub type GtinError {
  InvalidLength(got: Int)
  InvalidCheckDigit
  InvalidCharacters
  NoGs1PrefixFound
  InvalidFormat
  InvalidKeyFormat
}
```

All functions return `Result(value, GtinError)`, allowing you to handle errors gracefully:

```gleam
import gl_gtin
import result

pub fn validate_and_lookup(code: String) -> Result(String, GtinError) {
  use _format <- result.try(gl_gtin.validate(code))
  gl_gtin.gs1_prefix_country(code)
}
```

## API Overview

### Validation

- `validate(code: String) -> Result(GtinFormat, GtinError)` - Validate a GTIN code
- `validate_all(codes: List(String)) -> List(#(String, Result(GtinFormat, GtinError)))` - Validate a batch, pairing each original input with its result
- `partition(codes: List(String)) -> #(List(String), List(String))` - Split a batch into `#(valid, invalid)` groups

### Generation

- `generate(code: String) -> Result(String, GtinError)` - Generate a complete GTIN with check digit

### Prefix Lookup

- `gs1_prefix_country(code: String) -> Result(String, GtinError)` - Look up the country/region from a GTIN

### Normalization and Conversion

- `normalize(code: String) -> Result(String, GtinError)` - Convert GTIN-13 to GTIN-14 (indicator digit 1)
- `normalize_with_indicator(code: String, indicator: Int) -> Result(String, GtinError)` - Convert GTIN-13 to GTIN-14 with a caller-supplied indicator (0–9)
- `to_gtin13(code: String) -> Result(String, GtinError)` - Reduce an indicator-0 GTIN-14 to its base GTIN-13
- `to_gtin12(code: String) -> Result(String, GtinError)` - Reduce an indicator-0 GTIN-14 to its base GTIN-12 (UPC-A)
- `upce_to_upca(code: String) -> Result(String, GtinError)` - Expand an 8-digit UPC-E to 12-digit UPC-A
- `upca_to_upce(code: String) -> Result(String, GtinError)` - Compress a 12-digit UPC-A to 8-digit UPC-E

### Parsing

- `parse(code: String) -> Result(GtinInfo, GtinError)` - Decompose a validated GTIN into a structured `GtinInfo` record

### GS1 Identification Keys (SSCC, GSIN, generic)

- `validate_sscc(code: String) -> Result(String, GtinError)` - Validate an 18-digit SSCC; returns `Ok("SSCC")` on success
- `generate_sscc(body: String) -> Result(String, GtinError)` - Append the mod-10 check digit to a 17-digit body to produce an 18-digit SSCC
- `validate_gsin(code: String) -> Result(String, GtinError)` - Validate a 17-digit GSIN; returns `Ok("GSIN")` on success
- `generate_gsin(body: String) -> Result(String, GtinError)` - Append the mod-10 check digit to a 16-digit body to produce a 17-digit GSIN
- `validate_key(key: Gs1Key, code: String) -> Result(Gs1Key, GtinError)` - Validate a code against a specified `Gs1Key` kind
- `generate_key(key: Gs1Key, body: String) -> Result(String, GtinError)` - Generate a complete key of a specified `Gs1Key` kind from a body

The `Gs1Key` variants (`Gtin`, `Gln`, `Sscc`, `Gsin`, `Grai`, `Giai`, `Gsrn`, `Gdti`, `Gcn`) are imported from `gl_gtin/gtin_types`, e.g. `import gl_gtin/gtin_types.{Sscc, Gsin, Grai}`. Base-plus-serial keys (GRAI, GDTI, GCN) accept an optional serial after the numeric base, GIAI is freeform alphanumeric with no check digit, and a structurally malformed key returns `InvalidKeyFormat`.

### Opaque Gtin Type

- `from_string(code: String) -> Result(Gtin, GtinError)` - Create an opaque Gtin type
- `to_string(gtin: Gtin) -> String` - Extract the string value from a Gtin
- `format(gtin: Gtin) -> GtinFormat` - Get the format of a Gtin

### Structured Parse Output

`parse/1` returns a `GtinInfo` record:

```gleam
pub type GtinInfo {
  GtinInfo(
    format: GtinFormat,
    digits: String,
    indicator: Result(Int, Nil),
    gs1_prefix: String,
    gs1_region: Result(String, GtinError),
    check_digit: Int,
  )
}
```

## Documentation

Full API documentation is available at [hexdocs.pm/gl_gtin](https://hexdocs.pm/gl_gtin/).

Generate local documentation with:

```sh
gleam docs build
```

## Development

### Running Tests

```sh
gleam test
```

### Building Documentation

```sh
gleam docs build
```

### Format

Check the format

```sh
gleam format --check
```

Format

```sh
gleam format
```

### Project Structure

```text
gl_gtin/
├── src/
│   ├── gl_gtin.gleam           # Main public API (facade)
│   ├── gl_gtin/
│   │   ├── gtin_types.gleam    # Shared public types (GtinFormat, GtinError)
│   │   ├── validation.gleam    # Core validation and normalization logic
│   │   ├── check_digit.gleam   # Check digit calculation engine
│   │   ├── gs1_prefix.gleam    # GS1 country/region prefix lookup
│   │   ├── gs1_key.gleam       # GS1 identification key support (internal)
│   │   ├── upc.gleam           # UPC-E ⇄ UPC-A conversion
│   │   ├── parse.gleam         # Structured GTIN parsing (GtinInfo)
│   │   └── internal/
│   │       └── utils.gleam     # Internal utility functions
└── test/
    ├── gl_gtin_test.gleam      # Integration tests
    └── gl_gtin/
        ├── validation_test.gleam
        ├── check_digit_test.gleam
        ├── gs1_prefix_test.gleam
        ├── upc_test.gleam
        ├── parse_test.gleam
        ├── batch_helpers_test.gleam
        └── internal/
            └── utils_test.gleam
```

## GS1 Specification Compliance

This library implements the GS1 Modulo 10 check digit algorithm as specified in the GS1 General Specifications. The check digit is calculated as follows:

1. Multiply each digit alternately by 3 and 1, starting from the rightmost digit
2. Sum all products
3. Calculate modulo 10 of the sum
4. If the result is 0, the check digit is 0; otherwise, the check digit is (10 - result)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## References

- [GS1 General Specifications](https://www.gs1.org/standards/barcodes-eanupce)
- [ISO/IEC 15459 - Item identification](https://www.iso.org/standard/72601.html)

## Sponsors

This project is sponsored by [KickinEspresso](https://kickinespresso.com/?utm_source=github&utm_medium=sponsor&utm_campaign=opensource)

## Versioning

We use [SemVer](http://semver.org/) for versioning.

## Code of Conduct

Please refer to the [Code of Conduct](CODE_OF_CONDUCT.md) for details

## Security

Please refer to the [Security](SECURITY.md) for details

## Publish Package

```shell
gleam publish
```