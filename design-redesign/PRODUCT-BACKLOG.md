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

**Status:** IMPLEMENTED / ACCEPTED — ATTEMPT 01
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

### Implementation outcome

- Prototype A is implemented and accepted in attempt 01. Domain minimum is `0.01`; adjustments require finite values, apply exact deltas, preserve decimal remainders, and use floating-boundary tolerance.
- Exact TextField remains secondary. Save uses same amount validity. Four controls are `−10`, `−1`, `+1`, `+10`; normal layout uses one row, Accessibility3 uses a 2 × 2 grid. Amount controls do not change servings, and common adjustment flow opens no keyboard.
- Normal Almond Milk proof: `100 g / 15 kcal` → `−10` → `90 g / 14 kcal` → `+10` → `100 g / 15 kcal`. Remote Oat Drink at `250 ml / 100 kcal` verifies volume labels. Accessibility3 proof reached `90 g / 14 kcal` with serving `1`; menus were readable, total reachable, and no clipping appeared.
- Accepted evidence: `screenshots/AMOUNT-EDITOR-001/attempt-01-normal.png`, `attempt-01-adjusted.png`, `attempt-01-milliliters.png`, and `attempt-01-accessibility3.png`.
- Focused amount tests: 5 pass. Aggregate: 90 pass / 2 opt-in skips; `just check` passed. A diagnostic UI test was added, but final attempts were blocked before XCTest because Application launch did not return a process handle after one recover. `just simulator-run` passed; UI suite is not green.

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
- 2026-08-08: Prototype A implemented and accepted in attempt 01. Focused amount tests passed 5/5; final UI attempts remained blocked before XCTest by process-handle failure after one recover, while `just simulator-run` passed.

---

## Priority 3 — [TRACKING-IA-001] Tracking navigation and weight-log information architecture

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Priority:** HIGH VALUE
**Origin:** User-requested navigation split research covering calorie tracking, weight recording, and analytics.
**Implementation:** Implemented, visually accepted, and complete in worktree.

### User problem

Current root labels and combined Progress behavior do not clearly separate daily action, analytics, and raw weight history. The initial assessment favored a pushed Weight Log because nutrition apps usually nest sparse weight capture. Explicit user feedback then prioritized discoverability, and dedicated-weight precedent supported a clear root Weight destination. Calorie history still has incompatible semantics and remains outside this milestone.

### Decision history and approved final decision

The original `eae1c92` assessment chose three root tabs and rejected a fourth:

```text
Today | Progress | Settings
```

That initial nutrition-only inference is superseded by explicit user feedback. Initial nutrition evidence still informs Today/Progress and the generic-table boundary, but discoverability plus dedicated-weight precedent now wins.

Final root order:

```text
Today | Weight | Progress | Settings
```

1. Rename `Counter` → `Today` and `Config` → `Settings`.
2. Add root `Weight`; its navigation title is **Weight Log**.
3. Weight shows current/recent-seven-reading/target summary, compact raw-seven-reading native line + points with target rule, grouped newest-first measurements, toolbar add, row edit/backdate, multiple same-day entries, delete confirmation, and stacked undo. One reading shows a useful prompt; explicit endpoint dates appear only with at least two readings. `View full trends` selects `Progress` / `Weight`.
4. Progress owns fuller fourteen-reading analytics and interpretation. Progress has no weight create/edit/delete controls.
5. Settings retains target weight, age, calorie goal, target date, and reminders; it has no current-weight field or save path.
6. No calorie CRUD is added. Future calorie history is a separate date-first day diary with meal-grouped food rows, never a generic mixed Calories/Water/Weight table.

Full decision, evidence labels, exact source URLs, and access date: `docs/tracking-navigation-assessment.md` (all external sources accessed 2026-08-08).

### Requirements

