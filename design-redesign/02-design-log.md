# Component design log

## [HOME-001] Today dashboard

### Purpose

Answer three repeated daily questions quickly: calories remaining, what has been logged, and how to log next food/water.

### Current implementation

Grouped `List` containing daily calorie/water summary, separate water Stepper, flat meal rows, custom-food form, and barcode controls. Add/edit meal uses a medium/large sheet.

### Current strengths

- Calm native structure.
- Calories and water visible without navigation.
- Core add/edit/delete and scanner behaviors exist.
- Semantic orange/blue/red status colors.

### Problems

- Remaining calories is secondary to percentage.
- Low-frequency food administration crowds dashboard.
- Flat meal list hides meal organization and totals.
- Core log action has weak prominence.
- Lower fields appear beneath floating tab bar.
- Summary and meal strings are fragile at large text sizes.

### Competitive comparison

Foodnoms and Lose It foreground remaining budget, macro/goal status, and meal-grouped logs. MacroFactor and Lifesum expose immediate search plus recent/often-logged foods. Repeated category convention: status first, meal structure second, one-tap logging near each meal or persistent primary action.

### Native iOS comparison

Current use of `List`, semantic colors, `TabView`, and sheets is strong. Native review flags bottom safe-area overlap, compact stepper hit targets, weak VoiceOver grouping, and probable large-type crowding. Remedy should preserve native containers instead of introducing decorative cards.

### Missing opportunities

- Per-meal totals and add actions.
- Recent/frequent shortcuts.
- Goal-aware status language for near/exceeded states.
- Compact target-aware progress summary.

### Proposed direction

Make remaining calories dominant; expose consumed and goal as clear supporting values; keep water as compact quick action; organize entries by meal; move custom-food/barcode controls to secondary Food Tools sheet; rename primary action to `Log food`.

### Success criteria

- Remaining calories understood in under two seconds.
- Log Food visible without scrolling.
- Breakfast/lunch/dinner/snack organization and totals visible.
- All existing add/edit/delete/water/barcode/custom-food behavior preserved.
- No content appears trapped under floating tab bar.
- 44-point controls, useful VoiceOver values, no color-only status.
- Normal, empty, near-target, exceeded, and long-name states remain coherent.

### Hypothesis

Stronger status hierarchy plus meal-grouped rows will reduce parsing and repeated logging cost while removing administrative clutter from daily flow.

### Attempts

Eleven preserved attempts. Early section-based versions improved hierarchy but remained too tall. Two safe-area/material experiments had no effect and were rejected. Compact meal summaries plus navigable meal details solved density without removing edit/delete behavior. Water action variants were tested at 84×74, sub-44, then accepted at measured 44×44.

Accepted: `screenshots/HOME-001/attempt-11.png`.

Result: calorie answer, water actions, Log Food, and all four meal summaries fit without scrolling or tab collision. Secondary food tools remain available through native toolbar menu. Full evidence: `experiments/HOME-001.md`.

## [MEAL-001] Log food

### Purpose

Select meal and food, enter consumed amount/servings accurately, understand calculated calories, and commit with minimal friction.

### Current implementation

Large native Form sheet with segmented meal type, dedicated food navigation, scanner, exact numeric fields, serving presets, live total, and explicit Add/Save action.

### Current strengths

- Task sequence reads top to bottom.
- Exact inputs and presets support both accuracy and speed.
- Scanner remains adjacent to food choice.
- Calculated total is clear before commit.

### Problems

Original selector was hidden and slider-first. Attempt 01 had a narrow row hit region. Accessibility3 exposed sheet environment propagation and malformed Picker rendering.

### Competitive comparison

Lifesum and MacroFactor prioritize search, often-logged foods, and quick quantity controls. Current direction adopts category speed conventions without copying promotional color/AI styling.

### Native iOS comparison

Uses NavigationStack, Form, searchable list, segmented controls at normal sizes, and Menu rows at accessibility sizes. Cancel/Add semantics replace vague OK.

### Missing opportunities

Favorites and meal templates could further reduce repeated work, but recents solve immediate local repetition without new persistence.

