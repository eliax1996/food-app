# BACKLOG-CLOSURE-001 — finite Markdown backlog closure

**Status:** ACCEPTED / COMPLETE — 3/3 FINAL APPROVE
**Date:** 2026-08-20

## Goal

Resolve every worthwhile candidate still mentioned in project Markdown, explicitly reject unsupported candidates, and leave no active/deferred implementation queue.

## Accepted implementation

### Historical Food Diary mutations

Known item snapshots support explicit add, edit, copy, delete, exact delete undo, and copy undo. `PlateEntry` provenance keeps unknown legacy aggregates visible but mutation-limited. Full-snapshot food-log attestation schema 2, retained-only historical goals, explicit destination/meal, duplicate **Keep Both**, nonfuture timestamps, stable identity collision rejection, stale-command compare-and-set, finite/Int-representable portions, nutrient scaling, one evidence bump, and one atomic coordinator save preserve truth and rollback.

### Personal nutrition targets

Optional carbohydrate, protein, fat, and fiber targets are validated as one complete local set. Plan retains general adult references, shows exact user-entered grams and macro energy, supports edit and confirmed **Use General References**, and compares today only with complete relevant nutrient coverage. Daily Nutrition exposes the same coverage-gated target context. Target writes never change calorie goal/source, logs, adaptive evidence, or goal revisions.

### Repeat-use, accessibility, and orchestration

- `FoodUsageRanking` derives recent and count/recency-ranked frequent names from local history. Ambiguous duplicate saved names fail closed rather than selecting arbitrary nutrition.
- `DailyCaloriesAccessibilitySummary` supplies one complete/incomplete semantic value to app and widget.
- `TodayExternalSurfaceCoordinator` projects persisted Today calories, completeness, water, goals, and reminder evidence before widget/reminder/Live Activity side effects.
- Dashboard and diary writes use coordinator; durable widget-water import now triggers synchronization after SwiftData save and revision acknowledgment.

## Closed rejections

Permanently rejected from current scope:

- HealthKit, accounts, and cross-device sync — no permission, identity, backend, conflict, or evidence-provenance contract; local/offline privacy remains product boundary.
- Streak/adherence coaching — no retention evidence and conflicts with calm, non-shaming hierarchy.
- Exercise-calorie credits — no trusted activity source; risks overstating available budget.
- Duplicate dashboard per-meal shortcuts — global Log food and meal-detail Log food already cover repeated entry.
- Photo recognition, cloud model fallback/full-description upload, LLM-authored nutrition, scanner-only entry, reminder windows, and extra amount sheet/hold-repeat variants — retained accuracy, privacy, fallback, and interaction evidence does not justify them.

These are decisions, not deferred tasks.

## Evidence

Light:

- `../screenshots/BACKLOG-CLOSURE-001/plan-personal-targets-top-light.png`
- `../screenshots/BACKLOG-CLOSURE-001/nutrition-personal-targets-top-light.png`
- `../screenshots/BACKLOG-CLOSURE-001/nutrition-personal-targets-light.png`
- `../screenshots/BACKLOG-CLOSURE-001/diary-actions-light.png`

Accessibility 3 dark:

- `../screenshots/BACKLOG-CLOSURE-001/plan-personal-targets-ax3-dark.png`
- `../screenshots/BACKLOG-CLOSURE-001/nutrition-personal-targets-ax3-dark.png`
- `../screenshots/BACKLOG-CLOSURE-001/diary-actions-ax3-dark.png`

Hierarchy-driven device walkthroughs used separate device-interaction subagents. Exact target rows, edit/reset controls, coverage, snapshot nutrients, and diary actions remained readable and scroll-reachable; no persistent overlap, clipping, or dead action was found. Every session was closed.

## Independent review findings resolved

Three independent reviewers received one identical neutral critical/high prompt. Successive passes found twenty-two material issues; all were fixed before final acceptance:

