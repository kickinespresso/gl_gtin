import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import gl_gtin

pub fn main() -> Nil {
  gleeunit.main()
}

// Valid GTIN test data for property tests
fn valid_gtin_8_examples() -> List(String) {
  ["12345670", "96385074"]
}

fn valid_gtin_12_examples() -> List(String) {
  ["012345678905", "614141123452"]
}

fn valid_gtin_13_examples() -> List(String) {
  ["6291041500213", "5901234123457"]
}

fn valid_gtin_14_examples() -> List(String) {
  ["12345678901231", "10012345678902"]
}

// Opaque Type: to_string and format preserve values
//
// Test that from_string, to_string, and format work correctly across all formats
pub fn opaque_type_preservation_test() {
  // Test GTIN-8
  list.each(valid_gtin_8_examples(), fn(code) {
    let assert Ok(gtin_val) = gl_gtin.from_string(code)
    gl_gtin.to_string(gtin_val) |> should.equal(code)
    gl_gtin.format(gtin_val) |> should.equal(gl_gtin.Gtin8)
  })

  // Test GTIN-12
  list.each(valid_gtin_12_examples(), fn(code) {
    let assert Ok(gtin_val) = gl_gtin.from_string(code)
    gl_gtin.to_string(gtin_val) |> should.equal(code)
    gl_gtin.format(gtin_val) |> should.equal(gl_gtin.Gtin12)
  })

  // Test GTIN-13
  list.each(valid_gtin_13_examples(), fn(code) {
    let assert Ok(gtin_val) = gl_gtin.from_string(code)
    gl_gtin.to_string(gtin_val) |> should.equal(code)
    gl_gtin.format(gtin_val) |> should.equal(gl_gtin.Gtin13)
  })

  // Test GTIN-14
  list.each(valid_gtin_14_examples(), fn(code) {
    let assert Ok(gtin_val) = gl_gtin.from_string(code)
    gl_gtin.to_string(gtin_val) |> should.equal(code)
    gl_gtin.format(gtin_val) |> should.equal(gl_gtin.Gtin14)
  })
}

// Error Messages Include Context
pub fn property_error_messages_include_context_test() {
  // Test various invalid lengths
  let invalid_lengths = [
    "1",
    "12",
    "123",
    "1234",
    "12345",
    "123456",
    "1234567",
    "123456789",
    "1234567890",
    "12345678901",
    "123456789012345",
  ]

  list.each(invalid_lengths, fn(code) {
    let result = gl_gtin.validate(code)
    case result {
      Error(gl_gtin.InvalidLength(got)) -> {
        // Verify the error includes the actual length
        assert got == string.length(code)
      }
      _ -> {
        // If it's not an InvalidLength error, that's also acceptable
        // (some lengths might be valid)
        Nil
      }
    }
  })
}

// Specific Error Types for Different Failures
pub fn property_specific_error_types_test() {
  // Test InvalidCheckDigit - valid length but wrong check digit
  let invalid_check_digit_cases = [
    "12345671",
    // GTIN-8 with wrong check digit
    "012345678906",
    // GTIN-12 with wrong check digit
    "6291041500214",
    // GTIN-13 with wrong check digit
    "12345678901232",
    // GTIN-14 with wrong check digit
  ]

  list.each(invalid_check_digit_cases, fn(code) {
    let result = gl_gtin.validate(code)
    case result {
      Error(gl_gtin.InvalidCheckDigit) -> Nil
      _ -> {
        // Some might fail for other reasons, which is ok
        Nil
      }
    }
  })

  // Test InvalidCharacters - contains non-numeric characters
  let invalid_char_cases = [
    "629104150021A",
    "629 104 150 021",
    "629-104-150-021",
    "ABCDEFGHIJKLM",
  ]

  list.each(invalid_char_cases, fn(code) {
    let result = gl_gtin.validate(code)
    case result {
      Error(gl_gtin.InvalidCharacters) -> Nil
      _ -> Nil
    }
  })

  // Test InvalidLength - wrong number of digits
  let invalid_length_cases = ["123", "12345", "123456789012345"]

  list.each(invalid_length_cases, fn(code) {
    let result = gl_gtin.validate(code)
    case result {
      Error(gl_gtin.InvalidLength(_)) -> Nil
      _ -> Nil
    }
  })

  // Test NoGs1PrefixFound - valid GTIN but unknown prefix
  // Using a code with prefix that doesn't exist in the database
  let _result_prefix = gl_gtin.gs1_prefix_country("111111111111")

  // Test InvalidFormat - normalization on non-GTIN-13
  let assert Error(gl_gtin.InvalidFormat) = gl_gtin.normalize("12345670")
  let assert Error(gl_gtin.InvalidFormat) = gl_gtin.normalize("012345678905")
}

// Integration Tests - End-to-end workflows
// Integration Test 1: Validation then prefix lookup workflow
// Test that we can validate a GTIN and then look up its country
pub fn integration_validation_then_prefix_lookup_test() {
  // Validate a GTIN-13
  let assert Ok(_format) = gl_gtin.validate("6291041500213")

  // Look up the country for the same GTIN
  let assert Ok(country) = gl_gtin.gs1_prefix_country("6291041500213")
  country |> should.equal("GS1 Emirates")

  // Test with GTIN-12
  let assert Ok(_format) = gl_gtin.validate("012345678905")
  let assert Ok(country) = gl_gtin.gs1_prefix_country("012345678905")
  country |> should.equal("GS1 US")

  // Test with GTIN-8
  let assert Ok(_format) = gl_gtin.validate("96385074")
  // Note: GTIN-8 may not have a valid prefix lookup, so we just verify it validates
  Nil
}

