//// GS1 prefix lookup module for GTIN codes.
////
//// Provides country/region lookup based on GS1 prefix codes.
////
//// The lookup parses the first three digits of a format-normalized 13-digit
//// basis as an integer and matches it against GS1's real 3-digit allocation
//// ranges (ported from the `ex_gtin` `lookup_gs1_prefix/1` table).
////
//// ## Input length leniency
////
//// `lookup` is intentionally lenient about total input length. It does not
//// enforce a strict GTIN length (8/12/13/14); instead it guards only that the
//// normalized basis has at least three characters (`>= 3`). Shorter input
//// yields `Error(NoGs1PrefixFound)`, and extra trailing characters are
//// ignored. A stricter length check is deliberately out of scope to avoid a
//// second breaking change to the error surface.
////
//// ## GTIN-8 limitation
////
//// A GTIN-8 is used as-is for the prefix basis, so it reads its own leading
//// digits against the GTIN-13 range table. This module does NOT implement true
//// GS1-8 semantics; the result for a GTIN-8 reflects the GTIN-13 table lookup
//// rather than a dedicated GS1-8 allocation.

import gleam/int
import gleam/string

/// Error type for prefix lookup operations
pub type PrefixError {
  NoGs1PrefixFound
}

/// Normalize a GTIN string to its 13-digit prefix basis based on length.
///
/// The first three characters of the returned basis are the true GS1 prefix.
///
/// - Length 12 (UPC-A): prepend the implicit leading zero (`"0" <> code`).
/// - Length 14 (ITF-14): drop the leading GTIN-14 indicator digit.
/// - Otherwise (GTIN-8 / GTIN-13): use the code as-is.
fn normalized_prefix_digits(code: String) -> String {
  case string.length(code) {
    12 -> "0" <> code
    14 -> string.slice(code, 1, 13)
    _ -> code
  }
}

