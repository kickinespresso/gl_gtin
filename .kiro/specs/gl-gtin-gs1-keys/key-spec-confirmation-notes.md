# Key Specification Confirmation Notes (Task 1.1)

Purpose: confirm the residual open-question key boundaries and serial charsets for
the `key_spec` table in `src/gl_gtin/gs1_key.gleam` (not yet created — task 3.1
consumes this file). Each row below is intended to become a one-line `key_spec`
row plus a short code comment, so a later correction is a one-line edit.

Authoritative reference: **GS1 General Specifications** (reference material, not a
runtime service — Requirement 10.6). No network/runtime lookup is added to the
library. The confirmations below were cross-checked against the published GS1 AI
(Application Identifier) element-string format notation and GS1 member-organisation
key pages.

## Notation key (GS1 AI element-string format)

- `N` = numeric digit (0–9). `N13` = exactly 13 numeric. `N..12` = up to 12 numeric.
- `X` = alphanumeric character from GS1 encodable character set 82 (CSET 82:
  A–Z, a–z, 0–9, and a defined set of punctuation). `X..17` = up to 17 alphanumeric.
- These notations were the deciding evidence for the serial charsets below.
  Source: GS1 AI reference listing (e.g. gs1-128.info AI table mirroring the GS1
  General Specifications element-string formats). Content rephrased for compliance.

## Single-length keys — CONFIRMED (already hard-coded, listed for completeness)

| Key    | AI     | Total | Body | Charset | Status    |
|--------|--------|------:|-----:|---------|-----------|
| `Gln`  | (none/414 ctx) | 13 | 12 | numeric | confirmed |
| `Sscc` | (00)   | 18    | 17   | numeric | confirmed |
| `Gsin` | (402)  | 17    | 16   | numeric | confirmed |
| `Gsrn` | (8018) | 18    | 17   | numeric | confirmed |

`Sscc` = `N18`, `Gsin` = 17 numeric, `Gln` = 13 numeric, `Gsrn` = 18 numeric.
Each is a single-length mod-10 key. No structural (format) rule beyond length +
mod-10 check.

## Residual variable-serial keys — now CONFIRMED

### GRAI — AI (8003)

- **Element-string format:** 13-digit numeric base + `1–16` alphanumeric serial.
  (GS1: "14 Digit UPC/EAN + 1–16 Alphanumeric Serial Number" — the leading digit
  of that 14 is a fixed `0` padding for the AI, the meaningful key base is the
  13-digit GTIN-style component that carries the mod-10 check on its 13th digit.)
- **Base:** 13 numeric digits; **mod-10 check applies to the 13-digit base only.**
- **Serial:** OPTIONAL, up to **16 alphanumeric** (CSET 82) characters.
- **Component boundary:** 13-digit numeric base is fixed; everything after is the
  variable serial. Total length alone is insufficient to validate (Req 10.4).
- **Serial charset:** alphanumeric (CSET 82). Structure of the serial is left to
  the asset owner; the library-level `GraiRule` should check: base is exactly 13
  numeric with a valid mod-10 check on position 13, and the serial (if present) is
  ≤ 16 chars. **Status: CONFIRMED** (base 13, serial ≤16 alphanumeric).
