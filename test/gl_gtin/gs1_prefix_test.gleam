import gleeunit/should
import gl_gtin/gs1_prefix

// Known Prefixes Return Country
//
// For any GTIN with a known GS1 prefix, the lookup function SHALL return Ok 
// with the correct country name.
pub fn known_prefixes_return_country_test() {
  // Test 3-digit prefix
  let assert Ok(country) = gs1_prefix.lookup("6291041500213")
  country |> should.equal("GS1 Emirates")

  // Test 2-digit prefix (US)
  let assert Ok(country) = gs1_prefix.lookup("012345678905")
  country |> should.equal("GS1 US")

  // Test 2-digit prefix (France)
  let assert Ok(country) = gs1_prefix.lookup("301234567890")
  country |> should.equal("GS1 France")

  // Test 2-digit prefix (Germany)
  let assert Ok(country) = gs1_prefix.lookup("401234567890")
  country |> should.equal("GS1 Germany")

  // Test 2-digit prefix (UK)
  let assert Ok(country) = gs1_prefix.lookup("501234567890")
  country |> should.equal("GS1 UK")

  // Test 2-digit prefix (Italy)
  let assert Ok(country) = gs1_prefix.lookup("801234567890")
  country |> should.equal("GS1 Italy")

  // Test 2-digit prefix (Netherlands)
  let assert Ok(country) = gs1_prefix.lookup("901234567890")
  country |> should.equal("GS1 Netherlands")

  // Test special code (Malta)
  let assert Ok(country) = gs1_prefix.lookup("53523235")
  country |> should.equal("GS1 Malta")

  // Test special code (ISBN)
  let assert Ok(country) = gs1_prefix.lookup("978123456789")
  country |> should.equal("ISBN")

  // Test special code (ISSN)
  let assert Ok(country) = gs1_prefix.lookup("977123456789")
  country |> should.equal("Serial publications (ISSN)")
}

// Unknown Prefixes Return Error
//
// For any GTIN with an unknown GS1 prefix, the lookup function SHALL return 
// Error(NoGs1PrefixFound).
pub fn unknown_prefixes_return_error_test() {
  // Test very short code (less than 2 digits)
  let result = gs1_prefix.lookup("1")
  result |> should.be_error()

  // Test empty code
  let result = gs1_prefix.lookup("")
  result |> should.be_error()
}

// Prefix Lookup Checks 3-Digit Before 2-Digit
//
// For any GTIN where both 3-digit and 2-digit prefixes exist in the database, 
// the lookup function SHALL return the result for the 3-digit prefix.
pub fn prefix_lookup_checks_3_digit_before_2_digit_test() {
  // Test that 629 (3-digit) is returned instead of 62 (2-digit)
  // 629 -> GS1 Emirates
  // 62 -> GS1 France
  let assert Ok(country) = gs1_prefix.lookup("6291041500213")
  country |> should.equal("GS1 Emirates")

  // Test that 978 (3-digit) is returned instead of 97 (2-digit)
  // 978 -> ISBN
  // 97 -> Netherlands
  let assert Ok(country) = gs1_prefix.lookup("978123456789")
  country |> should.equal("ISBN")

  // Test that 977 (3-digit) is returned instead of 97 (2-digit)
  // 977 -> Serial publications (ISSN)
  // 97 -> Netherlands
  let assert Ok(country) = gs1_prefix.lookup("977123456789")
  country |> should.equal("Serial publications (ISSN)")
}

// Comprehensive GS1 Prefix Lookup Tests
//
// Tests for all major GS1 prefixes to ensure complete coverage
pub fn comprehensive_gs1_prefix_lookup_test() {
  // US prefixes (00-09)
  let assert Ok(country) = gs1_prefix.lookup("001234567890")
  country |> should.equal("GS1 US")

  let assert Ok(country) = gs1_prefix.lookup("091234567890")
  country |> should.equal("GS1 US")

  // France prefixes (30-39, 60-69)
  let assert Ok(country) = gs1_prefix.lookup("301234567890")
  country |> should.equal("GS1 France")

  let assert Ok(country) = gs1_prefix.lookup("601234567890")
  country |> should.equal("GS1 France")

  // Germany prefixes (40-49)
  let assert Ok(country) = gs1_prefix.lookup("401234567890")
  country |> should.equal("GS1 Germany")

  let assert Ok(country) = gs1_prefix.lookup("491234567890")
  country |> should.equal("GS1 Germany")

  // UK prefixes (50-59)
  let assert Ok(country) = gs1_prefix.lookup("501234567890")
  country |> should.equal("GS1 UK")

  let assert Ok(country) = gs1_prefix.lookup("591234567890")
  country |> should.equal("GS1 UK")

  // Italy prefixes (80-89)
  let assert Ok(country) = gs1_prefix.lookup("801234567890")
  country |> should.equal("GS1 Italy")

  let assert Ok(country) = gs1_prefix.lookup("891234567890")
  country |> should.equal("GS1 Italy")

  // Netherlands prefixes (90-99)
  let assert Ok(country) = gs1_prefix.lookup("901234567890")
  country |> should.equal("GS1 Netherlands")

  let assert Ok(country) = gs1_prefix.lookup("991234567890")
  country |> should.equal("GS1 Netherlands")

  // Norway prefixes (70-79)
  let assert Ok(country) = gs1_prefix.lookup("701234567890")
  country |> should.equal("GS1 Norway")

  let assert Ok(country) = gs1_prefix.lookup("791234567890")
  country |> should.equal("GS1 Norway")

  // Special prefixes
  let assert Ok(country) = gs1_prefix.lookup("978123456789")
  country |> should.equal("ISBN")

  let assert Ok(country) = gs1_prefix.lookup("979123456789")
  country |> should.equal("ISBN")

  let assert Ok(country) = gs1_prefix.lookup("977123456789")
  country |> should.equal("Serial publications (ISSN)")

  let assert Ok(country) = gs1_prefix.lookup("535123456789")
  country |> should.equal("GS1 Malta")
}

// Edge Cases for Prefix Lookup
//
// Tests for edge cases like very short codes and special formats
pub fn edge_cases_for_prefix_lookup_test() {
  // Single digit code
  let result = gs1_prefix.lookup("1")
  result |> should.be_error()

  // Empty code
  let result = gs1_prefix.lookup("")
  result |> should.be_error()

  // Very long code (should still work with first digits)
  let assert Ok(country) = gs1_prefix.lookup("6291041500213999999999")
  country |> should.equal("GS1 Emirates")

  // Code with leading zeros
  let assert Ok(country) = gs1_prefix.lookup("001234567890")
  country |> should.equal("GS1 US")

  // Minimum valid length (2 digits for 2-digit prefix)
  let assert Ok(country) = gs1_prefix.lookup("001234567890")
  country |> should.equal("GS1 US")
}
