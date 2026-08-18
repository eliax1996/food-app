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
- CONSISTENCY-001: accepted attempt 01. Food-action language and water bounds are reconciled; whole-app navigation, hierarchy, states, and destructive semantics passed 3/3 critical/high review.
- ROBUSTNESS-001: accepted attempt 01. Light/dark, normal/AX3, small/large, long/extreme/empty/dense matrix is retained; Today water/status and Settings summaries adapt cleanly at accessibility sizes.
- FINAL-001: accepted complete. Final primary journeys, 14 representative captures, exact +15 kcal Almond Milk proof, persistence/nutrition/reminder hardening, 3/3 independent approval, and all final gates are retained.
- COMPETITOR-GAP-001: accepted attempt 01. Selected Progress calorie days now open read-only, date-first Food Diary detail with meal-grouped immutable snapshots, truthful incomplete totals, and recorded-day navigation.

## Current component

None. FINAL-001 closed original redesign. COMPETITOR-GAP-001 then closed queued date-first historical Food Diary gap with normal/AX3-dark evidence, deterministic domain/UI proof, 3/3 independent critical/high approval, and green exact-tree gates.

Current root remains:

```text
Today | Weight | Progress | Settings
```

## Next components

No unchecked roadmap component. Historical diary mutation/copy, personal macro targets, and HealthKit/sync remain separate future proposals requiring explicit contracts.

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
- No historical calorie CRUD and no generic Calories/Water/Weight table; selected Progress days open separate read-only, date-first, meal-grouped Food Diary detail.
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
- HIGH VALUE: date-first historical Food Diary detail — implemented and accepted as COMPETITOR-GAP-001 attempt 01.

Detailed active backlog: `PRODUCT-BACKLOG.md`.

## Deferred opportunities

- Reassess one global Log food action versus per-meal shortcuts only with fresh usage/category evidence.
- Slice D resolved and accepted: 42 explicit complete days, distributed weights, 28/35/42 agreement, weekly fresh evidence, ±100-kcal proposals, and exact revert.
- Whether deferred personal macro targets should be editable in addition to transparent adult population reference defaults.
- Future cross-device consistency.
- Historical diary add/edit/delete/copy only after snapshot, attestation, goal-history, destination, duplicate, confirmation, and undo rules are specified.

## Technical debt discovered

- Dashboard owns food library, scanner, persistence, widget, activity, reminders, and presentation state.
- No reusable semantic accessibility summary for daily status.
- Numeric keyboard activation emits source-less iOS 27 SwiftUI `Invalid frame dimension (negative or non-finite).` runtime diagnostics in Food Tools and related UI tests; every flow passes with no visible defect or source frame.
- Weight raw same-day/backdated persistence is implemented; duplicate-profile and future-row correctness fixes are covered by passing app-hosted persistence runs.

## Validation snapshot

- Current exact-tree `just validate 300`: **passed** — 228 hostless tests / 2 opt-in live skips; app + widget compile, install, and launch passed.
- Current app-hosted `just test-app-unit 600`: **315 passed / 2 opt-in live skips**.
- Current functional `TEST_CASE_TIMEOUT=60 just test-ui 1800`: **47/47 passed**.
- `git diff --check`: **passed**.
- Live Open Food Facts checks remain intentionally opt-in.

## Visual evidence

Final representative set is under `screenshots/final/`; accepted post-closure diary evidence is under `screenshots/COMPETITOR-GAP-001/`. Both are indexed in `SCREENSHOTS.md`; closure comparison and evidence map live in `FINAL-REPORT.md`.

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
