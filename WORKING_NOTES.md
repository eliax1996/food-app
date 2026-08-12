# Working notes

## Current program

Original autonomous product redesign — **IN PROGRESS**.

Durable scope and live phase tracker: `design-redesign/COMPLETION-PLAN.md`.

## Completed core milestones

- Today dashboard, calorie/water hierarchy, meal grouping
- Meal editor, local/remote food search, custom/barcode tools
- Cached Open Food Facts search and keyboard-secondary amount controls
- Progress analytics
- Dedicated Weight Log
- Root `Today | Weight | Progress | Settings`

Latest accepted milestone: REFINE-001 attempt 03 Slice D evidence-gated adaptation.

## Current component

`BULK-AI-FOOD-001`: deeply researched typed/dictated bulk meal description, Apple on-device structured extraction, asynchronous food matching, editable provisional review, explicit atomic confirmation, retained corrections, and LRU-aware generic matching.

`STATES-001`, `NUTRIENTS-001`, NUTRITION-GOALS-001, REFINE Slices A–D, WEIGHT-ENTRY-001, and SETTINGS-DIRECT-EDIT-001 are accepted and complete.

## Remaining sequence

1. BULK-AI-FOOD-001 — competitor/Apple research and detailed Markdown specification, then implementation.
2. AUXILIARY-001 — Widget and Live Activity
3. CONSISTENCY-001
4. ROBUSTNESS-001
5. FINAL-001, final screenshots, judges, validation, and `FINAL-REPORT.md`

## Current validation baseline

- exact-tree `just validate 300`: passed
- hostless: 195 passed / 2 opt-in live skips
- functional UI target: 31/31 passed through `TEST_CASE_TIMEOUT=60 just test-ui 1200`
- exact-tree `just validate 300`: passed (hostless + simulator build/install/launch)
- app-hosted: 250 passed / 2 opt-in live skips
- REFINE Slice D architecture/safety/native UI/historical goal reviews: APPROVE; visual 3/3 APPROVE

## Immediate action

Run final Slice D exact-tree validation, commit milestone, then begin BULK-AI-FOOD-001 research/specification before code.
