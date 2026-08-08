# TRACKING-IA-001 — Tracking navigation and weight-log assessment

**Status:** RESEARCH COMPLETE / ARCHITECTURE APPROVED
**Decision/access date:** 2026-08-08
**Implementation:** Not started. This document records architecture approval before code changes.

## Decision

Keep three primary tabs:

```text
Today | Progress | Settings
```

- Rename `Counter` to **Today**.
- Rename `Config` to **Settings**.
- Keep **Progress** as analytics-only.
- Progress `Weight` segment links to dedicated **Weight Log**. Weight Log is a pushed destination, not a fourth tab.
- Weight Log uses a newest-first native grouped list, a `+ Record Weight` action, row editing, date/time backdating, raw multiple same-day entries, and protected deletion.
- Weight Log has no chart. Charts stay in Progress.
- Do not add a Today shortcut inside Weight Log initially.
- Settings removes current-weight recording field. Retain target weight, age, calorie goal, target date, and reminders.
- Defer calories historical CRUD. Future calorie history must be a separate date-first day diary, never a generic mixed Calories/Water/Weight table.

This decision is approved for implementation. No implementation acceptance is implied by this research status.

## Scope and evidence notation

- **Verified (V):** directly documented or shown by cited source.
- **Inference (I):** design implication drawn from verified evidence; not a vendor claim.
- **Repo-verified (R):** observed in current repository while preparing this assessment.
- **Decision (D):** Count Calories product choice approved here.

Research inputs:

- `/tmp/navigation-weight-research.txt` — nonempty; reviewed.
- `/tmp/navigation-nutrition-research.txt` — broad run was empty after timeout; no evidence taken from it.
- `/tmp/navigation-nutrition-focused-research.txt` — bounded MacroFactor, Foodnoms, MyFitnessPal, and Cronometer navigation report; reviewed.
- `/tmp/nutrition-history-research.txt` — reviewed.
- `/tmp/weight-history-research.txt` — reviewed.

All external sources below were accessed 2026-08-08. Screenshots and App Store listings prove shown UI or published claims; they do not prove undocumented behavior.

## Approved information architecture

### Root tabs

| Tab | Role | In scope |
| --- | --- | --- |
| **Today** | Daily action surface | Current-day calorie budget, meals/food, water, and existing daily tracking actions. `Counter` label becomes `Today`. |
| **Progress** | Analytics surface | Calorie history analytics and Weight analytics. Weight segment offers a clear route to Weight Log; it does not own weight CRUD. |
| **Settings** | Profile and planning | Target weight, age, calorie goal, target date, and reminders. `Config` label becomes `Settings`; current-weight recording field is removed. |

Three tabs preserve stable top-level orientation without promoting sparse weight data to equal root status. Weight remains discoverable through Progress analytics and its dedicated log.

### Progress

Progress is read-oriented analytics. Its metric segments may show calorie summaries and weight trend/target analytics, but Progress does not directly create, edit, or delete a weight record. The Weight segment links to Weight Log with an explicit action such as `View Weight Log`.

The weight chart belongs here, alongside trend context. It does not move into Weight Log. This keeps the distinction clear:

```text
Progress / Weight = what pattern means
Weight Log        = what was recorded
```

### Weight Log

Weight Log is a dedicated drill-down from Progress / Weight.

- Use native SwiftUI list behavior, not spreadsheet-first columns.
- Group rows by local calendar date, with newest date section first.
- Sort rows newest-first within each date section.
- Preserve every raw measurement, including multiple measurements on one calendar day. Never silently replace same-day data or collapse it to one daily value.
- Show each row's weight and date/time clearly. Native Dynamic Type, VoiceOver, and localized date/time formatting are required.
- Put `+ Record Weight` in the log as the primary creation action.
- Record form defaults to current date/time but permits independent date and time backdating.
- Tapping a row opens the same editor for correction, including date/time.
- Delete is an explicit row action with confirmation. A confirmed deletion must offer an undo path; a swipe or accidental gesture must not silently destroy data.
- Do not put a chart in Weight Log.
- Do not add an in-content Today shortcut initially. The tab bar remains navigation; revisit shortcut only after observed navigation need.

