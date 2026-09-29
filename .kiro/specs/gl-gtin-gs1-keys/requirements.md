# Requirements Document

## Introduction

This feature implements the Tier 2 GS1-key features (F5, F6, F7) from the `gl_gtin` feature roadmap for the Gleam `gl_gtin` library (baseline 2.0.0). These features add support for GS1 identification keys beyond the trade-item GTINs already supported:

- **F5 — SSCC** (Serial Shipping Container Code): validate and generate the 18-digit logistics key.
- **F6 — GSIN** (Global Shipment Identification Number): validate and generate the 17-digit shipment key.
- **F7 — Generic GS1 key support**: a key-parameterized validator and generator covering GLN, GRAI, GIAI, GSRN, GDTI, and GCN, all of which are mod-10 keys, in addition to GTIN, GLN, SSCC, and GSIN.

All three features reuse the shared GS1 Modulo 10 check-digit engine. They build directly on the **F0 generalized check-digit engine** (the `len > 13` cap removed, plus the new `valid` and `append` helpers) delivered by the sibling Tier 1 spec `.kiro/specs/gl-gtin-tier1-features/`. F0 is treated as a **prerequisite dependency, not in-scope work** for this spec.

All features are additive to the public API (minor version bumps). The work honors the library's existing design principles: total functions (no `let assert`, `panic`, or `todo` in library code), the `Result(value, GtinError)` public contract with specific error variants, the opaque `Gtin` "known-valid" type, and a string-first API. Every feature ships gleeunit tests, correct doc-comment examples, a `CHANGELOG.md` entry, and passes `gleam format --check`.

Several exact key lengths and format rules for the F7 keys (GRAI, GIAI, GDTI, GCN in particular) are defined by the **GS1 General Specifications**, which is reference material rather than a runtime service. Where the roadmap is not fully precise about a key's length or format, this document records the assumption explicitly and flags it as an open question to confirm against the GS1 General Specifications before design.

## Glossary

- **GS1 key**: A GS1 identification key that carries a GS1 Modulo 10 check digit. In this spec the supported keys are GTIN, GLN, SSCC, GSIN, GRAI, GIAI, GSRN, GDTI, and GCN.
- **GTIN**: Global Trade Item Number, a standardized product identifier of 8, 12, 13, or 14 digits.
- **SSCC**: Serial Shipping Container Code, an 18-digit logistics key consisting of an extension digit, a GS1 company prefix, a serial reference, and a mod-10 check digit.
- **GSIN**: Global Shipment Identification Number, a 17-digit key consisting of a GS1 company prefix, a shipper reference, and a mod-10 check digit.
- **GLN**: Global Location Number, a 13-digit GS1 key identifying a physical, functional, or legal location.
- **GRAI**: Global Returnable Asset Identifier, a GS1 key with a fixed leading component plus a variable-length serial component.
- **GIAI**: Global Individual Asset Identifier, a GS1 key with a GS1 company prefix plus a variable-length individual asset reference.
- **GSRN**: Global Service Relation Number, an 18-digit GS1 key.
- **GDTI**: Global Document Type Identifier, a GS1 key with a 13-digit document-type component plus an optional variable-length serial component.
- **GCN**: Global Coupon Number, a GS1 key with a 13-digit base component plus an optional variable-length serial component.
- **Body**: The digit string supplied to a generator function that excludes the check digit. A generator appends the computed check digit to the body to produce the complete key.
- **Extension digit**: The leading digit of an SSCC, assigned by the company to increase serial-reference capacity.
- **Check_Digit_Engine**: The module `gl_gtin/check_digit` that implements the GS1 Modulo 10 algorithm and, after F0, the generalized `calculate`, `valid`, and `append` helpers with no upper length cap.
- **GS1 Modulo 10 algorithm**: The checksum algorithm that multiplies digits alternately by 3 and 1 from right to left, sums the products, and derives the check digit as `(10 - (sum mod 10)) mod 10`.
- **F0 generalized check-digit engine**: The version of `gl_gtin/check_digit` produced by the `gl-gtin-tier1-features` spec, in which `calculate` accepts digit bodies longer than 13 and the `valid` and `append` helpers exist.
- **Gs1Key**: The public type enumerating the supported GS1 keys: `Gtin`, `Gln`, `Sscc`, `Gsin`, `Grai`, `Giai`, `Gsrn`, `Gdti`, `Gcn`.
- **GtinFormat**: The existing public type enumerating `Gtin8`, `Gtin12`, `Gtin13`, `Gtin14`.
- **Gtin**: The existing opaque public type representing a validated GTIN, constructible only through validation.
- **GtinError**: The public error type in `gl_gtin`. Existing variants: `InvalidLength(got: Int)`, `InvalidCheckDigit`, `InvalidCharacters`, `NoGs1PrefixFound`, `InvalidFormat`. All new public functions in this spec return `Result(value, GtinError)`.
- **InvalidKeyFormat**: A proposed new `GtinError` variant for key-specific structural failures that cannot be represented by an existing variant (for example, a variable-serial key whose component structure is malformed even though its length and check digit are otherwise plausible). Its exact name and shape are an open question to be settled in design.
- **CheckDigitError**: The error type in `gl_gtin/check_digit` used by the engine functions. Internal check-digit errors are mapped to `GtinError` at the public API boundary.
- **Total function**: A function that returns a value for every input without panicking (no `let assert`, no `panic`, no `todo`, no runtime crashes).
- **GS1 General Specifications**: The GS1 reference document that defines the structure, length, and format rules of each GS1 key. Reference material, not a runtime dependency.
- **Defect-ordering rule**: The order in which a validator evaluates possible defects and returns only the first failing rule's `Error`. In this spec the order is character validity, then digit count (length), then check digit, then (for keys that have them) key-specific structural format. Character validity is checked before length, matching the existing `validation.validate` flow (trim → parse digits → validate length → validate check digit), where non-digit characters are rejected during digit parsing before the length check runs.

