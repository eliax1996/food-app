# FOOD-REMOTE-SEARCH-001 — Open Food Facts search assessment

**Assessment date:** 2026-08-08
**Disposition:** Implemented; visually accepted in attempt 02.

## Scope

Before implementation, meal editor filtered local `Food.name` values only. Remote discovery keeps local results immediate, runs separately from barcode lookup, and exposes only usable foods. This assessment covers Open Food Facts search, query/page caching, request policy, and test architecture.

## Verified facts

### Official API boundary

- Open Food Facts API v3 is current, latest sub-version v3.6, and recommended for new integrations. API v2 is deprecated but supported. V2 `/api/v2/search` is structured/filter search; its official reference says it does not support full-text `search_term`. API v3 has no full-text search endpoint. Search-a-licious is the dedicated full-text service.
- Product lookup remains `GET https://world.openfoodfacts.org/api/v3.6/product/{barcode}` with v2 fallback. Current app code decodes v3.6 `nutrition.aggregated_set`/`input_sets` and v2 `nutriments.energy-kcal_100g` into nonoptional `FoodNutrition` (`barcode`, name, amount/unit, calories). Search must not replace that product-read boundary.
- Search-a-licious official OpenAPI exposes `GET https://search.openfoodfacts.org/search`. Relevant parameters: `q`, `langs`, `page` (starts at 1), `page_size`, `fields`, optional `sort_by`, `facets`, `charts`, and `index_id`. `q` supports full text/Lucene syntax; omit `sort_by` for relevance order. `fields` is server-side projection.
- Implemented projection:
  `code,product_name,quantity,product_quantity,product_quantity_unit,serving_size,serving_quantity,serving_quantity_unit,categories_tags,nutrition_data_per,nutrition,nutriments`.
  Request both `nutrition` and `nutriments`: search documents can expose v2-style flat nutrition while v3.6 product reads use structured nutrition. `nutrition_data_per` validates aggregate basis; unused `brands` from the research sample is not retained in the normalized result.
- Successful search response keys are `hits`, `aggregations`, `facets`, `charts`, `page`, `page_size`, `page_count`, `debug`, `took`, `timed_out`, `count`, `is_count_exact`, and `warnings`. Search returns `hits`, not v2's `products`; `count` can be inexact. App terminal state therefore uses raw hit count, not assumed `page_count` semantics. A response with `timed_out=true` may contain partial hits and is rejected as retryable failure, never cached as terminal knowledge.

### Sampled request

Captured official live sample:

```text
GET https://search.openfoodfacts.org/search?q=almond%20milk&langs=en&page=1&page_size=5&fields=code,product_name,brands,quantity,product_quantity,product_quantity_unit,serving_size,serving_quantity,serving_quantity_unit,nutrition,nutriments,categories_tags
```

It returned HTTP 200 and 3,957-byte JSON: five hits, `page=1`, `page_size=5`, `page_count=2000`, `count=10000`, `is_count_exact=false`, `took=24`, `timed_out=false`, `warnings=null`. First hit was barcode `20050894`, “Almond drink,” 35 kcal per 100 g in `nutriments`; two chocolate-milk hits had same name but distinct barcodes (`4157006837` and `0004157006837`). Barcode identity must therefore outrank name deduplication.

### Limits, licensing, and SDK evidence

- Official API guidance states 10 search requests/minute/IP for documented search endpoints, warns against search-as-you-type, and returns global HTTP 503 when infrastructure limits are exceeded. It also asks clients to send an identifiable custom `User-Agent`. The captured Search-a-licious OpenAPI publishes no separate quota; 10/min is therefore an intentionally conservative app cap.
- The database is ODbL; individual contents use DBCL; product images use CC BY-SA 3.0. Terms and attribution guidance apply. This feature projects metadata/nutrition, not images. Results and selected-food detail must attribute **Open Food Facts** and link its source/terms/license information; data accuracy is not guaranteed.
- Official `openfoodfacts-swift` README is marked “looking for maintainer”; its package is iOS 16-only and brings `BarcodeView` and `TOCropViewController`. It focuses on scanner/editor flows. Current nutrition code uses `URLSession`, protocol-injected clients, hostless macOS tests, and an actor-backed single-JSON barcode cache that currently writes access recency on reads. Direct `URLSession` is smaller, testable with mocked responses, avoids unrelated UI dependencies, and keeps v3.6/v2 decoding explicit; approved search-cache reads stay memory-only.

## Recommendations / approved architecture

