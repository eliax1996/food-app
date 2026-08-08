# [AMOUNT-EDITOR-001] Human-friendly amount adjustment

## Baseline

Meal amount editing was keyboard-first. Common corrections from food defaults such as `100 g` or `250 ml` required exact TextField interaction even when a small ±1/±10 change was enough.

## Approved pattern

Prototype A keeps accepted MEAL-001 hierarchy and adds four visible controls in this order: `−10`, `−1`, `+1`, `+10`.

- Normal Dynamic Type: one row. Each actual control measured about `78 × 58 pt`.
- Accessibility3: 2 × 2 grid, with `−10`, `−1` on first row and `+1`, `+10` on second. Each actual control measured `163 × 62 pt`.
- Unit derives from food: grams (`g`) or milliliters (`ml`); no unit toggle or conversion.
- Amount controls change amount only. Serving count and serving presets remain separate.
- Exact TextField remains secondary escape hatch. Common adjustment needs no keyboard; no hold-repeat.
- Stable identifiers and VoiceOver labels expose each action, unit, current value, and g/ml semantics.

## Domain and save rules

- Minimum valid amount is `0.01`.
- Deltas and source values must be finite; valid adjustments apply exact deltas.
- Floating-point boundary tolerance normalizes values that land on minimum to `0.01`.
- Decimal remainder is preserved; button results are not rounded to whole units.
- Exact TextField validation and Save validity use same rule.

## Attempt 01 evidence

### Normal grams

Almond Milk at `100 g / 15 kcal` changed with one tap to `90 g / 14 kcal` via `−10`, then returned to `100 g / 15 kcal` via `+10`. Serving count stayed unchanged and no keyboard appeared.

### Remote milliliters

Remote Oat Drink at `250 ml / 100 kcal` verified volume labels and the same adjustment control treatment for milliliters.

### Accessibility3

Accessibility3 proof reached Almond Milk `90 g / 14 kcal` with serving `1`. Adjustment controls used required 2 × 2 order and measured targets above minimum. Serving and preset menus were readable, calculated total was reachable, and no clipping appeared.

Accepted screenshots:

- `../screenshots/AMOUNT-EDITOR-001/attempt-01-normal.png`
- `../screenshots/AMOUNT-EDITOR-001/attempt-01-adjusted.png`
- `../screenshots/AMOUNT-EDITOR-001/attempt-01-milliliters.png`
- `../screenshots/AMOUNT-EDITOR-001/attempt-01-accessibility3.png`

## Tests and runtime record

- Focused amount tests: 5 pass.
- Aggregate: 90 pass / 2 opt-in skips.
- `just check` passed.
- Diagnostic UI test was added with stable identifiers and assertions for targets, values, calorie updates, unchanged servings, and no keyboard.
- Final UI attempts were blocked before XCTest: Application launch did not return a process handle after one recover. `just simulator-run` passed, isolating blocker to Xcode test hosting. UI suite is not green.

## Decision

**ACCEPTED — ATTEMPT 01**

Prototype A meets amount-entry, unit, accessibility, and keyboard-free correction requirements. Current next: `HISTORY-001 + PROGRESS-001 + WEIGHT-001`.
