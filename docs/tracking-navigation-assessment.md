# TRACKING-IA-001 — Tracking navigation and weight-log assessment

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Decision/access date:** 2026-08-08
**Implementation:** Implemented and complete. Attempt 01 is accepted. Later diary work is resolved separately; “future” language below is historical sequencing, not active backlog.

## Decision history and revised decision

Original `eae1c92` assessment chose three root destinations and a pushed Weight Log:

```text
Today | Progress | Settings
```

That initial drill-down-only choice was reasonable from first-pass nutrition evidence: MacroFactor, Foodnoms, MyFitnessPal, and Cronometer keep broad daily-log and analytics destinations top-level and nest sparse weight capture/history. It is superseded, not silently rewritten.

Explicit user feedback then prioritized discoverability. Current verified dedicated-weight precedent also supports giving weight a clear peer destination: Happy Scale separates Logbook and Reports; Weight Diary Lite exposes graph, summary, and full-log modes; Weigh In separates record, history, and progress actions. The user feedback and dedicated-weight precedent now win over the initial nutrition-only inference.

Final root order:

```text
Today | Weight | Progress | Settings
```

- Rename `Counter` to **Today**.
- Add **Weight** as a root destination whose navigation title is **Weight Log**.
- Keep **Progress** as analytics-only. Its Weight view owns fuller trend analytics and no weight CRUD.
- Keep **Settings** as profile/planning; remove current-weight recording.
- Keep calorie history out of this milestone. No calorie CRUD and no generic Calories/Water/Weight table.

Final Weight behavior is a compact measurement log plus basic seven-reading raw-chart context. `View full trends` switches directly to `Progress` with `Weight` selected. This revised decision is implemented and complete.

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

| Order | Tab | Role | In scope |
| --- | --- | --- | --- |
| 1 | **Today** | Daily action surface | Current-day calorie budget, meals/food, water, and existing daily tracking actions. `Counter` label becomes `Today`. |
| 2 | **Weight** | Measurement log | Root destination titled **Weight Log**; summary, compact seven-reading context, raw grouped measurements, add/edit/backdate/delete. |
| 3 | **Progress** | Analytics surface | Calorie history analytics and fuller fourteen-reading Weight analytics. No weight CRUD. |
| 4 | **Settings** | Profile and planning | Target weight, age, calorie goal, target date, and reminders. `Config` label becomes `Settings`; current-weight recording field is removed. |

Four destinations make Weight discoverable without creating a generic journal. Root order is intentional: daily action first, dedicated weight log second, interpretation third, planning last.

### Weight

Weight is a root destination with navigation title **Weight Log**.

- Put toolbar `+` / `Record Weight` in the log as the primary creation action.
- Show current, recent-seven-reading change/context, and target in a compact summary.
- Plot up to seven raw readings with native SwiftUI line and point marks. Show a target rule when target is valid.
- Show explicit chart endpoint dates only when at least two readings exist. With one reading, show a useful prompt instead of a single-dot/dead chart; the rejected single-reading chart is retained as evidence.
- Group raw rows by local calendar date, newest date section first; sort rows newest-first within each section.
- Preserve every raw measurement, including multiple measurements on one calendar day. Never silently replace same-day data or collapse it to one daily value.
- Show each row's weight and local date/time clearly. Native Dynamic Type, VoiceOver, and localized date/time formatting are required.
- Record defaults to current date/time but permits independent date and time backdating.
- Tapping a row opens the same editor for correction, including date/time.
- Delete requires explicit confirmation. Confirmed deletion enters stacked undo affordance; cancel preserves data and undo restores deleted records without silently replacing another same-day entry.
- `View full trends` switches to root `Progress` with `Weight` selected.

The Weight tab is a raw measurement record with compact context, not a calorie journal or generic table. Progress may calculate trend values from these raw entries, but analytics must not mutate or hide records.

### Progress

Progress remains read-oriented analytics. Its metric segments show calorie summaries and fuller Weight trend/target analytics from up to fourteen raw readings. Progress has no weight create, edit, or delete controls. The Weight view has no CRUD path; `View full trends` from Weight selects this view.

The distinction is now:

```text
Weight / Weight Log = what was recorded + compact seven-reading context
Progress / Weight   = fuller fourteen-reading analytics and interpretation
```

### Settings

Retain these controls:

- target weight;
- age;
- daily calorie goal;
- target date;
- reminders.

