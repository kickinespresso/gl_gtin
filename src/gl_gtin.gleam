//// A production-ready Gleam library for validating and generating GTIN (Global Trade Item Number) codes.
////
//// This library provides type-safe, idiomatic Gleam implementations of GTIN validation,
//// check digit generation, GS1 prefix lookup, and GTIN normalization according to the
//// GS1 specification.
////
//// # Quick Start
////
//// ```gleam
//// import gl_gtin
////
//// // Validate a GTIN code
//// case gl_gtin.validate("6291041500213") {
////   Ok(format) -> io.println("Valid GTIN-13")
////   Error(err) -> io.println("Invalid GTIN")
//// }
////
//// // Generate a GTIN with check digit
//// case gl_gtin.generate("629104150021") {
////   Ok(complete_gtin) -> io.println(complete_gtin)
////   Error(_) -> io.println("Generation failed")
//// }
////
//// // Look up country from GS1 prefix
//// case gl_gtin.gs1_prefix_country("6291041500213") {
////   Ok(country) -> io.println("Country: " <> country)
////   Error(_) -> io.println("Prefix not found")
//// }
//// ```

import gl_gtin/check_digit
import gl_gtin/gs1_prefix

// Re-export the shared public types `GtinFormat` and `GtinError` and bring
// their variant constructors into scope. The types are defined in
// `gl_gtin/gtin_types` so that sub-modules (e.g. `gl_gtin/upc`) can work in
// `GtinError` without importing this facade, which would create a cycle. The
// type aliases below make `gl_gtin.GtinFormat` / `gl_gtin.GtinError` the public
// type names; the variant constructors are owned by `gl_gtin/gtin_types`, so
// consumers import them from there, e.g.
// `import gl_gtin/gtin_types.{Gtin13, InvalidFormat}`.
import gl_gtin/gtin_types.{
  Gtin12, Gtin13, Gtin14, Gtin8, InvalidCharacters, InvalidCheckDigit,
  InvalidFormat, InvalidLength, NoGs1PrefixFound,
}
import gl_gtin/parse as parse_mod
import gl_gtin/upc
import gl_gtin/validation
import gleam/list
import gleam/result

/// Supported GTIN formats based on digit count.
///
/// This is a re-export of `gl_gtin/gtin_types.GtinFormat`. Import the variants
/// from the owning module — `import gl_gtin/gtin_types.{Gtin8, Gtin12, Gtin13,
/// Gtin14}` — to construct or pattern-match on them.
pub type GtinFormat =
  gtin_types.GtinFormat

/// Errors that can occur when working with GTIN codes.
///
/// This is a re-export of `gl_gtin/gtin_types.GtinError`. Import the variants
/// from the owning module — e.g. `import gl_gtin/gtin_types.{InvalidFormat,
/// InvalidLength}` — to construct or pattern-match on them.
pub type GtinError =
  gtin_types.GtinError

/// Structured decomposition of a validated GTIN code.
///
/// This is a re-export of `gl_gtin/parse.GtinInfo`. Import the record
/// constructor from the owning module — `import gl_gtin/parse.{GtinInfo}` — to
/// construct or pattern-match on it.
pub type GtinInfo =
  parse_mod.GtinInfo

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