### Proposed direction

Accepted normal design is attempt 03. Keep semantic typography and allow Accessibility sizes to become vertically scrollable rather than shrinking text.

### Success criteria

- Food selection within two taps for recent items.
- Exact amount fields visibly editable.
- Serving preset updates total immediately.
- Add/Save outcome explicit.
- Search selection and cancel/save behavior reliable.
- Accessibility text never clips; compact segmented controls become Menu rows.

### Hypothesis

Search-first selection plus exact inputs and live feedback will reduce logging errors and repeated interaction cost.

### Attempts

Three normal attempts. Attempt 03 received two independent ACCEPT verdicts (`8.7`, `8.6`) and one ITERATE (`8.1`). Luna `max` then verified Accessibility3 Menu rows and reachability without clipping. Accepted: `screenshots/MEAL-001/attempt-03.png`. Full evidence: `experiments/MEAL-001.md`.

## [FOOD-SEARCH-001] Choose food

### Purpose

Find a repeated or catalog food quickly and return its serving to Log Food.

### Current implementation

Dedicated native searchable list with Recently Logged and All Foods sections, live filtering, full-row buttons, and selected-food checkmark.

### Current strengths

- Recent choices appear before catalog.
- Search remains visible at top.
- Metadata consistently shows calories and serving.
- One-tap result selection updates editor amount and total.

### Problems

Original inline expansion clipped and limited results. First dedicated attempt had incomplete hit shape and bottom search overlap.

### Competitive comparison

Matches MacroFactor/Lifesum category convention of recents plus immediate search while retaining calmer native density.

### Native iOS comparison

Uses List, Section, searchable navigation drawer, semantic checkmark, and ContentUnavailableView for no results.

### Missing opportunities

Favorites and frequency ranking remain optional; current recency derivation needs no new model.

### Proposed direction

Keep current accepted native list. Do not add images or extra cards without evidence.

### Success criteria

- Recent food visible before typing.
- Search filters immediately.
- Entire result row is tappable.
- Long names and metadata remain readable.
- Selection returns with correct default serving.

### Hypothesis

Recents plus full catalog search will make repeated foods faster without hiding breadth.

### Attempts

Attempt 02 accepted after Banana search/select functional pass. Full evidence: `experiments/FOOD-SEARCH-001.md`.

## [FOOD-REMOTE-SEARCH-001] Remote food search

### Purpose

Find valid foods absent from local/saved data without delaying local results, wasting duplicate requests, or losing offline selections.

### Current implementation

Search-a-licious official flat `hits` run separately from barcode product lookup. Query state uses current language plus `en` fallback, minimum 3 graphemes, 750 ms debounce, and page size 5. Useful local, cached, and remote foods merge by valid barcode; fewer than five useful results auto-fetch one page, while explicit load more requests further work. Final snapshots and query/page generations prevent stale work from replacing newer state.

Positive data has 30-day freshness; empty-terminal knowledge has 90-day freshness. A rolling process limiter allows 10 requests per minute. Persistent query state uses one JSON LRU bounded at 2,048 queries / 32 MiB, with no write on read. Open Food Facts attribution is visible. Selected food persists normalized data without product refetch, and DEBUG uses deterministic responses.

### Attempt 01

Screenshot: `../screenshots/FOOD-REMOTE-SEARCH-001/attempt-01-results.png`

Full `ContentUnavailableView` for empty Saved foods consumed 234 pt and pushed remote controls beneath the keyboard.

Decision: **REJECTED**.

### Attempt 02

Screenshots:

- `../screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-results.png`
- `../screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-selected.png`
- `../screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-persisted.png`

Replaced full unavailable state with compact `Saved foods` empty row. Manual Xcode flow selected Remote Oat Drink at 250 ml / 100 kcal, dismissed keyboard, increased daily total by exactly 100 kcal after save, and confirmed persisted local row. Attempt 02 is visually accepted.

### Evidence and validation

