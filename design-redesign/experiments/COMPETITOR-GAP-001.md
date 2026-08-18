# COMPETITOR-GAP-001 — Historical food diary

**Status:** ATTEMPT 01 ACCEPTED — COMPLETE

**Date:** 2026-08-18

## Gap

Progress exposed exact historical calorie totals but not foods behind them. Current category evidence consistently keeps food history date-first and food/meal-specific, separate from weight analytics and generic mixed journals.

Research and contract: `../../docs/historical-calorie-diary-assessment.md`.

## Accepted implementation

```text
Progress / Calories
→ select recorded day
→ View Day
→ Food Diary
```

Diary is intentionally read-only v1:

- localized selected date and assessed calorie completeness;
- Breakfast, Lunch, Dinner, Snack ordering with only nonempty groups;
- immutable `PlateEntry` name/calorie/paired g-or-ml amount/portion/time snapshots;
- previous/next recorded-day navigation without inventing empty days;
- invalid legacy calories remain visible and mark totals incomplete;
- no historical mutation, copy, water/weight mixing, or current-food recalculation.

`PlateEntry.weightGrams` is a legacy name for amount expressed in paired `nutritionUnit`; diary projects normalized g/ml semantics exactly. Unknown legacy unit strings fail closed to grams instead of rendering arbitrary labels.

## Evidence

- `screenshots/COMPETITOR-GAP-001/attempt-01-diary-light.png`
- `screenshots/COMPETITOR-GAP-001/attempt-01-diary-ax3-dark.png`

Normal light view shows date, total, two meal groups, row snapshots, and recorded-day navigation. AX3 dark view stacks navigation and entry values while preserving full food names and scroll continuation.

## Validation

- Focused `CalorieDiaryTests`: 5/5 passed, including paired milliliter and unknown-unit normalization.
- `just validate 300`: 228 hostless passed / 2 opt-in live skips; app + widget compile/install/launch passed.
- `just test-app-unit 600`: 315 passed / 2 opt-in live skips.
- Full functional UI: 47/47 passed, including selected calorie day → View Day → three meal groups → adjacent recorded day; no mutation control.
- Three independent critical/high product/code/visual reviews: **APPROVE / APPROVE / APPROVE**.

## Decision

**ACCEPTED — ATTEMPT 01 / COMPLETE.** This completes queued competitor-gap iteration. Historical add/edit/delete/copy remains a separate future contract, not implied by read-only diary.
