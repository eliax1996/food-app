# REFINE-001 — Plan, setup, Settings, reminders, and adaptation

**Status:** ATTEMPT 01 ACCEPTED — SLICES A/B COMPLETE; REFINE CONTINUES
**Started:** 2026-08-10

## Purpose

Turn existing manual profile/reminder form into explainable, safe, native planning controls. Add missing calorie-goal-derived nutrition references and configurable reminders before calculated onboarding or adaptive recommendations.

## Baseline

- One flat Settings `Form` mixes age, target weight, calorie goal, target date, four fixed meal reminders, water reminder, notification recovery, and one bottom save action.
- Profile fields save explicitly; reminder toggles persist immediately.
- Meal times are fixed at 09:00/13:00/16:00/20:00.
- No weight reminder.
- Existing calorie goal has no visible source or calculation basis.
- Baseline images: `../screenshots/baseline/config-top.png` and `../screenshots/baseline/config-reminders.png`.

## Research

Full source-linked competitor, Apple, nutrition, safety, data-model, state-machine, migration, and acceptance assessment: `../../docs/refine-plan-reminder-assessment.md`.

Key decisions:

- Native `Form` hierarchy and progressive disclosure.
- Consistent explicit Save/Cancel transactions.
- Existing calorie goal remains Manual.
- Exact meal times, not windows, because MyFitnessPal, Yazio, and Cronometer expose exact times and no inspected evidence supports window ambiguity.
- Weight reminder supports Daily/Weekly; weekly waits seven days after latest weight.
- Notification permission requested only after reminder Save expresses intent.
- Plan reference math uses adult AMDR percent/gram ranges and Fiber 14 g/1,000 kcal; actual comparisons remain coverage-gated.
- No calculated calorie recommendation or adaptive calorie change in attempt 01.

## Hypothesis

Separating Plan, Profile, and Reminders will reduce scanning and clarify persistence. Showing transparent reference formulas beside trustworthy actuals will make current manual goal useful without pretending it is personalized. Exact conditional times plus truthful authorization state will make reminders controllable and dependable.

## Attempt 01 scope

1. Deterministic `NutritionReferencePlan` domain.
2. Hierarchical Settings root.
3. Plan detail and editor with manual-goal status, reference composition, and measured comparison.
4. Profile detail/editor preserving age.
5. Reminder detail/editor with exact meal times, water preference, Daily/Weekly weight reminder, contextual permission, denied recovery, and explicit Save/Cancel.
6. Planner/manager integration and reschedule after weight changes.
7. Domain, persistence, and critical UI coverage.
8. Normal, dark, Accessibility3, denied, partial, and small-phone visual evidence.

## Non-scope

- No first-launch gate yet.
- No Mifflin–St Jeor recommendation yet.
- No target-date feasibility claim yet.
- No HealthKit permission or sync yet.
- No automatic calorie adjustment.
- No personal macro target editor yet.

## Acceptance

See assessment acceptance rules. Attempt cannot be accepted without exact-tree validation, final UI proof, direct screenshot inspection, and independent critical/high visual review.

## Evidence log

- 2026-08-10: Read current project status, source, tests, and accepted design style.
- 2026-08-10: Reviewed current official help for seven competitors, retained selected Cronometer goal/reminder screenshots, queried Apple documentation through Xcode, and reviewed initial authoritative safety/nutrition sources.
- 2026-08-10: Wrote durable `design-redesign/TODO.md` and first-slice specification before coding.

## Attempts

### Attempt 01

**State:** ACCEPTED

#### Implementation

- Added transparent calorie-goal-derived carbohydrate/protein/fat gram ranges and Fiber reference.
- Replaced flat Settings with Plan, Profile, and Reminders hierarchy.
- Kept every existing calorie goal explicitly Manual; editors use draft state, Save/Cancel, and disabled interactive dismissal.
- Added exact independent meal times, Daily/Weekly weight reminders, independent water behavior, contextual permission request, denied recovery, authorization-return rescheduling, and deterministic 64-request guard.
- Rescheduled reminders after weight add/edit/delete/undo.
- Compacted Today nutrition and meal summaries so all four meal rows clear the floating tab bar in populated normal state.
- Corrected AMDR denominator after independent review: colored bar remains normalized macro-only composition; adult-range shares use reported logged calories. Today shows grams, avoiding conflicting percentages.

#### Iterations caused by review

1. Removed oversized Settings icon treatment and replaced target-weight Stepper with visible exact field.
2. Localized water reminder-window times and Fiber’s 1,000-kcal formatting.
3. Fixed overdue weekly reminder to use today when selected time remains ahead.
4. Disabled swipe dismissal for explicit transactions and removed unsupported “today onward” goal-history copy.
5. Rescheduled saved reminders when notification authorization changes after returning from iOS Settings.
6. Corrected normalized-macro-versus-total-energy AMDR mismatch and added deterministic denominator coverage.
7. Added explicit macro-only labeling and changed Today metrics to grams after visual review found apparently conflicting 49/28/23 versus 53/30/24 percentages.
8. Reduced populated Today density and added frame regression so Snack clears floating tab bar.

#### Evidence

Accepted files under `../screenshots/REFINE-001/`:

- `attempt-01-settings.png`
- `attempt-01-plan.png`
- `attempt-01-plan-partial.png`
- `attempt-01-plan-editor.png`
- `attempt-01-reminders.png`
- `attempt-01-reminder-editor.png`
- `attempt-01-reminders-denied.png`
- `attempt-01-reminder-editor-ax3-dark.png`
- `attempt-01-reminder-editor-small.png`
- `attempt-01-today.png`
- `attempt-01-nutrition-detail.png`

Normal, denied, dark/AX3, partial, editor, small-layout, Today, and detail pixels were inspected directly. Three bounded final critical/high visual groups approved after the denominator/value conflict was corrected. Bounded code reviews approved reminder scheduling/recovery, transaction semantics, nutrition denominator/gates, and deterministic coverage.

#### Validation

- `just validate 300`: passed; **155 passed / 2 live skips** hostless; simulator build/install/launch passed.
- `just test-app-unit 420`: passed; **184 passed / 2 live skips**.
- `just test-ui 600`: passed **14/14**, including Settings transactions, custom nutrients, populated Today/tab clearance, weight-entry controls, and numeric-keyboard Done.
- Xcode 27 retained source-less `Invalid frame dimension (negative or non-finite).` diagnostics while numeric keyboards opened. Tests and rendered pixels show no associated defect; this remains platform/runtime diagnostic evidence, not a failed gate.

#### Decision

**ACCEPTED — ATTEMPT 01 / SLICES A AND B COMPLETE.** Plan references, focused Settings, configurable reminders, authorization recovery, and requested numeric-entry follow-up meet acceptance. REFINE-001 continues with Slice C welcome/setup and explainable calculated calorie plan; no calculated or adaptive recommendation has been silently added.
