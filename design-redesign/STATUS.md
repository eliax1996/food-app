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
- HISTORY-001 / PROGRESS-001 / WEIGHT-001: **accepted attempt 02**. `History` is now `Progress`; target-aware seven-day calories, fourteen-reading weight trend, useful empty Weight action, and locale-safe Cancel/Save recording are verified.

# Current component

HISTORY-001 + PROGRESS-001 + WEIGHT-001 — **ACCEPTED, attempt 02**.

# Next components

1. Separate user-requested research into splitting navigation among calorie tracker, weight recording, and analytics; no split is pre-decided.
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
- HIGH VALUE: keyboard-free ±10/±1 amount editor — implemented and accepted; recent/frequent foods — recents implemented; target-aware calorie trend — implemented and accepted in Progress analytics.
- HIGH VALUE, data blocked: macro targets/summary.

Detailed active backlog: `PRODUCT-BACKLOG.md`.

# Open questions

- Best balance between one global Log Food action and per-meal add actions.
- Whether automatic settings persistence is worth behavior change.
- User-requested navigation split among calorie tracker, weight recording, and analytics; research only, with no design decision made in this milestone.

# Technical debt discovered

- Dashboard owns food library, scanner, persistence, widget, activity, reminders, and presentation state.
- No reusable semantic accessibility summary for daily status.
- Nutrition macros are not persisted on `Food`/`PlateEntry`.

# Blockers

- Final Progress `just test-ui 300` timed out before XCTest and reset simulator. UI suite is not green; deterministic preview evidence and hostless results remain valid separately.
- Navigation split is intentionally unresearched and undecided until next user-requested feature phase.

# Last successful automated result

`ProgressHistoryTests`: 16 pass. Aggregate: 106 pass / 2 opt-in skips. `just check` passed. Timed-out partial search responses remain rejected rather than cached as terminal.

# Previous full-app result

Full Xcode result: 52 passed, 0 failed, 2 opt-in live skips. Functional UI: 3/3 passed, including deterministic food-search/cancel journey. This is prior milestone evidence, not final Progress UI-suite proof.

# Last visual verification

2026-08-08: HISTORY-001 / PROGRESS-001 / WEIGHT-001 attempt 02 accepted through deterministic iPhone 17 Pro preview evidence. Calories, populated Weight, empty Weight, and weight editor captures are indexed in `SCREENSHOTS.md`. Fresh Banana diagnosis passed `100 g / 1 / 89 kcal` with keyboard hidden. Attempt 01 calories capture remains retained as rejected evidence.

# Next action

Start separate user-requested research into navigation split among calorie tracker, weight recording, and analytics. Do not pre-decide or redesign split in completed Progress milestone. Preserve attempt-02 acceptance, attempt-01 calories evidence, deterministic test results, and final UI-host timeout as separate evidence.
