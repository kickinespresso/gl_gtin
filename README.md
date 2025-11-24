# GTIN Gleam

[![Package Version](https://img.shields.io/hexpm/v/gtin)](https://hex.pm/packages/gl_gtin)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gl_gtin/)
[![Packagist](https://img.shields.io/packagist/l/doctrine/orm.svg)](LICENSE.md)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/kickinespresso/gl_gtin/issues)

A production-ready Gleam library for validating and generating GTIN (Global Trade Item Number) codes according to the GS1 specification. This library provides type-safe, idiomatic Gleam implementations with feature parity to the Elixir [ex_gtin](https://github.com/kickinespresso/ex_gtin) library.

## Features

- **GTIN Validation**: Validate GTIN-8, GTIN-12, GTIN-13, and GTIN-14 codes
- **Check Digit Generation**: Generate complete GTINs with calculated check digits using the GS1 Modulo 10 algorithm
- **GS1 Country Prefix Lookup**: Identify the country of origin from GTIN codes (100+ countries supported)
- **GTIN Normalization**: Convert GTIN-13 codes to GTIN-14 format for logistics applications
- **Type-Safe API**: Leverage Gleam's strong type system to prevent invalid GTINs
- **Comprehensive Error Handling**: Specific error types for different failure modes
- **Well-Documented**: Extensive documentation with practical examples for all functions

## Installation

```sh
gleam add gtin
```

## Quick Start

### Validating a GTIN

```gleam
import gtin

pub fn main() {
  // Validate a GTIN-13
  case gtin.validate("6291041500213") {
    Ok(format) -> io.println("Valid GTIN: " <> format_to_string(format))
    Error(err) -> io.println("Invalid GTIN: " <> error_to_string(err))
  }
}
```

### Generating a GTIN with Check Digit

```gleam
import gtin

pub fn main() {
  // Generate a GTIN-13 from 12 digits
  case gtin.generate("629104150021") {
    Ok(complete_gtin) -> io.println("Generated: " <> complete_gtin)
    Error(err) -> io.println("Error: " <> error_to_string(err))
  }
}
```

### Looking Up Country of Origin

```gleam
import gtin

pub fn main() {
  // Find the country for a GTIN
  case gtin.gs1_prefix_country("6291041500213") {
    Ok(country) -> io.println("Country: " <> country)
    Error(_) -> io.println("Country not found")
  }
}
```

### Normalizing GTIN-13 to GTIN-14

```gleam
import gtin

pub fn main() {
  // Convert GTIN-13 to GTIN-14
  case gtin.normalize("6291041500213") {
    Ok(gtin14) -> io.println("GTIN-14: " <> gtin14)
    Error(err) -> io.println("Error: " <> error_to_string(err))
  }
}
```

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
}
```

All functions return `Result(value, GtinError)`, allowing you to handle errors gracefully:

```gleam
import gtin
import result

pub fn validate_and_lookup(code: String) -> Result(String, GtinError) {
  use _format <- result.try(gtin.validate(code))
  gtin.gs1_prefix_country(code)
}
```

## API Overview

### Main Functions

- `validate(code: String) -> Result(GtinFormat, GtinError)` - Validate a GTIN code
- `generate(code: String) -> Result(String, GtinError)` - Generate a complete GTIN with check digit
- `gs1_prefix_country(code: String) -> Result(String, GtinError)` - Look up the country from a GTIN
- `normalize(code: String) -> Result(String, GtinError)` - Convert GTIN-13 to GTIN-14
- `from_string(code: String) -> Result(Gtin, GtinError)` - Create an opaque Gtin type
- `to_string(gtin: Gtin) -> String` - Extract the string value from a Gtin
- `format(gtin: Gtin) -> GtinFormat` - Get the format of a Gtin

## Documentation

Full API documentation is available at [hexdocs.pm/gtin](https://hexdocs.pm/gtin/).

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

```
gtin/
├── src/
│   ├── gtin.gleam              # Main public API
│   ├── gtin/
│   │   ├── validation.gleam    # Core validation logic
│   │   ├── check_digit.gleam   # Check digit calculation
│   │   ├── gs1_prefix.gleam    # GS1 country prefix lookup
│   │   └── internal/
│   │       └── utils.gleam     # Internal utility functions
└── test/
    ├── gtin_test.gleam         # Integration tests
    └── gtin/
        ├── validation_test.gleam
        ├── check_digit_test.gleam
        └── gs1_prefix_test.gleam
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
