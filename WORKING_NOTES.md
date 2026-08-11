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

Latest accepted milestone: REFINE-001 attempt 02 Slice C plus SETTINGS-DIRECT-EDIT-001 direct entry.

## Current component

`REFINE-001`: competitor/safety research, welcome/setup, explainable Plan and calorie goal, NUTRITION-GOALS-001 theoretical macro/fiber references versus measured actuals, weight adaptation, configurable reminders, and hierarchical Settings.

`STATES-001`, `NUTRIENTS-001`, NUTRITION-GOALS-001, REFINE Slices A–C, WEIGHT-ENTRY-001, and SETTINGS-DIRECT-EDIT-001 are accepted and complete.

## Remaining sequence

1. REFINE-001 — Slice D evidence-gated weight adaptation. Hierarchical Settings, Plan references, reminders, calculated setup, and direct/numeric-entry follow-ups are complete.
2. AUXILIARY-001 — Widget and Live Activity
3. CONSISTENCY-001
4. ROBUSTNESS-001
5. FINAL-001, final screenshots, judges, validation, and `FINAL-REPORT.md`

## Current validation baseline

- exact-tree `just validate 300`: passed
- hostless: 178 passed / 2 opt-in live skips
- functional UI target: 22/22 passed through `TEST_CASE_TIMEOUT=60 just test-ui 900`
- simulator build/install/launch: passed
- app-hosted: 210 passed / 2 opt-in live skips
- REFINE Slice C, direct Settings entry, and DEBUG-only test-store isolation critical/high review: APPROVE

## Immediate action

Begin Slice D adaptation evidence/state specification before implementation.