1. Widget-water import persisted water without rescheduling reminders/external surfaces. Import now synchronizes only after durable save and revision acknowledgment, with deterministic callback proof.
2. Historical CRUD fetched first matching `PlateEntry` under stable-ID collision. Required lookup now rejects unless exactly one row matches; persistence test proves neither collision row changes.
3. Recent/frequent shortcuts resolved duplicate names to arbitrary saved nutrition. Ambiguous names now fail closed and are excluded, with hostless coverage.
4. Generic Today edit could upgrade unknown legacy provenance. Legacy meal rows now expose delete only, and coordinator rejects generic updates without known item provenance.
5. Huge finite zero-calorie portion values could trap during `Double` to `Int` conversion. Shared portion validation rejects nonrepresentable values; model compatibility conversion never traps, including exact legacy undo.
6. Pre-upgrade item rows would remain read-only because new provenance decoded nil. One-time store-scoped migration now classifies only structurally valid rows whose name resolves to exactly one saved food; unmatched aggregates remain unknown permanently.
7. Delete accepted trusted legacy snapshots that restore’s new-row validation rejected. Restore now trusts and exactly rehydrates any snapshot returned by delete while retaining collision protection and safe compatibility conversion.
8. Repeated historical edits rescaled already-rounded integer calories. Persisted unrounded calorie density now survives item creation, copy, undo, attestation, and repeated edits, so `15 kcal / 100 g → 0 kcal / 1 g → 15 kcal / 100 g` is reversible.
9. Ranking considered unknown or future legacy rows. Usage events now require known item provenance and nonfuture finite timestamps; domain tests cover future exclusion.
10. Schema-1 empty or unmatched days could still appear Complete on Today. Startup now refreshes all completion staleness after migration, while Today directly requires current schema plus decodable snapshot before Complete.
11. Zero-ID legacy rows could be permanently stranded when migration marker advanced. Migration now assigns fresh collision-free IDs to every zero-ID row, verifies uniqueness before marking completion, and leaves unmatched rows delete-capable but edit/copy-limited.
12. Today editing reloaded mutable current `Food` and could rewrite logged calories/nutrients without explicit food replacement. Today now opens same persisted-snapshot editor as Food Diary; new logs alone read current saved food.
13. Today update/delete commands lacked frozen modification compare-and-set, and undo restored old token. Every user-triggered edit/delete/copy now checks frozen modification time; restore advances generation/time while preserving logged fields and stable identity.
14. Diary was reachable only from complete trend points. Progress now always exposes direct Food Diary, including empty/incomplete-only histories; focused UI proves first historical-log route before any complete trend.
15. Profileless stores had no durable migration completion and could reconsider rejected unknown rows after a matching Food appeared. Dedicated `AppMigrationState` now persists completion atomically independent of health/profile data; regression test proves no later promotion.
16. Reminder snapshots were wrapped in unstructured tasks, so stale invocation could claim newer manager generation. `enqueueReschedule` now assigns generation synchronously on MainActor and serializes work before returning its task.
17. Old delete undo could resurrect stale data after restore/edit/delete. Atomic bounded deletion tombstones carry one-use operation tokens; restore consumes token, advances mutation generation, and rejects obsolete undo.
18. Weight reminder refresh fetched long-lived UI context immediately after dedicated-context writes. Weight add/edit/delete/undo now routes through fresh-context `TodayExternalSurfaceCoordinator` projection.
19. Personal-target editor formatted persisted Doubles to one decimal and could mutate untouched precision. Initial fields now use locale-adjusted lossless `String(Double)` representation and accept scientific notation for tiny valid legacy values.
20. Delete snapshots sanitized malformed legacy nutrients and derived absent density before undo. Mutation snapshots now retain raw nutrient, density, legacy quantity, and optional portion fields; editing rejects malformed known rows while delete/undo restores raw data.
21. Unsupported legacy meal values were fabricated as Snack. Diary now uses explicit **Unknown meal** group/detail and blocks item mutation until meal provenance is valid.
22. Target parser accepted numeric prefixes/mixed separators through `NumberFormatter`. Shared strict full-string locale parser rejects misplaced signs, repeated/mixed separators, grouping, and malformed exponents; hostless tests cover syntax and exact roundtrip.

## Validation

Final working-tree results after review fixes:

- `just validate 600`: **243 hostless tests executed — 241 passed / 2 opt-in live skips**; app + widget build, simulator install, and launch passed.
- `just test-app-unit 900`: **351 passed / 2 opt-in live skips**.
- `TEST_CASE_TIMEOUT=60 just test-ui 2400`: **52/52 passed**.
- `git diff --check`: passed.

Functional UI covers direct diary access without a complete trend, historical add/edit/navigation, copy/delete/undo, Today snapshot-safe edit routing, personal target save/clear, and frequent-food selection. Deterministic/app-hosted suites cover raw exact undo, one-use tombstones, provenance/identity migration, reversible density, full snapshot staleness, collisions, stale commands, rollback, file reload/corruption, strict target parsing/bounds, ambiguous/future ranking, shared accessibility, external snapshot projection, widget-water/weight synchronization, reminder generation ordering, and overflow safety.

## Final review consensus

After every verified high finding above was fixed, three fresh independent reviewers received same unchanged neutral prompt and inspected final tree. Result:

```text
Reviewer 1: APPROVE
Reviewer 2: APPROVE
Reviewer 3: APPROVE
```

No critical/high finding remains. Earlier review rounds are retained as resolved hardening history, not residual disagreement.

## 2026-08-20 full Markdown re-audit

Fresh reviewers reread all 54 tracked Markdown files and cross-checked uncertain claims against current source/tests. Re-audit found documentation defects rather than missing production behavior: one unsupported day-estimate phrase, one superseded bulk row-override requirement, obsolete Log food labels/reminder-window wording, stale phase/current-count language, ephemeral or incorrectly relative evidence paths, missing delegation metadata, and a source-less iOS diagnostic needing explicit external-limitation disposition. Each was corrected or explicitly rejected with rationale; no item was silently deferred.

Parent mechanical audit reports 0 unchecked tasks, 0 broken inline links, 0 broken prose evidence paths, and 0 `/tmp` evidence references. Current `just test-unit 600` executed 243 tests with 241 pass / 2 opt-in live skips. Three fresh identical neutral repository-wide reviewers then returned **APPROVE / APPROVE / APPROVE**, each reporting 54 files read and 0 active/unresolved items.
