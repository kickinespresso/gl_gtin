//// Structured GTIN parsing module (F4).
////
//// Decomposes a validated GTIN string into a structured `GtinInfo` record
//// exposing the detected format, the trimmed digits, the packaging-level
//// indicator (for GTIN-14), the GS1 prefix, the GS1 prefix region, and the
//// check digit. It composes the shared subsystems — `validation` for the
//// length/character/check-digit gate, `gs1_prefix` for the region lookup, and
//// `internal/utils` for digit parsing — and works directly in the public
//// `GtinError` type.
////
//// ## GS1 company-prefix limitation
////
//// The length of the GS1 company prefix within a GTIN is assigned per licensee
//// and is NOT derivable offline from the digits alone (it requires a GEPIR /
//// GS1 registry lookup). This module therefore does not attempt to split the
//// code into company prefix and item reference. Only the GS1 *prefix region*
//// (derived from the leading three digits of the format-normalized 13-digit
//// basis) is exposed, via `gs1_region`. That region is derived solely from the
//// `gs1_prefix` subsystem; this module does not read or reimplement the prefix
//// allocation table.

import gl_gtin/gs1_prefix
import gl_gtin/gtin_types.{
  type GtinError, type GtinFormat, Gtin12, Gtin13, Gtin14, Gtin8,
  InvalidCharacters, InvalidCheckDigit, InvalidFormat, InvalidLength,
  NoGs1PrefixFound,
}
import gl_gtin/internal/utils
import gl_gtin/validation
import gleam/string

/// Structured decomposition of a validated GTIN code.
///
/// Every field is populated only after the input passes validation, so a
/// `GtinInfo` value always describes a well-formed GTIN.
///
/// * `format` - the GTIN format inferred from the trimmed digit count.
/// * `digits` - the trimmed input string.
/// * `indicator` - `Ok(n)` with the leading indicator digit for a GTIN-14,
///   `Error(Nil)` for every other format.
/// * `gs1_prefix` - the leading three characters of the format-normalized
///   13-digit basis (the true GS1 prefix).
/// * `gs1_region` - the GS1 prefix region from the prefix subsystem, `Ok(name)`
///   on a hit or `Error(NoGs1PrefixFound)` when the prefix has no allocation.
/// * `check_digit` - the integer value of the trimmed code's final digit.
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

/// Decompose a validated GTIN into a structured `GtinInfo` record.
///
/// The input is trimmed and validated first (length, then characters, then
/// check digit). An invalid code returns the corresponding `GtinError`
/// (`InvalidLength`, `InvalidCharacters`, or `InvalidCheckDigit`) and never a
/// partially populated `GtinInfo`. On success every field of the record is
/// populated from the trimmed input.
///
/// The GS1 company-prefix length is not derivable offline; only the GS1 prefix
/// region is exposed, and it is derived solely from the `gs1_prefix` subsystem.
///
/// # Arguments
///
/// * `code` - The GTIN string to parse (leading/trailing whitespace is trimmed)
///
/// # Returns
///
/// Ok(GtinInfo) with every field populated if the code is a valid GTIN,
/// Error(InvalidLength(got: n)) if the trimmed digit count is not 8/12/13/14,
/// Error(InvalidCharacters) if any character is non-numeric,
/// Error(InvalidCheckDigit) if the check digit does not match.
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
  // Trim once; validation and every field derive from the trimmed value.
  let trimmed = string.trim(code)

  // Validate first: an invalid code yields an Error and never a GtinInfo.
  case validation.validate(trimmed) {
    Error(error) -> Error(map_validation_error(error))
    Ok(validation_format) -> {
      let format = map_format(validation_format)
      let basis = normalized_basis(trimmed, format)
      Ok(GtinInfo(
        format: format,
        digits: trimmed,
        indicator: indicator_for(trimmed, format),
        gs1_prefix: string.slice(basis, 0, 3),
        gs1_region: map_prefix_lookup(gs1_prefix.lookup(trimmed)),
        check_digit: final_digit(trimmed),
      ))
    }
  }
}

/// Compute the format-normalized 13-digit basis whose leading three characters
/// are the true GS1 prefix.
///
/// This mirrors `gs1_prefix`'s own normalization rule: a GTIN-12 is padded with
/// an implicit leading zero, a GTIN-14 has its leading indicator digit dropped,
/// and every other format is used as-is.
fn normalized_basis(code: String, format: GtinFormat) -> String {
  case format {
    Gtin12 -> "0" <> code
    Gtin14 -> string.slice(code, 1, 13)
    _ -> code
  }
}

/// Determine the indicator field for a trimmed code and its format.
///
/// A GTIN-14 carries a leading packaging-level indicator digit, returned as
/// `Ok(n)`. Every other format has no indicator, so `Error(Nil)` is returned.
fn indicator_for(code: String, format: GtinFormat) -> Result(Int, Nil) {
  case format {
    Gtin14 -> utils.parse_digit(string.slice(code, 0, 1))
    _ -> Error(Nil)
  }
}

/// Extract the integer value of a trimmed code's final digit.
///
/// The code has already passed validation, so its final character is a digit;
/// a non-digit (which cannot occur here) falls back to 0 to keep the function
/// total.
fn final_digit(code: String) -> Int {
  case utils.parse_digit(string.slice(code, string.length(code) - 1, 1)) {
    Ok(digit) -> digit
    Error(_) -> 0
  }
}

/// Map a `validation.GtinFormat` to the public `gtin_types.GtinFormat`.
fn map_format(format: validation.GtinFormat) -> GtinFormat {
  case format {
    validation.Gtin8 -> Gtin8
    validation.Gtin12 -> Gtin12
    validation.Gtin13 -> Gtin13
    validation.Gtin14 -> Gtin14
  }
}

/// Map a `validation.ValidationError` to the public `GtinError`.
fn map_validation_error(error: validation.ValidationError) -> GtinError {
  case error {
    validation.InvalidLength(got) -> InvalidLength(got)
    validation.InvalidCheckDigit -> InvalidCheckDigit
    validation.InvalidCharacters -> InvalidCharacters
    validation.InvalidFormat -> InvalidFormat
  }
}

/// Map a `gs1_prefix` lookup result to the public `GtinError` on the error side.
fn map_prefix_lookup(
  result: Result(String, gs1_prefix.PrefixError),
) -> Result(String, GtinError) {
  case result {
    Ok(region) -> Ok(region)
    Error(gs1_prefix.NoGs1PrefixFound) -> Error(NoGs1PrefixFound)
  }
}
