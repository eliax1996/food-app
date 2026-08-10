# NUTRIENTS-001 — Daily macros, fiber, coverage, and explainable balance

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Started:** 2026-08-09
**Accepted:** 2026-08-10

## Purpose

Add daily carbohydrates, protein, fat, and fiber while preserving unknown data as unknown. Replace the requested “nutrition quality” idea with transparent measured balance, explicit coverage, and restrained suggestions rather than an opaque score.

## Baseline

- `FoodNutrition` normalizes only calories and serving amount.
- Open Food Facts requests nutrition payloads but discards carbohydrate, protein, fat, and fiber.
- `Food` stores calories per serving only.
- `PlateEntry` snapshots calories but no nutrients.
- Custom Food accepts name, calories, and serving only.
- Today has calorie and water status but no nutrient overview.
- Existing generic example foods have no trustworthy nutrient provenance and must not receive invented facts.

## Research

Detailed source, API, safety, and product-policy assessment: `../../docs/nutrition-balance-assessment.md`.

Retained competitor evidence supports calories-first hierarchy with compact macro support and detail on demand:

- Foodnoms: goal rings and separate Insights macro card.
- Cronometer: explicit, dense nutrient progress rows.
- MacroFactor: logging first, analysis outside search.

Authoritative adult references:

- carbohydrate 45–65% of macro energy;
- protein 10–35%;
- fat 20–35%;
- fiber 14 g per 1,000 kcal.

These are population references, not individualized medical targets.

## Hypothesis

A compact daily summary plus a native detail screen can answer “what is my measured macro balance?” while explicit entry coverage prevents false precision. Suggestions will feel trustworthy only when they quote a measured gap and disappear when required data is incomplete.

## Success criteria

- Optional facts survive v3.6, v2, search, both caches, Food, and PlateEntry without defaulting to zero.
- V3 and v2 mapping preserve explicit zero and reject invalid values.
- Search projection and barcode cache migration prevent stale calorie-only cache entries from appearing newly complete.
- Food stores facts for its serving; PlateEntry stores consumed snapshots.
- Editing Food later does not change historical entries.
- Custom Food offers optional carbohydrate, protein, fat, and fiber values for the shown serving.
- Today shows a compact nutrition-balance overview beneath primary calorie status.
- Detail shows measured grams, macro split only at complete macro coverage, fiber reference only at complete fiber coverage, and exact coverage counts.
- At most two suggestions cite measured percentages and adult reference ranges.
- No score, shaming, medical claim, inferred nutrient, or advice appears when relevant coverage is incomplete.
- Empty, complete, partial, dark, normal text, and Accessibility Dynamic Type states are visually reviewed.
- Deterministic hostless, app-hosted persistence, and critical UI tests pass through `just`.

## Proposed information architecture

### Today

Keep remaining calories primary. Add one compact `Nutrition balance` section after calorie/water status and before Meals:

- complete state: Carbs / Protein / Fat percentages, Fiber grams, coverage summary, and first measured guidance headline;
- partial state: known logged grams plus direct coverage/guidance-paused copy;
- empty state: short invitation without a decorative empty panel;
- row opens daily detail.

### Daily detail

Native List sections:

1. Macronutrient split and measured grams.
2. Fiber and energy-scaled adult reference.
3. Guidance or explicit paused reason.
4. Data coverage counts.
5. “How this works” references, label caveat, and nonmedical disclaimer.

### Custom Food

Use one optional native navigation row leading to a focused four-field Nutrients editor. Rounded numeric fields, explicit Done, draft/cancel behavior, and footer copy make edit and save semantics visible. Values apply to the same serving; unknown values remain blank.

## Data policy

- Macro split/guidance requires carbohydrate, protein, and fat on every logged entry.
- Fiber comparison requires fiber on every logged entry.
- Partial known values remain visible only with a partial-data qualifier.
- Reported food calories remain separate from 4/4/9 macro energy.
- Existing example foods remain unknown until backed by entered or remote facts.

## Implementation outcome

