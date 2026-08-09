# Visual evidence index

Device unless noted: iPhone 17 Pro, iOS 27.0, portrait, light appearance.

## NAV-001 / TRACKING-IA-001

Baseline: all files under `screenshots/baseline/`

Final root order shown by `screenshots/TRACKING-IA-001/attempt-01-four-tabs.png`:

```text
Today | Weight | Progress | Settings
```

Status: **ACCEPTED — ATTEMPT 01 / COMPLETE**.

Accepted TRACKING-IA-001 visual files are only these attempt-01 files under `screenshots/TRACKING-IA-001/`:

- `attempt-01-four-tabs.png` — four root tabs in final order.
- `attempt-01-weight-populated.png` — Weight Log title, current/recent-seven/target summary, compact raw-seven-reading line + points, target rule, endpoint dates, and grouped newest-first measurements.
- `attempt-01-weight-empty.png` — useful empty Weight Log state with Record Weight action.
- `attempt-01-weight-accessibility3.png` — large-text Weight Log stress capture.
- `attempt-01-weight-dark.png` — dark appearance Weight Log capture.
Superseded three-tab captures retained as historical implementation evidence only:

- `superseded-three-tab-two-same-day.png`
- `superseded-three-tab-backdated.png`
- `superseded-three-tab-editor.png`
- `superseded-three-tab-delete-confirmation.png`

Rejected evidence retained:

- `rejected-one-reading-chart.png` — rejected because single point makes dead chart with no useful trend. Final behavior replaces it with a useful prompt until at least two readings.

Explicit UI target: **6/6 passed**, covering four tabs; one-reading prompt → two-reading chart; two same-day readings; backdated date regrouping; edit; delete cancel/confirm/undo; Settings; and direct `View full trends` → `Progress` / `Weight`.

Validation: `just validate 300` **passed**; hostless **125 passed / 2 opt-in live skips**; simulator build/install/launch **passed**. `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`. App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and again in an integrated run. One later standalone `just test-app-unit 300` timed out before XCTest due to external Xcode 27 host instability; not a red product gate.

## HOME-001

Baseline:

- `screenshots/baseline/counter-empty.png` — empty day
- `screenshots/baseline/counter-normal.png` — one Snack entry, 15 kcal
- `screenshots/baseline/counter-entry-tools.png` — lower custom-food/barcode content

Attempts:

- `screenshots/HOME-001/attempt-01.png` through `attempt-11.png`
- supporting meal/lower/detail captures use filename suffixes

Accepted: `screenshots/HOME-001/attempt-11.png`
Reason: best hierarchy, all four meal summaries clear, 44pt water actions, no tab collision.

## CALORIES-001 / WATER-001 / MEALS-001

Baseline: `screenshots/baseline/counter-normal.png`
Attempts: tracked with HOME-001
Accepted: `screenshots/HOME-001/attempt-11.png`

## MEAL-001

Baseline: `screenshots/baseline/add-meal.png`, `screenshots/MEAL-001/baseline-current.png`
Attempts:

- `screenshots/MEAL-001/attempt-01.png`
- `screenshots/MEAL-001/attempt-02-selected.png`
- `screenshots/MEAL-001/attempt-03.png`

Accepted: `screenshots/MEAL-001/attempt-03.png`
Accessibility evidence: `screenshots/MEAL-001/accessibility3-top.png`, `accessibility3-lower.png`
Reason: explicit inputs/actions, live total, reliable search/scanner entry, adaptive large-text menus.

## FOOD-SEARCH-001

Baseline: `screenshots/baseline/food-selector.png`
Attempts:

- `screenshots/FOOD-SEARCH-001/attempt-01.png`
- `screenshots/FOOD-SEARCH-001/attempt-02.png`
- corresponding `-results` captures

Accepted: `screenshots/FOOD-SEARCH-001/attempt-02.png`
Reason: recents, immediate top search, full browse, and reliable full-row selection.

## FOOD-CREATE-001 / BARCODE-001

Baseline: `screenshots/baseline/counter-entry-tools.png`
Attempts:

