# Redesign status

## Baseline status

Complete: build, launch, primary flow, 9 screenshots, architecture audit, current App Store reference sample.

## Completed components

- HOME-001 / CALORIES-001 / WATER-001 / MEALS-001: accepted attempt 11. Budget-first summary, 44pt water actions, compact meal summaries/details, explicit Log Food, secondary Food Tools menu.
- MEAL-001: accepted attempt 03. Explicit Add/Save, search/scanner, exact amount/servings, presets, live total, adaptive Accessibility Menu rows.
- FOOD-SEARCH-001: accepted attempt 02. Recents, top search, full catalog, reliable full-row selection.
- FOOD-CREATE-001 / BARCODE-001 presentation: accepted attempt 04. Secondary large Form, visible disabled lookup, custom-food round trip verified.
- FOOD-REMOTE-SEARCH-001: accepted attempt 02. Official flat Search-a-licious search, bounded persistent query cache, explicit load more, attribution, and selected-food persistence verified.
- AMOUNT-EDITOR-001: accepted attempt 01. Prototype A inline amount controls, exact validation, g/ml semantics, accessibility layout, and keyboard-free correction verified.
- HISTORY-001 / PROGRESS-001 / WEIGHT-001: accepted attempt 02. `History` is now `Progress`; target-aware seven-day calories, fourteen-reading weight trend, useful empty Weight action, and locale-safe Cancel/Save recording are verified as pre-TRACKING baseline.
- STATES-001: accepted attempt 04. Truthful remote loading/terminal empty/offline states, permission-specific scanner recovery, draft-preserving scanner cancellation, and inline barcode loading/not-found/offline/success recovery are visually and functionally verified.
- NUTRIENTS-001: accepted attempt 01. Optional carbohydrate/protein/fat/fiber API mapping, cache migration, Food serving facts, immutable PlateEntry snapshots, custom-food entry, explicit coverage, and transparent general-adult measured guidance are visually and functionally verified.
- REFINE-001 Slices A/B: accepted attempt 01. Calorie-goal-derived Plan references, hierarchical Settings, explicit Plan/Profile/Reminder transactions, exact meal times, Daily/Weekly weight reminders, contextual notification authorization, denied recovery, and authorization-return rescheduling are verified.
- REFINE-001 Slice C: accepted attempt 02. Skippable/resumable supported-adult setup, explicit Mifflin–St Jeor inputs, transparent routine/rate/date calculation, infeasible recovery, Manual migration, override, and restore are verified.
- REFINE-001 Slice D: accepted attempt 03. Explicit complete-day evidence, stable migration-safe identity, coincident 28/35/42 estimates, bounded proposal-only adaptation, serialized compare-and-set mutation, truthful collecting/check-data states, Adapted source, per-day goal history, explicit disable/zero-intake confirmation, and exact revert are verified.
- WEIGHT-ENTRY-001: accepted attempt 01. Latest-measure defaults, direct `−1/−0.1/+0.1/+1` kg controls, and keyboard Done across all numeric entry surfaces are verified.
- SETTINGS-DIRECT-EDIT-001: accepted attempt 01. Reminder overview shows every saved meal time plus Enabled/Disabled state; one **Customize Meal Reminders** action separates meal enablement from notification timing; Weight and Water retain focused draft editing. Plan calculated setup opens, continues, closes, and resumes reliably.
- BULK-AI-FOOD-001: accepted attempt 01. Typed/on-device dictated descriptions produce provisional editable rows; nutrition stays record-owned; explicit/default estimates require acceptance; local retained choices and seven-day drafts are bounded/clearable; confirmation is atomic and idempotent with custom/saved recovery.
- AUXILIARY-001: accepted attempt 01. Medium widget shows remaining/over goal and durable water controls; explicit start/stop Live Activity uses goal-aware Lock Screen and Dynamic Island layouts without display-only mutations.

## Current component

REFINE-001 — **ACCEPTED; ATTEMPTS 01–03 / SLICES A–D COMPLETE**.

BULK-AI-FOOD-001 — **ACCEPTED; ATTEMPT 01 COMPLETE**. Typed and dictated local-first extraction, editable review, verified nutrition matching, manual/custom recovery, truthful privacy controls, bounded retained learning/drafts, and atomic idempotent confirmation are implemented. Final critical/high code-review consensus: **3/3 APPROVE**.

