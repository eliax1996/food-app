# SETTINGS-DIRECT-EDIT-001 — Direct Settings entry

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Date:** 2026-08-11

## User problem

Reminder `Off`/time values looked actionable, but tapping them did nothing; only top-bar Edit opened configuration. User also reported `Calculate a starting goal` did not open reliably from Plan.

## Decision

Direct summary-row entry is better UX. Native Settings rows with visible values conventionally navigate or edit. Whole-row buttons reduce discovery cost while keeping Save/Cancel, notification permission, and persistence unchanged.

## Attempt 01

- Breakfast, Lunch, Snack, and Dinner always show exact time or `Off`, plus chevron.
- Weight and Water use equivalent Schedule rows.
- Every row is a 44-point full-width button with explicit VoiceOver label/value/hint.
- Selected row opens same reminder draft and scrolls toward Meals, Weight, or Water. Summary taps never toggle, save, or request permission.
- Top Edit remains.
- AX3 stacks title/value vertically to prevent compressed wrapping.
- Plan replaced competing Boolean/optional sheet state with one item-driven presentation. This fixed reported dead `Calculate a starting goal` action.

## Evidence

- `../screenshots/SETTINGS-DIRECT-EDIT-001/attempt-01-reminder-summaries.png`
- `../screenshots/SETTINGS-DIRECT-EDIT-001/attempt-01-reminder-summaries-ax3-dark.png`
- Plan entry/result evidence: `../screenshots/REFINE-001/attempt-02-plan-manual-entry.png` and `attempt-02-plan-calculated.png`.

Focused independent visual judgment: **APPROVE**.

## Automated proof

- Meal `Off` row → editor → Cancel → `Off` unchanged.
- Weight row → editor focused near Weight → Cancel unchanged.
- Water row → editor focused near Water → Cancel unchanged.
- Plan → Calculate → Welcome → Continue → Goal → Close leaves Manual 1,700 kcal → next Plan tap resumes Goal.
- Final functional suite: **22/22 passed**.

## Decision

**ACCEPTED — ATTEMPT 01 / COMPLETE.** Direct reminder and calculated-setup entry now work without weakening explicit transactions.