## Requirements

### Requirement 1: Validate SSCC (F5)

**User Story:** As a logistics developer, I want to validate an 18-digit SSCC, so that I can confirm a shipping container code is well-formed before processing it.

#### Acceptance Criteria

1. WHEN `validate_sscc` is called with a code that, after trimming leading and trailing whitespace, consists of exactly 18 characters each in the range 0 through 9 and whose 18th digit equals the check digit computed by the Check_Digit_Engine from its first 17 digits, THE SSCC_Validator SHALL return `Ok("SSCC")`.
2. IF `validate_sscc` is called with a code that, after trimming leading and trailing whitespace, contains any character outside the range 0 through 9 (including interior whitespace), THEN THE SSCC_Validator SHALL return `Error(InvalidCharacters)`.
3. IF `validate_sscc` is called with a code that, after trimming leading and trailing whitespace, consists solely of characters in the range 0 through 9 but whose count is not exactly 18, THEN THE SSCC_Validator SHALL return `Error(InvalidLength(got: n))` where `n` is the count of trimmed characters.
4. IF `validate_sscc` is called with an 18-digit numeric code whose 18th digit does not equal the check digit computed from its first 17 digits, THEN THE SSCC_Validator SHALL return `Error(InvalidCheckDigit)`.
5. WHEN `validate_sscc` is called with a code that fails more than one validation rule, THE SSCC_Validator SHALL evaluate defects in the order character validity, then digit count, then check digit, and SHALL return only the `Error` for the first failing rule.
6. IF `validate_sscc` is called with a code that is empty or contains only whitespace, THEN THE SSCC_Validator SHALL return `Error(InvalidLength(got: 0))`.
7. WHEN `validate_sscc` is called with a valid 14-digit GTIN-14 code, THE SSCC_Validator SHALL return `Error(InvalidLength(got: 14))` and SHALL NOT return `Ok("SSCC")`.

### Requirement 2: Generate SSCC (F5)

**User Story:** As a logistics developer, I want to generate a complete SSCC from a 17-digit body, so that I can produce a valid shipping container code with the correct check digit.

#### Acceptance Criteria

