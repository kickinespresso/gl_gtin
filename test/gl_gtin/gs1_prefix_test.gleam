import gl_gtin/gs1_prefix
import gleeunit/should

// Real GS1 3-digit range lookups
//
// For a GTIN whose first three digits fall in a real GS1 allocation range, the
// lookup function SHALL return Ok with the correct country/region. These use
// 13-digit inputs so the first three characters ARE the prefix (no "0" prepend
// as with length-12, no indicator drop as with length-14). The check digit is
// not validated by lookup, so any 13-digit string with the right prefix works.
pub fn real_gs1_ranges_return_country_test() {
  // France 300-379 (boundaries)
  let assert Ok(country) = gs1_prefix.lookup("3001234567890")
  country |> should.equal("GS1 France")

  let assert Ok(country) = gs1_prefix.lookup("3791234567890")
  country |> should.equal("GS1 France")

  // Germany 400-440 (boundaries)
  let assert Ok(country) = gs1_prefix.lookup("4001234567890")
  country |> should.equal("GS1 Germany")

  let assert Ok(country) = gs1_prefix.lookup("4401234567890")
  country |> should.equal("GS1 Germany")

  // China 690-699 (boundaries)
  let assert Ok(country) = gs1_prefix.lookup("6901234567890")
  country |> should.equal("GS1 China")

  let assert Ok(country) = gs1_prefix.lookup("6991234567890")
  country |> should.equal("GS1 China")

  // Netherlands 870-879 (boundaries)
  let assert Ok(country) = gs1_prefix.lookup("8701234567890")
  country |> should.equal("GS1 Netherlands")

  let assert Ok(country) = gs1_prefix.lookup("8791234567890")
  country |> should.equal("GS1 Netherlands")

  // Austria 900-919 (boundaries)
  let assert Ok(country) = gs1_prefix.lookup("9001234567890")
  country |> should.equal("GS1 Austria")

  let assert Ok(country) = gs1_prefix.lookup("9191234567890")
  country |> should.equal("GS1 Austria")
}

// Single-prefix and special allocations
//
// For prefixes allocated to a single value (not a range), the lookup function
// SHALL return the correct label from the real GS1 table.
pub fn single_prefix_allocations_test() {
  // Malta 535
  let assert Ok(country) = gs1_prefix.lookup("5350000000006")
  country |> should.equal("GS1 Malta")

  // Emirates 629
  let assert Ok(country) = gs1_prefix.lookup("6291041500213")
  country |> should.equal("GS1 Emirates")

  // Serial publications (ISSN) 977
  let assert Ok(country) = gs1_prefix.lookup("9771234567890")
  country |> should.equal("Serial publications (ISSN)")

  // Bookland (ISBN) 978-979
  let assert Ok(country) = gs1_prefix.lookup("9781234567890")
  country |> should.equal("Bookland (ISBN)")
}

// Unassigned / unknown prefixes return error
//
// For a GTIN whose 3-digit prefix maps to no GS1 allocation, and for input too
// short to yield a prefix, the lookup function SHALL return
// Error(NoGs1PrefixFound).
pub fn unassigned_prefixes_return_error_test() {
  // Prefix 150 falls in the unassigned 140-199 gap
  let result = gs1_prefix.lookup("1501234567890")
  result |> should.be_error()

  // Very short code (fewer than 3 usable prefix digits)
  let result = gs1_prefix.lookup("1")
  result |> should.be_error()

  // Empty code
  let result = gs1_prefix.lookup("")
  result |> should.be_error()
}