1. **Separate client and identity.** Add a read-only Search-a-licious client behind a protocol. Accept remote hits only when app barcode normalization yields a valid 8–14 digit barcode and projected data normalizes to usable `FoodNutrition`. Merge local, cached, and remote foods by barcode; same-name products with different barcodes remain distinct. Selecting a hit persists normalized search nutrition through existing SwiftData rules for offline reuse and does **not** spend an additional product request. Existing barcode lookup remains v3.6-primary/v2-fallback and may refresh that same barcode when explicitly used later.
2. **Query key and trigger.** Key cache and in-flight work by trimmed, case-folded, internal-whitespace-collapsed query plus effective language list: current app language followed by `en` when different. Require 3 graphemes. Debounce 750 ms. Use page size 5. Merge and count useful local/cached/remote results first: fewer than 5 auto-fetches one page; 5 or more defers network work. Local rendering never waits for remote work.
3. **Pagination and generations.** A nonterminal query fetches its next missing page. A short or empty **raw remote page only** sets terminal knowledge; invalid/filtered hits do not make a full raw page terminal. Fresh terminal metadata suppresses automatic retry. Stale terminal metadata (90 days) revalidates page 1. Explicit bottom intent always permits an attempt, including fresh terminal state, but still obeys the limiter. Any terminal revalidation restarts at page 1 and replaces the old generation. Cancellation and generation checks prevent older query/page results from appearing.
4. **Freshness, cache, and rate control.** Positive page/result data has a 30-day TTL; terminal knowledge has a 90-day TTL. Use one persistent single-JSON LRU query cache, default maximum 2,048 queries and 32 MiB encoded size. Store normalized key, pages, fetch times, terminal state, and generation metadata. Reads update recency in process memory only and never write; fetches, mutations, and evictions persist atomically. Deterministic fixture measurement may revise either default. Use a process-memory rolling limiter capped at 10 search requests per 60 seconds. Explicit bottom can request, not bypass, this cap; retain local/cached content and show retry state when denied or failed.
5. **Tests and promotion.** Build deterministic mocked page fixtures for local-under-five, five-plus, short/empty pages, stale/fresh terminal state, page gaps, duplicate barcodes, cancellation, offline/error, limiter denial, cache restart, corruption, and LRU bounds. Add a deterministic UI fixture with seeded foods and mocked Search-a-licious responses. Use MCP only for initial visual/exploratory review, then promote repeatable MCP-to-UI behavior into a deterministic UI test before repeating manual proof. No live network belongs in normal gates.

## Implementation result

`FOOD-REMOTE-SEARCH-001` is implemented and visually accepted in attempt 02. Final implementation uses official flat Search-a-licious hits, current language followed by `en`, minimum three graphemes, 750 ms debounce, page size 5, useful-result merging with automatic one-page fetch below five, explicit load more, valid-barcode identity/deduplication, and final snapshots guarded by query/page generations.

Positive results remain fresh for 30 days; empty-terminal knowledge remains fresh for 90 days. A process-memory rolling limiter allows 10 requests per minute. Persistent storage is one JSON LRU bounded at 2,048 queries and 32 MiB encoded data; reads update memory-only recency and never write. Open Food Facts attribution is shown. Selecting a result persists normalized food data without product refetch, and DEBUG uses a deterministic fixture.

### Measurement and validation record

- 64 representative one-page five-hit queries encoded to 65,841 bytes. Projected 2,048-query storage is 2,106,912 bytes (about 2.01 MiB); count cap governs typical data while 32 MiB guards long/multipage outliers.
- Focused tests: client 11, cache 6, service 15, coordinator 8. Current hostless aggregate is 85 pass / 2 opt-in skips, including required `timed_out` decoding and partial-timeout rejection.
- Manual Xcode flow passed Remote Oat Drink at 250 ml and 100 kcal, dismissed keyboard, increased daily total by exactly 100 kcal after save, and persisted the selected food as a local row.
- UI suite had 2 pass / 2 fail before the final focus fix because the search keyboard lingered. Focus fix was manually proven. Later attempts were blocked before XCTest by process-handle failures even after recovery; exact-tree `just test-ui 300` then timed out before XCTest and reset the simulator. UI suite is not green.

## Official sources

- [API introduction, versions, limits, search, licensing](https://openfoodfacts.github.io/openfoodfacts-server/api/)
- [API v2 reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/)
- [Search-a-licious documentation](https://search.openfoodfacts.org/docs)
- [Search-a-licious OpenAPI](https://search.openfoodfacts.org/openapi.json)
- [Open Food Facts terms of use](https://world.openfoodfacts.org/terms-of-use)
- [License tutorial and attribution links](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/)
- [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1.0/)
- [Official Swift package](https://github.com/openfoodfacts/openfoodfacts-swift)
