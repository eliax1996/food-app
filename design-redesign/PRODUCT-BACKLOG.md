# Product redesign backlog

Persistent prioritized backlog. Read with `STATUS.md` before each redesign phase. Update status, evidence, decisions, tests, and outcome as work progresses.

## Priority 1 — [FOOD-REMOTE-SEARCH-001] Remote food search and query cache

**Status:** IMPLEMENTED / ACCEPTED — ATTEMPT 02
**Priority:** MUST HAVE
**Origin:** User observed that typing a food absent from the local database produces no result.

### User problem

Local seeded/saved foods are finite. A valid food can appear absent even though Open Food Facts or another approved nutrition API knows it. Querying on every keystroke or repeating identical searches would waste bandwidth, increase latency, and hit API rate limits.

### Required product behavior

1. Keep local results immediate.
2. Search approved remote food APIs in background when local coverage is insufficient.
3. Cache remote results by query so identical research does not spend another request unnecessarily.
4. Use a persistent large bounded LRU cache. Choose `N` from measured encoded size and expected usage; document rationale rather than guessing.
5. Cache positive results, pages, fetch time, and knowledge that a query has no additional results.
6. Treat cached “no more results” knowledge as stale after approximately 90 days; repeat search because products can be added.
7. Explicit user intent to load more by reaching/scrolling below current results always permits a remote query, even when cached metadata previously said no more.
8. Selecting a remote result should reuse current normalized nutrition/serving rules and persist the selected food for future local/offline use.
9. Merge and deduplicate local, cached, and remote results without replacing different barcode products merely because names match.
10. Preserve useful cached results offline and surface remote failures without erasing local matches.

### Approved trigger and pagination interpretation

- Query key is trimmed, case-folded, internal-whitespace-collapsed query plus current language and `en` fallback when different.
- Require 3 graphemes; debounce 750ms; request page size 5.
- Merge local/cached/remote results and count useful foods. Fewer than 5 auto-fetches one page; 5 or more defers network work.
- Nonterminal state fetches next missing page. Short/empty raw page only sets terminal knowledge.
- Fresh terminal state suppresses automatic retry; stale terminal state revalidates. Fresh/stale terminal revalidation restarts page 1 and replaces old generation.
- Explicit bottom permits an attempt, including fresh terminal state, but obeys the 10/min search budget.
- Positive TTL is 30d; terminal TTL is 90d.

### Research questions

- Which current official Open Food Facts search endpoint/schema is supported alongside v3.6 product lookup?
- Is another API justified, licensed, and compatible, or should “APIs” mean version/fallback layers of Open Food Facts?
- Search endpoint rate limit, pagination contract, field projection, attribution, User-Agent, and response size.
- Minimum query length and debounce interval that avoid noisy searches while feeling immediate.
- Exact query-key semantics: literal string versus trimmed/case-folded/whitespace-normalized equivalent.
- Page cache model, stale-while-revalidate behavior, cancellation, request coalescing, and in-flight deduplication.
- LRU capacity by item count and encoded bytes; migration/corruption recovery.
- Ranking and deduplication across local/cached/remote products.

### Approved architecture

Use separate Search-a-licious client/protocol from barcode product lookup. Search consumes official flat `hits`; deterministic coordinator owns debounce, cancellation, in-flight coalescing, paginated state, final snapshots, generation checks, and a process-memory rolling limiter. Query policy is current language plus `en` fallback, minimum 3 graphemes, 750 ms debounce, and page size 5. Merge useful local/cached/remote foods; fewer than 5 auto-fetches one page, while explicit load more requests further work. Persistent single-JSON LRU stores query pages, terminal state, fetch times, and normalized keys; defaults are max 2,048 queries and 32 MiB, with no write on read. Positive data is fresh for 30 days; empty-terminal knowledge is fresh for 90 days. Raw DTO optionals stay at API boundary; valid barcodes define identity and deduplication. Selecting a search hit persists it without an additional product request; explicit barcode lookup remains v3.6-primary/v2-fallback. Attribute Open Food Facts and use a deterministic DEBUG fixture with MCP-to-UI promotion.

### Implementation outcome

- Attempt 01 was rejected: full `ContentUnavailableView` consumed 234 pt and pushed remote controls beneath the keyboard.
- Attempt 02 replaced it with a compact `Saved foods` empty row and was visually accepted. Evidence: `screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-results.png`, `attempt-02-selected.png`, and `attempt-02-persisted.png`; `attempt-01-results.png` remains retained for comparison.
- Cache measurement covered 64 representative one-page five-hit queries at 65,841 bytes; 2,048 projected to 2,106,912 bytes (about 2.01 MiB). Count cap governs typical data; 32 MiB guards long/multipage outliers.
- Focused tests: client 11, cache 6, service 15, coordinator 8. Current hostless aggregate is 85 pass / 2 opt-in skips. Timed-out partial search responses are rejected rather than cached as terminal.
- Manual Xcode flow passed Remote Oat Drink at 250 ml / 100 kcal, dismissed keyboard, increased daily total by exactly 100 kcal after save, and persisted local row without product refetch.
- UI suite had 2 pass / 2 fail before the final focus fix due to lingering keyboard. Focus fix passed manual review. Later attempts were blocked before XCTest by process-handle failures even after recovery; exact-tree `just test-ui 300` then timed out before XCTest and reset the simulator. UI suite is not green.

