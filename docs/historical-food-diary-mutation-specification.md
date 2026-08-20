# Historical Food Diary mutation specification

**Status:** IMPLEMENTED / ACCEPTED — BACKLOG-CLOSURE-001

**Decision date:** 2026-08-18

## User value

Read-only history explains prior intake but cannot correct a wrong amount/meal/time, remove an accidental row, reuse a logged food, or add a missed food. Date-first item actions are supported by retained MacroFactor, Cronometer, MyFitnessPal, Lose It!, Foodnoms, Lifesum, and YAZIO evidence in `historical-calorie-diary-assessment.md`.

Count Calories adds item-specific historical actions without turning Progress into a mixed journal or deriving old nutrition from mutable current foods.

## Scope

Included:

- add a saved food at an explicit nonfuture date/time and meal;
- edit amount, portion count, meal, and date/time for a known item snapshot;
- copy a known item snapshot to an explicit nonfuture date/time and meal;
- delete one persisted diary row after named confirmation;
- exact logged-field delete undo using deleted snapshot, stable identity, and one-use deletion token;
- duplicate warning with explicit **Keep Both**;
- full-snapshot food-log attestation invalidation;
- retained historical-goal context only when an actual goal revision exists.

Permanently excluded:

- generic Calories/Water/Weight journal;
- recalculation from a current `Food` after logging;
- inferred item provenance for unknown legacy aggregates;
- retroactive goal edits or fabricated goal history;
- automatic duplicate merging;
- future-dated logging;
- silent save, delete, or copy.

## Snapshot and provenance contract

`PlateEntry` remains the authoritative logged snapshot. New rows carry `LoggedSnapshotKind.item`. One store-scoped versioned migration first assigns collision-free identity only where old identity is zero, verifies all IDs, then classifies a pre-contract row only when amount/unit/meal/date are valid and its name resolves to exactly one saved food—the prior app’s item-level logging shape. Unmatched aggregate/corrupt rows remain `nil` permanently; nil means **unknown legacy**, never “known item.” Profileless stores persist same atomic migration marker without fabricating a profile, so rejected unknown rows are never reconsidered after food-library changes.

Mutation snapshots retain raw persisted identity, name, rounded calories, optional unrounded calorie density, paired amount/unit, legacy integer quantity plus optional fractional portion, raw nutrient optionals (including malformed legacy values), meal, timestamp, and creation/modification timestamps. Valid known items use these fields for editing; delete undo restores raw fields exactly.

Rules:

1. Diary display always reads `PlateEntry`; changing or deleting a current `Food` cannot rewrite history.
2. Known item snapshots may be edited or copied. Unknown legacy rows remain visible and may be deleted with warning/undo, but cannot be edited or copied as an individual food.
3. Existing unknown units remain display-normalized for compatibility, but mutation never silently converts an unknown stored unit.
4. Editing from Today or Food Diary uses same persisted snapshot editor. Mutable current `Food` records are never reloaded unless user starts a new log. Amount or portion changes scale calories and each known nutrient from persisted snapshot by:

   `new amount × new portions ÷ (old amount × old portions)`

   Scaling requires finite positive/Int-representable old/new quantities and a resulting calorie value in 0...5,000. Persisted calorie density—not an already-rounded edited integer—calculates each new rounded total, so repeated edits are reversible. Missing nutrient values stay missing. Food name and paired unit remain unchanged.
5. Adding from a saved food snapshots that food’s current reported calories, serving amount/unit, and nutrients at save time.
6. Copy preserves every logged nutrition/amount/name field exactly, while destination date/time and meal are explicit and stable identity is new.

## Date, duplicate, and destination rules

- All day identity uses the injected local `Calendar` and time zone.
- Every new or changed timestamp must be finite and no later than coordinator `now`.
- Existing future legacy rows remain inspectable but are not mutation sources.
- Add and copy open an explicit destination date/time and meal editor.
- An equivalent row means same destination local day, food name, calories, calorie-density bit pattern, amount bit pattern, portion bit pattern, stored unit, meal, and nutrient snapshot. Time need not match.
- Equivalent rows are allowed because repeated portions can be intentional. First save reports duplicate; only explicit **Keep Both** retries with duplicate permission.
- No empty dates are invented in previous/next recorded-day navigation.