- Measurement: 64 representative one-page five-hit queries = 65,841 bytes; 2,048 projected = 2,106,912 bytes (about 2.01 MiB). Count cap governs typical data; 32 MiB guards long/multipage outliers.
- Focused suites: client 11, cache 6, service 15, coordinator 8. Current hostless aggregate: 85 pass / 2 opt-in skips. Timed-out partial search responses are rejected rather than cached as terminal.
- UI suite before final focus fix: 2 pass / 2 fail from lingering keyboard. Focus fix passed manual review. Later attempts were blocked before XCTest by process-handle failures even after recovery; exact-tree `just test-ui 300` then timed out before XCTest and reset the simulator. UI suite is not green.

### Decision

**ACCEPTED — ATTEMPT 02**

Reason: compact empty-state treatment preserves hierarchy and keyboard-safe remote interaction; architecture, persistence, manual behavior, and accepted screenshots meet feature requirements. Next phase: `AMOUNT-EDITOR-001`.

## [AMOUNT-EDITOR-001] Human-friendly amount adjustment

### Purpose

Make common corrections to food-derived gram/ml amounts fast without making keyboard entry primary.

### Accepted implementation

Prototype A adds `−10`, `−1`, `+1`, `+10` in one normal-size row and a 2 × 2 Accessibility3 grid. Normal measured controls are about `78 × 58 pt`; Accessibility3 controls are `163 × 62 pt`, ordered `−10`, `−1` above `+1`, `+10`. Controls adjust amount only; servings remain separate. Stable identifiers and VoiceOver labels expose actions, g/ml units, and current value. Common adjustment flow opens no keyboard; exact TextField remains secondary.

Amount rules require finite exact values, preserve decimal remainders, normalize floating-point boundary results at minimum `0.01`, and use same validity for exact entry and Save.

### Evidence

- Almond Milk manual proof: `100 g / 15 kcal` → `−10` → `90 g / 14 kcal` → `+10` → `100 g / 15 kcal`.
- Remote Oat Drink at `250 ml / 100 kcal` verifies volume labels.
- Accessibility3 proof reached `90 g / 14 kcal`, serving `1`; menus were readable, total reachable, and no clipping appeared.
- Screenshots: `../screenshots/AMOUNT-EDITOR-001/attempt-01-normal.png`, `attempt-01-adjusted.png`, `attempt-01-milliliters.png`, `attempt-01-accessibility3.png`.
- Focused amount tests: 5 pass. Aggregate: 90 pass / 2 opt-in skips. `just check` passed.
- Diagnostic UI test was added. Final attempts were blocked before XCTest because Application launch did not return a process handle after one recover; `just simulator-run` passed. UI suite is not green.

### Decision

**ACCEPTED — ATTEMPT 01**

Reason: Prototype A meets keyboard-free correction, exact-entry fallback, domain-boundary, unit, serving-separation, measured-target, and Accessibility3 evidence requirements. Completed next milestone: `HISTORY-001 + PROGRESS-001 + WEIGHT-001` attempt 02. Next work is separate user-requested navigation-split research.

## [HISTORY-001 / PROGRESS-001 / WEIGHT-001] Progress analytics

### Purpose

Explain calorie adherence and weight direction over time, then support quick weight recording.

### Accepted implementation

Visible `History` became `Progress` in tab and navigation title. A segmented Calories/Weight view remains native and task-focused.

Calories use seven most recent recorded days. Summary makes recorded-day average prominent and states relation to profile goal. Chart uses orange bars, one goal `RuleMark`, seven compact actual day labels, and no bar annotations.

Weight uses current, change, and target text above a line chart. Chart plots latest fourteen raw readings with linear `LineMark` plus points, an adaptive nonzero domain, and target `RuleMark`. Duplicate timestamps remain in input order; valid readings are filtered, sorted, and limited to fourteen. Invalid values are ignored. Calorie summaries filter invalid values, sort and limit to seven, and average with `Double`.

Empty Weight state explains value of recording and exposes direct `Record weight` action. Record/update sheet uses `Cancel` and `Save`, locale-consistent wheel values and header, save-only dismissal, and `modelContext.rollback()` on save failure.

### Competitive comparison