- Root tab bar exposes exactly `Today`, `Weight`, `Progress`, and `Settings` in that order; obsolete user-facing `Counter` and `Config` labels are removed.
- Today remains current-day calorie/food/water action surface.
- Progress exposes calorie and fuller fourteen-reading Weight analytics only; it has no weight CRUD. `View full trends` from Weight selects Progress / Weight.
- Weight root navigation title is `Weight Log`; toolbar `+` / `Record Weight` is the primary creation action. Measurements use native SwiftUI grouped sections by local calendar date, newest section first, newest rows first.
- Weight summary shows current, recent-seven-reading context, and target. Its compact chart uses up to seven raw readings with native line + points and target rule; endpoint dates appear only with at least two readings; one reading shows a prompt instead of a single-dot/dead chart.
- Toolbar add defaults to now and allows independently backdated date and time; row tap edits one raw record, including date/time.
- Row tap opens editor for value/date/time; updates one raw record only.
- Same-day measurements remain separate and visible; no daily overwrite or collapse.
- Delete requires explicit confirmation and stacked undo; accidental swipe cannot silently destroy data.
- Weight has no generic journal or calorie controls; its `View full trends` handoff selects Progress / Weight.
- Settings retains target weight, age, daily calorie goal, target date, and reminders; removes current-weight recording field and save path.
- Do not add historical calorie CRUD in this milestone. `PlateEntry` snapshot integrity and preview aggregate behavior require a separate future day-diary design.
- Do not create generic mixed history table. Keep food history date/meal semantics separate from weight measurement semantics.
- Preserve native accessibility: Dynamic Type, VoiceOver date/time/value labels and actions, localized formatting, dark mode, 44-point targets, and non-color-only meaning.

### Rejected options

- **Initial three-tab drill-down: `Today | Progress | Settings`:** superseded by explicit discoverability feedback and dedicated-weight precedent. Initial nutrition evidence remains relevant but no longer controls root order.
- **`Today | Log | Trends | Settings` with generic journal:** Log duplicates Today for current-day food work and creates one table with incompatible row density, aggregation, editing, and deletion rules. Calories history must become a separate day diary later, never this journal.

### Tests / success criteria

Acceptance gates are closed. TRACKING-IA-001 is accepted and complete.

- UI test confirms exactly four tabs in order and labels `Today`, `Weight`, `Progress`, `Settings`; `Counter`/`Config` absent.
- UI test confirms Progress Weight owns fuller fourteen-reading analytics and exposes no direct weight create/edit/delete controls; `View full trends` selects it.
- UI test confirms Weight tab title `Weight Log`, toolbar add, summary, compact seven-reading chart behavior, and useful one-reading prompt.
- UI test confirms target rule appears when valid and explicit endpoint dates appear only with at least two readings.
- Seed multiple dates/times; verify grouped newest-first sections and rows after reload.
- Save backdated weight with explicit date and time; verify exact displayed placement.
- Edit row value/date/time; verify only selected raw record changes.
- Save two same-day values; verify both survive persistence and analytics processing.
- Cancel deletion; verify record remains. Confirm deletion; verify only selected record disappears. Verify stacked undo restores deletions.
- Verify destructive actions never silently replace another same-day entry.
- Settings test confirms target weight, age, calorie goal, target date, and reminders remain; current-weight recording field is absent.
- Architecture/UI review confirms no generic Calories/Water/Weight table and no historical calorie CRUD claim.
- Accessibility review covers Dynamic Type, VoiceOver, localization, dark mode, and touch targets for navigation, log, editor, and destructive confirmation.

### Final results

- `just validate 300`: **passed**.
- Hostless validation: **125 passed / 2 opt-in live skips**.
- Simulator build, install, and launch: **passed**.
- `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`.
- Explicit UI target: **6/6 passed**, covering four tabs; one-reading prompt → two-reading chart; two same-day readings; backdated date regrouping; edit; delete cancel/confirm/undo; Settings; and direct `View full trends` → `Progress` / `Weight`.
- App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and passed again in an integrated run.
- One later standalone `just test-app-unit 300` timed out before XCTest. Record as external Xcode 27 host instability, not a red product gate.

### Evidence and result log