1. WHEN `generate_sscc` is called with a 17-digit numeric body, THE SSCC_Generator SHALL compute the check digit using the Check_Digit_Engine and return `Ok(sscc)` where `sscc` is the 17-digit body followed by the computed check digit as an 18-digit string.
2. IF `generate_sscc` is called with a body that, after trimming leading and trailing whitespace, does not have exactly 17 digits, THEN THE SSCC_Generator SHALL return `Error(InvalidLength(got: n))` where `n` is the trimmed digit count.
3. IF `generate_sscc` is called with a 17-character body containing any character outside the range 0 through 9, THEN THE SSCC_Generator SHALL return `Error(InvalidCharacters)`.
4. FOR ALL 17-digit numeric bodies, calling `generate_sscc` and then `validate_sscc` on the generated result SHALL return `Ok("SSCC")`.

### Requirement 3: Validate GSIN (F6)

**User Story:** As a logistics developer, I want to validate a 17-digit GSIN, so that I can confirm a shipment identification number is well-formed before processing it.

#### Acceptance Criteria

1. WHEN `validate_gsin` is called with a code that, after trimming leading and trailing whitespace, consists of exactly 17 characters each in the range 0 through 9 and whose 17th digit equals the check digit computed by the Check_Digit_Engine from its first 16 digits, THE GSIN_Validator SHALL return `Ok("GSIN")`.
2. IF `validate_gsin` is called with a code that, after trimming leading and trailing whitespace, contains any character outside the range 0 through 9 (including interior whitespace), THEN THE GSIN_Validator SHALL return `Error(InvalidCharacters)`.
3. IF `validate_gsin` is called with a code that, after trimming leading and trailing whitespace, consists solely of characters in the range 0 through 9 but whose count is not exactly 17, THEN THE GSIN_Validator SHALL return `Error(InvalidLength(got: n))` where `n` is the count of trimmed characters.
4. IF `validate_gsin` is called with a 17-digit numeric code whose 17th digit does not equal the check digit computed from its first 16 digits, THEN THE GSIN_Validator SHALL return `Error(InvalidCheckDigit)`.
5. WHEN `validate_gsin` is called with a code that fails more than one validation rule, THE GSIN_Validator SHALL evaluate defects in the order character validity, then digit count, then check digit, and SHALL return only the `Error` for the first failing rule.
6. IF `validate_gsin` is called with a code that is empty or contains only whitespace, THEN THE GSIN_Validator SHALL return `Error(InvalidLength(got: 0))`.
7. WHEN `validate_gsin` is called with a valid 18-digit SSCC code, THE GSIN_Validator SHALL return `Error(InvalidLength(got: 18))` and SHALL NOT return `Ok("GSIN")`.

### Requirement 4: Generate GSIN (F6)

**User Story:** As a logistics developer, I want to generate a complete GSIN from a 16-digit body, so that I can produce a valid shipment identification number with the correct check digit.

#### Acceptance Criteria

1. WHEN `generate_gsin` is called with a 16-digit numeric body, THE GSIN_Generator SHALL compute the check digit using the Check_Digit_Engine and return `Ok(gsin)` where `gsin` is the 16-digit body followed by the computed check digit as a 17-digit string.
2. IF `generate_gsin` is called with a body that, after trimming leading and trailing whitespace, does not have exactly 16 digits, THEN THE GSIN_Generator SHALL return `Error(InvalidLength(got: n))` where `n` is the trimmed digit count.
3. IF `generate_gsin` is called with a 16-character body containing any character outside the range 0 through 9, THEN THE GSIN_Generator SHALL return `Error(InvalidCharacters)`.
4. FOR ALL 16-digit numeric bodies, calling `generate_gsin` and then `validate_gsin` on the generated result SHALL return `Ok("GSIN")`.

### Requirement 5: Generic GS1 key type (F7)

**User Story:** As a developer, I want a single typed enumeration of the supported GS1 keys, so that I can select a key at the type level and avoid same-length collisions between different key kinds.

#### Acceptance Criteria

1. THE gl_gtin library SHALL define a public type `Gs1Key` with exactly the variants `Gtin`, `Gln`, `Sscc`, `Gsin`, `Grai`, `Giai`, `Gsrn`, `Gdti`, and `Gcn`.
2. THE gl_gtin library SHALL associate each `Gs1Key` variant with the length and format rules that variant requires, so that two keys sharing the same digit length are distinguished by their `Gs1Key` value rather than by length alone.