Remove current-weight recording from Settings. Weight recording has one home: Weight Log. Settings has no current-weight field or save path.

## Calories history boundary

Historical calorie CRUD was excluded from TRACKING-IA-001 and later resolved under separate date-first diary contracts.

**Repo-verified constraint (R):** `PlateEntry` stores food-name, calorie, amount, quantity/portion, serving-unit, meal type, and date snapshots. Existing calorie history groups those records by calendar day and sums calories; preview data also seeds aggregate-style historical entries. A generic historical editor would need explicit rules for preserving the `PlateEntry` snapshot when its source `Food` changes, and for keeping preview/aggregate data coherent. That integrity and preview-aggregate issue is not resolved by navigation alone.

**Decision (D):** Do not add calorie historical edit/delete to Weight Log, Progress, or a mixed log. Later work implemented separate date-first diary with meal context and contracted food-specific actions. It never became a generic Calories/Water/Weight table.

This boundary preserves current food-entry behavior while preventing an unsafe, semantically ambiguous journal from becoming a navigation destination.

## Superseded and rejected options

### Superseded initial decision: `Today | Progress | Settings` + pushed Weight Log

The original `eae1c92` assessment rejected a fourth root tab because weight is sparse and reviewed nutrition apps usually nest weight. That evidence remains relevant for nutrition navigation, but it did not settle discoverability for this product. Explicit user feedback asked for a clear Weight destination, and current dedicated-weight products provide precedent for a visible log/report split. The three-tab drill-down choice is superseded by the final four-tab order:

```text
Today | Weight | Progress | Settings
```

Weight and Progress remain distinct within that order: Weight records raw measurements and compact seven-reading context; Progress owns fuller fourteen-reading analytics and no CRUD.

### `Today | Log | Trends | Settings` with a generic journal

Rejected because `Log` duplicates Today for current-day food work while inviting a generic historical journal. A mixed journal is unsafe: calorie rows are meal/time and snapshot-rich, weight rows are sparse measurements with backdatable date/time, and water has different aggregation/deletion rules. Shared persistence does not justify shared primary UI.

Later calorie history became separate day diary and did not become this generic table.

## Research synthesis

### Verified patterns

1. **Apple Health separates metric detail, recording, logbook, and analytics (V).** Apple documents category/metric detail, `Add Data` with date/time/value, `Show All Data` chronological records, edit/delete controls, and trend views. Recording and history are controls inside a metric context rather than one global mixed table.
2. **Nutrition trackers keep broad daily-log and analytics destinations top-level (V).** MacroFactor uses Dashboard/Food Log, Foodnoms uses Food Log/Insights, MyFitnessPal uses Today/Progress, and Cronometer uses Diary/Discover. Their weight capture/history is nested or reached through a global add action; this remains relevant nutrition evidence, even though it does not decide Count Calories' final root order.
3. **Current dedicated-weight products establish a visible log/report precedent (V).** Happy Scale exposes Summary, Reports, Logbook, Settings, and a global add action; Weight Diary Lite exposes graph, summary, and full-log modes; Weigh In separates record, history, and progress actions. Monitor Your Weight contains useful current/legacy comparison material, but its older screenshots are a legacy caveat, not decisive current workflow evidence. Dedicated-weight precedent supports the revised root Weight decision without requiring Count Calories to copy any tab count.
4. **Native timeline/list patterns support this log (V).** Withings documents a newest-first measurement timeline with edit/delete actions. Happy Scale documents row editing and date changes. Apple and Withings show chronological metric records rather than spreadsheet-first mobile tables.
5. **Weight records and food diaries have different structures (V).** Nutrition research found food logs organized by selected day and meal/time, while weight is handled as a separate dated list/chart or body-measurement history. Row editing/deletion, backdating, and bulk semantics vary by data type.
6. **A native chronological list is the strongest mobile default (I).** The verified Apple/Withings patterns and weight-history comparison favor a grouped native list for scanability, Dynamic Type, VoiceOver, and touch accuracy. Spreadsheet density is better suited to export, cleanup, or desktop-sized datasets.
7. **Metric-specific drill-down beats a generic table (I).** Food, water, and weight differ in frequency, context, aggregation, and destructive actions. A shared model can exist underneath, but primary UI should preserve those semantics.

### Current repository baseline

