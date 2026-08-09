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

## Current component

NUTRIENTS-001 — **NEXT / READY FOR RESEARCH AND DATA-MODEL AUDIT**.

Whole-product closure plan: `COMPLETION-PLAN.md`. TRACKING-IA-001 remains **ACCEPTED — ATTEMPT 01 / COMPLETE** with final root order:

```text
Today | Weight | Progress | Settings
```

STATES-001 is complete. Current work begins daily nutrient persistence, coverage, presentation, and explainable guidance before deferred Refine, auxiliary surfaces, global consistency, robustness, and final review.

## Next components

1. REFINE-001 — deferred until NUTRIENTS is complete; welcome setup, explainable calorie-goal calculator, weight reminders/adaptive tuning, custom meal windows, and hierarchical Settings. Full preserved scope: `COMPLETION-PLAN.md#refine`.
2. AUXILIARY-001 — Widget and Live Activity
3. CONSISTENCY-001
4. ROBUSTNESS-001
5. FINAL-001 and `FINAL-REPORT.md`

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
- HIGH VALUE: NUTRIENTS-001 daily macro/fiber summary and transparent nutrition-balance guidance — newly requested; data-model/API completeness research pending immediately after STATES-001.

Detailed active backlog: `PRODUCT-BACKLOG.md`.

## Open questions

- Best balance between one global Log Food action and per-meal add actions.
- Exact evidence-based calorie equation, required inputs, safety bounds, adjustment cadence, and confidence rules for deferred REFINE-001.
- Whether meal reminders should use exact times or configurable windows after competitor research.
- Future cross-device consistency.

## Technical debt discovered

- Dashboard owns food library, scanner, persistence, widget, activity, reminders, and presentation state.
- No reusable semantic accessibility summary for daily status.
- Nutrition macros are not persisted on `Food`/`PlateEntry`.
- Weight raw same-day/backdated persistence is implemented; duplicate-profile and future-row correctness fixes are covered by passing app-hosted persistence runs.

## Validation snapshot

- Latest exact-tree `just validate 300`: **passed**.
- Hostless validation: **130 passed / 2 opt-in live skips**.
- Simulator compile, install, and launch: **passed**.
- `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`.
- Latest explicit UI target: **11/11 passed** through `just test-ui 420`, covering core logging/tracking plus remote, scanner, and barcode recovery states.
- App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and passed again in an integrated run.
- One later standalone `just test-app-unit 300` timed out before XCTest. This is external Xcode 27 host instability, not a red product gate.

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
