//// A production-ready Gleam library for validating and generating GTIN (Global Trade Item Number) codes.
////
//// This library provides type-safe, idiomatic Gleam implementations of GTIN validation,
//// check digit generation, GS1 prefix lookup, and GTIN normalization according to the
//// GS1 specification.
////
//// # Quick Start
////
//// ```gleam
//// import gtin
////
//// // Validate a GTIN code
//// case gtin.validate("6291041500213") {
////   Ok(format) -> io.println("Valid GTIN-13")
////   Error(err) -> io.println("Invalid GTIN")
//// }
////
//// // Generate a GTIN with check digit
//// case gtin.generate("629104150021") {
////   Ok(complete_gtin) -> io.println(complete_gtin)
////   Error(_) -> io.println("Generation failed")
//// }
////
//// // Look up country from GS1 prefix
//// case gtin.gs1_prefix_country("6291041500213") {
////   Ok(country) -> io.println("Country: " <> country)
////   Error(_) -> io.println("Prefix not found")
//// }
//// ```

import gleam/result
import gtin/check_digit
import gtin/gs1_prefix
import gtin/validation

/// Supported GTIN formats based on digit count.
pub type GtinFormat {
  /// 8-digit GTIN format, used for small packages outside North America
  Gtin8
  /// 12-digit GTIN format (UPC-A), primarily used in North America
  Gtin12
  /// 13-digit GTIN format (EAN-13), used internationally
  Gtin13
  /// 14-digit GTIN format (ITF-14), used for trade items at various packaging levels
  Gtin14
}

/// Errors that can occur when working with GTIN codes.
pub type GtinError {
  /// Input has wrong number of digits. Includes the actual length provided.
  InvalidLength(got: Int)
  /// Check digit does not match the calculated value.
  InvalidCheckDigit
  /// Input contains non-numeric characters.
  InvalidCharacters
  /// GS1 prefix not found in the database.
  NoGs1PrefixFound
  /// Operation not applicable to this GTIN format.
  InvalidFormat
}

/// A validated GTIN code.
///
/// This is an opaque type that can only be constructed through validation.
/// This ensures that any Gtin value in your code is guaranteed to be valid.
pub opaque type Gtin {
  Gtin(value: String, format: GtinFormat)
}

/// Validate a GTIN code string.
///
/// Checks that the input is a valid GTIN (8, 12, 13, or 14 digits) with a correct check digit.
/// Automatically trims leading and trailing whitespace before validation.
///
/// # Examples
///
/// ```gleam
/// validate("6291041500213")
/// // -> Ok(Gtin13)
///
/// validate("012345678905")
/// // -> Ok(Gtin12)
///
/// validate("invalid")
/// // -> Error(InvalidCharacters)
///
/// validate("123")
/// // -> Error(InvalidLength(got: 3))
/// ```
pub fn validate(code: String) -> Result(GtinFormat, GtinError) {
  validation.validate(code)
  |> result.map(fn(fmt) {
    case fmt {
      validation.Gtin8 -> Gtin8
      validation.Gtin12 -> Gtin12
      validation.Gtin13 -> Gtin13
      validation.Gtin14 -> Gtin14
    }
  })
  |> result.map_error(fn(err) {
    case err {
      validation.InvalidLength(got) -> InvalidLength(got)
      validation.InvalidCheckDigit -> InvalidCheckDigit
      validation.InvalidCharacters -> InvalidCharacters
      validation.InvalidFormat -> InvalidFormat
    }
  })
}

/// Generate a complete GTIN with calculated check digit.
///
/// Takes an incomplete GTIN (7, 11, 12, or 13 digits) and calculates the check digit
/// to produce a complete GTIN (8, 12, 13, or 14 digits respectively).
///
/// # Examples
///
/// ```gleam
/// generate("629104150021")
/// // -> Ok("6291041500213")
///
/// generate("123456789012")
/// // -> Ok("1234567890128")
///
/// generate("invalid")
/// // -> Error(InvalidCharacters)
/// ```
pub fn generate(code: String) -> Result(String, GtinError) {
  check_digit.generate(code)
  |> result.map_error(fn(err) {
    case err {
      check_digit.InvalidLength(got) -> InvalidLength(got)
      check_digit.InvalidCharacters -> InvalidCharacters
    }
  })
}

/// Look up the country of origin from a GTIN code's GS1 prefix.
///
/// Checks the first 2-3 digits of the GTIN against the GS1 prefix database.
/// Checks 3-digit prefixes first, then 2-digit prefixes.
///
/// # Examples
///
/// ```gleam
/// gs1_prefix_country("6291041500213")
/// // -> Ok("GS1 Emirates")
///
/// gs1_prefix_country("012345678905")
/// // -> Ok("GS1 US")
///
/// gs1_prefix_country("999999999999")
/// // -> Error(NoGs1PrefixFound)
/// ```
pub fn gs1_prefix_country(code: String) -> Result(String, GtinError) {
  gs1_prefix.lookup(code)
  |> result.map_error(fn(_err) { NoGs1PrefixFound })
}

/// Convert a GTIN-13 to GTIN-14 format.
///
/// Prepends the indicator digit "1" and recalculates the check digit.
/// Only works with GTIN-13 codes; other formats return an error.
///
/// # Examples
///
/// ```gleam
/// normalize("6291041500213")
/// // -> Ok("16291041500214")
///
/// normalize("012345678905")
/// // -> Error(InvalidFormat)
/// ```
pub fn normalize(code: String) -> Result(String, GtinError) {
  validation.normalize(code)
  |> result.map_error(fn(err) {
    case err {
      validation.InvalidLength(got) -> InvalidLength(got)
      validation.InvalidCheckDigit -> InvalidCheckDigit
      validation.InvalidCharacters -> InvalidCharacters
      validation.InvalidFormat -> InvalidFormat
    }
  })
}

/// Create an opaque Gtin value from a validated string.
///
/// This function validates the input and wraps it in the opaque Gtin type.
/// Only valid GTINs can be wrapped.
///
/// # Examples
///
/// ```gleam
/// from_string("6291041500213")
/// // -> Ok(Gtin(...))
///
/// from_string("invalid")
/// // -> Error(InvalidCharacters)
/// ```
pub fn from_string(code: String) -> Result(Gtin, GtinError) {
  use format <- result.try(validate(code))
  Ok(Gtin(code, format))
}

/// Extract the string value from a Gtin.
///
/// # Examples
///
/// ```gleam
/// let assert Ok(gtin) = from_string("6291041500213")
/// to_string(gtin)
/// // -> "6291041500213"
/// ```
pub fn to_string(gtin: Gtin) -> String {
  let Gtin(value, _) = gtin
  value
}

/// Get the format of a Gtin.
///
/// # Examples
///
/// ```gleam
/// let assert Ok(gtin) = from_string("6291041500213")
/// format(gtin)
/// // -> Gtin13
/// ```
pub fn format(gtin: Gtin) -> GtinFormat {
  let Gtin(_, fmt) = gtin
  fmt
}