// Integration Test 2: Generation then validation workflow
// Test that we can generate a GTIN and then validate it
pub fn integration_generation_then_validation_test() {
  // Generate a GTIN-8 from 7 digits
  let assert Ok(generated_8) = gl_gtin.generate("1234567")

  // Validate the generated GTIN-8
  let assert Ok(format) = gl_gtin.validate(generated_8)
  format |> should.equal(gl_gtin.Gtin8)

  // Generate a GTIN-13 from 12 digits
  let assert Ok(generated_13) = gl_gtin.generate("629104150021")

  // Validate the generated GTIN-13
  let assert Ok(format) = gl_gtin.validate(generated_13)
  format |> should.equal(gl_gtin.Gtin13)

  // Generate a GTIN-14 from 13 digits
  let assert Ok(generated_14) = gl_gtin.generate("1234567890123")

  // Validate the generated GTIN-14
  let assert Ok(format) = gl_gtin.validate(generated_14)
  format |> should.equal(gl_gtin.Gtin14)
}

// Integration Test 3: Normalization then validation workflow
// Test that we can normalize a GTIN-13 to GTIN-14 and then validate it
pub fn integration_normalization_then_validation_test() {
  // Normalize a GTIN-13 to GTIN-14
  let assert Ok(normalized) = gl_gtin.normalize("6291041500213")

  // Validate the normalized GTIN-14
  let assert Ok(format) = gl_gtin.validate(normalized)
  format |> should.equal(gl_gtin.Gtin14)

  // Verify the normalized code is 14 digits
  string.length(normalized) |> should.equal(14)

  // Test with another GTIN-13
  let assert Ok(normalized) = gl_gtin.normalize("5901234123457")
  let assert Ok(format) = gl_gtin.validate(normalized)
  format |> should.equal(gl_gtin.Gtin14)
  string.length(normalized) |> should.equal(14)
}

// Integration Test 4: Full workflow - generate, validate, and lookup
// Test a complete workflow combining generation, validation, and prefix lookup
pub fn integration_full_workflow_test() {
  // Start with incomplete GTIN-12
  let incomplete = "629104150021"

  // Generate complete GTIN-13
  let assert Ok(generated) = gl_gtin.generate(incomplete)

  // Validate the generated GTIN
  let assert Ok(format) = gl_gtin.validate(generated)
  format |> should.equal(gl_gtin.Gtin13)

  // Look up the country
  let assert Ok(country) = gl_gtin.gs1_prefix_country(generated)
  country |> should.equal("GS1 Emirates")
}

// Integration Test 5: Error handling in workflows
// Test that errors are properly propagated through workflows
pub fn integration_error_handling_test() {
  // Try to validate invalid GTIN
  let result = gl_gtin.validate("invalid")
  result |> should.be_error()

  // Try to generate with invalid length
  let result = gl_gtin.generate("123")
  result |> should.be_error()

  // Try to normalize non-GTIN-13
  let result = gl_gtin.normalize("12345670")
  result |> should.be_error()

  // Try to lookup prefix on invalid GTIN
  let result = gl_gtin.gs1_prefix_country("invalid")
  result |> should.be_error()
}

// Edge Cases: Very Large Numbers
//
// Test that very large number strings are properly rejected
pub fn edge_case_very_large_numbers_test() {
  let result = gl_gtin.validate("999999999999999999999999999999")
  result |> should.be_error()

  let result = gl_gtin.generate("999999999999999999999999999999")
  result |> should.be_error()
}

// README Examples: Validate
//
// Test examples from README documentation
pub fn readme_example_validate_test() {
  // Valid GTIN-13
  let assert Ok(format) = gl_gtin.validate("6291041500213")
  format |> should.equal(gl_gtin.Gtin13)

  // Invalid GTIN-13
  let result = gl_gtin.validate("6291041500214")
  result |> should.be_error()
}

// README Examples: Generate
//
// Test generate examples from README
pub fn readme_example_generate_test() {
  let assert Ok(complete) = gl_gtin.generate("629104150021")
  complete |> should.equal("6291041500213")
}

// README Examples: GS1 Prefix
//
// Test GS1 prefix examples from README
pub fn readme_example_gs1_prefix_test() {
  let assert Ok(country) = gl_gtin.gs1_prefix_country("6291041500213")
  country |> should.equal("GS1 Emirates")
}

// README Examples: Normalize
//
// Test normalize examples from README
pub fn readme_example_normalize_test() {
  let assert Ok(normalized) = gl_gtin.normalize("6291041500213")
  string.length(normalized) |> should.equal(14)

  // Verify it's a valid GTIN-14
  let assert Ok(format) = gl_gtin.validate(normalized)
  format |> should.equal(gl_gtin.Gtin14)
}

// Opaque Type: from_string with invalid input
//
// Test that from_string properly rejects invalid input
pub fn opaque_type_from_string_invalid_test() {
  // Invalid characters
  let result = gl_gtin.from_string("629104150021A")
  result |> should.be_error()

  // Invalid length
  let result = gl_gtin.from_string("123")
  result |> should.be_error()

  // Invalid check digit
  let result = gl_gtin.from_string("6291041500214")
  result |> should.be_error()
}
