# Personal nutrition targets specification

**Status:** IMPLEMENTED / ACCEPTED — BACKLOG-CLOSURE-001

**Decision date:** 2026-08-18

## Decision

Implement optional user-entered daily carbohydrate, protein, fat, and fiber targets. Keep general adult reference ranges visible and unchanged. Count Calories records targets; it does not calculate, prescribe, or judge their suitability.

This closes the remaining macro-target candidate because measured immutable nutrients, coverage gates, and Plan disclosure already exist. User-owned exact targets add coherent value without pretending that one composition fits every person.

## Product rules

1. Personal targets are one complete set: carbohydrate, protein, fat, and fiber grams per day. Partial sets are not saved.
2. No target is prefilled from population references. Blank editor fields avoid turning a reference midpoint into a silent prescription.
3. Values must be finite and positive. Combined carbohydrate/protein/fat energy using 4/4/9 must not exceed the app’s supported 5,000-kcal daily domain. Fiber has a 200 g storage-sanity ceiling. These are software bounds, not health recommendations.
4. Personal macro energy may differ from the calorie goal. UI shows the calculated macro-energy total and says that food-label calories remain budget-authoritative.
5. General adult ranges remain visible before and after personal targets are saved.
6. **Use General References** clears the personal set after confirmation; it does not convert ranges into exact targets.
7. Changes never alter calorie goals, logged foods, nutrition snapshots, adaptive evidence, or historical goal revisions.
8. Targets remain local in the existing profile store. No account, HealthKit, analytics, or network transport is added.

## Data and migration

`PersonalNutritionTargets` is a versionless Codable value containing four `Double` gram values. Validation happens before construction and again on decode through a validating initializer.

`UserProfile.personalNutritionTargetsData` is optional. Nil means no personal set. Existing profiles migrate to nil without fabricated values. Corrupt/unsupported data decodes as unavailable while general references and all calorie behavior remain usable.

`PlanEvidenceMutationCoordinator.setPersonalNutritionTargets` owns persistence through its dedicated context and one save. It does not bump `evidenceRevision`, change plan source, or supersede adaptive proposals because targets are display context, not calorie evidence.

## UI

Plan adds **Your nutrition targets** after population references:

- unset: concise explanation and **Set Personal Targets**;
- set: exact carb/protein/fat/fiber grams, calculated macro energy, today’s measured value when relevant coverage is complete, **Edit Targets**, and **Use General References**;
- editor: four lossless locale-aware decimal fields, explicit units, keyboard Done, Save/Cancel, live macro-energy summary, and validation copy; opening and saving cannot round untouched persisted values;
- reset: confirmation that logged foods and calorie goal remain unchanged.

Daily Nutrition adds **Your targets** when configured. Each nutrient shows measured versus target only with complete relevant coverage. Known partial grams remain visible with **Comparison paused**; missing values never become zero. Progress indicators cap visually but text preserves over-target values.

Copy consistently states:

- “Targets are values you entered, not recommendations.”
- “General adult references remain available.”
- “Food-label calories remain authoritative for the calorie budget.”

## Accessibility and privacy

- Every field has nutrient, grams, and target semantics.
- Numeric keyboard has Done that dismisses without saving.
- Save/Cancel remain separate.
- Status never relies on color.
- Dynamic Type uses native Form/List reflow and 44-point actions.
- VoiceOver reads measured value, target, coverage state, and macro-energy basis.
- Data stays in local SwiftData profile storage.

## Acceptance

- Valid targets round-trip through file-backed persistence and survive profile reload.
- Invalid, nonfinite, partial, excessive-energy, and corrupt payloads fail closed.
- Save/clear leaves calorie goal, plan source, adaptive evidence, logs, and goal revisions unchanged.
- Plan always retains general references and exposes exact user-entered targets distinctly.
- Daily comparison requires complete relevant nutrient coverage.
- Editor Save/Cancel/Done and clear confirmation have functional UI coverage.
- Hostless, app-hosted, full UI, appearance/accessibility evidence, and independent critical/high review pass.

## Implementation result

Implemented as optional validated local profile data, atomic coordinator persistence, Plan set/edit/clear controls, and coverage-gated Daily Nutrition comparison. General references always remain visible; no value is prescribed or prefilled. File-backed reload, corrupt payload, rollback, domain bounds, focused UI, light, and Accessibility 3 dark evidence are covered under `design-redesign/screenshots/BACKLOG-CLOSURE-001/`. Final integrated gates reached 243 hostless executed (241 pass / 2 skips), 351 app-hosted pass / 2 skips, 52/52 UI, and 3/3 neutral critical/high approval. This specification has no unimplemented acceptance item.