- Cross-checked: GS1 IT / GS1 ES GRAI pages ("parte seriale opzionale, lunghezza
  variabile massima di 16 caratteri alfanumerici").

### GIAI — AI (8004)

- **Element-string format:** `1–30` alphanumeric characters total (`X..30`).
- **Base:** numeric GS1 Company Prefix (variable length, 7–11 digits per GCP),
  followed by an individual asset reference whose structure is left to the asset
  owner/manager.
- **Check digit:** **NONE at the key level** — GIAI has no mod-10 key check digit.
- **Boundary:** there is NO single fixed GCP/reference split the library can assert
  positionally, because the GCP length varies and is not encoded in the string.
  So `GiaiRule` should assert only: total length 1–30, characters within the
  allowed alphanumeric set; it MUST NOT run a mod-10 check.
- **Status: CONFIRMED** — overall max 30 alphanumeric, no key-level check digit,
  no fixed internal boundary the library can enforce.
- Cross-checked: GS1 AU / GS1 UK GIAI pages ("individual asset reference is
  alphanumeric; its structure is left to the discretion of the asset owner").

> Implementation note for task 3.1/4.x: because GIAI has no mod-10 check, its
> `key_spec` must route around the check-digit step (the generic `validate_key`
> flow does character → length → check digit → format). GIAI needs the check-digit
> step skipped. Flag for the driver: either a `VariableLen` length rule paired
> with a "no check digit" marker, or handle GIAI's absence-of-check explicitly.
> This is a real divergence from the "all keys are mod-10" framing in the F7
> requirement intro and should be raised with the driver design in task 4.2.

### GDTI — AI (253)

- **Element-string format:** `N3 + N13 + X..17` → 13-digit numeric base +
  OPTIONAL serial of up to **17 ALPHANUMERIC** (CSET 82) characters.
- **Base:** 13 numeric digits; **mod-10 check applies to the 13-digit base only.**
  CONFIRMED.
- **Serial:** up to 17 characters. **CHARSET CORRECTION:** the serial is
  **alphanumeric (`X..17`), NOT numeric.** The design.md note said "serial charset
  (numeric) pending final confirmation" — this is now RESOLVED and the assumption
  should be corrected to **alphanumeric**.
- **Status: CONFIRMED** — base 13 numeric (mod-10 on base), serial ≤17 alphanumeric.

### GCN — AI (255)

- **Element-string format:** `N3 + N13 + N..12` → 13-digit numeric base +
  OPTIONAL serial of up to **12 NUMERIC** digits.
- **Base:** 13 numeric digits; **mod-10 check applies to the 13-digit base only.**
  CONFIRMED.
- **Serial:** up to 12 characters, **NUMERIC** (`N..12`). CONFIRMED numeric (unlike
  GDTI).
- **Status: CONFIRMED** — base 13 numeric (mod-10 on base), serial ≤12 numeric.

## Summary table for `key_spec` (values to hard-code, with confirmed status)

| `Gs1Key` | Base (numeric) | Check applies to | Serial max | Serial charset | Key-level check? | Status |
|----------|---------------:|------------------|-----------:|----------------|------------------|--------|
| `Gtin`   | 8/12/13/14     | full             | —          | numeric        | yes (mod-10)     | confirmed |
| `Gln`    | 13             | full (13)        | —          | numeric        | yes (mod-10)     | confirmed |
| `Sscc`   | 18             | full (18)        | —          | numeric        | yes (mod-10)     | confirmed |
| `Gsin`   | 17             | full (17)        | —          | numeric        | yes (mod-10)     | confirmed |
| `Gsrn`   | 18             | full (18)        | —          | numeric        | yes (mod-10)     | confirmed |
| `Grai`   | 13             | 13-digit base    | 16         | alphanumeric   | yes (on base)    | confirmed |
| `Giai`   | variable GCP   | n/a              | up to 30 total | alphanumeric | **NO**          | confirmed |
| `Gdti`   | 13             | 13-digit base    | 17         | **alphanumeric** (corrected) | yes (on base) | confirmed |
| `Gcn`    | 13             | 13-digit base    | 12         | numeric        | yes (on base)    | confirmed |

## Changes this task recommends to design.md's Key Specification Table

1. **GDTI serial charset:** change "serial charset (numeric) pending final
   confirmation" → **alphanumeric (CSET 82), confirmed** (`AI 253 = N3+N13+X..17`).
2. **GRAI / GIAI:** the "open question" flags for the residual serial-charset /
   component-boundary can be promoted to **confirmed**: GRAI serial ≤16
   alphanumeric with the check on the 13-digit base; GIAI ≤30 alphanumeric total
   with NO key-level check and no library-enforceable internal boundary.
3. **GCN:** serial ≤12 **numeric** confirmed; check on 13-digit base confirmed.
4. **GIAI has no mod-10 key check digit** — must be handled specially by the
   generic driver (see the implementation note above). This is the one substantive
   finding that affects the driver, not just a table value.

## Remaining genuinely-open item

- The exact CSET 82 punctuation subset (which non-alphanumeric punctuation is
  permitted in `X` fields) is defined by the GS1 General Specifications' encodable
  character set table. For this library's purposes the practical rule is
  "A–Z, a–z, 0–9 plus the GS1 CSET 82 punctuation"; if the implementation only
  needs to distinguish numeric vs alphanumeric serials, the exact punctuation set
  does not change any `key_spec` length/boundary value and can be treated as a
  charset-membership predicate. No length/boundary remains open.
