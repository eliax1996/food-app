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
- FOOD-REMOTE-SEARCH-001: accepted attempt 02. Official flat Search-a-licious search, bounded persistent query cache, explicit load more, attribution, and selected-food persistence verified.
- AMOUNT-EDITOR-001: accepted attempt 01. Prototype A inline amount controls, exact validation, g/ml semantics, accessibility layout, and keyboard-free correction verified.

# Current component

HISTORY-001 + PROGRESS-001 + WEIGHT-001 — next redesign phase.

# Next components

1. HISTORY-001 + PROGRESS-001 + WEIGHT-001
2. NAV-001 + SETTINGS-001 + REMINDERS-001
3. empty/error/loading states
4. global consistency, dark mode, Dynamic Type, small-device checks

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
- MUST HAVE: remote API food search with persistent query/page LRU and explicit load-more semantics — implemented and accepted as FOOD-REMOTE-SEARCH-001 attempt 02.
- HIGH VALUE: keyboard-free ±10/±1 amount editor — implemented and accepted; recent/frequent foods — recents implemented; target-aware calorie trend.
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

- Final FOOD-REMOTE-SEARCH-001 UI attempts were blocked before XCTest by process-handle failures even after recovery; exact-tree `just test-ui 300` then timed out before XCTest and reset the simulator. UI suite is not green.
- AMOUNT-EDITOR-001 diagnostic UI test was added; final attempts were blocked before XCTest because Application launch did not return a process handle after one recover. `just simulator-run` passed; UI suite is not green.
- Terra quota exhausted after repeated microtasks; straightforward work now routes to Luna `max` per updated model matrix.
- Large multi-image reviewer jobs time out; small evidence sets complete reliably.

# Last successful automated result

`just check` passed. Current hostless aggregate is 90 pass / 2 opt-in skips; AMOUNT-EDITOR-001 focused rules: 5 pass. Timed-out partial search responses remain rejected rather than cached as terminal.

# Previous full-app result

Full Xcode result: 52 passed, 0 failed, 2 opt-in live skips. Functional UI: 3/3 passed, including deterministic food-search/cancel journey. This is prior milestone evidence, not final remote-search UI-suite proof.

# Last visual verification

2026-08-08: AMOUNT-EDITOR-001 attempt 01 accepted. Almond Milk proof passed `100 g / 15 kcal` → `90 g / 14 kcal` → `100 g / 15 kcal`; Remote Oat Drink at `250 ml / 100 kcal` verified volume labels; Accessibility3 proof reached `90 g / 14 kcal` with serving `1`, readable menus, reachable total, and no clipping. Accepted screenshots are indexed in `SCREENSHOTS.md`.

Prior visual verification: FOOD-REMOTE-SEARCH-001 attempt 02 selected Remote Oat Drink at 250 ml / 100 kcal, dismissed keyboard, increased daily total by exactly 100 kcal after save, and confirmed persisted local row.

# Next action

Start HISTORY-001 + PROGRESS-001 + WEIGHT-001. Preserve AMOUNT-EDITOR-001 acceptance and its Xcode UI-host blocker as separate evidence.