- 2026-08-08: Reviewed nonempty `/tmp/navigation-weight-research.txt`; Apple Health, Happy Scale, Withings, Weight Diary Lite, and Weigh In evidence separated recording, chronological history, and analytics. Monitor Your Weight evidence retained with legacy screenshot caveat.
- 2026-08-08: Broad `/tmp/navigation-nutrition-research.txt` timed out empty; bounded `/tmp/navigation-nutrition-focused-research.txt` then verified MacroFactor, Foodnoms, MyFitnessPal, and Cronometer placement. Initial nutrition evidence favors nested weight and remains relevant to Today/Progress; it does not override explicit discoverability feedback.
- 2026-08-08: Reviewed `/tmp/nutrition-history-research.txt`; date-first meal diaries and separate weight histories supported metric-specific flows rather than a generic table.
- 2026-08-08: Reviewed `/tmp/weight-history-research.txt`; native newest-first list, row edit/delete, date handling, raw-entry preservation, and accessibility patterns supported the implemented Weight tab.
- 2026-08-08: Original `eae1c92` three-tab/drill-down assessment was superseded by explicit user feedback plus dedicated-weight precedent. Final order is `Today | Weight | Progress | Settings`.
- 2026-08-08: Final attempt-01 navigation/visual evidence under `screenshots/TRACKING-IA-001/`: `attempt-01-four-tabs.png`, `attempt-01-weight-populated.png`, `attempt-01-weight-empty.png`, `attempt-01-weight-accessibility3.png`, and `attempt-01-weight-dark.png`. Earlier functional captures were renamed `superseded-three-tab-*` and retained only as pre-root implementation history. `rejected-one-reading-chart.png` is retained because a single dot is a dead chart; final behavior uses a prompt until two readings.
- 2026-08-08: `just validate 300` passed; hostless validation reported **125 passed / 2 opt-in live skips**; simulator build, install, and launch passed.
- 2026-08-08: Explicit UI target reached **6/6 pass** for four tabs, prompt-to-chart, two same-day readings, backdated regrouping, edit, delete cancel/confirm/undo, Settings, and direct `View full trends` to Progress / Weight.
- 2026-08-08: App-hosted persistence tests passed after duplicate-profile/future-row correctness fixes and again in an integrated run. One later standalone `just test-app-unit 300` timed out before XCTest; this is external Xcode 27 host instability, not a red product gate.
- 2026-08-08: TRACKING-IA-001 marked **ACCEPTED — ATTEMPT 01 / COMPLETE**.

### Next component

`empty/error/loading states`, followed by global consistency, dark mode, Dynamic Type, and small-device checks.

---

## Priority 3A — [WEIGHT-ENTRY-001] Low-friction weight and numeric entry

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Priority:** HIGH VALUE
**Origin:** User requested fewer weight-recording actions, latest-measure defaults, direct fine/coarse adjustments, and an obvious numeric-keyboard dismissal action.

### User problem

Weight check-ins are repeated, low-complexity actions. Re-entering the previous value or fighting a decimal keyboard adds avoidable work. Numeric pads also have no Return key, so every numeric entry surface needs an explicit way to close the keyboard without accidentally saving.

### Required product behavior

1. From Weight, recording an unchanged check-in requires no intermediate navigation: one action opens the editor with a useful value and one explicit Save records it.
2. New weight defaults to the chronologically latest valid recorded measurement, not profile setup weight. Fall back to valid profile current weight, then 70 kg only when no measurement exists.
3. Provide direct `−1`, `−0.1`, `+0.1`, and `+1` kg controls. Update the field immediately, preserve one-decimal precision, prevent nonpositive/nonfinite values, and keep exact keyboard entry available.
4. Keep date and time editable in the same editor; do not add a second confirmation screen or silently record from one tap.
5. Every app-owned numeric pad/decimal pad exposes a trailing keyboard **Done** action that only dismisses the keyboard. This includes weight, meal amount/servings, manual barcode, custom calories/serving/nutrients, Plan target weight, and future numeric setup fields.
6. Use Apple’s native `ToolbarItemGroup(placement: .keyboard)` plus focus state. Keep modal Save/Cancel semantically separate from keyboard Done.
7. Adjustment controls and keyboard Done remain VoiceOver-labeled, localized, dark-mode compatible, and at least 44 points where app-owned hit regions apply.
8. Add deterministic default/adjustment tests, focused UI proof for keyboard dismissal and value changes, normal/dark/large-text screenshots, and exact-tree validation.

