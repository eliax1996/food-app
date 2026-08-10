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

Latest committed milestone: `0a19ef6 Add truthful daily nutrition balance`. REFINE-001 attempt 01 Slices A/B and WEIGHT-ENTRY-001 are accepted and ready for a focused commit.

## Current component

`REFINE-001`: competitor/safety research, welcome/setup, explainable Plan and calorie goal, NUTRITION-GOALS-001 theoretical macro/fiber references versus measured actuals, weight adaptation, configurable reminders, and hierarchical Settings.

`STATES-001`, `NUTRIENTS-001`, NUTRITION-GOALS-001, REFINE Slices A/B, and WEIGHT-ENTRY-001 are accepted and complete.

## Remaining sequence

1. REFINE-001 — Slice C welcome/setup and explainable calculated calorie plan, then Slice D evidence-gated weight adaptation. Hierarchical Settings, Plan references, reminders, and numeric-entry follow-up are complete.
2. AUXILIARY-001 — Widget and Live Activity
3. CONSISTENCY-001
4. ROBUSTNESS-001
5. FINAL-001, final screenshots, judges, validation, and `FINAL-REPORT.md`

## Current validation baseline

- exact-tree `just validate 300`: passed
- hostless: 155 passed / 2 opt-in live skips
- functional UI target: 14/14 passed through `just test-ui 600`
- simulator build/install/launch: passed
- app-hosted: 184 passed / 2 opt-in live skips
- REFINE and WEIGHT-ENTRY critical/high visual/code review: APPROVE

## Immediate action

Create focused REFINE-001 attempt-01 + WEIGHT-ENTRY-001 commit excluding `.TASK_NOTES.md`, then begin REFINE Slice C supported-population/equation specification before onboarding implementation.
