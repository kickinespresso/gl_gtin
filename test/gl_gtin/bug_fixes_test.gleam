//// Bug condition exploration / fix-checking tests for the
//// gl-gtin-prefix-normalize-fixes bugfix spec.
////
//// These tests encode the EXPECTED (correct) behavior for the proven
//// counterexamples. They are written against the public API and are
//// EXPECTED TO FAIL on the unfixed (v2.0.0) code. That failure confirms
//// the bugs exist. After the fix (tasks 3 and 4) these same tests must pass.
////
//// Clusters (from design.md):
////   A - prefix range table (2-digit decade lookup returns the wrong country)
////   B - format-aware prefix basis (GTIN-14 indicator digit misread)
////   C - normalize whitespace (untrimmed slice fails on padded valid input)

import gl_gtin
import gl_gtin/gtin_types.{
  Gtin12, Gtin13, Gtin14, Gtin8, InvalidCharacters, InvalidCheckDigit,
  InvalidFormat, InvalidLength, NoGs1PrefixFound,
}
import gleeunit/should

// Cluster A - Prefix range table (Issue 1)
//
// The real 3-digit GS1 prefix must be matched against GS1's real ranges,
// not collapsed onto a 2-digit decade.
//
// Bug_Condition: isBugCondition_A (region differs from decade-table answer)
// Validates: Requirements 2.1a, 2.1b, 2.1c
pub fn cluster_a_prefix_range_table_test() {
  // 871 is in the Netherlands range 870-879.
  // Unfixed code returns Ok("GS1 Italy") (decade 87).
  gl_gtin.gs1_prefix_country("8711111111116")
  |> should.equal(Ok("GS1 Netherlands"))

  // 690 is in the China range 690-699.
  // Unfixed code returns Ok("GS1 France") (decade 69).
  gl_gtin.gs1_prefix_country("6901234567890")
  |> should.equal(Ok("GS1 China"))

  // 620 is Tanzania.
  // Unfixed code returns Ok("GS1 France") (decade 62).
  gl_gtin.gs1_prefix_country("6201234567890")
  |> should.equal(Ok("GS1 Tanzania"))
}

// Cluster B - Format-aware prefix basis (Issue 2)
//
// A normalized GTIN-14 begins with an indicator digit, which must be dropped
// before reading the 3-digit GS1 prefix.
//
// Bug_Condition: isBugCondition_B (length 14)
// Validates: Requirements 2.2a
pub fn cluster_b_format_aware_basis_test() {
  // Emirates GTIN-14 "16291041500210": drop indicator "1" -> basis
  // "6291041500210", prefix 629 -> Emirates.
  // Unfixed code reads leading "16" -> Ok("GS1 US").
  gl_gtin.gs1_prefix_country("16291041500210")
  |> should.equal(Ok("GS1 Emirates"))
}

// Cluster C - normalize whitespace (Issue 4)
//
// normalize must trim once up front and use the trimmed value throughout, so
// whitespace-padded but otherwise valid GTIN-13 input succeeds.
//
// Bug_Condition: isBugCondition_C (trim(input) <> input AND valid GTIN-13)
// Validates: Requirements 2.4, 2.5
pub fn cluster_c_normalize_whitespace_test() {
  // " 6291041500213 " trims to a valid GTIN-13 that normalizes to
  // "16291041500210".
  // Unfixed code returns Error(InvalidFormat) because it slices the
  // untrimmed string.
  gl_gtin.normalize(" 6291041500213 ")
  |> should.equal(Ok("16291041500210"))
}

// Edge / negative case (Requirement 2.3, 3.6)
//
// A genuinely unassigned 3-digit prefix must map through the public API to
// Error(NoGs1PrefixFound). Prefix 150 falls in the unassigned 140-199 gap of
// the faithful ex_gtin table (100-139 US, then 200-299). On the unfixed decade
// table it returned Ok("GS1 US") (decade 15), so this still serves as a valid
// exploration counterexample that now correctly errors after the fix.
pub fn unassigned_range_returns_error_test() {
  gl_gtin.gs1_prefix_country("1501234567890")
  |> should.equal(Error(NoGs1PrefixFound))
}

// ---------------------------------------------------------------------------
// Preservation checks (Task 2) - observation-first methodology.
//
// These assertions capture behavior observed on the UNFIXED (v2.0.0) code that
// must SURVIVE the fix unchanged (design.md "Preservation Requirements",
// Property 4). Every value encoded below was observed by running the unfixed
// code, and each was chosen so it will remain valid after the fix too.
//
// They MUST PASS on the unfixed code (they establish the baseline to preserve).
// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7
// ---------------------------------------------------------------------------