AUXILIARY-001 — **ACCEPTED; ATTEMPT 01 COMPLETE**. Widget/Live Activity now match Today’s remaining-calorie hierarchy, widget water is locked/revisioned into SwiftData, and Live Activity lifecycle is explicit. Final critical/high code-review consensus: **3/3 APPROVE**.

Whole-product closure plan: `COMPLETION-PLAN.md`. TRACKING-IA-001 remains **ACCEPTED — ATTEMPT 01 / COMPLETE** with final root order:

```text
Today | Weight | Progress | Settings
```

STATES-001, NUTRIENTS-001, NUTRITION-GOALS-001, hierarchical Settings/reminders, calculated setup, evidence-gated adaptation, direct Settings entry, numeric-entry refinements, BULK-AI-FOOD-001, and AUXILIARY-001 are complete. Global/final review follows.

## Next components

1. CONSISTENCY-001
2. ROBUSTNESS-001
3. FINAL-001 and `FINAL-REPORT.md`

## Accepted design principles

- Native SwiftUI before custom chrome.
- Remaining calories is primary daily answer.
- Repeated logging outranks food-database administration.
- Meal type should organize entries, not appear as tiny metadata.
- One clear action label per task; avoid `OK`.
- Semantic colors and typography; never color-only meaning.

## Accepted design decisions

- Root order is exactly `Today`, `Weight`, `Progress`, `Settings`; rename `Counter` → `Today` and `Config` → `Settings`.
- Weight root destination navigation title is `Weight Log`.
- Weight shows current/recent-seven-reading/target summary, compact raw-seven-reading native line + points with target rule, endpoint dates only when at least two readings, and a prompt for one reading.
- Weight toolbar add records value plus independently editable date/time. Measurements group newest-first by local calendar date; rows edit/backdate; multiple same-day readings remain distinct.
- Weight deletion requires confirmation and stacked undo.
- `View full trends` selects Progress / Weight. Progress owns fuller fourteen-reading analytics and has no weight CRUD.
- Settings removes current-weight recording but retains target weight, age, calorie goal, target date, and reminders.
- No calorie CRUD and no generic Calories/Water/Weight table; future calorie history is a separate date-first day diary.
- Preserve all existing functionality and offline behavior.
- Move custom-food/barcode tools out of dashboard hierarchy, not remove them.
- Use DEBUG-only in-memory design-review states.
- Normal Dynamic Type is visual target for accepted/final screenshots. Accessibility sizes are stress evidence only; never present them as default design.

## Feature opportunities

- MUST HAVE: meal-grouped daily log — implemented.
- MUST HAVE: remote API food search with persistent query/page LRU and explicit load-more semantics — implemented and accepted as FOOD-REMOTE-SEARCH-001 attempt 02.
- HIGH VALUE: keyboard-free ±10/±1 amount editor — implemented and accepted; recent/frequent foods — recents implemented; target-aware calorie trend — implemented and accepted in Progress analytics.
- HIGH VALUE: revised TRACKING-IA-001 Weight root/log and Progress handoff — **accepted attempt 01 / complete**.
- HIGH VALUE: NUTRIENTS-001 daily macro/fiber summary and transparent nutrition-balance guidance — implemented and accepted attempt 01.
- HIGH VALUE: NUTRITION-GOALS-001 theoretical adult macro/fiber reference values derived from calorie goal versus real measured intake — implemented and accepted with REFINE attempt 01.
- HIGH VALUE: latest-measure weight defaults, coarse/fine adjustments, and explicit numeric-keyboard Done — implemented and accepted as WEIGHT-ENTRY-001 attempt 01.
- HIGH VALUE: explainable optional calorie setup with transparent Manual/Calculated source and reversible restore — implemented and accepted as REFINE attempt 02.
- HIGH VALUE: direct reminder summary and Plan setup entry — implemented and accepted as SETTINGS-DIRECT-EDIT-001 attempt 01.

Detailed active backlog: `PRODUCT-BACKLOG.md`.

## Open questions

