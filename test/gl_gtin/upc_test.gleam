import gl_gtin
import gl_gtin/gtin_types.{
  Gtin12, InvalidCharacters, InvalidCheckDigit, InvalidFormat, InvalidLength,
}
import gl_gtin/upc
import gleeunit/should

// F1 — upce_to_upca (task 4.1)

// Worked example from the design and Requirement 2.2.
pub fn upce_to_upca_worked_example_test() {
  upc.upce_to_upca("04252614")
  |> should.equal(Ok("042100005264"))
}

// The produced UPC-A validates as a GTIN-12 (Requirement 2.11).
pub fn upce_to_upca_produces_valid_gtin12_test() {
  let assert Ok(upca) = upc.upce_to_upca("04252614")
  gl_gtin.validate(upca)
  |> should.equal(Ok(Gtin12))
}

// Expansion branch X6 ∈ {0, 1, 2}: X1 X2 X6 0 0 0 0 X3 X4 X5 (Requirement 2.3).
// UPC-E "04252614": NS=0, body 4 2 5 2 6 1, X6=1 -> 4 2 1 0 0 0 0 5 2 6.
pub fn upce_to_upca_branch_x6_le_2_test() {
  upc.upce_to_upca("04252614")
  |> should.equal(Ok("042100005264"))
}

// Expansion branch X6 = 3: X1 X2 X3 0 0 0 0 0 X4 X5 (Requirement 2.4).
pub fn upce_to_upca_branch_x6_eq_3_test() {
  // NS=0, body 1 2 3 4 5 3 -> 1 2 3 0 0 0 0 0 4 5 -> body 0 1 2 3 0 0 0 0 0 4 5.
  let assert Ok(upca) = upc.upce_to_upca("01234530")
  // Assert the manufacturer+item expansion is applied (first 11 digits).
  upca
  |> should.equal("012300000451")
}

// Expansion branch X6 = 4: X1 X2 X3 X4 0 0 0 0 0 X5 (Requirement 2.5).
pub fn upce_to_upca_branch_x6_eq_4_test() {
  // NS=0, body 1 2 3 4 5 4 -> 1 2 3 4 0 0 0 0 0 5 -> body 0 1 2 3 4 0 0 0 0 0 5.
  let assert Ok(upca) = upc.upce_to_upca("01234540")
  upca
  |> should.equal("012340000053")
}

// Expansion branch X6 ∈ {5..9}: X1 X2 X3 X4 X5 0 0 0 0 X6 (Requirement 2.6).
pub fn upce_to_upca_branch_x6_ge_5_test() {
  // NS=0, body 1 2 3 4 5 6 -> 1 2 3 4 5 0 0 0 0 6 -> body 0 1 2 3 4 5 0 0 0 0 6.
  let assert Ok(upca) = upc.upce_to_upca("01234560")
  upca
  |> should.equal("012345000065")
}

// Number-system digit 2..9 -> InvalidFormat (Requirement 2.7).
pub fn upce_to_upca_bad_number_system_test() {
  upc.upce_to_upca("24252614")
  |> should.equal(Error(InvalidFormat))
}

// Trimmed length ≠ 8 -> InvalidLength(got: n) (Requirement 2.8).
pub fn upce_to_upca_bad_length_test() {
  upc.upce_to_upca("12345")
  |> should.equal(Error(InvalidLength(got: 5)))
}

// Whitespace is trimmed before validation (Requirement 2.8 length uses trimmed count).
pub fn upce_to_upca_trims_whitespace_test() {
  upc.upce_to_upca("  04252614  ")
  |> should.equal(Ok("042100005264"))
}

// Length 8 but non-numeric -> InvalidCharacters (Requirement 2.9).
pub fn upce_to_upca_non_numeric_test() {
  upc.upce_to_upca("0425261a")
  |> should.equal(Error(InvalidCharacters))
}

// Defect ordering: length checked before characters (Requirement 2.10).
// A 5-char non-numeric input reports length, not characters.
pub fn upce_to_upca_ordering_length_before_chars_test() {
  upc.upce_to_upca("abcde")
  |> should.equal(Error(InvalidLength(got: 5)))
}

// F1 — doc-comment example mirrors for upce_to_upca (module + facade, Req 8.8)

// Mirrors the upc.upce_to_upca doc example: Ok case.
pub fn upce_to_upca_doc_example_ok_test() {
  upc.upce_to_upca("04252614")
  |> should.equal(Ok("042100005264"))
}

// Mirrors the upc.upce_to_upca doc example: length error case.
pub fn upce_to_upca_doc_example_length_test() {
  upc.upce_to_upca("12345")
  |> should.equal(Error(InvalidLength(got: 5)))
}

// Mirrors the upc.upce_to_upca doc example: number-system error case.
pub fn upce_to_upca_doc_example_format_test() {
  upc.upce_to_upca("24252614")
  |> should.equal(Error(InvalidFormat))
}

