# Historical calorie diary assessment

**Decision date:** 2026-08-18

**Milestone:** COMPETITOR-GAP-001

## User problem

Progress shows which recorded days were higher or lower, but not which logged foods produced a historical total. Today is meal-grouped and inspectable; yesterday becomes one bar. This breaks the path from trend to explanation.

## Current evidence

Retained first-party evidence establishes date-first food diaries and food-specific historical context:

- MacroFactor documents [logging to previous days](https://help.macrofactorapp.com/en/articles/228-log-food-to-previous-days) and [deleting foods from its timeline](https://help.macrofactorapp.com/en/articles/96-delete-foods-from-your-timeline).
- Cronometer documents its [mobile diary](https://support.cronometer.com/hc/en-us/articles/360018593112-Mobile-Diary-Overview) and [diary-entry editing/bulk actions](https://support.cronometer.com/hc/en-us/articles/360019003171-Mobile-Edit-Diary-Entries).
- MyFitnessPal documents [adding food to a diary](https://support.myfitnesspal.com/hc/en-us/articles/360032274592-How-do-I-add-a-food-to-my-food-diary) and [deleting diary food](https://support.myfitnesspal.com/hc/en-us/articles/360032624311-How-to-delete-an-entry-from-your-food-diary).
- Lose It! documents [planning food on another date](https://loseit.zendesk.com/hc/en-us/articles/47273187626260-How-to-Plan-Food-in-Lose-It).
- Foodnoms documents [editing entries](https://foodnoms.com/help/edit-entries).
- Lifesum documents [calendar context](https://help.lifesum.com/en/article/what-does-the-different-colours-in-the-calendar-represent-ios-bcpckv/) and [editing/removing diary items](https://help.lifesum.com/en/article/edit-or-remove-items-from-your-diary-mghpcc/).
- YAZIO documents [deleting diary entries](https://help.yazio.com/hc/en-us/articles/360002407038-How-can-I-delete-entries-in-my-Diary) and [copying entries to another day](https://help.yazio.com/hc/en-us/articles/360002401437-How-do-I-copy-Diary-entries-to-another-day).

Sources were retained/currently reassessed through 2026-08-18. They prove published capabilities, not undocumented action counts, goal-history semantics, or identical copy behavior.

## Product decision

Implement **read-only Historical Day Diary v1** as smallest safe, high-value gap closure:

```text
Progress / Calories → select recorded bar → View Day
→ dated diary with total + meal-grouped immutable logged snapshots
```

Why read-only first:

- `PlateEntry` already owns immutable logged food name, calories, amount, portion count, unit, nutrient facts, meal type, and timestamp.
- Current historical fixtures can contain aggregate legacy rows such as `Recorded meals`; read-only rendering remains truthful while editing would imply unavailable item-level provenance.
- Historical CRUD needs separate rules for goal context, attestation staleness, deletion confirmation/undo, backdating, copy destination, duplicate handling, and aggregate/legacy rows.
- Progress remains analytics-only. Diary answers “what produced this day?” without becoming a generic Calories/Water/Weight journal.

## Data contract

Hostless projection types:

- `CalorieDiaryRecord`: stable identity, date, meal type, food name, calories, logged amount, normalized g/ml unit, and portion count. `PlateEntry.weightGrams` is a legacy property name: its magnitude is expressed in paired `nutritionUnit` (g or ml), matching current logging and Today rendering. Unknown legacy unit strings normalize to grams rather than being rendered verbatim.
- `CalorieDiaryDay`: canonical local day, assessed calorie total/completeness, and four ordered meal groups.
- `CalorieDiary`: filters nonfinite dates, groups using injected `Calendar`, sorts newest day first, sorts entries chronologically with stable identity tie-break, and supports previous/next recorded-day navigation.

Rules:

1. Never reload nutrition from current `Food`; render `PlateEntry` snapshots only.
2. Unknown/legacy meal type falls back to Snack, matching Today compatibility behavior.
3. Invalid legacy calories stay visible as incomplete; known total is labeled incomplete and no budget claim appears.
4. Multiple records remain distinct, including same timestamp.
5. Navigation moves only among recorded days. It does not invent empty intervening days.
6. Future records remain inspectable as persisted legacy data but normal mutation paths continue rejecting future inserts.
7. No mutation control appears in v1.

## UI

- Progress chart selection exposes `View Day` only for selected recorded day.
- Push native `List` destination titled `Food Diary`.
- Header shows localized complete date, known daily calories or “Calorie total incomplete,” entry count, and previous/next recorded-day buttons.
- Meal sections follow Breakfast, Lunch, Dinner, Snack order and show only nonempty groups.
- Each row shows logged food name, amount/portion description, local time, and calorie snapshot. Invalid calorie value renders `Unavailable` with non-color-only warning semantics.
- Empty state remains available defensively but no chart action routes to an empty day.
- Dynamic Type stacks metadata; VoiceOver combines food, serving, time, and calorie state; buttons meet 44-point target.

## Scope

### Included

- Read-only date-first historical food detail.
- Previous/next recorded-day navigation.
- Meal grouping, totals, entry snapshots, localized timestamps.
- Complete/incomplete legacy-calorie state.
- Deterministic domain tests and functional UI journey.

### Excluded

- Historical add/edit/delete/copy.
- Water or weight rows.
- Generic mixed journal.
- Current-goal retroactive comparison.
- Recalculation from current food records.
- Personal macro targets, HealthKit, accounts, or sync.

## Acceptance

- Selecting a calorie bar then `View Day` opens matching local date.
- Displayed rows reconcile exactly with assessed day total.
- Historical entry remains unchanged if source food changes/disappears.
- Previous/next traverses recorded days in deterministic order and disables at ends.
- Legacy invalid calories mark day incomplete instead of understating intake.
- No diary control mutates data.
- Progress weight surface and root navigation remain unchanged.
- Normal, dark/Accessibility, hostless, app-hosted, and UI gates pass.
