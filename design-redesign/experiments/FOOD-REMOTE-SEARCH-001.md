# [FOOD-REMOTE-SEARCH-001] Remote food search

## Baseline

Meal food selection exposed local/saved foods only. A valid food absent from that list had no discovery path, and a large empty state risked consuming space needed by remote results and keyboard-safe controls.

---

## Attempt 01

Screenshot retained for comparison:

- `../screenshots/FOOD-REMOTE-SEARCH-001/attempt-01-results.png`

### Hypothesis

A full native unavailable state would explain an empty Saved foods section while remote search loads.

### Changes

Used full `ContentUnavailableView` for the empty Saved foods state while presenting remote-search controls below it.

### Feedback

The full `ContentUnavailableView` consumed 234 pt. With the search keyboard visible, it pushed remote controls beneath the keyboard and made remote discovery difficult to reach.

### Decision

REJECTED

### Reason

Empty-state explanation had too much vertical cost and broke keyboard-safe remote interaction.

---

## Attempt 02

Accepted screenshots:

- `../screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-results.png`
- `../screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-selected.png`
- `../screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-persisted.png`

### Hypothesis

A compact Saved foods empty row will preserve context without displacing remote results or controls.

### Changes

Replaced full `ContentUnavailableView` with compact `Saved foods` empty-row treatment. Kept remote results, selection, attribution, and persistence visible in one keyboard-safe flow.

### Functional evidence

Manual Xcode flow searched and selected Remote Oat Drink. Editor showed 250 ml and 100 kcal; keyboard was dismissed; saving increased daily total by exactly 100 kcal; selected food persisted as a local row without another product refetch.

### Visual evidence

Results, selected state, and persisted local row are captured in accepted attempt-02 evidence. The compact empty row keeps remote controls reachable and avoids the 234 pt attempt-01 expansion.

### Decision

ACCEPTED

### Reason

Attempt 02 preserves local context, keeps remote discovery usable with the keyboard, and proves selected-food persistence without adding a product request.

---

## Accepted implementation

- Search client consumes official flat Search-a-licious `hits`; it does not assume speculative nested search-result schemas.
- Query key and request policy use current app language followed by `en` when different, minimum 3 graphemes, 750 ms debounce, and page size 5.
- Coordinator merges useful local, cached, and remote foods. Fewer than 5 useful results auto-fetch one page; 5 or more defer network work until explicit load-more intent.
- Valid barcodes define remote identity and deduplication. Different products with same names remain distinct.
- Final snapshots and query/page generations prevent cancellation or older pages from replacing newer query state.
- Positive results use 30-day freshness; empty-terminal knowledge uses 90-day freshness. A process-memory rolling limiter caps search requests at 10 per minute.
- Persistent query cache is one JSON LRU with maximum 2,048 queries and 32 MiB encoded size. Reads update in-memory recency only and never write.
- Results and selected-food detail attribute Open Food Facts. Selecting a result persists normalized food data without product refetch. DEBUG uses deterministic search fixtures.

### Cache measurement

A deterministic measurement test encoded 64 representative one-page, five-hit queries at 65,841 bytes. Projecting that sample to 2,048 queries gives 2,106,912 bytes (about 2.01 MiB). The 2,048-query count therefore governs typical data; 32 MiB remains a guard for long or multipage outliers.

---

## Test and runtime record

- Focused suites: client 11, cache 6, service 15, coordinator 8. Cache focused run passed 6/6 after measurement coverage was added.
- Current hostless aggregate: 85 pass and 2 opt-in skips. Client coverage requires `timed_out` and rejects partial timeout responses rather than caching them as terminal.
- UI suite reached XCTest before the final focus fix: 2 passed and 2 failed because the search keyboard lingered. Focus fix was manually proven.
- Later feature-local UI attempts were blocked before XCTest by process-handle failures. Subsequent whole-product exact-tree UI suites passed remote search; archived host failure is not current missing work.

## Phase transition

FOOD-REMOTE-SEARCH-001 is accepted. Current redesign phase: `AMOUNT-EDITOR-001`.