// Mirrors the gl_gtin facade upce_to_upca doc examples (Req 8.8).
pub fn facade_upce_to_upca_doc_example_ok_test() {
  gl_gtin.upce_to_upca("04252614")
  |> should.equal(Ok("042100005264"))
}

pub fn facade_upce_to_upca_doc_example_format_test() {
  gl_gtin.upce_to_upca("24252614")
  |> should.equal(Error(InvalidFormat))
}

// F1 — upca_to_upce (task 4.2 / task 4.4)

// Worked example from the design and Requirement 3.2.
pub fn upca_to_upce_worked_example_test() {
  upc.upca_to_upce("042100005264")
  |> should.equal(Ok("04252614"))
}

// Valid, check-digit-correct UPC-A that is not compressible -> InvalidFormat
// (Requirement 3.4). "012345678905" has a valid check digit but no suppression
// pattern.
pub fn upca_to_upce_not_compressible_test() {
  upc.upca_to_upce("012345678905")
  |> should.equal(Error(InvalidFormat))
}

// Compression branch X6 ∈ {0, 1, 2}: block X1 X2 m 0 0 0 0 X3 X4 X5 (Req 3.1/3.2).
// Inverse of upce_to_upca("04252614") == "042100005264".
pub fn upca_to_upce_branch_x6_le_2_test() {
  upc.upca_to_upce("042100005264")
  |> should.equal(Ok("04252614"))
}

// Compression branch X6 = 3: block X1 X2 X3 0 0 0 0 0 X4 X5.
// Compressing "012300000451" carries the UPC-A check digit (1) as the UPC-E
// check digit, yielding body 0 1 2 3 4 5 + NS 0 + check 1.
pub fn upca_to_upce_branch_x6_eq_3_test() {
  upc.upca_to_upce("012300000451")
  |> should.equal(Ok("01234531"))
}

// Compression branch X6 = 4: block X1 X2 X3 X4 0 0 0 0 0 X5.
pub fn upca_to_upce_branch_x6_eq_4_test() {
  upc.upca_to_upce("012340000053")
  |> should.equal(Ok("01234543"))
}

// Compression branch X6 ∈ {5..9}: block X1 X2 X3 X4 X5 0 0 0 0 X6.
pub fn upca_to_upce_branch_x6_ge_5_test() {
  upc.upca_to_upce("012345000065")
  |> should.equal(Ok("01234565"))
}

// Number-system digit 2..9 -> InvalidFormat: a valid-check-digit UPC-A whose
// number system is not 0 or 1 is rejected before compression (Requirement 3.4).
// "234100005263" has NS=2, a valid check digit, and a compressible block, so
// only the NS restriction can produce the InvalidFormat result.
pub fn upca_to_upce_bad_number_system_test() {
  upc.upca_to_upce("234100005263")
  |> should.equal(Error(InvalidFormat))
}

// Digit count ≠ 12 -> InvalidLength(got: n) (Requirement 3.5).
pub fn upca_to_upce_bad_length_test() {
  upc.upca_to_upce("12345")
  |> should.equal(Error(InvalidLength(got: 5)))
}

// Any non-numeric character -> InvalidCharacters (Requirement 3.6).
pub fn upca_to_upce_non_numeric_test() {
  upc.upca_to_upce("04210000526a")
  |> should.equal(Error(InvalidCharacters))
}

// 12 numeric digits with a wrong check digit -> InvalidCheckDigit (Req 3.7).
// "042100005265" is the worked example with its check digit flipped from 4 to 5.
pub fn upca_to_upce_bad_check_digit_test() {
  upc.upca_to_upce("042100005265")
  |> should.equal(Error(InvalidCheckDigit))
}

// Defect ordering: characters checked before digit count (Requirement 3.8).
// A short non-numeric input reports characters, not length.
pub fn upca_to_upce_ordering_chars_before_length_test() {
  upc.upca_to_upce("abcde")
  |> should.equal(Error(InvalidCharacters))
}

// Whitespace is trimmed before validation (Requirement 3.1 uses trimmed input).
pub fn upca_to_upce_trims_whitespace_test() {
  upc.upca_to_upce("  042100005264  ")
  |> should.equal(Ok("04252614"))
}

// Mirrors the upc.upca_to_upce doc example: not-compressible error case.
pub fn upca_to_upce_doc_example_format_test() {
  upc.upca_to_upce("012345678905")
  |> should.equal(Error(InvalidFormat))
}

// Mirrors the gl_gtin facade upca_to_upce doc examples (Req 8.8).
pub fn facade_upca_to_upce_doc_example_ok_test() {
  gl_gtin.upca_to_upce("042100005264")
  |> should.equal(Ok("04252614"))
}

pub fn facade_upca_to_upce_doc_example_format_test() {
  gl_gtin.upca_to_upce("012345678905")
  |> should.equal(Error(InvalidFormat))
}