Foodnoms and Cronometer interpret values against targets. Strong category products expose trend/balance rather than raw history alone. This implementation keeps that interpretation in concise native summaries instead of adding dashboard-card chrome.

### Native iOS comparison

Charts use semantic marks: bars for daily intake, line/points for continuous weight data, and standard `RuleMark` target guidance. `List`, segmented Picker, native sheet, wheel Pickers, and toolbar Cancel/Save preserve platform conventions.

### Success criteria

Trend and goal relationship understood in under three seconds; readable axes; no zero-based weight distortion; empty state leads directly to recording; locale and Dynamic Type remain usable.

### Attempts

#### Attempt 01 — rejected

Retained calories evidence: `../screenshots/HISTORY-001/attempt-01-calories.png`.

Rejected for weak one-line gray summary, full month-day labels overlapping, and stale parent-computed sheet header. Keep screenshot as rejected evidence; do not present it as accepted design.

#### Attempt 02 — accepted

Deterministic iPhone 17 Pro preview evidence:

- `../screenshots/HISTORY-001/attempt-02-calories.png`
- `../screenshots/WEIGHT-001/attempt-02-populated.png`
- `../screenshots/WEIGHT-001/attempt-02-empty.png`
- `../screenshots/WEIGHT-001/attempt-02-editor.png`

Attempt 02 fixes hierarchy, actual-day labeling, localized wheel/header rendering, and weight recording affordance. It satisfies `HISTORY-001`, `PROGRESS-001`, and `WEIGHT-001` analytics requirements.

### Evidence and validation

- `ProgressHistoryTests`: 16 pass.
- Aggregate: 106 pass / 2 opt-in skips.
- `just check` passed.
- Diagnostic Progress weight UI test was added. Label/locale test defects were corrected. Fresh Banana diagnosis passed `100 g / 1 / 89 kcal` with keyboard hidden.
- Final `just test-ui 300` timed out before XCTest and reset simulator. UI suite is not green; deterministic preview and hostless evidence are reported separately.

### Decision

**ACCEPTED — ATTEMPT 02** for `HISTORY-001`, `PROGRESS-001`, and `WEIGHT-001`.

Reason: target-aware calorie interpretation, data-appropriate weight trend, useful empty recording path, robust domain rules, and native locale-safe save flow are evidenced without overstating UI-test-host status.

### Next work

Historical note: this milestone's next work was the user-requested navigation split. The later `eae1c92` three-tab/drill-down assessment was superseded by explicit discoverability feedback and dedicated-weight precedent; see revised TRACKING-IA-001 below.

## [TRACKING-IA-001] Revised tracking navigation and Weight Log

### Decision history

Original `eae1c92` assessment selected:

```text
Today | Progress | Settings
```

Initial nutrition evidence favored nesting sparse weight under analytics or a global add flow. User feedback explicitly prioritized discoverability. Current verified dedicated-weight precedent now wins: Happy Scale has Logbook and Reports; Weight Diary Lite exposes graph, summary, and full-log modes; Weigh In separates record, history, and progress actions. Final root order is:

```text
Today | Weight | Progress | Settings
```

This is transparent supersession, not a claim that initial nutrition evidence was wrong. Nutrition references remain relevant to Today/Progress placement and the rejection of generic mixed history.

### Implemented structure

- `Counter` is user-facing **Today**.
- Root **Weight** destination uses navigation title **Weight Log**.
- **Progress** remains analytics-only; its Weight view owns fuller fourteen-reading analytics and no CRUD.
- **Settings** retains target weight, age, calorie goal, target date, and reminders; no current-weight field or save path.
- No calorie CRUD and no generic Calories/Water/Weight table. Future calorie history remains a separate date-first day diary.

### Weight tab

