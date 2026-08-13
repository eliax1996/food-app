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

- [x] Specify supported adult population and exclusions before calculator code.
- [x] Add skippable/resumable welcome setup with goal mode, current/target weight, age, height, equation-required physiological input, activity examples, units, and rate/date feedback.
- [x] Implement validated resting-energy estimate, activity factor, bounded rate adjustment, infeasible-date handling, transparent breakdown, manual override, and restore-calculated action.
- [x] Never generate under-1,000 kcal/day adult goals; never treat estimate as medical advice; never auto-change existing manual goal.
- [x] Add deterministic boundaries, units, finite math, calendar, migration, localization, and UI journey tests.

### User-requested follow-up — Direct Settings entry

- [x] Make every meal `Off`/time summary row open reminder editor without changing saved state.
- [x] Make Weight and Water summary rows open same explicit reminder editor; retain top Edit.
- [x] Prove `Plan → Calculate a starting goal` opens setup, Continue advances, Close preserves draft, and next tap resumes from Settings.
- [x] Add focused UI coverage and inspect normal/large-text interaction affordances.

### Slice D — Weight adaptation

- [x] Define minimum observation window, explicit all-day food-log coverage, weigh-in coverage, trend method, evidence agreement, cadence, adjustment bounds, mutation gateway, and exact revert contract in `../docs/adaptive-calorie-plan-specification.md`.
- [x] Add explainable proposal only; user confirmation required; reversible; no response to one reading or short plateau.
- [x] Distinguish measurement noise, logging gaps, and expenditure uncertainty without asserting one cause.
- [x] Add deterministic and UI coverage plus visual evidence.

## Complete — BULK-AI-FOOD-001

- [x] Deep competitor and Apple Foundation Models/Speech research; write detailed data model, pipeline, privacy, fallback, review, learning, LRU, accessibility, and acceptance specification before code.
- [x] Implement deterministic extraction/review models, validation, matching/ranking, retained-learning/draft LRU, and atomic idempotent batch persistence.
- [x] Implement typed SystemLanguageModel flow, async food matching, editable review, and manual/saved/custom/unavailable recovery.
- [x] Implement SpeechAnalyzer dictation, permission/assets/lifecycle recovery, local-data controls, deterministic tests, and light/dark/AX3 evidence.
- [x] Redesign meal-reminder overview to show every saved time and Enabled/Disabled state; separate enablement from timing behind one customization action.

## Whole-product closure

- [x] AUXILIARY-001 — accepted attempt 01: goal-aware medium widget, explicit Live Activity lifecycle, durable widget-water handoff, and visual evidence.
- [x] CONSISTENCY-001 — accepted attempt 01: cross-product language, action semantics, shared bounds, states, navigation, and destructive behavior reconciled.
- [x] ROBUSTNESS-001 — accepted attempt 01: full appearance/type/device/data stress matrix, accessibility stacking fixes, and focused reachability proof.
- [x] FINAL-001 — final journeys, 14 screenshots, exact +15 kcal proof, 3/3 independent approval, final gates, and `FINAL-REPORT.md` complete.

## Future product work

- [ ] Competitor-gap iteration — after closure, reassess current category products and implement next evidence-backed missing feature without copying branded styles.