The log is a raw measurement record, not a daily summary. Progress may calculate trend values from these raw entries, but analytics must not mutate or hide records.

### Settings

Retain these controls:

- target weight;
- age;
- daily calorie goal;
- target date;
- reminders.

Remove current-weight recording from Settings. Weight recording has one home: Weight Log.

## Calories history boundary

Historical calorie CRUD is deferred from TRACKING-IA-001.

**Repo-verified constraint (R):** `PlateEntry` stores food-name, calorie, amount, quantity/portion, serving-unit, meal type, and date snapshots. Existing calorie history groups those records by calendar day and sums calories; preview data also seeds aggregate-style historical entries. A generic historical editor would need explicit rules for preserving the `PlateEntry` snapshot when its source `Food` changes, and for keeping preview/aggregate data coherent. That integrity and preview-aggregate issue is not resolved by navigation alone.

**Decision (D):** Do not add calorie historical edit/delete to Weight Log, Progress, or a mixed log. Future calorie history is a separate day diary with date context, meal sections, food-specific row editing, and food-specific delete/copy semantics. It must never be a generic table mixing Calories, Water, and Weight.

This boundary preserves current food-entry behavior while preventing an unsafe, semantically ambiguous journal from becoming a navigation destination.

## Rejected options

### Four tabs: `Today | Weight | Progress | Settings`

Rejected for Count Calories:

- Weight data is sparse compared with daily calorie activity; a Weight tab gives a low-frequency task equal root status.
- Raw weight records and their interpretation become split across peer Weight and Progress tabs.
- Current nutrition-app evidence nests weight capture/history instead of making Weight a primary tab.

Use dedicated Weight Log as a drill-down instead: weight recording and history stay coherent without a sparse fourth tab.

### `Today | Log | Trends | Settings` with a generic journal

Rejected because `Log` duplicates Today for current-day food work while inviting a generic historical journal. A mixed journal is unsafe: calorie rows are meal/time and snapshot-rich, weight rows are sparse measurements with backdatable date/time, and water has different aggregation/deletion rules. Shared persistence does not justify shared primary UI.

Future calories history can be a separate day diary. It must not become this generic table.

## Research synthesis

### Verified patterns

1. **Apple Health separates metric detail, recording, logbook, and analytics (V).** Apple documents category/metric detail, `Add Data` with date/time/value, `Show All Data` chronological records, edit/delete controls, and trend views. Recording and history are controls inside a metric context rather than one global mixed table.
2. **Nutrition trackers keep broad daily-log and analytics destinations top-level (V).** MacroFactor uses Dashboard/Food Log, Foodnoms uses Food Log/Insights, MyFitnessPal uses Today/Progress, and Cronometer uses Diary/Discover. Their weight capture/history is nested or reached through a global add action; none of the reviewed current navigation sets has a top-level Weight tab.
3. **Dedicated weight products separate logbook and reports (V).** Happy Scale exposes Summary, Reports, Logbook, Settings, and a global add action; Monitor Your Weight's current App Store screenshot shows Summary, Reports, Logbook, Settings, and `+`. These are precedent, not a requirement to copy their tab count.
4. **Native timeline/list patterns support this log (V).** Withings documents a newest-first measurement timeline with edit/delete actions. Happy Scale documents row editing and date changes. Apple and Withings show chronological metric records rather than spreadsheet-first mobile tables.
5. **Weight records and food diaries have different structures (V).** Nutrition research found food logs organized by selected day and meal/time, while weight is handled as a separate dated list/chart or body-measurement history. Row editing/deletion, backdating, and bulk semantics vary by data type.
6. **A native chronological list is the strongest mobile default (I).** The verified Apple/Withings patterns and weight-history comparison favor a grouped native list for scanability, Dynamic Type, VoiceOver, and touch accuracy. Spreadsheet density is better suited to export, cleanup, or desktop-sized datasets.
7. **Metric-specific drill-down beats a generic table (I).** Food, water, and weight differ in frequency, context, aggregation, and destructive actions. A shared model can exist underneath, but primary UI should preserve those semantics.

### Current repository baseline