- Added independently optional `FoodNutrients`; invalid values become unknown while explicit zero remains known.
- Open Food Facts v3.6 structured sets, v2 flat nutriments, and Search-a-licious hits now normalize carbohydrate, protein, fat, and fiber. Serving-based values scale to per-100; prepared-only and incompatible-unit values remain unknown.
- Barcode cache moved to a nutrient-aware filename and search cache projection advanced to v2 so old calorie-only responses cannot masquerade as newly checked facts.
- `Food` persists facts for its serving. `PlateEntry` persists consumed immutable snapshots and updates the selected entry snapshot only when that meal is edited.
- Custom food now has a focused optional Nutrients editor with local draft, native Back cancellation, explicit Done commit, visible field treatment, and a return-to-Food-tools save explanation.
- Today keeps calories first, separates the three-color macro-energy split from Fiber, exposes coverage, and links to a native detail List.
- Detail shows actual grams, adult macro ranges only with complete macro coverage, energy-scaled Fiber comparison only with complete fiber coverage, explicit coverage counts, methodology links, label-data caveat, and nonmedical copy.
- Guidance ranks measured percentage-point gaps, caps output at two, uses neutral actions, and remains paused when relevant coverage is incomplete. Food-label calories never derive from macro factors.
- Accessibility layouts remove the decorative macro bar at accessibility sizes and keep measured percentages/ranges as text; this exposes a complete macro card boundary and clear next-section continuation at AX3.

## Visual iteration and judgment

Attempt 01 evidence is under `../screenshots/NUTRIENTS-001/`:

- `attempt-01-today.png`
- `attempt-01-complete.png`
- `attempt-01-guidance.png`
- `attempt-01-partial.png`
- `attempt-01-guidance-ax3-dark.png`
- `attempt-01-custom-food.png`
- `attempt-01-custom-nutrients.png`
- `attempt-01-custom-nutrients-ax3-dark.png`

Direct inspection found and corrected four concrete issues before acceptance: preview evidence initially hid real pushed Back controls; Today’s macro bar could appear associated with Fiber; general adult comparisons could read as personal approval; and custom nutrient values looked read-only without explicit completion. Final evidence uses pushed native navigation, a separated Fiber column, neutral `adult range` language plus visible general-reference copy, blue labeled Fiber reference progress, editable rounded fields, and explicit Done.

Three final independent read-only acceptance reviewers received identical neutral critical/high criteria and all returned `APPROVE`. Earlier broad rounds disagreed on medium polish and misread locale-aware separators or scroll continuation; no critical/high finding survived the corrected final pass.

## Validation

- `just validate 300`: passed; **140 hostless tests passed / 2 opt-in live skips**, simulator build/install/launch passed.
- `just test-app-unit 420`: passed after one Xcode-host timeout plus bounded recovery; **167 passed / 2 opt-in live skips**.
- `just test-ui 420`: passed **12/12**, including custom-food nutrient entry → meal snapshot → measured daily balance.
- Focused nutrient UI flow passed repeatedly; final full run completed it in about 34 seconds.
- Xcode 27 reported `Invalid frame dimension (negative or non-finite).` while Food Tools keyboards opened in both the new custom-nutrient journey and the pre-existing barcode journey. Both flows passed, the warning had no source frame or visible defect, and replacing nutrient layout/focus variants did not change it; retained as a platform/runtime diagnostic, not a failed product gate.

## Acceptance decision

**ACCEPTED — ATTEMPT 01 / COMPLETE.** Missing values remain truthful, historical snapshots are stable, actual-versus-general-reference presentation is explainable, critical UI coverage is deterministic, final rendered evidence is accepted, and all product gates are green. Calorie-goal-derived theoretical gram ranges versus measured actuals are intentionally scheduled as `NUTRITION-GOALS-001` inside REFINE-001 rather than expanding this completed daily-truth milestone.

### REFINE-001 denominator correction

A later critical review identified that AMDR uses total energy, not a normalized carbohydrate/protein/fat-only denominator. REFINE-001 preserves the colored normalized macro-only split as a descriptive view, but adult-range guidance now divides each macro’s 4/4/9 estimate by reported logged food-label calories. UI labels both bases, coverage and positive-calorie gates remain explicit, and a deterministic mismatch test prevents normalized split percentages from driving AMDR guidance.