- Best balance between one global Log Food action and per-meal add actions.
- Slice D resolved and accepted: 42 explicit complete days, distributed weights, 28/35/42 agreement, weekly fresh evidence, ±100-kcal proposals, and exact revert.
- Whether deferred personal macro targets should be editable in addition to transparent adult population reference defaults.
- Future cross-device consistency.

## Technical debt discovered

- Dashboard owns food library, scanner, persistence, widget, activity, reminders, and presentation state.
- No reusable semantic accessibility summary for daily status.
- Numeric keyboard activation emits source-less iOS 27 SwiftUI `Invalid frame dimension (negative or non-finite).` runtime diagnostics in Food Tools and related UI tests; every flow passes with no visible defect or source frame.
- Weight raw same-day/backdated persistence is implemented; duplicate-profile and future-row correctness fixes are covered by passing app-hosted persistence runs.

## Validation snapshot

- Latest exact-tree `just validate 300`: **passed** after Slice D final docs/code.
- Hostless validation: **178 passed / 2 opt-in live skips**.
- Simulator compile, install, and launch: **passed**.
- `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`.
- Latest explicit UI target: **31/31 passed** through `TEST_CASE_TIMEOUT=60 just test-ui 1200`, adding Today attestation and adaptive collecting/proposal/apply/decline/close/disable/revert/source regressions to existing core coverage.
- App-hosted tests: **250 passed / 2 opt-in live skips**.
- Hostless tests: **195 passed / 2 opt-in live skips**.
- Full UI results retain source-less iOS 27 `Invalid frame dimension (negative or non-finite).` diagnostics while numeric keyboards open; no test or rendered flow failed.

## Visual evidence

Accepted TRACKING-IA-001 visual files are only these attempt-01 files under `screenshots/TRACKING-IA-001/`:

- `attempt-01-four-tabs.png`
- `attempt-01-weight-populated.png`
- `attempt-01-weight-empty.png`
- `attempt-01-weight-accessibility3.png`
- `attempt-01-weight-dark.png`

Superseded three-tab captures remain historical only: `superseded-three-tab-two-same-day.png`, `superseded-three-tab-backdated.png`, `superseded-three-tab-editor.png`, and `superseded-three-tab-delete-confirmation.png`.

`rejected-one-reading-chart.png` remains rejected historical evidence: single dot/dead chart; final behavior prompts until two readings.

Accepted STATES-001 evidence is under `screenshots/STATES-001/`; `attempt-04-remote-offline.png` is the final live post-fix remote capture. Attempt 02 scanner and attempt 03 barcode captures are accepted supporting state/accessibility evidence; `attempt-01-remote-offline-small-retry.png` remains explicitly rejected.

Accepted NUTRIENTS-001 attempt-01 evidence is under `screenshots/NUTRIENTS-001/`: Today, complete, measured-gap, partial, AX3-dark, custom-food entry, and normal/AX3-dark nutrient editor captures. Final critical/high visual judgment: **3/3 APPROVE**.

Accepted REFINE-001 attempt-01 evidence is under `screenshots/REFINE-001/`: Settings, Plan/reference/editor/partial, reminders/editor/denied/small/AX3-dark, Today, and corrected nutrition detail.

Accepted REFINE-001 attempt-02 evidence adds setup welcome/body/infeasible/review/AX3-dark plus Manual-entry and Calculated-basis Plan states. Final bounded visual and code judgments: **APPROVE**.

Accepted REFINE-001 attempt-03 evidence adds Today In progress/genuine-zero confirmation/Complete/Needs review, exact collecting status, proposal evidence/actions, Applied/revert, and AX3-dark disable confirmation. Final critical/high architecture, safety, native-UI, historical-goal, and visual judgments: **APPROVE; visual 3/3 consensus**.

Accepted SETTINGS-DIRECT-EDIT-001 evidence is under `screenshots/SETTINGS-DIRECT-EDIT-001/`: normal and AX3-dark actionable reminder summaries. Final visual judgment: **APPROVE**.

Accepted WEIGHT-ENTRY-001 evidence is under `screenshots/WEIGHT-ENTRY-001/`: normal editor and AX3-dark adaptive editor. Final bounded visual and code judgments: **APPROVE**.
