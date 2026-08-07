# Open Food Facts API assessment

Assessment date: 2026-08-07

## API choice

Open Food Facts now marks API v3.6 as current and recommends it for new integrations. API v2 is deprecated but supported for compatibility. Product reads therefore use:

- primary: `GET /api/v3.6/product/{barcode}`;
- fallback: `GET /api/v2/product/{barcode}`.

V3.6 cannot reuse v2 decoding. Since v3.5, nutrition is exposed through `nutrition.aggregated_set.nutrients`; the old flat `nutriments` object is empty in v3.6 responses. V2 still uses fields such as `nutriments.energy-kcal_100g`.

## Sampling

Fourteen barcodes were queried against both product endpoints with focused fields. Twelve existed and two returned HTTP 404. Samples covered solid food, beverages, water, products with package amounts, products with serving amounts, and products without serving data.

Presence among 12 found products:

| Field | v3.6 | v2 |
| --- | ---: | ---: |
| product name | 12/12 | 12/12 |
| brand | 12/12 | 12/12 |
| quantity text | 11/12 | 11/12 |
| numeric package quantity | 11/12 | 11/12 |
| serving size | 10/12 | 10/12 |
| serving quantity | 10/12 | 10/12 |
| serving unit | 11/12 | 11/12 |
| calories per 100 g/ml | 12/12 | 11/12 |
| protein | 12/12 | 11/12 |
| fiber | 9/12 | 7/12 |

Observed product-response latency was about 0.19–0.30 seconds when not rate-limited. An initial parallel v3.6/v2 sampling pass received HTTP 429 before seven product pairs completed. Open Food Facts documents a limit of 15 product reads per minute per IP, plus global limits. This makes two unconditional requests per scan wasteful.

Resulting request policy:

1. Start v3.6 immediately.
2. If v3.6 quickly reports incomplete product data or a version-specific failure, start v2 immediately; a definitive v3.6 not-found before the hedge returns without spending another request.
3. If v3.6 is still pending after 750 ms, start v2 as a hedge. Once that request is spent, use a complete fallback result even if slow v3.6 later reports not-found or a shared-limit error.
4. Use whichever endpoint first returns complete normalized nutrition.
5. Stop all work after a six-second UX deadline.
6. Do not start fallback after HTTP 429 or global-limit HTTP 503 because both versions share infrastructure and rate limits. If a hedge is already in flight when that late response arrives, keep its result instead of wasting completed work.

This preserves fast fallback for a slow or schema-incompatible v3 response without doubling normal traffic.

## Optionality assessment

Previous `FoodNutrition` stored 11 optional fields. Most were either unused by the app (`brand` and six macronutrient fields) or forced downstream fallback code (`servingGrams`, `servingUnit`, and `quantityDescription`).

Normalized `FoodNutrition` now has no optional properties:

- `barcode`;
- `name`;
- `defaultAmount` (`NutritionAmount` with value and unit);
- `caloriesPer100`.

Missing product and incomplete product are represented as explicit `FoodNutritionFetchResult` cases instead of a nullable product. When serving/package data is absent, default amount is the API's standard 100 g/ml reference using unit evidence from serving, package, nutrition-basis, or beverage category fields. Explicit liquid metadata outranks a `100g` aggregate basis because sampling returned Coca-Cola nutrition as `100g` while its serving and package are correctly expressed in ml; an explicit `100ml` basis remains authoritative.

Optionals remain only at external-data boundaries where absence changes meaning: missing API product payloads, missing calorie values, missing structured serving sets, and cache misses. Legacy cache decoding accepts old optional JSON and normalizes it into current nonoptional model.

## Swift SDK assessment

Official `openfoodfacts-swift` package was considered but not adopted:

- README marks maintenance as looking for a maintainer;
- no published GitHub release was available during assessment;
- package focuses on scanner/editor UI rather than focused product reads;
- it adds BarcodeView and TOCropViewController dependencies;
- package declares iOS only, while this repository compiles nutrition production code in hostless macOS tests;
- direct v3.6 structured-nutrition support was not evident.

Native `URLSession` keeps this read-only integration smaller, hostless-testable, and explicit about v3.6/v2 schema differences.

## Ad hoc live checks

Live tests remain opt-in and never run in normal gates:

```sh
RUN_OPEN_FOOD_FACTS_LIVE_TEST=1 just test-one OpenFoodFactsLiveTests
```

They perform one real v3.6 structured lookup and one real v2 fallback lookup. Deterministic tests use mocked responses for normal automation.
