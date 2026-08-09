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

Latest committed milestone: `83b68a1 Add resilient food lookup recovery`. NUTRIENTS-001 is accepted and ready for its focused commit.

## Current component

`REFINE-001`: competitor/safety research, welcome/setup, explainable Plan and calorie goal, NUTRITION-GOALS-001 theoretical macro/fiber references versus measured actuals, weight adaptation, configurable reminders, and hierarchical Settings.

`STATES-001` and `NUTRIENTS-001` are accepted and complete.

## Remaining sequence

1. REFINE-001 — prerequisite complete; full onboarding/calorie-goal/weight-adaptation/custom-reminder/Settings scope plus NUTRITION-GOALS-001 calorie-goal-derived macro/fiber reference composition versus measured actuals is preserved under `COMPLETION-PLAN.md#refine`
2. AUXILIARY-001 — Widget and Live Activity
3. CONSISTENCY-001
4. ROBUSTNESS-001
5. FINAL-001, final screenshots, judges, validation, and `FINAL-REPORT.md`

## Current validation baseline

- exact-tree `just validate 300`: passed
- hostless: 140 passed / 2 opt-in live skips
- functional UI target: 12/12 passed through `just test-ui 420`
- simulator build/install/launch: passed
- app-hosted: 167 passed / 2 opt-in live skips after one bounded host recovery
- NUTRIENTS critical/high visual acceptance: 3/3 APPROVE

## Immediate action

Create focused NUTRIENTS-001 commit excluding `.TASK_NOTES.md`, then begin REFINE-001 competitor and nutrition-safety research/specification. Include NUTRITION-GOALS-001: derive theoretical macro gram ranges and Fiber reference from calorie goal, then compare them with real measured intake without calling one composition universally ideal.