### Requirement 6: Validate a GS1 key by kind (F7)

**User Story:** As a developer, I want to validate a code against a specific GS1 key kind, so that I can confirm the code matches that key's length, format, and check digit.

#### Acceptance Criteria

1. WHEN `validate_key` is called with a `Gs1Key` value and a code that, after trimming whitespace, satisfies that key's required length, format rules, and check digit, THE Key_Validator SHALL return `Ok(key)` where `key` is the supplied `Gs1Key` value.
2. WHEN `validate_key` is called with `Gln` and `"0614141000012"`, THE Key_Validator SHALL return `Ok(Gln)`.
3. IF `validate_key` is called with a `Gs1Key` value and a code that, after trimming whitespace, contains any character outside the range 0 through 9, THEN THE Key_Validator SHALL return `Error(InvalidCharacters)`.
4. IF `validate_key` is called with a `Gs1Key` value and a code that, after trimming whitespace, consists solely of digits but does not match that key's required length, THEN THE Key_Validator SHALL return `Error(InvalidLength(got: n))` where `n` is the trimmed digit count.
5. IF `validate_key` is called with a `Gs1Key` value and a code that matches the key's length and character set but whose final digit does not equal the check digit computed from the preceding digits, THEN THE Key_Validator SHALL return `Error(InvalidCheckDigit)`.
6. WHEN `validate_key` is called with a code that fails more than one validation rule, THE Key_Validator SHALL evaluate defects in the order character validity, then digit count, then check digit, then key-specific structural format, and SHALL return only the `Error` for the first failing rule.
7. WHERE the selected `Gs1Key` is a variable-serial key (`Grai` or `Giai`), IF the code satisfies the length and check-digit rules but violates that key's structural format rules, THEN THE Key_Validator SHALL return an `Error` whose `GtinError` variant specifically denotes a key format failure and SHALL NOT return an `Ok` value.
8. WHEN `validate_key` is called with two codes of identical length that are valid for two different `Gs1Key` kinds, THE Key_Validator SHALL validate each code only against the `Gs1Key` kind supplied in that call.

### Requirement 7: Generate a GS1 key by kind (F7)

**User Story:** As a developer, I want to generate a complete GS1 key of a specific kind from a body, so that I can produce a valid key with the correct check digit for any supported key kind.

#### Acceptance Criteria

1. WHEN `generate_key` is called with a `Gs1Key` value and a body that, after leading and trailing whitespace is trimmed, contains only characters in the range 0 through 9 and satisfies that key's required body length and format rules, THE Key_Generator SHALL return `Ok(key)` where `key` is the trimmed body followed by the check digit computed by the Check_Digit_Engine.
2. IF `generate_key` is called with a body that, after leading and trailing whitespace is trimmed, contains any character outside the range 0 through 9, THEN THE Key_Generator SHALL return `Error(InvalidCharacters)`, and this character check SHALL be evaluated before the body length check.
3. IF `generate_key` is called with a body that, after leading and trailing whitespace is trimmed, contains only characters in the range 0 through 9 but has a digit count that does not satisfy the selected `Gs1Key` value's required body length, THEN THE Key_Generator SHALL return `Error(InvalidLength(got: n))` where `n` is the count of digits in the trimmed body.
4. WHERE the selected `Gs1Key` is a variable-serial key (`Grai` or `Giai`), IF the trimmed body satisfies that key's required body length but does not satisfy that key's positional format rules for its fixed and variable serial components, THEN THE Key_Generator SHALL return an `Error` whose `GtinError` variant specifically denotes a key format failure, and SHALL NOT return an `Ok` value.
5. FOR ALL `Gs1Key` kinds and all bodies that are valid for the selected kind, WHEN `generate_key` returns `Ok(key)` and `validate_key` is then called with the same `Gs1Key` value and that `key`, THE Key_Generator SHALL cause `validate_key` to return `Ok` of that `Gs1Key` value.

### Requirement 8: API and quality constraints

**User Story:** As a library maintainer, I want all new functionality to follow the library's established conventions, so that the public contract, safety guarantees, and release discipline remain consistent.

#### Acceptance Criteria

