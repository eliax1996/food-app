# Objective

Create calm, native, fast daily calorie tracker through screenshot-driven component iteration.

# Environment

Image input VERIFIED. Xcode MCP device interaction works on iPhone 17 Pro / iOS 27.0. Apple events delegated to exclusive subagent. Project operations use `just` only.

# Baseline status

Complete: build, launch, primary flow, 9 screenshots, architecture audit, current App Store reference sample.

# Completed components

- HOME-001 / CALORIES-001 / WATER-001 / MEALS-001: accepted attempt 11. Budget-first summary, 44pt water actions, compact meal summaries/details, explicit Log Food, secondary Food Tools menu.
- MEAL-001: accepted attempt 03. Explicit Add/Save, search/scanner, exact amount/servings, presets, live total, adaptive Accessibility Menu rows.
- FOOD-SEARCH-001: accepted attempt 02. Recents, top search, full catalog, reliable full-row selection.
- FOOD-CREATE-001 / BARCODE-001 presentation: accepted attempt 04. Secondary large Form, visible disabled lookup, custom-food round trip verified.

# Current component

FOOD-REMOTE-SEARCH-001 — official endpoint/rate-limit/cache/pagination research.

# Next components

1. FOOD-REMOTE-SEARCH-001 — API-backed query search, pagination, 90-day terminal knowledge, persistent large LRU
2. AMOUNT-EDITOR-001 — competitor research and keyboard-free ±10/±1 amount control
3. HISTORY-001 + PROGRESS-001 + WEIGHT-001
4. NAV-001 + SETTINGS-001 + REMINDERS-001
5. empty/error/loading states
6. global consistency, dark mode, Dynamic Type, small-device checks

# Accepted design principles

- Native SwiftUI before custom chrome.
- Remaining calories is primary daily answer.
- Repeated logging outranks food-database administration.
- Meal type should organize entries, not appear as tiny metadata.
- One clear action label per task; avoid `OK`.
- Semantic colors and typography; never color-only meaning.

# Accepted design decisions

- Keep three primary tabs.
- Preserve all existing functionality and offline behavior.
- Move custom-food/barcode tools out of dashboard hierarchy, not remove them.
- Use DEBUG-only in-memory design-review states.
- Normal Dynamic Type is visual target for accepted/final screenshots. Accessibility sizes are stress evidence only; never present them as default design.

# Feature opportunities

- MUST HAVE: meal-grouped daily log — implemented.
- MUST HAVE: remote API food search with persistent query/page LRU and explicit load-more semantics.
- HIGH VALUE: keyboard-free ±10/±1 amount editor; recent/frequent foods — recents implemented; target-aware calorie trend.
- HIGH VALUE, data blocked: macro targets/summary.

Detailed active backlog: `PRODUCT-BACKLOG.md`.

# Open questions

- Best balance between one global Log Food action and per-meal add actions.
- Whether automatic settings persistence is worth behavior change.

# Technical debt discovered

- Dashboard owns food library, scanner, persistence, widget, activity, reminders, and presentation state.
- No reusable semantic accessibility summary for daily status.
- Nutrition macros are not persisted on `Food`/`PlateEntry`.

# Blockers

- Terra quota exhausted after repeated microtasks; straightforward work now routes to Luna `max` per updated model matrix.
- Large multi-image reviewer jobs time out; small evidence sets complete reliably.

# Last successful build

Full Xcode result: 52 passed, 0 failed, 2 opt-in live skips. Functional UI: 3/3 passed, including deterministic food-search/cancel journey.

# Last visual verification

2026-08-08 12:29: Food Tools custom-food create/search/select/cancel passed; daily total unchanged. Disabled barcode affordance fixed afterward and full app/UI suite passed.

# Next action

Research official remote food-search API and competitor amount-entry patterns; update `PRODUCT-BACKLOG.md` before architecture/implementation.
