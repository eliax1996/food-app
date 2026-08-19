# Feature opportunities

## Meal-grouped daily log

### User problem

Flat list forces users to read tiny meal labels and gives no breakfast/lunch/dinner context or subtotal.

### Competitive evidence

Foodnoms and Lose It organize logs by meal and show meal calories.

### Proposed UX

Four compact meal groups with subtotal, entries, and per-meal add action.

### Why it belongs in this product

Existing `mealType` data fully supports it; no backend work.

### Expected impact

Faster scanning and lower repeated logging cost.

### Required backend/data support

None.

### Prototype status

Implemented and accepted in HOME-001. Meal summary rows lead to per-meal detail screens with existing edit/delete behavior.

**Classification: MUST HAVE**

---

## Recent and frequent foods

### User problem

Repeated foods require searching the full seeded catalog each time.

### Competitive evidence

MacroFactor exposes recent foods and direct plus actions; Lifesum surfaces often-tracked breakfast chips.

### Proposed UX

When meal search is empty, show recent unique foods, derived frequently logged foods that are not already recent, then full alphabetical results.

### Why it belongs in this product

Daily trackers are repetition-heavy. Existing entries and foods can derive recency without new backend.

### Expected impact

One or two fewer interactions for common foods.

### Required backend/data support

None. Recency and frequency are derived deterministically from local `PlateEntry` history; no persistent index is needed.

### Prototype status

Implemented and accepted across FOOD-SEARCH-001 and BACKLOG-CLOSURE-001. Recent unique local foods and count/recency-ranked frequent foods appear before alphabetical browse when search is empty. Only known, nonfuture item snapshots contribute; ambiguous duplicate saved names fail closed. Ranking has deterministic tests and functional UI proof.

**Classification: HIGH VALUE**

---

## Macro target summary

### User problem

Calories alone cannot explain nutritional balance or support macro-oriented goals.

### Competitive evidence

Every sampled advanced tracker surfaces protein/carbs/fat; Cronometer extends to micronutrients.

### Proposed UX

Compact protein/carbs/fat progress below calories, with detailed nutrient screen only when data is available.

### Why it belongs in this product

Nutrition API already normalizes products, but persistence currently stores calories only.

### Expected impact

Substantial competitiveness and better food decisions.

### Required backend/data support

Persist macro values and targets; migrate existing foods/entries; handle incomplete crowdsourced data honestly.

### Prototype status

Implemented and accepted in NUTRIENTS-001 and REFINE-001. Logged facts remain immutable/coverage-gated; Plan exposes transparent adult reference ranges.

**Classification: HIGH VALUE**

---

## Goal-aware calorie trend

### User problem

Raw bars do not show whether intake is consistently near goal.

### Competitive evidence

Foodnoms Insights and category dashboards provide adherence/goal context rather than isolated values.

### Proposed UX

Seven/fourteen-day chart with calorie-goal rule, average, and days in target range.

### Why it belongs in this product

Existing calorie history and profile target support it locally.

### Expected impact

Turns history into useful feedback.

### Required backend/data support

None.

### Prototype status

Implemented and accepted in PROGRESS-001 with seven recent recorded days, average, historical goal context, and goal rule.

**Classification: HIGH VALUE**

---

## Date-first historical Food Diary

### User problem

Progress totals did not explain which logged foods produced a recorded day.

### Competitive evidence

Fresh category reassessment retained date-first diaries with meal-specific food rows and kept weight history separate; generic mixed journals were not supported.

### Proposed UX

Select a recorded calorie day in Progress, choose **View Day**, inspect read-only meal-grouped immutable snapshots, then move between previous/next recorded days.

### Why it belongs in this product

Existing `PlateEntry` snapshots already retain historical identity, name, calories, amount, portions, meal, and time locally. Read-only detail closes context gap without inventing risky mutation semantics.

### Expected impact

Faster explanation of historical calorie totals and stronger trust in Progress.

### Required backend/data support

Implemented follow-up support adds snapshot provenance, full-snapshot attestation schema 2, atomic coordinator mutations, retained historical goals, duplicate confirmation, and exact delete undo. Contract: `../docs/historical-food-diary-mutation-specification.md`.

### Prototype status

Read-only v1 was accepted in COMPETITOR-GAP-001. BACKLOG-CLOSURE-001 then implemented known-snapshot add/edit/copy/delete/undo while preserving legacy limitations and date-first structure.

**Classification: HIGH VALUE**

---

## Photo/AI meal recognition

### User problem

Manual food entry can be slow.

### Competitive evidence

MyFitnessPal, Lifesum, and Lose It market camera-assisted logging.

### Proposed UX

Not proposed now. Accuracy, privacy, model cost, and correction flow require product validation.

### Why it belongs in this product

Insufficient evidence for current product scope.

### Expected impact

Potentially high convenience, high complexity and trust risk.

### Required backend/data support

Vision model, confidence UX, privacy policy, telemetry, correction pipeline.

### Prototype status

Permanently rejected for current product. No trustworthy local accuracy/privacy/correction contract supports it.

**Classification: NOT RECOMMENDED**

---

## Streaks and adherence coaching

### User problem

Users may need motivation to sustain logging.

### Competitive evidence

Foodnoms displays a streak; many products add coaching and gamification.

### Proposed UX

Do not add streaks or adherence coaching. Current calm, non-shaming product should not invent engagement pressure without user or retention evidence.

### Why it belongs in this product

Calm product objective conflicts with unsupported gamification.

### Expected impact

Unclear.

### Required backend/data support

Local history sufficient for prototype.

### Prototype status

Permanently rejected from current backlog. New implementation would require a new explicit product request and evidence; it is not missing work.

**Classification: NOT RECOMMENDED**