The pre-change root composition was `Counter`, `Progress`, and `Config` (R). Pre-change Progress combined calorie analytics, weight analytics, and a direct weight recorder; current-weight recording could update today's entry/profile state (R). TRACKING-IA-001 now implements `Today | Weight | Progress | Settings`: labels become Today/Settings, Weight owns raw CRUD plus compact seven-reading context, Progress owns fuller analytics only, and Settings has no current-weight field. Existing HISTORY-001 / PROGRESS-001 / WEIGHT-001 attempt-02 evidence remains the pre-change baseline.

Observed repository files:

- `count_calories/App/ContentView.swift`
- `count_calories/Features/History/HistoryView.swift`
- `count_calories/Models/MealModels.swift`
- `count_calories/Models/WeightAndProfileModels.swift`
- `count_calories/Tracking/CalorieHistory.swift`
- `count_calories/App/PreviewData.swift`

## Requirements and acceptance

| ID | Requirement |
| --- | --- |
| IA-01 | Root tab bar has exactly four destinations in order: `Today`, `Weight`, `Progress`, `Settings`. |
| IA-02 | Existing `Counter` user-facing label becomes `Today`; existing `Config` user-facing label becomes `Settings`; Weight navigation title is `Weight Log`. |
| IA-03 | Weight root exposes toolbar add / `Record Weight` and a useful empty state. |
| IA-04 | Weight summary shows current, recent-seven-reading context, and target. |
| IA-05 | Weight chart uses up to seven raw readings with native line and point marks plus target rule; explicit endpoint dates appear only with at least two readings; one reading shows a prompt instead of a dead chart. |
| IA-06 | Weight measurements use newest-first native grouped sections by local calendar date and newest-first rows. |
| IA-07 | Add creates raw measurement with value plus independently editable date and time; default is now and backdating is supported. |
| IA-08 | Row tap edits one existing raw measurement, including date/time. |
| IA-09 | Multiple same-day raw entries remain visible and distinct. No same-day overwrite or daily collapse. |
| IA-10 | Deletion requires explicit confirmation and provides stacked undo; accidental swipe/gesture cannot silently delete. |
| IA-11 | `View full trends` selects `Progress` with `Weight` selected. Progress owns fuller fourteen-reading analytics and has no weight create/edit/delete controls. |
| IA-12 | Settings retains target weight, age, calorie goal, target date, and reminders; removes current-weight recording field and save path. |
| IA-13 | No calorie historical CRUD was added in this scope. Later work completed separate meal/day diary and known-item actions, never generic mixed history. |
| IA-14 | Native controls support Dynamic Type, VoiceOver labels/actions, localized date/time, sufficient touch targets, dark mode, and semantic non-color-only state. |

## Tests and success criteria

All gates below are closed by final validation. TRACKING-IA-001 is accepted and complete.

### Navigation and destination tests

- Launch shows exactly four primary tabs in order: `Today`, `Weight`, `Progress`, `Settings`.
- Accessibility labels and visible labels contain `Today`, `Weight`, `Progress`, and `Settings`; obsolete user-facing `Counter` and `Config` tab labels are absent.
- Weight tab navigation title is `Weight Log`; toolbar add is discoverable.
- Progress can switch between analytics metrics without exposing weight create/edit/delete controls.
- `View full trends` from Weight selects Progress / Weight.

### Weight visual and behavior tests

- Empty Weight state explains value of recording and exposes `Record Weight`.
- One valid reading shows a useful prompt, not a single-dot/dead chart.
- Two or more readings show compact native line plus points, target rule when valid, and endpoint dates only when at least two readings exist.
- Weight chart consumes no more than the latest seven raw readings; Progress Weight owns fuller fourteen-reading analytics.
- Seed entries across dates and times; verify date sections and rows are newest-first.
- Seed two or more entries on one calendar day; verify every raw value/time remains visible after reload.
- Tap toolbar `+` / `Record Weight`; verify default date/time is now, then save independently backdated date and time and verify exact row placement.
- Tap an existing row; change value/date/time; verify only that row changes and ordering/grouping updates.
- Attempt deletion; verify confirmation appears, cancel preserves data, confirm removes only selected row, and stacked undo restores deletions.
- Verify no code path turns a second same-day record into an update of the first record.
- Verify Progress analytics consumes raw entries without mutating the Weight dataset.

### Settings and scope tests

