# [MEAL-001] Log food

## Baseline

Screenshots:

- `../screenshots/baseline/add-meal.png`
- `../screenshots/MEAL-001/baseline-current.png`

Problems:

- `OK` does not describe outcome.
- Meal field repeats Meal / Type / Breakfast.
- Food search is hidden behind expandable row and limited to five visible results.
- Sliders dominate exact amount entry and obscure scale/serving meaning.
- Medium detent can clip selector/amount flow and produced tap-through during MCP interaction.

---

## Attempt 01

Screenshots:

- `../screenshots/MEAL-001/attempt-01.png`
- `../screenshots/FOOD-SEARCH-001/attempt-01.png`
- `../screenshots/FOOD-SEARCH-001/attempt-01-results.png`

### Hypothesis

Large search-first sheet with exact fields will reduce repeated-use cost and serving ambiguity.

### Changes

- Full-height sheet and explicit Add/Save.
- Segmented meal type.
- Dedicated searchable food destination with recent foods.
- Scanner adjacent to food selection.
- Exact amount/serving fields plus common serving presets.
- Live calculated total.

### Judge feedback

Visual structure improved. Banana result did not respond to center tap because plain button label lacked full-row content shape. Bottom search placement also let list content pass behind search chrome.

### Decision

ITERATE

---

## Attempt 02

Screenshots:

- `../screenshots/MEAL-001/attempt-02-selected.png`
- `../screenshots/FOOD-SEARCH-001/attempt-02.png`
- `../screenshots/FOOD-SEARCH-001/attempt-02-results.png`

### Hypothesis

Full-row hit shape and always-visible navigation search will make selection reliable and remove bottom overlap.

### Changes

Added full-row rectangular hit shape; moved native search to navigation drawer; strengthened calculated total.

### Functional evidence

Banana filtered to one result, selected in one tap, popped to editor, set 100 g / 1 serving / 89 kcal, and Cancel left HOME unchanged.

### Judge scores

Meal overall `8.4`, `8.4`; Search overall `8.0` with ACCEPT.

### Judge feedback

Search/recent flow accepted. Meal numeric fields still looked static. Accessibility-size segmented labels remained a risk.

### Decision

ITERATE for Meal; ACCEPTED for Food Search.

---

## Attempt 03

Screenshot: `../screenshots/MEAL-001/attempt-03.png`

### Hypothesis

Native rounded text fields and accessibility-specific control adaptation will clarify exact editing while preserving compact normal layout.

### Changes

- Rounded exact numeric controls.
- Accessibility-size meal picker switches away from segmented layout.
- Accessibility-size serving presets switch away from segmented layout.
- More precise accessibility labels.

### Functional evidence

Amount field 254×34 and serving field 338×34; 0.5 serving updated 15 kcal to 8 kcal and restoring 1 returned 15 kcal. Cancel preserved HOME.

### Judge scores

`8.7 ACCEPT`, `8.1 ITERATE`, `8.6 ACCEPT`.

### Judge feedback

Two independent judges accepted. Remaining concerns were largely screenshot perception of native segmented hit size and supporting contrast. Accessibility3 stress test then found SwiftUI's menu-style Picker rendered malformed; follow-up replaced accessibility controls with explicit native Menu rows.

### Own visual assessment

Normal layout is clear, restrained, exact, and fast. Accessibility3 is stress evidence only, not default sizing.

### Accessibility evidence

Luna `max` runtime retest verified full-width Meal and Serving Presets Menu rows, all meal options, exact fields, Total, Add, and Cancel. No clipping or overlap remained. Lunch was correctly suggested at 12:19; subagent's expected-Breakfast failure was rejected by parent review.

Screenshots:

- `../screenshots/MEAL-001/accessibility3-top.png`
- `../screenshots/MEAL-001/accessibility3-lower.png`

### Decision

ACCEPTED

### Reason

Normal attempt passed functional serving/search tests and two of three independent judges. Accessibility controls now adapt without clipping; remaining giant typography is expected user-selected Accessibility3 behavior and is not used as final visual target.
