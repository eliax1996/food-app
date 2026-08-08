# AMOUNT-EDITOR-001: amount-entry pattern assessment

**Date:** 2026-08-08
**Decision:** Prototype A approved for first implementation; implementation accepted in attempt 01.
**Disposition:** IMPLEMENTED / ACCEPTED — ATTEMPT 01. Research evidence below is preserved; competitor sources do not support claims beyond stated observations.

## Evidence reviewed

- Accepted Meal evidence: `design-redesign/screenshots/MEAL-001/attempt-03.png`, `design-redesign/experiments/MEAL-001.md`, and `count_calories/Features/Counter/MealEditorView.swift`. Accepted editor has food-derived `NutritionUnit`, exact amount entry, separate servings/presets, live calorie total, and accessibility-size adaptations. Current amount path is keyboard-based exact entry; adjustment controls remain unimplemented.
- Stored MacroFactor capture/metadata (`macrofactor-2.jpg`, `macrofactor.json`): visible search results with direct actions and serving-related metadata.
- Stored MyFitnessPal capture/metadata (`myfitnesspal-2.jpg`, `myfitnesspal.json`): food-specific portion labels and explicit “Log breakfast” action.
- Stored Foodnoms metadata/capture (`foodnoms.json`, `foodnoms-1.jpg`): claims Dynamic Type, Dark Mode, VoiceOver, metric and imperial units, including kilojoules; capture shows meal-log context.

Public evidence supports visible food/serving context, direct logging, and accessibility/unit intent. No inspected public source proves competitor keypad, Stepper, ±10/±1 controls, or hold-repeat. Those are not competitor claims. App Store screenshots are marketing material, and metadata can change.

## Prototype comparison

| Prototype | Pattern | Assessment | Decision |
| --- | --- | --- | --- |
| A | Amount/value row plus `−10`, `−1`, `+1`, `+10` controls | One-tap common corrections; keeps accepted Meal hierarchy; requires careful width and Dynamic Type adaptation. | **Approve first** |
| B | Tap Amount to open compact sheet with four controls and secondary exact entry | More room for large type and VoiceOver; adds navigation cost and hides current amount controls. | Fallback if A fails inline visual review |
| C | Native Stepper for ±1 plus explicit ±10 actions | Familiar native semantics, but two control models compete and row can become dense. | Do not implement first |

## Approved prototype A

- Keep amount/value row. Place four buttons in one horizontal row in normal Dynamic Type: `−10`, `−1`, `+1`, `+10`. Each target is at least 44 × 44 pt, with visible action text.
- At accessibility sizes, use same order in a 2 × 2 grid. Do not compress targets or rely on text truncation.
- Derive amount unit from selected food: grams (`g`) or milliliters (`ml`). No unit toggle or conversion inside editor.
- Apply exact deltas and preserve decimal remainder: `100.5 − 1 = 99.5`; never round button results to whole units.
- Enforce lower bound `0.01`. Disable any decrement whose result would be below `0.01`; exact entry uses same validation. No hold-repeat; one tap makes one adjustment.
- Keep exact amount entry as secondary escape hatch. Common corrections must not require keyboard. Keep serving count and serving presets separate; amount buttons never change servings. Recalculate calories immediately through existing normalized amount/serving math.
- Use B only if inline A fails visual review for hierarchy, wrapping, or accessibility-size layout.

## Verification and promotion

### VoiceOver

Give amount value, each adjustment, serving count/presets, and calculated total separate, useful labels. Include unit in amount labels and button actions, expose current amount as value, and let VoiceOver announce disabled decrement controls at `0.01` or near-bound values. After each tap, updated amount and calories must be discoverable without losing focus. Keep exact entry reachable after adjustment controls; do not merge servings with amount actions.

### Unit/UI tests

Unit coverage should verify `100 → 90/99/101/110`, decimal preservation, `0.01` lower bound, disabled crossing decrements, positive increments, grams/ml labels, immediate calorie scaling, and unchanged serving count. UI coverage should verify four identifiers/labels, 44-point hit targets, one-row normal layout, 2 × 2 accessibility layout, no keyboard requirement for button flow, VoiceOver-facing values, and separate serving controls using deterministic gram and milliliter foods.

First use MCP for bounded visual review of A with deterministic Almond Milk (`100 g`, `15 kcal`) and a milliliter fixture at normal and accessibility sizes. Inspect latest accessibility hierarchy before interaction; capture screenshots and verify one-tap outcomes. If A fails inline review, review B. Promote repeated behavior to deterministic UI tests with stable identifiers and fixtures; retain MCP for visual/transient review, not regression proof.

## Sources

Captured/reviewed 2026-08-08:

- MyFitnessPal: https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718
- MacroFactor: https://apps.apple.com/us/app/macrofactor-macro-tracker/id1553503471
- Foodnoms: https://apps.apple.com/us/app/nutrition-tracker-foodnoms/id1479461686
- Apple Human Interface Guidelines — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
