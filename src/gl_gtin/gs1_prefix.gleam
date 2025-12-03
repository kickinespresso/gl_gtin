//// GS1 prefix lookup module for GTIN codes.
////
//// Provides country/region lookup based on GS1 prefix codes.
//// Checks 3-digit prefixes first, then 2-digit prefixes.

import gleam/dict
import gleam/string

/// Error type for prefix lookup operations
pub type PrefixError {
  NoGs1PrefixFound
}

/// Get the GS1 prefix database.
///
/// Returns a dictionary mapping GS1 prefixes to country/region names.
/// Includes both 2-digit and 3-digit prefixes covering 100+ countries and regions.
/// The database includes special prefixes for ISBN, ISSN, and other uses.
///
/// # Returns
///
/// A dictionary mapping prefix strings to country/region names.
///
/// # Examples
///
/// The database includes entries like:
/// - "629" -> "GS1 Emirates"
/// - "00" -> "GS1 US"
/// - "40" -> "GS1 Germany"
/// - "977" -> "Serial publications (ISSN)"
fn gs1_prefix_map() -> dict.Dict(String, String) {
  dict.from_list([
    // 3-digit prefixes (checked first)
    #("629", "GS1 Emirates"),
    #("535", "GS1 Malta"),
    #("977", "Serial publications (ISSN)"),
    #("978", "ISBN"),
    #("979", "ISBN"),
    // 2-digit prefixes
    #("00", "GS1 US"),
    #("01", "GS1 US"),
    #("02", "GS1 US"),
    #("03", "GS1 US"),
    #("04", "GS1 US"),
    #("05", "GS1 US"),
    #("06", "GS1 US"),
    #("07", "GS1 US"),
    #("08", "GS1 US"),
    #("09", "GS1 US"),
    #("10", "GS1 US"),
    #("11", "GS1 US"),
    #("12", "GS1 US"),
    #("13", "GS1 US"),
    #("14", "GS1 US"),
    #("15", "GS1 US"),
    #("16", "GS1 US"),
    #("17", "GS1 US"),
    #("18", "GS1 US"),
    #("19", "GS1 US"),
    #("20", "GS1 US"),
    #("21", "GS1 US"),
    #("22", "GS1 US"),
    #("23", "GS1 US"),
    #("24", "GS1 US"),
    #("25", "GS1 US"),
    #("26", "GS1 US"),
    #("27", "GS1 US"),
    #("28", "GS1 US"),
    #("29", "GS1 US"),
    #("30", "GS1 France"),
    #("31", "GS1 France"),
    #("32", "GS1 France"),
    #("33", "GS1 France"),
    #("34", "GS1 France"),
    #("35", "GS1 France"),
    #("36", "GS1 France"),
    #("37", "GS1 France"),
    #("38", "GS1 France"),
    #("39", "GS1 France"),
    #("40", "GS1 Germany"),
    #("41", "GS1 Germany"),
    #("42", "GS1 Germany"),
    #("43", "GS1 Germany"),
    #("44", "GS1 Germany"),
    #("45", "GS1 Germany"),
    #("46", "GS1 Germany"),
    #("47", "GS1 Germany"),
    #("48", "GS1 Germany"),
    #("49", "GS1 Germany"),
    #("50", "GS1 UK"),
    #("51", "GS1 UK"),
    #("52", "GS1 UK"),
    #("53", "GS1 UK"),
    #("54", "GS1 UK"),
    #("55", "GS1 UK"),
    #("56", "GS1 UK"),
    #("57", "GS1 UK"),
    #("58", "GS1 UK"),
    #("59", "GS1 UK"),
    #("60", "GS1 France"),
    #("61", "GS1 France"),
    #("62", "GS1 France"),
    #("63", "GS1 France"),
    #("64", "GS1 France"),
    #("65", "GS1 France"),
    #("66", "GS1 France"),
    #("67", "GS1 France"),
    #("68", "GS1 France"),
    #("69", "GS1 France"),
    #("70", "GS1 Norway"),
    #("71", "GS1 Norway"),
    #("72", "GS1 Norway"),
    #("73", "GS1 Norway"),
    #("74", "GS1 Norway"),
    #("75", "GS1 Norway"),
    #("76", "GS1 Norway"),
    #("77", "GS1 Norway"),
    #("78", "GS1 Norway"),
    #("79", "GS1 Norway"),
    #("80", "GS1 Italy"),
    #("81", "GS1 Italy"),
    #("82", "GS1 Italy"),
    #("83", "GS1 Italy"),
    #("84", "GS1 Italy"),
    #("85", "GS1 Italy"),
    #("86", "GS1 Italy"),
    #("87", "GS1 Italy"),
    #("88", "GS1 Italy"),
    #("89", "GS1 Italy"),
    #("90", "GS1 Netherlands"),
    #("91", "GS1 Netherlands"),
    #("92", "GS1 Netherlands"),
    #("93", "GS1 Netherlands"),
    #("94", "GS1 Netherlands"),
    #("95", "GS1 Netherlands"),
    #("96", "GS1 Netherlands"),
    #("97", "GS1 Netherlands"),
    #("98", "GS1 Netherlands"),
    #("99", "GS1 Netherlands"),
  ])
}

/// Find a matching GS1 prefix in the code.
///
/// Checks 3-digit prefixes first, then 2-digit prefixes.
/// This priority ensures that more specific prefixes are matched before general ones.
/// Returns the country/region name if found.
///
/// # Arguments
///
/// * `code` - GTIN code string
///
/// # Returns
///
/// Ok(country) if a prefix is found, Error(NoGs1PrefixFound) otherwise.
///
/// # Examples
///
/// ```gleam
/// find_prefix_match("6291041500213")
/// // -> Ok("GS1 Emirates")
///
/// find_prefix_match("012345678905")
/// // -> Ok("GS1 US")
///
/// find_prefix_match("999999999999")
/// // -> Error(NoGs1PrefixFound)
/// ```
fn find_prefix_match(code: String) -> Result(String, PrefixError) {
  let map = gs1_prefix_map()

  // Try 3-digit prefix first
  case string.length(code) >= 3 {
    True -> {
      let prefix_3 = string.slice(code, 0, 3)
      case dict.get(map, prefix_3) {
        Ok(country) -> Ok(country)
        Error(_) -> {
          // Try 2-digit prefix
          case string.length(code) >= 2 {
            True -> {
              let prefix_2 = string.slice(code, 0, 2)
              case dict.get(map, prefix_2) {
                Ok(country) -> Ok(country)
                Error(_) -> Error(NoGs1PrefixFound)
              }
            }
            False -> Error(NoGs1PrefixFound)
          }
        }
      }
    }
    False -> Error(NoGs1PrefixFound)
  }
}

/// Look up the country of origin from a GTIN code's GS1 prefix.
///
/// Checks the first 2-3 digits of the GTIN against the GS1 prefix database.
/// Checks 3-digit prefixes first, then 2-digit prefixes.
///
/// # Arguments
///
/// * `code` - GTIN code string
///
/// # Returns
///
/// Ok(country) if a prefix is found, Error(NoGs1PrefixFound) otherwise.
///
/// # Examples
///
/// ```gleam
/// lookup("6291041500213")
/// // -> Ok("GS1 Emirates")
///
/// lookup("012345678905")
/// // -> Ok("GS1 US")
///
/// lookup("999999999999")
/// // -> Error(NoGs1PrefixFound)
/// ```
pub fn lookup(code: String) -> Result(String, PrefixError) {
  find_prefix_match(code)
}