### Success criteria

- Existing latest reading `71.2 kg` opens as `71.2`, regardless of older profile current weight.
- One tap can reach `70.2`, `71.1`, `71.3`, or `72.2`; controls never change date/time.
- Weight tab → editor → unchanged Save is two deliberate actions.
- Numeric keyboards always show Done and dismiss without committing the surrounding form.
- Existing amount controls, custom-food draft semantics, and explicit Save/Cancel flows remain intact.

### Result

Attempt 01 accepted. Latest chronological default and adjustment math have deterministic coverage; focused weight, meal-keyboard, and Plan-keyboard UI flows passed; normal and AX3-dark evidence passed critical/high review; exact-tree validation passed; final functional UI suite passed 14/14.

---

## Priority 3B — [SETTINGS-DIRECT-EDIT-001] Direct reminder and calculated-setup entry

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Priority:** HIGH VALUE
**Origin:** User found reminder values looked tappable but only the separate Edit action worked, and reported that Calculate a starting goal did not reliably enter setup from Settings.

### User problem

Settings summaries should lead directly to the focused editor they summarize. Requiring people to notice a distant top-bar Edit after tapping an `Off` value or meal time creates a dead interaction. Plan’s calculated-setup action must also open or resume the real setup flow and let Continue progress without changing the manual goal early.

### Required product behavior

1. Tapping any meal reminder row—including `Off` or its displayed time—opens the existing reminder draft editor. Keep the top Edit action as an alternate entry.
2. Tapping Weight or Water reminder summary rows opens that same explicit Save/Cancel editor; no summary tap toggles a preference, requests permission, or persists anything.
3. Use full-width native rows with at least 44-point hit regions, useful VoiceOver button traits/values, and visible affordance. Prefer opening near the relevant section when this remains reliable at all Dynamic Type sizes.
4. `Plan → Calculate a starting goal` must open new setup when no draft exists and resume the persisted step when setup is in progress.
5. Continue must work after entry from Settings through goal, body details, equation, routine, pace, and review. Existing manual goal remains unchanged until explicit final confirmation; Close preserves resumable draft.
6. Add focused UI regression coverage for reminder summary entry and Settings-origin calculated setup/Continue, then retain both paths in the full functional suite.

### UX decision

Direct row entry is better UX. Native Settings rows conventionally act as navigation/edit affordances, and displayed times/`Off` states describe exactly the configuration people expect to change. Whole-row entry reduces discovery cost without weakening explicit Save/Cancel semantics.

### Success criteria

- Meal `Off`/time, Weight, and Water rows each open reminder editor in one tap.
- Cancel after direct entry changes nothing and requests no notification permission.
- Calculate a starting goal opens from Plan, Continue reaches the next setup step, Close persists progress, and tapping the Plan action again resumes that step.
- Existing top Edit and accepted reminder scheduling behavior remain intact.

### Result

Attempt 01 accepted. Every meal row now shows `Off` or exact time with full-row button semantics and chevron; Weight and Water use equivalent summary rows. Taps open the explicit draft editor and scroll toward the selected section; Cancel leaves saved preferences and authorization untouched. AX3 uses vertical title/value layout instead of compressed wrapping.

Plan setup entry now uses one item-driven sheet presentation, fixing the reported dead `Calculate a starting goal` action. Focused UI proof opens from Settings, advances with Continue, closes without changing 1,700-kcal Manual source, and resumes at Goal. Final functional suite passed 22/22; normal and AX3-dark reminder evidence passed critical/high visual review.

---

