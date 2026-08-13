# Whole-app robustness assessment

**Work item:** ROBUSTNESS-001
**Date:** 2026-08-13

## Matrix

| Dimension | Evidence |
|---|---|
| Light / normal | Today normal, small, empty, dense, over-goal; accepted component library |
| Dark / AX3 | Today normal+dense, Weight, Settings, Meal editor, Nutrition detail, reminders, bulk review, widget, Live Activity |
| Small iPhone | Fixed 375×667 Today normal/empty and reminder editor |
| Large iPhone | Fixed 430×932 dense and over-goal Today |
| Long content | Long meal name plus 11 additional meal rows, summarized by meal |
| Extreme values | 670 kcal over goal; dense 2,370 kcal; full water; calorie/weight chart domains |
| Empty | Zero food/water Today, empty Weight/Progress, empty nutrition and remote states |
| Dense | 12 foods, all meal sections, complete nutrient facts, 13 historical days, weight trend |

## Findings and fixes

### Today status controls at Accessibility Dynamic Type

Food-log status/action used one fixed horizontal row. At AX3, status and **Mark Complete** clipped and overflowed.

Fix: accessibility sizes now stack label, status, and action vertically. Normal sizes use `ViewThatFits` to fall back to two lines on narrow phones while preserving compact layout on standard widths.

### Water row at Accessibility Dynamic Type

Water title wrapped mid-word on small AX3 layout because controls competed in one horizontal row.

Fix: accessibility sizes stack summary above 44×44 controls; normal sizes retain accepted horizontal row.

### Settings summary rows at Accessibility Dynamic Type

Title and trailing value shared a baseline at AX3, producing character-by-character wrapping (`Paused`, goal values).

Fix: accessibility sizes stack title, value, and detail. Normal sizes retain trailing summary value.

### Preview state contamination

App Group widget water could override in-memory preview fixtures, making empty-state evidence show nonzero water.

Fix: Xcode preview process is treated as design review for external widget/reminder/activity side effects. Runtime app and UI-test behavior remains unchanged.

## Accepted behavior

- AX3 screenshots show only upper portions by design; List scrolling and focused UI proof keep primary controls reachable.
- Floating tab bar may cover current viewport content, but retained 84-point tail spacer and UI scroll assertions let final rows clear it.
- Long food names truncate in compact meal summaries and remain complete in detail/editor accessibility labels.
- Over-goal state uses text plus red semantics; no color-only signal.
- Charts avoid zero-baseline distortion for weight and expose exact selected values.

## Validation

- Incremental app + widget build passed.
- Focused AX3 Today UI test proves status, 44-point completion action, Nutrition link, and Log food remain reachable by scrolling.
- Existing small reminder, weight AX3, meal AX3, bulk AX3, nutrition AX3, scanner AX3, widget AX3, and Live Activity AX3 evidence remains accepted.
- Three independent critical/high robustness reviews: **APPROVE / APPROVE / APPROVE**.