## Persistence and evidence

All writes pass through `PlanEvidenceMutationCoordinator` and its private `ModelContext`:

1. begin with no uncommitted changes;
2. fetch by nonzero stable identity and reject collisions;
3. compare frozen modification token for every user-triggered edit/delete/copy before mutation;
4. validate complete command before mutation;
5. mutate entry, stale affected completion(s), and bump adaptive evidence once;
6. save once through the coordinator mutation phase;
7. rollback every staged effect on failure.

Affected completion days:

- add/copy: destination;
- edit on same day: that day;
- edit across days: source and destination;
- delete/undo: row day.

`FoodLogCompletion` schema 2 attests stable identity, date, name, calories, calorie density, amount, portions, stored unit, meal, nutrient fields, and provenance. Startup refresh marks schema-1, corrupt, or mismatched attestations stale even on empty/unclassified days; Today also gates Complete directly on current schema and decodable snapshot. Any logged snapshot change requires reconfirmation where reconfirmation is supported. Delete atomically persists a bounded one-use tombstone token. Undo trusts exact logged fields and stable identity from coordinator-issued snapshot—even if legacy name/value fields would fail new-row validation—but must consume matching token and advances modification generation/time. Obsolete undo cannot resurrect data after restore/edit/delete; no undo silently restores prior attestation.

Every actual food mutation increments `evidenceRevision` once and supersedes a pending adaptive proposal. Goal revisions are never changed. Diary goal context selects the highest retained revision sequence effective on or before the selected local day; absent history remains **Historical goal unavailable**.

## UI

`Progress → Calories → selected point → View Day` opens a query-backed Food Diary.

Progress exposes a direct **Food Diary** route even with no complete trend day, so invalid legacy-only rows can be inspected/deleted and first missed historical food can be added. Selected complete chart points retain contextual **View Day**.

Header:

- localized complete date;
- complete calorie total or explicit incomplete known total;
- logged-food count;
- retained historical goal or unavailable state;
- food-log attestation state;
- previous/next recorded-day navigation;
- **Log Food** action.

Known item row opens detail with **Edit Logged Food**, **Copy Food**, and **Delete Entry**. Unknown legacy detail names its limited provenance, permits only deletion, and never implies item-level nutrition confidence. Nil/unsupported meal values render under explicit **Unknown meal**, never fabricated Snack.

Delete names food/date, warns when completion becomes stale, and returns an **Undo** action. Edit uses Save/Cancel. Add/copy requires explicit Add/Copy. Duplicate confirmation names destination and uses **Keep Both**. Errors preserve current data and show retryable copy.

All app-owned actions are at least 44 points, carry stable accessibility identifiers, expose legacy/incomplete/stale states in text rather than color alone, and reflow at accessibility Dynamic Type sizes.

## Acceptance

- Known snapshots add, edit, copy, delete, and exact-undo through atomic coordinator APIs.
- Unknown legacy rows remain truthful and cannot be edited/copied.
- Paired g/ml, unrounded calorie density, and unknown nutrient values survive all supported actions; repeated round-trip amount edits recover original calories.
- Future timestamps, invalid scaling, collisions, stale commands, and unconfirmed duplicates fail closed.
- Full-snapshot metadata edits stale completion and adaptive evidence exactly once.
- Date moves stale both affected days; copy never changes source.
- Goal history is retained-only and never fabricated.
- Hostless policy tests, app-hosted coordinator/persistence tests, focused functional UI proof, accessibility/dark evidence, full validation, and independent critical/high review pass.

## Implementation result

Implemented through query-backed Food Diary add/edit/copy/delete/undo flows and atomic `PlanEvidenceMutationCoordinator` APIs. Full-snapshot attestation schema 2, one-time conservative provenance migration, stable-ID collision rejection, stale-command compare-and-set, duplicate/future rejection, reversible calorie density, retained-only goals, exact trusted delete undo, and external-surface synchronization are covered. Light and Accessibility 3 dark evidence is retained under `design-redesign/screenshots/BACKLOG-CLOSURE-001/`. Final gates reached 243 hostless executed (241 pass / 2 skips), 351 app-hosted pass / 2 skips, 52/52 UI, and 3/3 neutral critical/high approval. Every acceptance item in this specification is implemented.