/// Map a 3-digit integer prefix to a GS1 country/region.
///
/// Ported from the `ex_gtin` `lookup_gs1_prefix/1` allocation table
/// (GS1 reference: https://www.gs1.org/company-prefix). Prefixes that map to
/// no GS1 allocation return `Error(NoGs1PrefixFound)`.
fn region(n: Int) -> Result(String, PrefixError) {
  case n {
    _ if n >= 1 && n <= 19 -> Ok("GS1 US")
    _ if n >= 30 && n <= 39 -> Ok("GS1 US")
    _ if n >= 50 && n <= 59 -> Ok("GS1 US")
    _ if n >= 60 && n <= 99 -> Ok("GS1 US")
    _ if n >= 100 && n <= 139 -> Ok("GS1 US")
    _ if n >= 20 && n <= 29 ->
      Ok(
        "Used to issue restricted circulation numbers within a geographic region (MO defined)",
      )
    _ if n >= 40 && n <= 49 ->
      Ok("Used to issue GS1 restricted circulation numbers within a company")
    _ if n >= 200 && n <= 299 ->
      Ok(
        "Used to issue GS1 restricted circulation number within a geographic region (MO defined)",
      )
    _ if n >= 300 && n <= 379 -> Ok("GS1 France")
    380 -> Ok("GS1 Bulgaria")
    383 -> Ok("GS1 Slovenija")
    385 -> Ok("GS1 Croatia")
    387 -> Ok("GS1 BIH (Bosnia-Herzegovina)")
    389 -> Ok("GS1 Montenegro")
    _ if n >= 400 && n <= 440 -> Ok("GS1 Germany")
    _ if n >= 450 && n <= 459 -> Ok("GS1 Japan")
    _ if n >= 490 && n <= 499 -> Ok("GS1 Japan")
    _ if n >= 460 && n <= 469 -> Ok("GS1 Russia")
    470 -> Ok("GS1 Kyrgyzstan")
    471 -> Ok("GS1 Taiwan")
    474 -> Ok("GS1 Estonia")
    475 -> Ok("GS1 Latvia")
    476 -> Ok("GS1 Azerbaijan")
    477 -> Ok("GS1 Lithuania")
    478 -> Ok("GS1 Uzbekistan")
    479 -> Ok("GS1 Sri Lanka")
    480 -> Ok("GS1 Philippines")
    481 -> Ok("GS1 Belarus")
    482 -> Ok("GS1 Ukraine")
    483 -> Ok("GS1 Turkmenistan")
    484 -> Ok("GS1 Moldova")
    485 -> Ok("GS1 Armenia")
    486 -> Ok("GS1 Georgia")
    487 -> Ok("GS1 Kazakstan")
    488 -> Ok("GS1 Tajikistan")
    489 -> Ok("GS1 Hong Kong")
    _ if n >= 500 && n <= 509 -> Ok("GS1 UK")
    _ if n >= 520 && n <= 521 -> Ok("GS1 Association Greece")
    528 -> Ok("GS1 Lebanon")
    529 -> Ok("GS1 Cyprus")
    530 -> Ok("GS1 Albania")
    531 -> Ok("GS1 Macedonia")
    535 -> Ok("GS1 Malta")
    539 -> Ok("GS1 Ireland")
    _ if n >= 540 && n <= 549 -> Ok("GS1 Belgium & Luxembourg")
    560 -> Ok("GS1 Portugal")
    569 -> Ok("GS1 Iceland")
    _ if n >= 570 && n <= 579 -> Ok("GS1 Denmark")
    590 -> Ok("GS1 Poland")
    594 -> Ok("GS1 Romania")
    599 -> Ok("GS1 Hungary")
    _ if n >= 600 && n <= 601 -> Ok("GS1 South Africa")
    603 -> Ok("GS1 Ghana")
    604 -> Ok("GS1 Senegal")
    608 -> Ok("GS1 Bahrain")
    609 -> Ok("GS1 Mauritius")
    611 -> Ok("GS1 Morocco")
    613 -> Ok("GS1 Algeria")
    615 -> Ok("GS1 Nigeria")
    616 -> Ok("GS1 Kenya")
    618 -> Ok("GS1 Ivory Coast")
    619 -> Ok("GS1 Tunisia")
    620 -> Ok("GS1 Tanzania")
    621 -> Ok("GS1 Syria")
    622 -> Ok("GS1 Egypt")
    623 -> Ok("GS1 Brunei")
    624 -> Ok("GS1 Libya")
    625 -> Ok("GS1 Jordan")
    626 -> Ok("GS1 Iran")
    627 -> Ok("GS1 Kuwait")
    628 -> Ok("GS1 Saudi Arabia")
    629 -> Ok("GS1 Emirates")
    _ if n >= 640 && n <= 649 -> Ok("GS1 Finland")
    _ if n >= 690 && n <= 699 -> Ok("GS1 China")
    _ if n >= 700 && n <= 709 -> Ok("GS1 Norway")
    729 -> Ok("GS1 Israel")
    _ if n >= 730 && n <= 739 -> Ok("GS1 Sweden")
    740 -> Ok("GS1 Guatemala")
    741 -> Ok("GS1 El Salvador")
    742 -> Ok("GS1 Honduras")
    743 -> Ok("GS1 Nicaragua")
    744 -> Ok("GS1 Costa Rica")
    745 -> Ok("GS1 Panama")
    746 -> Ok("GS1 Republica Dominicana")
    750 -> Ok("GS1 Mexico")
    _ if n >= 754 && n <= 755 -> Ok("GS1 Canada")
    759 -> Ok("GS1 Venezuela")
    _ if n >= 760 && n <= 769 -> Ok("GS1 Schweiz, Suisse, Svizzera")
    _ if n >= 770 && n <= 771 -> Ok("GS1 Colombia")
    773 -> Ok("GS1 Uruguay")
    775 -> Ok("GS1 Peru")
    777 -> Ok("GS1 Bolivia")
    _ if n >= 778 && n <= 779 -> Ok("GS1 Argentina")
    780 -> Ok("GS1 Chile")
    784 -> Ok("GS1 Paraguay")
    786 -> Ok("GS1 Ecuador")
    _ if n >= 789 && n <= 790 -> Ok("GS1 Brasil")
    _ if n >= 800 && n <= 839 -> Ok("GS1 Italy")
    _ if n >= 840 && n <= 849 -> Ok("GS1 Spain")
    850 -> Ok("GS1 Cuba")
    858 -> Ok("GS1 Slovakia")
    859 -> Ok("GS1 Czech")
    860 -> Ok("GS1 Serbia")
    865 -> Ok("GS1 Mongolia")
    867 -> Ok("GS1 North Korea")
    _ if n >= 868 && n <= 869 -> Ok("GS1 Turkey")
    _ if n >= 870 && n <= 879 -> Ok("GS1 Netherlands")
    880 -> Ok("GS1 South Korea")
    884 -> Ok("GS1 Cambodia")
    885 -> Ok("GS1 Thailand")
    888 -> Ok("GS1 Singapore")
    890 -> Ok("GS1 India")
    893 -> Ok("GS1 Vietnam")
    896 -> Ok("GS1 Pakistan")
    899 -> Ok("GS1 Indonesia")
    _ if n >= 900 && n <= 919 -> Ok("GS1 Austria")
    _ if n >= 930 && n <= 939 -> Ok("GS1 Australia")
    _ if n >= 940 && n <= 949 -> Ok("GS1 New Zealand")
    950 -> Ok("GS1 Global Office")
    951 ->
      Ok(
        "Used to issue General Manager Numbers for the EPC General Identifier (GID) scheme as defined by the EPC Tag Data Standard*",
      )
    955 -> Ok("GS1 Malaysia")
    958 -> Ok("GS1 Macau")
    _ if n >= 960 && n <= 969 -> Ok("Global Office (GTIN-8s)*")
    977 -> Ok("Serial publications (ISSN)")
    _ if n >= 978 && n <= 979 -> Ok("Bookland (ISBN)")
    980 -> Ok("Refund receipts")
    _ if n >= 981 && n <= 984 ->
      Ok("GS1 coupon identification for common currency areas")
    _ if n >= 990 && n <= 999 -> Ok("GS1 coupon identification")
    _ -> Error(NoGs1PrefixFound)
  }
}

/// Look up the country of origin from a GTIN code's GS1 prefix.
///
/// Computes the format-normalized 13-digit basis, then parses its first three
/// digits as an integer and matches GS1's real 3-digit allocation ranges.
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
/// lookup("8711111111116")
/// // -> Ok("GS1 Netherlands")
///
/// lookup("999999999999")
/// // -> Error(NoGs1PrefixFound)
/// ```
pub fn lookup(code: String) -> Result(String, PrefixError) {
  let basis = normalized_prefix_digits(code)
  case string.length(basis) >= 3 {
    False -> Error(NoGs1PrefixFound)
    True ->
      case int.parse(string.slice(basis, 0, 3)) {
        Error(_) -> Error(NoGs1PrefixFound)
        Ok(n) -> region(n)
      }
  }
}