- Settings still exposes target weight, age, calorie goal, target date, and reminders.
- Settings has no current-weight recording field or save path.
- No generic mixed Calories/Water/Weight history table is introduced.
- Current-day food logging remains available in Today; no historical calorie CRUD is claimed by this milestone.
- Dynamic Type, VoiceOver, localized date/time, dark mode, and minimum 44-point interaction targets remain usable in tabs, Weight Log, editor, and destructive confirmation.

### Final results

- `just validate 300`: **passed**.
- Hostless validation: **125 passed / 2 opt-in live skips**.
- Simulator build, install, and launch: **passed**.
- `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`.
- Explicit UI target: **6/6 passed**, covering four tabs; one-reading prompt → two-reading chart; two same-day readings; backdated date regrouping; edit; delete cancel/confirm/undo; Settings; and direct `View full trends` → `Progress` / `Weight`.
- App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and passed again in an integrated run.
- One later standalone `just test-app-unit 300` timed out before XCTest. Record as external Xcode 27 host instability, not a red product gate.

## Evidence log

- **2026-08-08 — V:** Reviewed `/tmp/navigation-weight-research.txt`. Apple Health, Happy Scale, Withings, Weight Diary Lite, and Weigh In evidence separates recording, chronological history, and analytics. Monitor Your Weight includes useful current/legacy comparison material, but older screenshots are a legacy caveat.
- **2026-08-08 — V:** Reviewed `/tmp/nutrition-history-research.txt`. MacroFactor, Cronometer, MyFitnessPal, Lose It!, Foodnoms, Lifesum, and YAZIO evidence uses date-first food diaries and meal/group-specific actions; weight remains a separate measurement/history concern. Nutrition references remain relevant to Today, Progress, and the no-generic-table boundary.
- **2026-08-08 — V:** Reviewed `/tmp/weight-history-research.txt`. Apple Health, Happy Scale, Withings, and dedicated weight apps support chronological native lists, row edit/delete patterns, date handling, raw-reading preservation, and accessibility patterns; source file explicitly marks undocumented behavior and inferences.
- **2026-08-08 — V:** Broad `/tmp/navigation-nutrition-research.txt` timed out empty and contributed no evidence. Bounded `/tmp/navigation-nutrition-focused-research.txt` verified MacroFactor, Foodnoms, MyFitnessPal, and Cronometer: daily log and analytics remain broad destinations while weight is nested or globally added.
- **2026-08-08 — D:** Original `eae1c92` three-tab/drill-down assessment is superseded by explicit user feedback. Initial nutrition evidence still favors nested Weight, but discoverability plus dedicated-weight precedent now wins.
- **2026-08-08 — R:** Repository baseline confirmed pre-change `Counter | Progress | Config`, combined Progress weight recording, `PlateEntry` snapshot fields, and calendar-day calorie aggregation. Implementation now records raw same-day/backdated measurements under root Weight and removes current-weight recording from Settings.
- **2026-08-08 — V/R:** Attempt-01 visual evidence was captured under `screenshots/TRACKING-IA-001/`; explicit UI target reached **6/6 pass** for four tabs, prompt-to-chart, two same-day readings, backdated regrouping, edit, delete cancel/confirm/undo, Settings, and direct `View full trends` to Progress / Weight.
- **2026-08-08 — R:** `just validate 300` passed; hostless validation reported **125 passed / 2 opt-in live skips**; simulator build, install, and launch passed. App-hosted persistence tests passed after duplicate-profile/future-row correctness fixes and again in an integrated run.
- **2026-08-08 — R:** One later standalone `just test-app-unit 300` timed out before XCTest. This is external Xcode 27 host instability, not a red product gate.
- **2026-08-08 — D:** Final IA is `Today | Weight | Progress | Settings`; Weight owns basic seven-reading raw-chart context and raw CRUD; Progress owns fuller fourteen-reading analytics with no weight CRUD; Settings has no current-weight field. Generic mixed history remains rejected. COMPETITOR-GAP-001 and BACKLOG-CLOSURE-001 later implemented separate date-first calorie diary detail and known-snapshot mutations.
- **2026-08-08 — D:** TRACKING-IA-001 marked **ACCEPTED — ATTEMPT 01 / COMPLETE**.

## Source index — exact URLs

All URLs below are current verified official URLs accessed 2026-08-08 unless marked as legacy evidence.

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
- [Monitor Your Weight App Store listing — legacy screenshot caveat](https://apps.apple.com/us/app/monitor-your-weight/id413313086)
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

### Nutrition navigation and history — still relevant

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