// Preservation - previously-correct prefix lookups (Requirement 3.1)
//
// These prefixes already resolved correctly under the old decade table and
// must continue to return the same country/region after the fix. All inputs
// are GTIN-13 (or a 13-digit basis) so the format-aware basis change does not
// alter them.
pub fn preservation_previously_correct_prefixes_test() {
  // 012345678905: 3-digit "012" misses -> decade "01" -> US.
  // Real 3-digit prefix 012 is also in the GS1 US range, so unchanged.
  gl_gtin.gs1_prefix_country("012345678905")
  |> should.equal(Ok("GS1 US"))

  // 4001234567890: 13-digit code whose real 3-digit prefix 400 is in the
  // Germany range 400-440. (gs1_prefix_country does not validate the check
  // digit, so only prefix and length-13 matter here.)
  gl_gtin.gs1_prefix_country("4001234567890")
  |> should.equal(Ok("GS1 Germany"))

  // 535 is Malta as a real 3-digit prefix and as the old 3-digit special.
  // Using a 13-digit code so the basis is used as-is (no length rewrite).
  gl_gtin.gs1_prefix_country("5350000000006")
  |> should.equal(Ok("GS1 Malta"))

  // 629 is Emirates as a real 3-digit prefix and as the old 3-digit special.
  gl_gtin.gs1_prefix_country("6291041500213")
  |> should.equal(Ok("GS1 Emirates"))

  // ISBN/Bookland special (978...). NOTE: the unfixed code returns
  // Ok("ISBN"); the fix relabels this family to "Bookland (ISBN)". The
  // preserved behavior is that a 978 code stays a SUCCESSFUL ISBN-family
  // lookup (Ok, not an error) - the classification survives even though the
  // exact label string changes. We therefore assert success rather than
  // pinning the label, so this check is valid both before and after the fix.
  gl_gtin.gs1_prefix_country("9780000000002")
  |> should.be_ok()
}

// Preservation - validate outcomes (Requirements 3.2, 3.3)
//
// validate must keep returning Ok(<format>) for valid GTIN-8/12/13/14 and the
// matching Error for invalid input. Observed values encoded directly.
pub fn preservation_validate_outcomes_test() {
  // Valid GTIN-8/12/13/14 with correct check digits.
  gl_gtin.validate("96385074")
  |> should.equal(Ok(Gtin8))

  gl_gtin.validate("012345678905")
  |> should.equal(Ok(Gtin12))

  gl_gtin.validate("6291041500213")
  |> should.equal(Ok(Gtin13))

  gl_gtin.validate("12345678901231")
  |> should.equal(Ok(Gtin14))

  // Wrong length -> InvalidLength(got).
  gl_gtin.validate("123")
  |> should.equal(Error(InvalidLength(3)))

  // Correct length, bad check digit -> InvalidCheckDigit.
  gl_gtin.validate("6291041500214")
  |> should.equal(Error(InvalidCheckDigit))

  // Non-digit characters -> InvalidCharacters.
  gl_gtin.validate("629104150021A")
  |> should.equal(Error(InvalidCharacters))
}

// Preservation - whitespace-free normalize (Requirements 3.4, 3.5)
//
// A valid GTIN-13 with no surrounding whitespace must keep normalizing to the
// same GTIN-14, and a non-GTIN-13 format must keep returning InvalidFormat.
// (The whitespace-padded case is the BUG covered by the Cluster C exploration
// test above; this pins only the already-correct no-whitespace behavior.)
pub fn preservation_normalize_no_whitespace_test() {
  gl_gtin.normalize("6291041500213")
  |> should.equal(Ok("16291041500210"))

  // GTIN-12 is not a GTIN-13 -> InvalidFormat, unchanged by the fix.
  gl_gtin.normalize("012345678905")
  |> should.equal(Error(InvalidFormat))
}

// Preservation - NoGs1PrefixFound (Requirement 3.6)
//
// A code that yields no valid GS1 prefix must keep returning
// Error(NoGs1PrefixFound) through the public API.
//
// IMPORTANT NUANCE: design.md suggests "9991234567890" as the unassigned
// example, but the UNFIXED decade table maps decade "99" -> Netherlands, so
// that input currently returns Ok("GS1 Netherlands") (this is itself a latent
// defect and is covered by the exploration test above, not here). To capture a
// value that is Error(NoGs1PrefixFound) BOTH on the unfixed code AND after the
// fix, we use a too-short input that has no extractable 3-digit prefix in
// either implementation.
pub fn preservation_no_gs1_prefix_found_test() {
  // "1" is shorter than a prefix -> no GS1 prefix in either implementation.
  gl_gtin.gs1_prefix_country("1")
  |> should.equal(Error(NoGs1PrefixFound))
}
