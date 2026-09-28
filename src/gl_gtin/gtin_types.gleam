//// Shared public GTIN types.
////
//// This module defines the public `GtinError` and `GtinFormat` types in a
//// location that does NOT import the root `gl_gtin` facade. Both the facade
//// (`gl_gtin`) and the sub-modules that already work in `GtinError`
//// (e.g. `gl_gtin/upc`) import these types from here, which breaks what would
//// otherwise be an import cycle (`gl_gtin` → `gl_gtin/upc` → `gl_gtin`).
////
//// The root `gl_gtin` module re-exports these types via type aliases
//// (`gl_gtin.GtinError`, `gl_gtin.GtinFormat`) so the public type names are
//// unchanged. The variant constructors are owned by this module, so consumers
//// import them from here, e.g. `import gl_gtin/gtin_types.{Gtin13, InvalidFormat}`.

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
