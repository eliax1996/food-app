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

Latest milestone commit: `96e6ec9 Add dedicated weight tracking tab`.

## Current component

`NUTRIENTS-001`: daily carbohydrates, protein, fat, and fiber persistence; explicit coverage; transparent nutrition-balance guidance.

`STATES-001` is accepted attempt 04 and complete.

## Remaining sequence

1. NUTRIENTS-001 — daily carbohydrates/protein/fat/fiber split plus transparent nutrition-balance guidance
2. REFINE-001 — deferred until NUTRIENTS completes; full onboarding/calorie-goal/weight-adaptation/custom-reminder/Settings scope is preserved under `COMPLETION-PLAN.md#refine`
3. AUXILIARY-001 — Widget and Live Activity
4. CONSISTENCY-001
5. ROBUSTNESS-001
6. FINAL-001, final screenshots, judges, validation, and `FINAL-REPORT.md`

## Current validation baseline

- exact-tree `just validate 300`: passed
- `just iterate 240`: passed
- hostless: 130 passed / 2 opt-in live skips
- functional UI target: 11/11 passed through `just test-ui 420`
- simulator build/install/launch: passed
- app-host persistence: passed after final tracking correctness fixes; one later standalone host attempt timed out before XCTest

## Immediate action

Research NUTRIENTS-001 source completeness and target/range rules, then specify migration-safe Food/PlateEntry nutrient snapshots and coverage behavior before implementation. REFINE-001 stays deferred until nutrients are accepted.
