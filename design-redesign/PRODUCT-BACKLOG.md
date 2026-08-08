# Product redesign backlog

Persistent prioritized backlog. Read with `STATUS.md` before each redesign phase. Update status, evidence, decisions, tests, and outcome as work progresses.

## Priority 1 — [FOOD-REMOTE-SEARCH-001] Remote food search and query cache

**Status:** RESEARCH / DESIGN REQUIRED
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

### Trigger interpretation to validate before implementation

User wording mentions both `> 5` and “if smaller than 5 search.” Working interpretation:

- auto-search remotely after debounce when fewer than 5 useful local/cached results exist;
- if 5 or more useful results exist, defer network work until explicit load-more/scroll-bottom intent;
- fresh cached terminal metadata suppresses automatic repeat for the same normalized literal query;
- explicit load-more always queries the next page or revalidates terminal state.

Validate this interpretation against API pagination/rate limits and prototype behavior before locking code. Record any correction here.

### Research questions

- Which current official Open Food Facts search endpoint/schema is supported alongside v3.6 product lookup?
- Is another API justified, licensed, and compatible, or should “APIs” mean version/fallback layers of Open Food Facts?
- Search endpoint rate limit, pagination contract, field projection, attribution, User-Agent, and response size.
- Minimum query length and debounce interval that avoid noisy searches while feeling immediate.
- Exact query-key semantics: literal string versus trimmed/case-folded/whitespace-normalized equivalent.
- Page cache model, stale-while-revalidate behavior, cancellation, request coalescing, and in-flight deduplication.
- LRU capacity by item count and encoded bytes; migration/corruption recovery.
- Ranking and deduplication across local/cached/remote products.

### Initial technical hypothesis

Separate search client/protocol from barcode product lookup. Use deterministic coordinator with debounced query tasks, cancellation, in-flight request coalescing, paginated result state, and persistent Codable LRU entries containing normalized query, pages, terminal flag, timestamps, and last access. Keep raw DTO optionality at API boundary; expose only usable normalized search foods.

This is hypothesis, not approved architecture. Research and tests must justify it.

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