### Success criteria

- Local results render without waiting for network.
- Remote results appear for a locally missing food.
- Repeating same fresh query makes zero duplicate requests.
- Concurrent identical queries share one request.
- Auto-search follows the final five-result rule.
- Fresh terminal cache suppresses automatic retries; 90-day stale terminal cache revalidates.
- Scrolling to load more always attempts appropriate remote page/revalidation.
- Query cancellation cannot display stale results for newer text.
- Rate-limit/errors retain local/cached content and provide retry affordance.
- Cache survives recreation, evicts LRU entries, recovers from corruption, and remains bounded.
- Deterministic tests cover positive, empty, short, paginated, stale, explicit-more, rate-limit, cancellation, deduplication, offline, and cache behavior.

### Evidence and result log

- 2026-08-08: Backlog created from user observation. No endpoint or architecture selected yet.
- 2026-08-08: Official API introduction, v2 reference, Search-a-licious OpenAPI, license guidance, Swift package artifacts, current Nutrition code, and one live `almond milk` page reviewed. Search-a-licious `GET /search` selected for full-text search; 10/min conservative rolling limit, page/terminal TTLs, query/page LRU, valid-barcode identity, and UI fixture/test promotion approved. Full evidence: `docs/open-food-facts-search-assessment.md`.
- 2026-08-08: Implemented and accepted attempt 02 after compacting the Saved foods empty state. Manual Xcode proof passed Remote Oat Drink selection/persistence and an exact 100 kcal daily-total increase; final UI-host attempts remained blocked before XCTest and are not reported green. Experiment record: `experiments/FOOD-REMOTE-SEARCH-001.md`.

---

## Priority 2 — [AMOUNT-EDITOR-001] Human-friendly amount adjustment

**Status:** RESEARCH COMPLETE / PROTOTYPE A APPROVED
**Priority:** HIGH VALUE
**Origin:** User found keyboard-first amount editing clunky and requested ±10 and ±1 controls.

### User problem

Logging often means nudging a default amount from 100 g/ml to a nearby value. Opening a numeric keyboard, selecting text, typing, and dismissing is excessive for common corrections.

### Required product behavior

1. Research current quantity/serving editors in strong nutrition apps and relevant native iOS patterns before implementation.
2. Make amount adjustment usable without opening keyboard by default.
3. Provide explicit decrement/increment actions for 10 and 1 units: `−10`, `−1`, `+1`, `+10`.
4. Keep grams and milliliters explicit and use same normalized amount calculation.
5. Update calories immediately after every adjustment.
6. Prevent invalid/nonpositive values and define behavior near lower bound.
7. Preserve a path for unusual or large exact values if button-only adjustment becomes inefficient; do not make keyboard primary.
8. Keep serving-count presets conceptually separate from amount-unit adjustment.
9. Support VoiceOver labels/values, 44-point targets, repeat use, Dynamic Type, localization, and dark mode.

### Decisions

- Public evidence shows MacroFactor search results with direct actions and serving metadata, MyFitnessPal food-specific portion labels with a log action, and Foodnoms accessibility/unit claims. No inspected public source proves competitor keypad, Stepper, ±10/±1, or hold-repeat behavior; do not present those as competitor patterns.
- Approve A first: amount/value row plus `−10`, `−1`, `+1`, `+10`; one horizontal row at normal sizes, 2 × 2 at accessibility sizes, every target at least 44 pt.
- Derive unit from food (`g` or `ml`); no unit toggle. Preserve decimal remainder. Enforce `0.01` minimum and disable any decrement that would cross it. No hold-repeat.
- Keep exact entry secondary and servings/presets separate. Reuse normalized calorie math and update total immediately.
- Use compact-sheet B only if inline A fails visual review. Compare screenshots and repeated interaction cost; C is not first implementation.
- Verify VoiceOver, units, bounds, calorie scaling, 44-point targets, Dynamic Type, and separate servings with deterministic tests. Use MCP for bounded visual review, then promote repeated behavior to UI tests; MCP is not regression proof. Full assessment: `docs/amount-entry-pattern-assessment.md`.

### Success criteria

- Default amount can move from 100 to 90, 99, 101, or 110 in one tap.
- No keyboard appears for common adjustment.
- Value cannot become zero/negative.
- Calories animate/update correctly.
- Controls remain understandable for g and ml.
- Exact unusual values remain possible without crowding primary flow.
- Important controls meet 44-point targets and pass normal/large Dynamic Type.
- Existing fractional serving behavior and barcode defaults remain intact.
- Focused calorie-scaling and UI behavior tests pass.

### Evidence and result log

- 2026-08-08: Backlog created from direct user feedback. Competitive pattern research pending.
- 2026-08-08: Research completed; A approved for first prototype with B as inline-review fallback. Unit, VoiceOver, Dynamic Type, deterministic test, and MCP-to-UI promotion plan recorded in `docs/amount-entry-pattern-assessment.md`.
