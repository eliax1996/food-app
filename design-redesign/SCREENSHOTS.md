# Visual evidence index

Device unless noted: iPhone 17 Pro, iOS 27.0, portrait, light appearance.

## NAV-001

Baseline: all files under `screenshots/baseline/`
Accepted: pending

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

## HISTORY-001 / PROGRESS-001

Baseline: `screenshots/baseline/history-calories.png`
Attempts: pending
Accepted: pending

## WEIGHT-001

Baseline: `screenshots/baseline/history-weight-empty.png`
Attempts: pending
Accepted: pending

## SETTINGS-001

Baseline: `screenshots/baseline/config-top.png`
Attempts: pending
Accepted: pending

## REMINDERS-001

Baseline: `screenshots/baseline/config-reminders.png`
Attempts: pending
Accepted: pending