The current root composition is `Counter`, `Progress`, and `Config` (R). Current Progress combines calorie analytics, weight analytics, and a direct weight recorder; current weight recording can update today's entry/profile state (R). TRACKING-IA-001 changes that architecture: labels become Today/Settings, Progress becomes analytics-only, and raw weight CRUD moves to Weight Log. Existing HISTORY-001 / PROGRESS-001 / WEIGHT-001 attempt-02 evidence remains the pre-change baseline.

Observed repository files:

- `count_calories/App/ContentView.swift`
- `count_calories/Features/History/HistoryView.swift`
- `count_calories/Models/MealModels.swift`
- `count_calories/Models/WeightAndProfileModels.swift`
- `count_calories/Tracking/CalorieHistory.swift`
- `count_calories/App/PreviewData.swift`

## Requirements for implementation

| ID | Requirement |
| --- | --- |
| IA-01 | Root tab bar has exactly three destinations labeled `Today`, `Progress`, and `Settings`. |
| IA-02 | Existing `Counter` user-facing label becomes `Today`; existing `Config` user-facing label becomes `Settings`. |
| IA-03 | Progress remains analytics-only. No direct weight create/edit/delete control lives in Progress. |
| IA-04 | Progress Weight segment exposes a clear route to Weight Log. Weight chart/trend remains in Progress. |
| IA-05 | Weight Log is a pushed, dedicated destination with no chart and no in-content Today shortcut initially. |
| IA-06 | Weight Log uses newest-first native grouped sections by local calendar date and newest-first rows. |
| IA-07 | `+ Record Weight` creates raw measurement with value plus independently editable date and time; default is now, backdating is supported. |
| IA-08 | Row tap edits existing raw measurement, including date/time. |
| IA-09 | Multiple same-day raw entries remain visible and distinct. No same-day overwrite or daily collapse. |
| IA-10 | Deletion requires explicit confirmation and provides undo; accidental swipe/gesture cannot silently delete. |
| IA-11 | Settings retains target weight, age, calorie goal, target date, and reminders; removes current-weight recording field. |
| IA-12 | No calorie historical CRUD is added in this scope. Future calorie history is a separate meal/day diary, never a generic mixed table. |
| IA-13 | Native controls support Dynamic Type, VoiceOver labels/actions, localized date/time, sufficient touch targets, and semantic non-color-only state. |

## Tests and success criteria

Implementation is not started; tests below are acceptance gates, not completed results.

### Navigation and destination tests

- Launch shows exactly three primary tabs: `Today`, `Progress`, `Settings`.
- Accessibility labels and visible labels contain `Today` and `Settings`; obsolete user-facing `Counter` and `Config` tab labels are absent.
- Progress can switch between analytics metrics without exposing weight create/edit/delete controls.
- Progress Weight has a discoverable Weight Log link.
- Weight Log is reached from Progress Weight and has no chart or in-content Today shortcut.

### Weight Log behavior tests

- Seed entries across dates and times; verify date sections and rows are newest-first.
- Seed two or more entries on one calendar day; verify every raw value/time remains visible after reload.
- Tap `+ Record Weight`; verify default date/time is now, then save a backdated date and time and verify exact row placement.
- Tap an existing row; change value/date/time; verify only that row changes and ordering/grouping updates.
- Attempt row deletion through each exposed destructive affordance; verify confirmation appears, cancel preserves data, confirm removes only selected row, and undo restores it.
- Verify no code path turns a second same-day record into an update of the first record.
- Verify Progress analytics can consume raw entries without mutating the Weight Log dataset.

### Settings and scope tests

- Settings still exposes target weight, age, calorie goal, target date, and reminders.
- Settings has no current-weight recording field or save path.
- No generic mixed Calories/Water/Weight history table is introduced.
- Current-day food logging remains available in Today; no historical calorie CRUD is claimed by this milestone.
- Dynamic Type, VoiceOver, localized date/time, and minimum 44-point interaction targets remain usable in tabs, route, list, editor, and destructive confirmation.

## Evidence log