## Priority 3C — [REFINE-001-SLICE-D] Evidence-gated adaptive calorie check-ins

**Status:** ACCEPTED — ATTEMPT 03 / COMPLETE
**Priority:** HIGH VALUE

Explicit complete-day attestations, stable evidence identity, distributed weight requirements, coincident agreeing 28/35/42 estimates, bounded weekly proposals, Adapted source, per-day goal revisions, explicit apply/decline/disable, and exact revert are implemented. Missing days never become zero; empty completion needs genuine-zero confirmation; unknown/corrupt context fails closed. Final validation: 195 hostless pass / 2 skips, 250 app-hosted pass / 2 skips, functional UI 31/31, and visual 3/3 APPROVE. Full contract: `docs/adaptive-calorie-plan-specification.md`.

---

## Priority 3D — [BULK-AI-FOOD-001] Typed or dictated bulk food logging

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Priority:** USER-PRIORITIZED

### User problem

Logging several foods one by one is slow when user can describe meal naturally. Proposed solution must preserve nutrition accuracy, privacy, recoverability, and explicit review rather than turning language-model guesses into logged facts.

### Required direction

1. Add compact AI-assisted bulk-entry action integrated with existing Today/Meal flow, minimizing clicks without displacing direct Log food.
2. Accept editable typed paragraph and optional microphone transcription. Speech populates same text field; typed fallback always works.
3. Use Apple SystemLanguageModel/Foundation Models only when supported and available; specify OS/device/language availability and truthful fallback before implementation.
4. Extract provisional `(food query, amount/weight)` items asynchronously. Missing amount may get a clearly marked LLM estimate, but calories/macros must never come from LLM.
5. Match each item through existing saved/cache/Open Food Facts pipeline. Generic terms prefer retained matching user selections by recency/frequency/LRU before remote search.
6. Show loading/progress and partial failures, then one editable review surface with transcript/query/amount plus selected product result beneath every item.
7. Tapping item edits query, amount, selected product, serving, and explicit nutrition override through existing food editor semantics. Every row remains marked for review until resolved.
8. Confirm performs one atomic batch insert into chosen meal/day and invalidates complete-day evidence once. Cancel inserts nothing and preserves editable draft until explicit discard policy.
9. Retain corrected extraction examples on device with bounded storage, provenance, schema/version, recency, generic-term key, and deletion controls. Never upload meal text or imply model training.
10. Research competitors deeply and write detailed data model, pipeline, privacy, permission, availability, async/cancellation, matching/ranking, retained-learning, accessibility, localization, and acceptance Markdown before code.

### Guardrails

- LLM output is provisional text structure only; selected food data or explicit user edits own nutrition.
- Explicit review and confirmation required; no silent insertion.
- Speech permission/denial and Foundation Model unavailable states stay truthful.
- Sensitive meal text and retained corrections remain on device and user-deletable.
- Batch confirm is atomic; partial lookup can be reviewed, retried, removed, or canceled without partial logging.

### Result

Attempt 01 accepted. Describe/Dictate feeds on-device provisional query/amount/unit extraction, then local-first verified matching and editable review. Default/model estimates require explicit acceptance; invalid visible amounts and every unresolved row block confirmation. Saved/custom recovery, seven-day draft, bounded clearable learning, iOS 17 fallback, frozen post-commit learning, durable operation/row/date identity, and atomic idempotent coordinator persistence are implemented. Final critical/high review consensus: **3/3 APPROVE**.

Reminder usability follow-up also replaced misleading per-meal editor rows with visible saved times + Enabled/Disabled state and one customization action separating meal switches from notification timing.

---

## Priority 4 — [NUTRITION-GOALS-001] Reference nutrition composition in Plan

**Status:** ACCEPTED WITH REFINE-001 SLICE A — ATTEMPT 01
**Priority:** HIGH VALUE
**Origin:** User requested a theoretical healthy carbohydrate, protein, fat, and fiber composition beside measured intake.

### User problem

