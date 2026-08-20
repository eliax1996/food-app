# REFINE-001 — Plan, setup, Settings, reminders, and adaptation

**Status:** ATTEMPTS 01–03 ACCEPTED — SLICES A–D COMPLETE
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

**ACCEPTED — ATTEMPT 01 / SLICES A AND B COMPLETE.** Plan references, focused Settings, configurable reminders, authorization recovery, and requested numeric-entry follow-up meet acceptance. Historical sequence then continued with Slice C welcome/setup and explainable calculated calorie plan; no calculated or adaptive recommendation was silently added.

### Attempt 02 — Slice C

**State:** ACCEPTED

Pre-code contract: `../../docs/calculated-plan-specification.md`.

#### Implementation

- Added skippable/resumable native welcome flow for scope, goal mode, metric/US body values, explicit Mifflin–St Jeor equation constant, routine examples, rate/date, and review.
- Requires height, equation, and routine selection instead of silently assuming missing inputs. Existing profile age/weights remain prefilled and visible.
- Added published female/male resting equations, transparent routine factors, exact 0.25/0.50 kg weekly choices, local-calendar date-derived rate, 7,700 kcal/kg static planning adjustment, nearest-10 rounding, BMI floor, 1,000–5,000 kcal product bounds, and typed infeasibility.
- Existing profiles migrate Manual byte-for-value and are never auto-replaced. Accepted calculated metadata is reproducible; manual edits retain optional restore; restore returns saved calorie/target/forecast context without changing raw weight logs.
- Setup drafts persist by step. Accepted-plan timestamp reconciliation repairs a crash gap between SwiftData acceptance and setup marker persistence without mistaking a deliberate in-progress redo for completion.
- Plan and Profile show truthful source, accepted inputs, formula components, limitations, and on-device privacy.

#### Review iterations

Independent critical/high review blocked initial code on split acceptance persistence, stale target context after restore, arbitrary weekly rates, fixed-second date defaults, rationale order, and missing boundaries. Fixes added accepted-date reconciliation, full target/forecast restore/display, exact weekly choices, calendar-day defaults, pre-control explanations, and expanded finite/boundary/non-Gregorian tests. Follow-up found nonfinite `Date` handling and remaining boundary gaps; both were fixed. Final isolation review then found test launch flags and preferences could affect release/persistent defaults; in-memory flags are now DEBUG-only and UI/review reminders/setup use isolated suites. Follow-up code review: **APPROVE**.

Visual review exposed no real critical/high defect after bounded recapture. Broad automated visual attempts timed out and one Sol reading falsely claimed visible Back/Close clipping; direct pixel inspection plus a focused independent judge confirmed both controls fully visible. Final bounded groups approved welcome, body, infeasible recovery, review, AX3 dark, Manual Plan entry, and Calculated Plan basis.

#### Evidence

Accepted files under `../screenshots/REFINE-001/`:

- `attempt-02-setup-welcome.png`
- `attempt-02-setup-body.png`
- `attempt-02-setup-infeasible-date.png`
- `attempt-02-setup-review.png`
- `attempt-02-setup-review-ax3-dark.png`
- `attempt-02-plan-manual-entry.png`
- `attempt-02-plan-calculated.png`

#### Validation

- Calculator: **17/17** focused hostless tests.
- Setup state/migration: **6/6** focused hostless tests.
- `just validate 300`: passed; **178 passed / 2 live skips** hostless; simulator build/install/launch passed.
- `just test-app-unit 480`: passed; **210 passed / 2 live skips**.
- `TEST_CASE_TIMEOUT=60 just test-ui 900`: passed **22/22**; every final XCTest completed under one minute. Post-isolation default-cap runs reached 21/22 once on a legacy numeric-entry race and once when a custom-food test hit exactly 60 seconds. Weight lifecycle now uses deterministic adjustment controls, its focused rerun passed, and neither partial suite was called green.
- Xcode 27 retained source-less `Invalid frame dimension (negative or non-finite).` diagnostics around numeric keyboards; no failed final flow or visible defect is associated.

#### Decision

**ACCEPTED — ATTEMPT 02 / SLICE C COMPLETE.** Optional setup is explainable, supported-population-bounded, resumable, reversible, and explicit. Manual goals remain untouched until confirmation. Historical sequence then continued with Slice D evidence-gated adaptation.

### Attempt 03 — Slice D

**State:** ACCEPTED

Pre-code contract: `../../docs/adaptive-calorie-plan-specification.md`.

#### Implementation

- Added explicit Today food-log attestation with In progress, Complete, and Needs review states. Empty completion requires separate genuine-zero confirmation; food calorie/date edits reopen evidence while metadata-only edits do not.
- Added migration-safe stable Plate/Weight identity, immutable evidence snapshots, completion records, goal revisions, Unknown/Adapted sources, epochs, proposal history, and per-day historical goal resolution without fabricating pre-migration context.
- Centralized evidence and plan writes in one app-owned dedicated-context coordinator. Identity migration uses staged fresh-context verification; proposal generation/application use stable operation keys, signatures, revisions, and compare-and-set checks.
- Implemented 42 complete days, distributed weights, coincident 28/35/42 estimates, agreement/noise/discrepancy checks, ±100-kcal proposals, 200-kcal trailing cap, fresh weekly cadence, expiry, explicit apply/decline/close, disable confirmation, and exact revert.
- Goal check-ins expose exact missing date ranges, earliest possible date, progressive method disclosure, neutral limitations, focused hidden tab bar, and normal/AX3-dark layouts.

#### Critical iterations

Reviews found and resolved hidden Revert after disabling, calendar/time-zone epoch lock, stale proposal values, redundant attestations, stale apply retry, missing collection dates, fabricated current-goal history, empty-day ambiguity, destructive disable without confirmation, proposal Close/Decline ambiguity, and sub-44 Today controls. DEBUG fixture setup and UI assertions were tightened after full-suite launch/state races.

#### Evidence

Accepted attempt-03 files under `../screenshots/REFINE-001/` cover Today In progress/genuine-zero confirmation/Complete/Needs review, exact collecting status and bottom actions, proposal details/evidence/actions, applied/revert, AX3 dark, and disable confirmation. Final independent critical/high visual consensus: **3/3 APPROVE**.

#### Validation

- Hostless: **195 passed / 2 opt-in live skips**.
- App-hosted: **250 passed / 2 opt-in live skips**.
- Functional UI: **31/31 passed**.
- Exact-tree `just validate 300`: **passed** (hostless plus simulator build/install/launch).

#### Decision

**ACCEPTED — ATTEMPT 03 / SLICE D COMPLETE.** Adaptation remains evidence-gated, on-device, proposal-only, explicit, reversible, and fail-closed. REFINE-001 is complete; historical sequence then moved to now-complete BULK-AI-FOOD-001.