- `screenshots/FOOD-TOOLS-001/attempt-01.png`
- `screenshots/FOOD-TOOLS-001/attempt-02.png`
- `screenshots/FOOD-TOOLS-001/attempt-03-functional.png`
- `screenshots/FOOD-TOOLS-001/attempt-04.png`

Accepted: `screenshots/FOOD-TOOLS-001/attempt-04.png`
Reason: secondary native sheet, keyboard-safe layout, visible disabled lookup, verified custom-food round trip.

## FOOD-REMOTE-SEARCH-001

Baseline: local/saved-food selector with no remote discovery evidence.

Attempts:

- `screenshots/FOOD-REMOTE-SEARCH-001/attempt-01-results.png` — retained rejected attempt. Full `ContentUnavailableView` consumed 234 pt and pushed remote controls beneath keyboard.
- `screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-results.png`
- `screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-selected.png`
- `screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-persisted.png`

Accepted: attempt 02 evidence above.
Reason: compact `Saved foods` empty row preserves local context and keeps remote results/controls keyboard-safe. Manual flow selected Remote Oat Drink at 250 ml / 100 kcal, increased daily total by exactly 100 kcal after save, and confirmed persisted local row.

## AMOUNT-EDITOR-001

Attempts:

- `screenshots/AMOUNT-EDITOR-001/attempt-01-normal.png` — Almond Milk normal layout, 100 g / 15 kcal.
- `screenshots/AMOUNT-EDITOR-001/attempt-01-adjusted.png` — Almond Milk after −10, 90 g / 14 kcal.
- `screenshots/AMOUNT-EDITOR-001/attempt-01-milliliters.png` — Remote Oat Drink volume layout, 250 ml / 100 kcal.
- `screenshots/AMOUNT-EDITOR-001/attempt-01-accessibility3.png` — Accessibility3 adjusted state, 90 g / 14 kcal.

Accepted: attempt 01.
Reason: Prototype A keeps common corrections keyboard-free, preserves serving separation, exposes g/ml semantics, and adapts controls to measured normal and Accessibility3 targets without clipping.

## HISTORY-001 / PROGRESS-001 / WEIGHT-001 analytics milestone

Device evidence: deterministic iPhone 17 Pro preview, portrait, light appearance.

### HISTORY-001 / PROGRESS-001

Baseline: `screenshots/baseline/history-calories.png`

Attempts:

- `screenshots/HISTORY-001/attempt-01-calories.png` — retained rejected attempt. Weak one-line gray summary and full month-day labels overlapped.
- `screenshots/HISTORY-001/attempt-02-calories.png` — accepted calorie Progress preview: recorded-day average, profile-goal relation, orange seven-day bars, goal rule, and compact actual day labels without bar annotations.

Accepted: `screenshots/HISTORY-001/attempt-02-calories.png`

Status: **ACCEPTED — attempt 02** for `HISTORY-001` and `PROGRESS-001`.

### WEIGHT-001

Baseline: `screenshots/baseline/history-weight-empty.png`

Attempts:

- `screenshots/WEIGHT-001/attempt-02-populated.png` — current/change/target summary and fourteen-reading line/point trend with target rule.
- `screenshots/WEIGHT-001/attempt-02-empty.png` — useful empty copy with direct Record Weight action.
- `screenshots/WEIGHT-001/attempt-02-editor.png` — locale-consistent wheel/header record/update sheet with Cancel and Save.

Accepted:

- `screenshots/WEIGHT-001/attempt-02-populated.png`
- `screenshots/WEIGHT-001/attempt-02-empty.png`
- `screenshots/WEIGHT-001/attempt-02-editor.png`

Status: **ACCEPTED — attempt 02** for `WEIGHT-001`. This is pre-TRACKING baseline; final Weight root evidence is indexed above.

## SETTINGS-001

Baseline: `screenshots/baseline/config-top.png`

Visual root-tab evidence: `screenshots/TRACKING-IA-001/attempt-01-four-tabs.png`

Status: implemented and complete in TRACKING attempt 01. Settings retains target weight, age, calorie goal, target date, and reminders; no current-weight field.

## REMINDERS-001

Baseline: `screenshots/baseline/config-reminders.png`
Attempts: pending
Accepted: pending