- Toolbar `+` is the add/Record Weight action.
- Summary shows current value, basic recent-seven-reading context, and target.
- Compact basic chart uses latest seven raw readings with native line + points and target rule. Explicit endpoint dates appear only when at least two readings exist.
- One reading shows a useful prompt instead of a single dot/dead chart. Rejected evidence is retained at `../screenshots/TRACKING-IA-001/rejected-one-reading-chart.png` because that chart had no useful trend; final behavior prompts until two readings.
- Measurements are grouped by local calendar date, newest date first, with newest rows first. Multiple same-day readings remain distinct.
- Toolbar add defaults to now and supports independent date/time backdating. Row tap edits value/date/time for one raw record.
- Delete requires confirmation and stacked undo; cancel preserves data.
- `View full trends` selects `Progress` with `Weight` selected.

### Evidence

Accepted TRACKING-IA-001 visual files are only these attempt-01 files under `../screenshots/TRACKING-IA-001/`:

- `attempt-01-four-tabs.png`
- `attempt-01-weight-populated.png`
- `attempt-01-weight-empty.png`
- `attempt-01-weight-accessibility3.png`
- `attempt-01-weight-dark.png`

Superseded three-tab functional history is retained as historical evidence only:

- `superseded-three-tab-two-same-day.png`
- `superseded-three-tab-backdated.png`
- `superseded-three-tab-editor.png`
- `superseded-three-tab-delete-confirmation.png`

`rejected-one-reading-chart.png` retains the rejected single-dot/dead-chart comparison.

### Final results

- `just validate 300`: **passed**.
- Hostless validation: **125 passed / 2 opt-in live skips**.
- Simulator build, install, and launch: **passed**.
- `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`.
- Explicit UI target: **6/6 passed**, covering four tabs; one-reading prompt → two-reading chart; two same-day readings; backdated date regrouping; edit; delete cancel/confirm/undo; Settings; and direct `View full trends` → `Progress` / `Weight`.
- App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and passed again in an integrated run.
- One later standalone `just test-app-unit 300` timed out before XCTest. This is external Xcode 27 host instability, not a red product gate.

### Decision

**ACCEPTED — ATTEMPT 01 / COMPLETE**

### Next component

`empty/error/loading states`, followed by global consistency, dark mode, Dynamic Type, and small-device checks.

## [FOOD-TOOLS-001] Barcode and custom food tools

### Purpose

Preserve manual barcode lookup and custom-food creation without crowding repeated daily logging.

### Current implementation

Secondary toolbar menu opens large native Form with Barcode and Custom Food sections.

### Current strengths

Clear separation, exact units, keyboard-safe sheet, valid zero-calorie custom foods, and direct handoff into food selection.

### Problems

Original inline forms overwhelmed Today. Medium sheet clipped Save. Empty barcode action initially looked enabled despite semantic disablement.

### Competitive comparison

Category products place scanner/search adjacent to logging and move food-database administration out of dashboard hierarchy.

### Native iOS comparison

Large Form sheet, semantic disabled color, grouped fields, Done toolbar action, and explanatory footers follow native conventions.

### Missing opportunities

Deterministic UI fixture for successful barcode lookup would remove live-network dependence if this integration needs repeated end-to-end proof.

### Proposed direction

Keep current large sheet. Do not shorten merely to fill space; keyboard and Accessibility sizes need room.

### Success criteria

Tools remain discoverable; invalid barcode action looks disabled; custom food round trip works; no Today clutter; keyboard and large text remain reachable.

### Hypothesis

Progressive disclosure will improve daily hierarchy without removing advanced entry paths.

### Attempts

Attempt 04 accepted after custom-food create/search/select/cancel proof plus visible disabled-state correction. Full evidence: `experiments/FOOD-TOOLS-001.md`.

## [NUTRIENTS-001] Daily measured nutrition balance

### Purpose

Expose carbohydrate, protein, fat, and Fiber without converting missing crowdsourced facts into false zeroes or replacing transparent evidence with a health score.

### Accepted implementation

Open Food Facts v3.6, v2, and search now map independently optional facts into nutrient-aware caches. `Food` stores facts for its serving; each `PlateEntry` stores consumed snapshots, so later food edits never rewrite historical intake. Custom food uses a focused optional Nutrients editor with explicit Done draft commit.