1. THE gl_gtin library SHALL add all new public functions and the `Gs1Key` type without removing, renaming, or changing the signature or return type of any existing public function or type.
2. THE gl_gtin library SHALL return every new public function's result as a `Result` value whose error case is the `GtinError` type.
3. WHERE a new error condition cannot be represented by an existing `GtinError` variant, THE gl_gtin library SHALL add a new variant to `GtinError` and SHALL NOT raise a runtime panic for that condition.
4. THE gl_gtin library SHALL implement every new library function as a total function that returns a value for all inputs without using `let assert`, `panic`, or `todo`.
5. THE gl_gtin library SHALL keep the `Gtin` type opaque, constructible only through validation, so that every `Gtin` value is guaranteed valid.
6. THE gl_gtin library SHALL define every new public function that consumes or produces a GS1 key code to use the `String` type for that code.
7. THE gl_gtin library SHALL include at least one gleeunit test asserting a success case and at least one gleeunit test asserting a failure case for each of the features F5, F6, and F7.
8. WHEN the doc-comment examples for each new public function are exercised by tests, THE gl_gtin library SHALL produce the outputs stated in those examples with zero failures.
9. THE gl_gtin library SHALL include one `CHANGELOG.md` entry that names each of the F5, F6, and F7 additions.
10. WHEN `gleam format --check` is run against the gl_gtin library source, THE gl_gtin library source SHALL complete with a zero (success) exit status and report no files requiring reformatting.

### Requirement 9: F0 engine prerequisite dependency

**User Story:** As a library maintainer, I want the GS1-key features to build on the generalized check-digit engine, so that keys longer than 13 digits reuse the shared mod-10 routine instead of duplicating it.

#### Acceptance Criteria

1. THE gl-gtin-gs1-keys spec SHALL declare the F0 generalized check-digit engine delivered by `.kiro/specs/gl-gtin-tier1-features/` as a prerequisite dependency, and THE gl-gtin-gs1-keys spec SHALL NOT include the F0 engine generalization within its own scope.
2. WHEN the SSCC, GSIN, and generic-key functions compute or verify a check digit for a body longer than 13 digits, THE gl_gtin library SHALL obtain that check digit from the F0 generalized Check_Digit_Engine and SHALL NOT introduce a separate mod-10 implementation.
3. WHERE the F0 `valid` and `append` helpers are available, THE gl_gtin library SHALL prefer those helpers for check-digit verification and generation of GS1 keys over reimplementing equivalent logic.

### Requirement 10: GS1 key length and format assumptions to confirm

**User Story:** As a spec author, I want the exact key lengths and format rules that the roadmap does not fully pin down recorded as explicit assumptions, so that the design phase confirms them against the GS1 General Specifications before implementation.

#### Acceptance Criteria

1. THE gl-gtin-gs1-keys spec SHALL contain a labeled assumptions section in which each recorded assumption is an individually identifiable entry carrying exactly one status flag of either "confirmed" or "open question".
2. THE gl-gtin-gs1-keys spec SHALL record one length assumption entry for each of the nine `Gs1Key` variants (`Gtin`, `Gln`, `Sscc`, `Gsin`, `Grai`, `Giai`, `Gsrn`, `Gdti`, `Gcn`) with none omitted.
3. THE gl-gtin-gs1-keys spec SHALL record the length assumptions that `Sscc` and `Gsrn` are 18-digit keys, `Gsin` is a 17-digit key, and `Gln` is a 13-digit key, each carrying the "open question" status flag for confirmation against the GS1 General Specifications.
4. THE gl-gtin-gs1-keys spec SHALL record for `Grai` and `Giai` an entry stating they contain a variable-length serial component such that total length alone is insufficient to validate them, carrying the "open question" status flag for the exact fixed-versus-variable component boundaries.
5. THE gl-gtin-gs1-keys spec SHALL record for `Gdti` and `Gcn` an entry stating they consist of a 13-digit base component plus an optional variable-length serial component, carrying the "open question" status flag for whether the check digit applies to the 13-digit base only.
6. THE gl-gtin-gs1-keys spec SHALL identify the GS1 General Specifications as the authoritative external reference for every assumption recorded under this requirement, and SHALL note that it is reference material rather than a runtime service.