A calorie goal alone does not explain what a broadly balanced adult macro composition could look like. Daily measured grams are also hard to interpret without a transparent comparison. Calling one composition “ideal” would overstate general population guidance and ignore individual or clinical needs.

### Required product behavior

1. In the Plan/goal surface, show general adult **reference ranges**, not a universal “ideal”: carbohydrates 45–65%, protein 10–35%, and fat 20–35% of total energy.
2. Convert those percentages into theoretical gram ranges for the selected daily calorie goal using 4 kcal/g for carbohydrate and protein and 9 kcal/g for fat. Show both percentages and grams, plus the calculation basis.
3. Show fiber’s energy-scaled adult reference of 14 g per 1,000 kcal as a daily gram value for the selected calorie goal.
4. Compare today’s real measured composition with the reference beside it: actual grams and estimated shares of reported logged calories versus reference ranges, plus measured fiber versus its reference. Keep the normalized colored macro-only split explicitly separate.
5. Gate actual-versus-reference comparisons on 100% relevant nutrient coverage. Keep known partial grams visible, but never estimate missing values or treat them as zero.
6. Keep food-label calories authoritative and separate from 4/4/9-derived macro energy; explain why the values may not reconcile exactly.
7. Recalculate theoretical ranges when the calorie goal changes. Do not silently alter logged foods, calorie goals, or user choices.
8. Label guidance as general adult population information, not medical advice or a personal prescription. Preserve explicit exclusions for children, pregnancy/lactation, clinical diets, and other individualized needs.
9. During REFINE-001 research, decide whether users may optionally set personal macro targets while retaining transparent reference defaults and a restore action.
10. Cover formulas, rounding, finite/boundary calorie goals, unit presentation, missing coverage, VoiceOver, Dynamic Type, and dark mode with deterministic tests and screenshots.

### Success criteria

- Plan shows a calorie-goal-derived reference composition in percentages and grams for all four requested nutrients.
- Daily detail makes theoretical reference and real measured values easy to compare without an opaque score.
- Every displayed comparison exposes its basis and coverage.
- No missing nutrient is inferred and no general reference is presented as universally optimal.

### Scheduling decision

NUTRIENTS-001 is accepted and now supplies trustworthy persisted actuals, coverage, and measured daily comparison. Goal-integrated theoretical values proceed with REFINE-001’s explainable Plan/calorie-goal work.

---

## Priority 5 — [AUXILIARY-001] Widget and Live Activity

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Priority:** CLOSURE

Medium widget now matches Today’s remaining/over-goal hierarchy, shows eaten/goal and water progress, and keeps Log food plus bounded water actions. Cross-process locked revision handoff preserves widget water until SwiftData imports it. Live Activity requires explicit Start/Stop, carries current goals in dynamic state, and provides goal-aware Lock Screen/Dynamic Island layouts without display-only mutation controls. Light/dark/AX3 evidence and final 3/3 critical/high approval are retained in `design-redesign/experiments/AUXILIARY-001.md`.

---

## Priority 6 — [CONSISTENCY-001] Whole-app consistency

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Priority:** CLOSURE

Accepted app/widget surfaces share one navigation, hierarchy, semantic-color, typography, state, and confirmation system. Final fixes standardized persisted intake actions as **Log food**, named provisional bulk insertion **Add another food**, and enforced one-glass bounded water deep links. Intentional Weight Log, dialog, bulk, destructive-check-in, and widget-family differences are documented in `docs/whole-app-consistency-assessment.md`. Final critical/high review: **3/3 APPROVE**.

---

## Priority 7 — [ROBUSTNESS-001] Whole-app stress matrix

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Priority:** CLOSURE

Light/dark, normal/AX3, fixed small/large iPhone, and long/extreme/empty/dense fixtures are covered. Today status and water controls plus Settings summary rows now adapt vertically at accessibility sizes; preview fixtures ignore external widget side effects; focused UI proves lower primary actions remain scroll-reachable. Evidence and final 3/3 critical/high approval are recorded in `docs/whole-app-robustness-assessment.md`.