- **2026-08-08 — V:** Reviewed `/tmp/navigation-weight-research.txt`. Apple Health, Happy Scale, Withings, Monitor Your Weight, Weight Diary Lite, and Weigh In evidence consistently separates recording, chronological history, and analytics, with varying tab choices and several legacy screenshot caveats.
- **2026-08-08 — V:** Reviewed `/tmp/nutrition-history-research.txt`. MacroFactor, Cronometer, MyFitnessPal, Lose It!, Foodnoms, Lifesum, and YAZIO evidence uses date-first food diaries and meal/group-specific actions; weight remains a separate measurement/history concern.
- **2026-08-08 — V:** Reviewed `/tmp/weight-history-research.txt`. Apple Health, Happy Scale, Withings, and dedicated weight apps support chronological native lists, row edit/delete patterns, date handling, and preservation of raw readings; source file explicitly marks undocumented behavior and inferences.
- **2026-08-08 — V:** Broad `/tmp/navigation-nutrition-research.txt` timed out empty and contributed no evidence. A bounded follow-up, `/tmp/navigation-nutrition-focused-research.txt`, verified current navigation/placement for MacroFactor, Foodnoms, MyFitnessPal, and Cronometer; daily log and analytics remain broad destinations while weight is nested or globally added.
- **2026-08-08 — R:** Current repository inspection confirmed three existing root destinations (`Counter`, `Progress`, `Config`), combined Progress analytics/weight recording, `PlateEntry` snapshot fields, and calendar-day calorie aggregation. No repository files were changed during research.
- **2026-08-08 — I:** Synthesized evidence favors three stable top-level tasks plus metric-specific drill-down, native grouped weight history, and a separate future calorie diary rather than a generic mixed table.
- **2026-08-08 — D:** Approved `Today | Progress | Settings`; Progress analytics-only; dedicated Weight Log with raw newest-first grouped entries, record/edit/backdate/delete safety; Settings field boundary; calorie-history deferral.

## Source index — exact URLs

All URLs accessed 2026-08-08.

### Navigation and weight

