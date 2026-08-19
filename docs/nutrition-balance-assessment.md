# Nutrition balance assessment

Assessment date: 2026-08-09

## Product question

Count Calories needs daily carbohydrate, protein, fat, and fiber visibility without inventing values that Open Food Facts, legacy foods, or custom foods do not contain. It also needs useful suggestions without presenting an opaque health score or implying individualized medical advice.

## Authoritative references

- National Academies, *Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids*: https://doi.org/10.17226/10490
- U.S. FDA nutrition-label calorie factors, 21 CFR 101.9(c)(1): https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9
- Open Food Facts v3 nutrient schema: https://openfoodfacts.github.io/openfoodfacts-server/api/ref-api/
- Open Food Facts v2 product/nutriment reference: https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/
- Existing sampled API assessment: `open-food-facts-api-assessment.md`

Adult Acceptable Macronutrient Distribution Ranges are population references, not personal prescriptions:

| Nutrient | Adult AMDR |
| --- | ---: |
| Carbohydrate | 45–65% of energy |
| Protein | 10–35% of energy |
| Total fat | 20–35% of energy |

Fiber uses the energy-scaled adult reference of 14 g per 1,000 kcal. It is an Adequate Intake reference, not a diagnosis or guaranteed individual requirement.

Macro-energy calculation uses label factors for two distinct views:

```text
carbohydrate kcal = carbohydrate grams × 4
protein kcal      = protein grams × 4
fat kcal          = fat grams × 9

colored macro-only split = each macro kcal ÷ summed carbohydrate/protein/fat kcal
adult-range share        = each macro kcal ÷ reported logged food calories
```

Reported food calories remain authoritative for the calorie budget and the AMDR denominator. Macro-derived energy never replaces them because labels can differ through rounding, fiber definitions, sugar alcohols, alcohol, organic acids, and incomplete data. The colored split therefore describes only the relative 4/4/9 energy of the three measured macros. Adult-range shares can legitimately total above or below 100%; UI identifies them as approximate logged-energy shares rather than treating the normalized colored split as an AMDR percentage.

## Open Food Facts mapping

### V3.6

Use `nutrition.aggregated_set.nutrients` when its basis is `100g` or `100ml`. Otherwise use one non-prepared `input_sets` record whose basis can be normalized from `100g`, `100ml`, or a declared serving. Decode:

- `carbohydrates`, falling back to `carbohydrates-total` only when available carbohydrate is absent;
- `proteins`;
- `fat`;
- `fiber`.

Keep each field independently optional. Accept explicit numeric zero. Reject negative, nonfinite, incompatible-unit, prepared-only, and unparsable values instead of converting them to zero.

### V2

Use normalized flat fields:

- `carbohydrates_100g`, with `carbohydrates-total_100g` fallback;
- `proteins_100g`;
- `fat_100g`;
- `fiber_100g`.

V2 and v3 map into one normalized optional nutrient structure. Search uses the same mapping as barcode lookup.

### Carbohydrate caveat

Open Food Facts documents `carbohydrates` as available carbohydrate excluding fiber and `carbohydrates-total` as the U.S./Canada gross definition. Source products are regionally inconsistent. The app must not add fiber to carbohydrate or otherwise infer one definition from another. UI uses the neutral label “Carbs” and explains that values follow supplied food-label data.

## Persistence and historical truth

- `FoodNutrition` stores optional per-100 g/ml facts.
- `Food` stores optional facts for its declared serving.
- `PlateEntry` snapshots consumed nutrient totals when saved or edited.
- Later edits to a Food or changes in Open Food Facts never rewrite historical PlateEntry facts.
- Existing Food and PlateEntry rows migrate with `nil`, meaning unknown—not zero.
- Custom-food nutrient fields are optional and describe the same serving as custom calories.
- Barcode and search caches change projection versions so old calorie-only entries do not masquerade as newly checked nutrient data.

## Coverage policy

Coverage is count-based and explicit:

- macro coverage = logged entries with carbohydrate, protein, and fat / all logged entries;
- fiber coverage = logged entries with fiber / all logged entries;
- complete coverage = logged entries with all four facts / all logged entries.

Known totals can be displayed as partial logged values. The macro-only split appears only at 100% macro coverage and positive derived macro energy. AMDR comparisons and suggestions additionally require positive reported logged calories so each macro can use total food-label energy as its denominator. Fiber reference comparison appears only at 100% fiber coverage. These gates are conservative product policy, not a scientific confidence score and not a claim that crowdsourced values are accurate.

When coverage is incomplete, use direct copy such as:

> Guidance paused. Macro data is complete for 3 of 4 logged foods; no missing values were estimated.

Never call partial totals daily totals without a coverage qualifier.

## Guidance policy

- Show no composite health score.
- Rank percentage-point gaps between estimated logged-energy shares and adult AMDR boundaries; never compare the normalized macro-only split directly with AMDR.
- Cite measured value and reference range in every suggestion.
- Use neutral language: “below range,” “above range,” “consider,” and “if it fits your needs.”
- Never recommend skipping food, compensating, fasting, supplements, or automatic calorie changes.
- When all macro shares are inside ranges, state only that the measured split is within the population reference ranges.
- Fiber shows current measured grams and the energy-scaled daily reference; avoid claiming deficiency.
- Always identify references as general adult information, not medical advice.

This feature is not suitable as individualized guidance for children, pregnancy or lactation, eating-disorder care, kidney disease, diabetes treatment, medically prescribed diets, or unusual athletic/clinical requirements. Users needing individualized targets should use professional guidance.

## Competitive evidence

Retained current App Store evidence under `/tmp/calorie-design-research/images/` shows:

- Foodnoms places Calories, Carbs, Fat, and Protein as compact supporting goals beneath the primary calorie log (`foodnoms-1.jpg`) and uses a separate Insights macro card (`foodnoms-3.jpg`).
- Cronometer exposes explicit nutrient progress rows and values in a denser Daily Report (`cronometer-3.jpg`).
- MacroFactor prioritizes rapid logging and leaves analysis outside the search flow (`macrofactor-2.jpg`).

Count Calories should follow the category hierarchy—calories first, compact macros second, detail on demand—without copying Foodnoms rings, Cronometer’s clinical density, or an opaque branded score.

## Acceptance rules

1. Missing values remain `nil` through API decoding, caches, Food, PlateEntry, and daily summaries.
2. Explicit zero survives every layer.
3. Historical entries retain snapshots after Food changes.
4. Partial totals and coverage are clearly labeled.
5. No split, target comparison, or suggestion appears without corresponding complete coverage.
6. Suggestions state measured gaps, cite ranges, remain nonmedical, and are capped at two.
7. Normal, empty/unknown, partial, dark, and large-text states receive rendered review.

## Implementation status

NUTRIENTS-001 is accepted attempt 01. Optional facts now survive API decoding, cache projection migration, Food serving persistence, and immutable consumed PlateEntry snapshots. Daily comparison remains coverage-gated, source-linked, and nonmedical; final critical/high visual review reached 3/3 approval. Validation passed 140 hostless tests with 2 live skips, 167 app-hosted tests with 2 skips, and 12/12 functional UI tests.

REFINE-001 completed calorie-goal-derived carbohydrate/protein/fat gram ranges and energy-scaled Fiber reference without presenting one composition as universally ideal. BACKLOG-CLOSURE-001 then added optional exact user-entered targets under `personal-nutrition-targets-specification.md`, while retaining these general references and complete-coverage gates. No nutrition-balance item remains queued.
