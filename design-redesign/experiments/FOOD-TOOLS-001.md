# [FOOD-TOOLS-001] Barcode and custom food tools

## Baseline

Screenshot: `../screenshots/baseline/counter-entry-tools.png`

Problems:

- Low-frequency custom-food and barcode forms permanently occupy Today.
- Save/control rows pass behind floating tab bar until scrolling.
- Administrative tasks compete with daily status and meals.

---

## Attempt 01

Screenshot: `../screenshots/FOOD-TOOLS-001/attempt-01.png`

### Hypothesis

Moving secondary tools to a native sheet will preserve functionality while clarifying Today.

### Changes

Toolbar menu entry opens Food Tools Form with barcode and custom-food sections.

### Judge feedback

Medium sheet clipped Save Custom Food below initial viewport.

### Decision

ITERATE

---

## Attempt 02

Screenshot: `../screenshots/FOOD-TOOLS-001/attempt-02.png`

### Hypothesis

Large native detent will keep fields keyboard-safe and Dynamic Type resilient.

### Changes

Large-only detent; clearer labels, units, footer guidance, zero-calorie custom foods remain valid.

### Judge scores

Overall `8.0`, verdict ITERATE. Main criticism was unused lower space; secondary concerns were disabled-action clarity and helper contrast.

### Own visual assessment

Full height is intentional interaction space for keyboard and large text. Shortening sheet would recreate clipping and is not a user-visible improvement when keyboard appears.

### Decision

ITERATE only disabled affordance.

---

## Attempt 03

Screenshot: `../screenshots/FOOD-TOOLS-001/attempt-03-functional.png`

### Functional evidence

Luna `max` MCP flow created `Luna Test Food` at 120 kcal / 100 g, found it through Log Food search, selected it, verified 120 kcal total, and cancelled without changing daily calories. Empty barcode lookup remained behaviorally disabled.

### Problem

Disabled lookup still appeared blue/enabled, creating false affordance.

### UI-test candidacy

At attempt 03, custom-food creation had one deterministic in-memory MCP proof plus app compilation, so another manual proof was not warranted. Later deterministic functional coverage (`testCustomFoodNutrientEditorSavesDraftFood` plus bulk/offline custom recovery) completed promotion; no test follow-up remains.

### Decision

ITERATE

---

## Attempt 04

Screenshot: `../screenshots/FOOD-TOOLS-001/attempt-04.png`

### Changes

One `canLookupBarcode` condition now drives behavior and semantic disabled color; footer explicitly requires at least eight digits.

### Evidence

Rendered current preview shows lookup icon/text visibly secondary while empty. Full Xcode result later passed 52 tests, including three functional UI journeys.

### Decision

ACCEPTED

### Reason

Today remains focused, all tools remain reachable, custom-food round trip works, invalid barcode action is both disabled and visibly secondary, and large detent protects keyboard/Dynamic Type behavior.
