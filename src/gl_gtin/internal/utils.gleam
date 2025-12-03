//// Internal utility functions for the GTIN library.
//// These functions are not part of the public API.

/// Extract the last digit from a list of integers.
///
/// Returns the last element if the list is non-empty, otherwise returns 0.
///
/// # Examples
///
/// ```gleam
/// last_digit([1, 2, 3])
/// // -> 3
///
/// last_digit([])
/// // -> 0
/// ```
pub fn last_digit(digits: List(Int)) -> Int {
  case digits {
    [] -> 0
    [last] -> last
    [_, ..rest] -> last_digit(rest)
  }
}

/// Parse a single character to an integer digit.
///
/// Returns Ok(digit) if the character is a digit (0-9), otherwise returns Error.
///
/// # Examples
///
/// ```gleam
/// parse_digit("5")
/// // -> Ok(5)
///
/// parse_digit("a")
/// // -> Error(InvalidCharacters)
/// ```
pub fn parse_digit(char: String) -> Result(Int, Nil) {
  case char {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    _ -> Error(Nil)
  }
}
