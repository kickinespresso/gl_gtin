import gleam/list
import gleeunit/should
import gl_gtin/internal/utils

// Tests for last_digit function
pub fn last_digit_single_element_test() {
  utils.last_digit([5])
  |> should.equal(5)
}

pub fn last_digit_multiple_elements_test() {
  utils.last_digit([1, 2, 3, 4, 5])
  |> should.equal(5)
}

pub fn last_digit_two_elements_test() {
  utils.last_digit([9, 8])
  |> should.equal(8)
}

pub fn last_digit_empty_list_test() {
  utils.last_digit([])
  |> should.equal(0)
}

pub fn last_digit_large_list_test() {
  utils.last_digit([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
  |> should.equal(0)
}

// Tests for parse_digit function
pub fn parse_digit_zero_test() {
  utils.parse_digit("0")
  |> should.equal(Ok(0))
}

pub fn parse_digit_five_test() {
  utils.parse_digit("5")
  |> should.equal(Ok(5))
}

pub fn parse_digit_nine_test() {
  utils.parse_digit("9")
  |> should.equal(Ok(9))
}

pub fn parse_digit_all_digits_test() {
  let digits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
  let expected = [
    Ok(0),
    Ok(1),
    Ok(2),
    Ok(3),
    Ok(4),
    Ok(5),
    Ok(6),
    Ok(7),
    Ok(8),
    Ok(9),
  ]

  list.map(digits, utils.parse_digit)
  |> should.equal(expected)
}

pub fn parse_digit_letter_test() {
  utils.parse_digit("a")
  |> should.equal(Error(Nil))
}

pub fn parse_digit_special_char_test() {
  utils.parse_digit("!")
  |> should.equal(Error(Nil))
}

pub fn parse_digit_space_test() {
  utils.parse_digit(" ")
  |> should.equal(Error(Nil))
}

pub fn parse_digit_empty_string_test() {
  utils.parse_digit("")
  |> should.equal(Error(Nil))
}