Today keeps remaining calories primary and adds a compact macro-only energy split separated from Fiber, coverage, and one neutral headline. Detail uses native List sections for measured grams, adult ranges, energy-scaled Fiber reference, at most two measured-gap suggestions, exact coverage, source links, label caveat, and nonmedical scope. Macro/Fiber comparisons require 100% corresponding coverage; adult-range macro shares use reported logged calories as denominator while the colored 4/4/9 split stays explicitly normalized across the three measured macros.

### Iteration

Direct screenshot review and independent judges exposed hidden Back controls in root previews, macro/Fiber ambiguity, overly approval-like range language, read-only-looking custom fields, and AX3 card continuation. Corrected evidence uses pushed navigation previews, explicit macro/Fiber separation, `adult range` wording with general-reference copy, visible rounded fields plus Done, and an accessibility text-first macro card with visible boundary.

### Evidence

Accepted attempt-01 files under `../screenshots/NUTRIENTS-001/` cover Today, complete, measured-gap, partial, AX3 dark, Food Tools, and normal/AX3-dark custom nutrient entry. Full record: `experiments/NUTRIENTS-001.md`.

### Validation and decision

- `just validate 300`: 140 hostless pass / 2 opt-in skips; simulator build/install/launch passed.
- `just test-app-unit 420`: 167 pass / 2 skips after one bounded Xcode-host recovery.
- `just test-ui 420`: 12/12 pass, including custom nutrient entry → immutable logged snapshot → daily balance.
- Final critical/high visual judgment: 3/3 `APPROVE`.

**ACCEPTED — ATTEMPT 01 / COMPLETE.** Next: REFINE-001, including queued NUTRITION-GOALS-001 theoretical calorie-goal-derived ranges versus measured actuals.

## [REFINE-001] Plan references, focused Settings, and configurable reminders

### Accepted implementation

Settings now separates Plan, Profile, and Reminders. Existing calorie goals stay explicitly Manual. Focused editors use draft state, Save/Cancel, and no swipe-to-discard. Plan derives adult carbohydrate/protein/fat gram ranges and Fiber reference from the current calorie goal, shows method/scope, and keeps partial measured data honest.

Meal reminders use independent exact times. Weight reminders support Daily/Weekly; weekly waits seven local-calendar days after latest weight. Water remains independent. Permission is requested only after Save expresses intent; denial preserves selected preferences and exposes iOS Settings recovery; returning authorization reschedules immediately.

### Critical iterations

Review corrected overdue weekly timing, localized reminder windows, accidental sheet dismissal, unsupported goal-history copy, authorization-return rescheduling, and AMDR denominator math. Today now labels the normalized colored bar macro-only, shows grams, and uses reported logged calories only for adult-range shares. Compact meal rows preserve all four groups above the floating tab bar.

### Evidence and validation

Evidence under `screenshots/REFINE-001/` covers Settings, Plan/editor/partial, reminder summary/editor/denied/small/AX3-dark, Today, and nutrition detail. Three bounded visual groups and bounded domain/UI reviewers approved final critical/high state.

- `just validate 300`: 155 pass / 2 live skips; simulator build/install/launch passed.
- `just test-app-unit 420`: 184 pass / 2 live skips.
- `just test-ui 600`: 14/14 pass.

**ATTEMPT 01 ACCEPTED — SLICES A/B COMPLETE.** REFINE continues with welcome/setup and explainable calculated calorie plan.

## [WEIGHT-ENTRY-001] Low-friction weight and numeric entry

### Accepted implementation

Weight → toolbar add → editor → Save remains two deliberate actions. New drafts use latest valid nonfuture measurement, then profile current weight, then 70 kg. `−1`, `−0.1`, `+0.1`, and `+1` kg controls update one-decimal value without keyboard; exact input/date/time remain available. Every numeric pad now has native keyboard Done that dismisses focus only, never saves.

Normal and AX3-dark screenshots passed bounded visual review. Deterministic rules, focused latest-default/adjustment/Done UI flow, meal keyboard Done, Plan keyboard Done, exact-tree validation, and final 14/14 UI suite passed.

**ACCEPTED — ATTEMPT 01 / COMPLETE.**