/// Validate a batch of GTIN code strings, pairing each original input with its
/// validation result.
///
/// Applies `validate` to every element and returns a list of
/// `#(original_code, result)` pairs in the same order as the input. The tuple
/// key is the byte-for-byte original string (untrimmed); duplicates and empty
/// lists are preserved. This helper is total — a malformed element yields an
/// `Error(...)` pair rather than a crash.
///
/// # Examples
///
/// ```gleam
/// validate_all(["6291041500213", "6291041500214"])
/// // -> [#("6291041500213", Ok(Gtin13)), #("6291041500214", Error(InvalidCheckDigit))]
/// ```
pub fn validate_all(
  codes: List(String),
) -> List(#(String, Result(GtinFormat, GtinError))) {
  list.map(codes, fn(code) { #(code, validate(code)) })
}

/// Partition a batch of GTIN code strings into valid and invalid groups.
///
/// Returns a `#(valid, invalid)` 2-tuple: the first list holds every element
/// for which `validate` returns `Ok`, the second holds every element for which
/// it returns `Error`. Each element is stored as the byte-for-byte original
/// string (untrimmed), relative order is preserved within each list, duplicates
/// are kept, and the two lists together contain every input element exactly
/// once. This helper is total — a malformed element is routed to the invalid
/// list rather than causing a crash.
///
/// # Examples
///
/// ```gleam
/// partition(["6291041500213", "6291041500214"])
/// // -> #(["6291041500213"], ["6291041500214"])
/// ```
pub fn partition(codes: List(String)) -> #(List(String), List(String)) {
  list.partition(codes, fn(code) { result.is_ok(validate(code)) })
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
/// // -> Ok("16291041500210")
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

/// Convert a GTIN-13 to GTIN-14 format with an explicit indicator digit.
///
/// Prepends the given indicator digit (0 through 9) and recalculates the check
/// digit. Only works with GTIN-13 codes; other formats or an out-of-range
/// indicator return an error.
///
/// # Examples
///
/// ```gleam
/// normalize_with_indicator("6291041500213", 2)
/// // -> Ok("26291041500217")
///
/// normalize_with_indicator("6291041500213", 10)
/// // -> Error(InvalidFormat)
/// ```
pub fn normalize_with_indicator(
  code: String,
  indicator: Int,
) -> Result(String, GtinError) {
  validation.normalize_with_indicator(code, indicator)
  |> result.map_error(fn(err) {
    case err {
      validation.InvalidLength(got) -> InvalidLength(got)
      validation.InvalidCheckDigit -> InvalidCheckDigit
      validation.InvalidCharacters -> InvalidCharacters
      validation.InvalidFormat -> InvalidFormat
    }
  })
}

/// Convert a GTIN-14 with indicator digit 0 to its base GTIN-13.
///
/// Requires a valid GTIN-14 (14 digits, correct check digit). When the leading
/// indicator digit is 0, the leading `0` is dropped and the existing check
/// digit is preserved, yielding a 13-digit string. A non-zero indicator returns
/// `Error(InvalidFormat)`. Leading and trailing whitespace is trimmed before
/// validation.
///
/// # Examples
///
/// ```gleam
/// to_gtin13("06291041500213")
/// // -> Ok("6291041500213")
///
/// to_gtin13("16291041500210")
/// // -> Error(InvalidFormat)
/// ```
pub fn to_gtin13(code: String) -> Result(String, GtinError) {
  validation.to_gtin13(code)
  |> result.map_error(fn(err) {
    case err {
      validation.InvalidLength(got) -> InvalidLength(got)
      validation.InvalidCheckDigit -> InvalidCheckDigit
      validation.InvalidCharacters -> InvalidCharacters
      validation.InvalidFormat -> InvalidFormat
    }
  })
}

/// Convert a GTIN-14 with indicator digit 0 to its base GTIN-12 (UPC-A).
///
/// Requires a valid GTIN-14 (14 digits, correct check digit) whose base code is
/// a UPC-A padded with an implicit leading zero (both leading digits are 0).
/// When so, both leading zeros are dropped to yield the 12-digit UPC-A,
/// preserving the existing check digit. A non-zero indicator or a base code that
/// cannot be represented as a GTIN-12 returns `Error(InvalidFormat)`. Leading
/// and trailing whitespace is trimmed before validation.
///
/// # Examples
///
/// ```gleam
/// to_gtin12("00042100005264")
/// // -> Ok("042100005264")
///
/// to_gtin12("16291041500210")
/// // -> Error(InvalidFormat)
/// ```
pub fn to_gtin12(code: String) -> Result(String, GtinError) {
  validation.to_gtin12(code)
  |> result.map_error(fn(err) {
    case err {
      validation.InvalidLength(got) -> InvalidLength(got)
      validation.InvalidCheckDigit -> InvalidCheckDigit
      validation.InvalidCharacters -> InvalidCharacters
      validation.InvalidFormat -> InvalidFormat
    }
  })
}

/// Expand a compressed 8-digit UPC-E code to its full 12-digit UPC-A form.
///
/// This is a thin pass-through to `gl_gtin/upc.upce_to_upca`, which already
/// works in the public `GtinError` type. See that module for the full
/// zero-suppression expansion rules and validation ordering.
///
/// # Examples
///
/// ```gleam
/// upce_to_upca("04252614")
/// // -> Ok("042100005264")
///
/// upce_to_upca("24252614")
/// // -> Error(InvalidFormat)
/// ```
pub fn upce_to_upca(code: String) -> Result(String, GtinError) {
  upc.upce_to_upca(code)
}

/// Compress a full 12-digit UPC-A code to its 8-digit UPC-E form when possible.
///
/// This is a thin pass-through to `gl_gtin/upc.upca_to_upce`, which already
/// works in the public `GtinError` type. See that module for the full
/// zero-suppression compression rules and validation ordering.
///
/// # Examples
///
/// ```gleam
/// upca_to_upce("042100005264")
/// // -> Ok("04252614")
///
/// upca_to_upce("012345678905")
/// // -> Error(InvalidFormat)
/// ```
pub fn upca_to_upce(code: String) -> Result(String, GtinError) {
  upc.upca_to_upce(code)
}

/// Decompose a validated GTIN into a structured `GtinInfo` record.
///
/// This is a thin pass-through to `gl_gtin/parse.parse`, which already works in
/// the public `GtinError` type. The input is trimmed and validated first
/// (length, then characters, then check digit); an invalid code returns the
/// corresponding `GtinError` and never a partially populated `GtinInfo`. See
/// that module for the full field-derivation and GS1 company-prefix rules.
///
/// # Examples
///
/// ```gleam
/// parse("6291041500213")
/// // -> Ok(GtinInfo(
/// //   format: Gtin13,
/// //   digits: "6291041500213",
/// //   indicator: Error(Nil),
/// //   gs1_prefix: "629",
/// //   gs1_region: Ok("GS1 Emirates"),
/// //   check_digit: 3,
/// // ))
///
/// parse("invalid")
/// // -> Error(InvalidCharacters)
/// ```
pub fn parse(code: String) -> Result(GtinInfo, GtinError) {
  parse_mod.parse(code)
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
