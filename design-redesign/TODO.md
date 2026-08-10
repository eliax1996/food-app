# Product iteration TODO

Live execution queue. Read with `STATUS.md` and `COMPLETION-PLAN.md`. Check items only after code, evidence, tests, and durable docs agree.

## Active — REFINE-001

### Research and specification

- [x] Re-read project status, backlog, completion plan, working notes, current Settings/reminder/profile code, tests, and accepted style.
- [x] Review current official help and retained UI evidence for MacroFactor, MyFitnessPal, Lose It!, Yazio, Lifesum, Cronometer, and Foodnoms.
- [x] Review Apple HIG/Developer guidance for onboarding, data entry, settings, notifications, privacy, HealthKit, accessibility, and 44 pt controls through Xcode Documentation Search.
- [x] Review initial authoritative safety sources: CDC gradual loss, NIDDK Body Weight Planner limits/scope, Mifflin–St Jeor validation, and National Academies nutrient references.
- [x] Finish `docs/refine-plan-reminder-assessment.md` with source-linked findings, current-app critique, decisions, state machines, formulas, migration, privacy, accessibility, and acceptance rules.

### Slice A — Plan references + focused Settings

- [x] Add deterministic calorie-goal-derived carbohydrate/protein/fat gram ranges and Fiber reference domain model.
- [x] Add focused Plan surface showing current manual calorie goal, calculation basis, adult references, and coverage-gated comparison with today’s measured intake.
- [x] Replace mixed flat Settings form with calm native hierarchy while preserving age, target weight/date, calorie goal, reminders, and explicit save/cancel behavior.
- [x] Preserve existing `dailyCalorieGoal` as manual; never silently replace it with calculated value.
- [x] Add domain and UI regression coverage.
- [x] Build, run, capture normal/dark/Accessibility evidence, inspect pixels/hierarchy, and iterate on visible defects.

### Slice B — Configurable reminders

- [x] Replace hard-coded meal reminder hours with independently persisted exact times; retain only-when-not-logged behavior.
- [x] Add weight reminder with researched daily/weekly semantics and configurable time.
- [x] Keep water reminders independent and explain current two-hour window behavior.
- [x] Request notification authorization only after explicit reminder save; expose denied state and direct system-settings recovery without claiming delivery.
- [x] Cover custom times, elapsed reminders, DST/calendar behavior, meal suppression, preference independence, weight cadence, and 64-request cap.
- [x] Capture normal, denied, dark, large-text, and small-device evidence.

### User-requested follow-up — Weight and numeric entry

- [x] Keep Weight → editor → Save as two deliberate actions with no intermediate screen.
- [x] Default new weight to latest valid chronological measurement, then profile current weight, then 70 kg.
- [x] Add `−1`, `−0.1`, `+0.1`, and `+1` kg controls with immediate valid one-decimal updates.
- [x] Add native keyboard Done to every numeric/decimal pad; dismissal must not save.
- [x] Add deterministic and focused UI coverage plus normal/dark/large-text evidence.

### Slice C — Welcome + explainable calorie plan

- [ ] Specify supported adult population and exclusions before calculator code.
- [ ] Add skippable/resumable welcome setup with goal mode, current/target weight, age, height, equation-required physiological input, activity examples, units, and rate/date feedback.
- [ ] Implement validated resting-energy estimate, activity factor, bounded rate adjustment, infeasible-date handling, transparent breakdown, manual override, and restore-calculated action.
- [ ] Never generate under-1,000 kcal/day adult goals; never treat estimate as medical advice; never auto-change existing manual goal.
- [ ] Add deterministic boundaries, units, finite math, calendar, migration, localization, and UI journey tests.

### Slice D — Weight adaptation

- [ ] Define minimum observation window, food-log coverage, weigh-in coverage, trend method, confidence, cadence, and adjustment bounds from retained sources.
- [ ] Add explainable proposal only; user confirmation required; reversible; no response to one reading or short plateau.
- [ ] Distinguish measurement noise, logging gaps, and expenditure uncertainty without asserting one cause.
- [ ] Add deterministic and UI coverage plus visual evidence.

## Remaining whole-product sequence

- [ ] AUXILIARY-001 — widget and Live Activity audit/improvement.
- [ ] CONSISTENCY-001 — cross-screen terminology, spacing, typography, iconography, actions, and state language.
- [ ] ROBUSTNESS-001 — light/dark, Dynamic Type, small/large phones, long/extreme/empty/dense states.
- [ ] FINAL-001 — final journeys, screenshots, independent reviews, final validation, and `FINAL-REPORT.md`.
- [ ] Competitor-gap iteration — after closure, reassess current category products and implement next evidence-backed missing feature without copying branded styles.