- [Apple iOS 26 Health guide](https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/26/ios/26)
- [Apple manage Health data](https://support.apple.com/en-us/108779)
- [Apple Add Data screenshot](https://cdsassets.apple.com/live/7WUAS350/images/health/ios-26-iphone-16-pro-health-browse-activity-steps-add-data.png)
- [Happy Scale App Store listing](https://apps.apple.com/us/app/happy-scale/id532430574)
- [Happy Scale support](https://happyscale.com/support)
- [Withings App Store listing](https://apps.apple.com/us/app/withings/id542701020)
- [Withings Home tab](https://support.withings.com/hc/en-us/articles/39368966174481-Withings-App-Home-tab)
- [Withings manual logging](https://support.withings.com/hc/en-us/articles/39295659539217-Withings-App-Manually-Logging-Data)
- [Withings viewing measurements](https://support.withings.com/hc/en-us/articles/39334195353233-Withings-App-Viewing-my-measurements)
- [Monitor Your Weight App Store listing](https://apps.apple.com/us/app/monitor-your-weight/id413313086)
- [Monitor Your Weight official site](https://monitoryourweight.com/)
- [Weight Diary Lite App Store listing](https://apps.apple.com/us/app/weight-diary-lite/id468520999)
- [Weight Diary Lite developer page](https://www.curlybrace.co.uk/weightdiaryfree)
- [Weigh In official site/screenshots](https://weighin.app/)
- [Weigh In App Store listing](https://apps.apple.com/us/app/weigh-in-weight-tracker/id1082115351)
- [Apple Health guide, non-versioned URL](https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/ios)
- [Apple accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Happy Scale support, localized URL](https://happyscale.com/support.en)
- [Withings manual logging, legacy URL](https://support.withings.com/hc/en-us/articles/205523268-Withings-App-Manually-Logging-Data)
- [Withings deleting a measurement](https://support.withings.com/hc/en-us/articles/205319258-Withings-App-iOS-Deleting-a-measurement)

### Nutrition navigation and history

- [MacroFactor Dashboard](https://help.macrofactorapp.com/en/articles/22-get-to-know-your-dashboard)
- [MacroFactor weight logging](https://help.macrofactorapp.com/en/articles/15-log-your-weight)
- [MacroFactor past days](https://help.macrofactorapp.com/en/articles/228-log-food-to-previous-days)
- [MacroFactor food actions](https://help.macrofactorapp.com/en/articles/96-delete-foods-from-your-timeline)
- [MacroFactor weight entries](https://help.macrofactorapp.com/en/articles/99-edit-or-delete-past-weight-entries)
- [Cronometer mobile diary](https://support.cronometer.com/hc/en-us/articles/360018593112-Mobile-Diary-Overview)
- [Cronometer mobile charts](https://support.cronometer.com/hc/en-us/articles/360019864311-Mobile-Charts)
- [Cronometer diary editing and bulk actions](https://support.cronometer.com/hc/en-us/articles/360019003171-Mobile-Edit-Diary-Entries)
- [Cronometer biometrics](https://support.cronometer.com/hc/en-us/articles/360020717131-Mobile-Add-a-Biometric)
- [MyFitnessPal Today](https://support.myfitnesspal.com/hc/en-us/articles/39985611667341-Your-Today-tab)
- [MyFitnessPal Progress](https://support.myfitnesspal.com/hc/en-us/articles/45246617814669-Introducing-Progress-Overview-Your-Progress-Personalized)
- [MyFitnessPal weight recording](https://support.myfitnesspal.com/hc/en-us/articles/360032624431-How-do-I-record-my-weight-and-other-measurements)
- [MyFitnessPal add food](https://support.myfitnesspal.com/hc/en-us/articles/360032274592-How-do-I-add-a-food-to-my-food-diary)
- [MyFitnessPal delete food](https://support.myfitnesspal.com/hc/en-us/articles/360032624311-How-to-delete-an-entry-from-your-food-diary)
- [MyFitnessPal weight entries](https://support.myfitnesspal.com/hc/en-us/articles/360032273492-How-do-I-change-my-starting-weight-or-edit-incorrect-weight-entries)
- [Lose It! planning/past date](https://loseit.zendesk.com/hc/en-us/articles/47273187626260-How-to-Plan-Food-in-Lose-It)
- [Lose It! past date](https://loseit.zendesk.com/hc/en-us/articles/51856407130900-How-to-Track-Fasting-for-a-Past-Day)
- [Lose It! weight tracking](https://loseit.zendesk.com/hc/en-us/articles/51996179035156-Unresponsive-Dashboard-Weight-Tracking)
- [Foodnoms food edits](https://foodnoms.com/help/edit-entries)
- [Foodnoms weight tracking](https://foodnoms.com/help/track-weight)
- [Lifesum calendar](https://help.lifesum.com/en/article/what-does-the-different-colours-in-the-calendar-represent-ios-bcpckv/)
- [Lifesum food edits](https://help.lifesum.com/en/article/edit-or-remove-items-from-your-diary-mghpcc/)
- [Lifesum past weight](https://help.lifesum.com/en/article/can-i-add-my-weight-on-a-past-date-ncm2mi/)
- [YAZIO diary delete](https://help.yazio.com/hc/en-us/articles/360002407038-How-can-I-delete-entries-in-my-Diary)
- [YAZIO diary copy](https://help.yazio.com/hc/en-us/articles/360002401437-How-do-I-copy-Diary-entries-to-another-day)
- [YAZIO weight recording](https://help.yazio.com/hc/en-us/articles/4406824736913-How-can-I-record-my-current-weight)
- [MacroFactor App Store listing](https://apps.apple.com/us/app/macrofactor-macro-tracker/id1553503471)
- [Cronometer App Store listing](https://apps.apple.com/us/app/cronometer-calorie-counter/id1145935738)
- [MyFitnessPal App Store listing](https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718)
- [Lose It! App Store listing](https://apps.apple.com/us/app/lose-it-calorie-counter/id297368629)
- [Foodnoms App Store listing](https://apps.apple.com/us/app/nutrition-tracker-foodnoms/id1479461686)
- [Lifesum App Store listing](https://apps.apple.com/us/app/lifesum-ai-calorie-counter/id286906691)
- [YAZIO App Store listing](https://apps.apple.com/us/app/ai-calorie-tracker-by-yazio/id946099227)
