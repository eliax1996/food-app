<!--
LLM authoring rule: Render screenshot references with Markdown image syntax:
`![descriptive alt text](relative/path/to/screenshot.png)`.
Do not use inline-code or plain-text screenshot paths when visual preview is intended.
Keep paths relative to this file.
-->
# Visual evidence index

Device unless noted: iPhone 17 Pro, iOS 27.0, portrait, light appearance.

## NAV-001 / TRACKING-IA-001

Baseline: all files under `screenshots/baseline/`

Final root order:

![Final four-tab order](screenshots/TRACKING-IA-001/attempt-01-four-tabs.png)

```text
Today | Weight | Progress | Settings
```

Status: **ACCEPTED — ATTEMPT 01 / COMPLETE**.

Accepted TRACKING-IA-001 visual files are only these attempt-01 files under `screenshots/TRACKING-IA-001/`:

- ![Four root tabs](screenshots/TRACKING-IA-001/attempt-01-four-tabs.png) — four root tabs in final order.
- ![Populated Weight Log](screenshots/TRACKING-IA-001/attempt-01-weight-populated.png) — Weight Log title, current/recent-seven/target summary, compact raw-seven-reading line + points, target rule, endpoint dates, and grouped newest-first measurements.
- ![Empty Weight Log](screenshots/TRACKING-IA-001/attempt-01-weight-empty.png) — useful empty Weight Log state with Record Weight action.
- ![Large-text Weight Log](screenshots/TRACKING-IA-001/attempt-01-weight-accessibility3.png) — large-text Weight Log stress capture.
- ![Dark Weight Log](screenshots/TRACKING-IA-001/attempt-01-weight-dark.png) — dark appearance Weight Log capture.

Superseded three-tab captures retained as historical implementation evidence only:

- ![Superseded same-day capture](screenshots/TRACKING-IA-001/superseded-three-tab-two-same-day.png)
- ![Superseded backdated capture](screenshots/TRACKING-IA-001/superseded-three-tab-backdated.png)
- ![Superseded editor capture](screenshots/TRACKING-IA-001/superseded-three-tab-editor.png)
- ![Superseded delete confirmation](screenshots/TRACKING-IA-001/superseded-three-tab-delete-confirmation.png)

Rejected evidence retained:

- ![Rejected one-reading chart](screenshots/TRACKING-IA-001/rejected-one-reading-chart.png) — rejected because single point makes dead chart with no useful trend. Final behavior replaces it with a useful prompt until at least two readings.

Explicit UI target: **6/6 passed**, covering four tabs; one-reading prompt → two-reading chart; two same-day readings; backdated date regrouping; edit; delete cancel/confirm/undo; Settings; and direct `View full trends` → `Progress` / `Weight`.

Validation: `just validate 300` **passed**; hostless **125 passed / 2 opt-in live skips**; simulator build/install/launch **passed**. `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`. App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and again in an integrated run. One later standalone `just test-app-unit 300` timed out before XCTest due to external Xcode 27 host instability; not a red product gate.

## HOME-001

Baseline:

- ![Counter empty](screenshots/baseline/counter-empty.png) — empty day
- ![Counter normal](screenshots/baseline/counter-normal.png) — one Snack entry, 15 kcal
- ![Counter entry tools](screenshots/baseline/counter-entry-tools.png) — lower custom-food/barcode content

Attempts:

- ![HOME attempt 01](screenshots/HOME-001/attempt-01.png)
- ![HOME attempt 02](screenshots/HOME-001/attempt-02.png)
- ![HOME attempt 03](screenshots/HOME-001/attempt-03.png)
- ![HOME attempt 04](screenshots/HOME-001/attempt-04.png)
- ![HOME attempt 05](screenshots/HOME-001/attempt-05.png)
- ![HOME attempt 06](screenshots/HOME-001/attempt-06.png)
- ![HOME attempt 07](screenshots/HOME-001/attempt-07.png)
- ![HOME attempt 08](screenshots/HOME-001/attempt-08.png)
- ![HOME attempt 09](screenshots/HOME-001/attempt-09.png)
- ![HOME attempt 10](screenshots/HOME-001/attempt-10.png)
- ![HOME attempt 11](screenshots/HOME-001/attempt-11.png)
- supporting meal/lower/detail captures use filename suffixes

Accepted: attempt 11 (shown above).
Reason: best hierarchy, all four meal summaries clear, 44pt water actions, no tab collision.

## CALORIES-001 / WATER-001 / MEALS-001

Baseline: ![Counter normal](screenshots/baseline/counter-normal.png)
Attempts: tracked with HOME-001
Accepted: HOME attempt 11 (shown above).

## MEAL-001

Baseline:

- ![Add meal baseline](screenshots/baseline/add-meal.png)
- ![Current meal baseline](screenshots/MEAL-001/baseline-current.png)

Attempts:

- ![Meal attempt 01](screenshots/MEAL-001/attempt-01.png)
- ![Meal attempt 02 selected](screenshots/MEAL-001/attempt-02-selected.png)
- ![Meal attempt 03](screenshots/MEAL-001/attempt-03.png)

Accepted: attempt 03 (shown above).
Accessibility evidence:

- ![Meal accessibility top](screenshots/MEAL-001/accessibility3-top.png)
- ![Meal accessibility lower](screenshots/MEAL-001/accessibility3-lower.png)

Reason: explicit inputs/actions, live total, reliable search/scanner entry, adaptive large-text menus.

## FOOD-SEARCH-001

Baseline: ![Food selector baseline](screenshots/baseline/food-selector.png)

Attempts:

- ![Food search attempt 01](screenshots/FOOD-SEARCH-001/attempt-01.png)
- ![Food search attempt 01 results](screenshots/FOOD-SEARCH-001/attempt-01-results.png)
- ![Food search attempt 02](screenshots/FOOD-SEARCH-001/attempt-02.png)
- ![Food search attempt 02 results](screenshots/FOOD-SEARCH-001/attempt-02-results.png)

Accepted: attempt 02 (shown above).
Reason: recents, immediate top search, full browse, and reliable full-row selection.

## FOOD-CREATE-001 / BARCODE-001

Baseline: ![Counter entry tools](screenshots/baseline/counter-entry-tools.png)

Attempts:

- ![Food tools attempt 01](screenshots/FOOD-TOOLS-001/attempt-01.png)
- ![Food tools attempt 02](screenshots/FOOD-TOOLS-001/attempt-02.png)
- ![Food tools attempt 03 functional](screenshots/FOOD-TOOLS-001/attempt-03-functional.png)
- ![Food tools attempt 04](screenshots/FOOD-TOOLS-001/attempt-04.png)

Accepted: attempt 04 (shown above).
Reason: secondary native sheet, keyboard-safe layout, visible disabled lookup, verified custom-food round trip.

## FOOD-REMOTE-SEARCH-001

Baseline: local/saved-food selector with no remote discovery evidence.

Attempts:

- ![Remote search rejected results](screenshots/FOOD-REMOTE-SEARCH-001/attempt-01-results.png) — retained rejected attempt. Full `ContentUnavailableView` consumed 234 pt and pushed remote controls beneath keyboard.
- ![Remote search results](screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-results.png)
- ![Remote search selected](screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-selected.png)
- ![Remote search persisted](screenshots/FOOD-REMOTE-SEARCH-001/attempt-02-persisted.png)

Accepted: attempt 02 evidence above.
Reason: compact `Saved foods` empty row preserves local context and keeps remote results/controls keyboard-safe. Manual flow selected Remote Oat Drink at 250 ml / 100 kcal, increased daily total by exactly 100 kcal after save, and confirmed persisted local row.

## AMOUNT-EDITOR-001

Attempts:

- ![Amount editor normal](screenshots/AMOUNT-EDITOR-001/attempt-01-normal.png) — Almond Milk normal layout, 100 g / 15 kcal.
- ![Amount editor adjusted](screenshots/AMOUNT-EDITOR-001/attempt-01-adjusted.png) — Almond Milk after −10, 90 g / 14 kcal.
- ![Amount editor milliliters](screenshots/AMOUNT-EDITOR-001/attempt-01-milliliters.png) — Remote Oat Drink volume layout, 250 ml / 100 kcal.
- ![Amount editor accessibility](screenshots/AMOUNT-EDITOR-001/attempt-01-accessibility3.png) — Accessibility3 adjusted state, 90 g / 14 kcal.

Accepted: attempt 01 (shown above).
Reason: Prototype A keeps common corrections keyboard-free, preserves serving separation, exposes g/ml semantics, and adapts controls to measured normal and Accessibility3 targets without clipping.

## HISTORY-001 / PROGRESS-001 / WEIGHT-001 analytics milestone

Device evidence: deterministic iPhone 17 Pro preview, portrait, light appearance.

### HISTORY-001 / PROGRESS-001

Baseline: ![History calories baseline](screenshots/baseline/history-calories.png)

Attempts:

- ![History calories rejected attempt](screenshots/HISTORY-001/attempt-01-calories.png) — retained rejected attempt. Weak one-line gray summary and full month-day labels overlapped.
- ![History calories accepted attempt](screenshots/HISTORY-001/attempt-02-calories.png) — accepted calorie Progress preview: recorded-day average, profile-goal relation, orange seven-day bars, goal rule, and compact actual day labels without bar annotations.

Accepted: attempt 02 (shown above).

Status: **ACCEPTED — attempt 02** for `HISTORY-001` and `PROGRESS-001`.

### WEIGHT-001

Baseline: ![Weight empty baseline](screenshots/baseline/history-weight-empty.png)

Attempts:

- ![Weight populated](screenshots/WEIGHT-001/attempt-02-populated.png) — current/change/target summary and fourteen-reading line/point trend with target rule.
- ![Weight empty](screenshots/WEIGHT-001/attempt-02-empty.png) — useful empty copy with direct Record Weight action.
- ![Weight editor](screenshots/WEIGHT-001/attempt-02-editor.png) — locale-consistent wheel/header record/update sheet with Cancel and Save.

Accepted: attempts shown above.

Status: **ACCEPTED — attempt 02** for `WEIGHT-001`. This is pre-TRACKING baseline; final Weight root evidence is indexed above.

## STATES-001

Attempts and accepted evidence:

- ![Remote loading](screenshots/STATES-001/attempt-01-remote-loading.png) — truthful loading during cache, debounce, and network work.
- ![Remote no matches](screenshots/STATES-001/attempt-01-remote-no-matches.png) — terminal empty response distinct from initial state.
- ![Rejected remote offline Retry target](screenshots/STATES-001/attempt-01-remote-offline-small-retry.png) — retained rejected evidence; Retry measured about 20 points high.
- ![Scanner permission recovery](screenshots/STATES-001/attempt-02-scanner-permission.png) — permission-specific Open Settings and manual-entry recovery.
- ![Scanner permission recovery at Accessibility 3 in dark appearance](screenshots/STATES-001/attempt-02-scanner-permission-ax3-dark.png) — large-text and dark stress evidence.
- ![Barcode lookup loading](screenshots/STATES-001/attempt-03-barcode-loading.png) — stable inline loading with custom-food work retained.
- ![Barcode lookup offline](screenshots/STATES-001/attempt-03-barcode-offline.png) — one retry plus available custom-food recovery.
- ![Accepted remote offline recovery](screenshots/STATES-001/attempt-04-remote-offline.png) — post-fix live iPhone 17 Pro capture; Retry hierarchy measures `69.7 × 44.0` points.

Status: **ACCEPTED — ATTEMPT 04 / COMPLETE**.

Reason: typed loading, terminal empty, offline, unavailable, scanner permission, scanner availability, and barcode failure states preserve unaffected local work and provide one calm recovery path. Final screenshot reviews returned 2/3 approval for both remote and barcode offline evidence; residual objections concerned a measured 44-point Retry target and the native iOS 27 Done control, so no counter-native replacement was made. Full functional UI target passed 11/11.

## NUTRIENTS-001

Accepted attempt 01 evidence:

- ![Today nutrition balance](screenshots/NUTRIENTS-001/attempt-01-today.png) — calories remain primary; separated macro-energy split, Fiber, complete coverage, and neutral general-adult comparison appear before Meals.
- ![Complete daily nutrition](screenshots/NUTRIENTS-001/attempt-01-complete.png) — measured grams, adult macro ranges, labeled Fiber reference, and non-personal guidance.
- ![Measured gap guidance](screenshots/NUTRIENTS-001/attempt-01-guidance.png) — at most two measured, range-citing, non-shaming suggestions.
- ![Partial nutrient coverage](screenshots/NUTRIENTS-001/attempt-01-partial.png) — known grams remain visible while split, Fiber comparison, and guidance pause without estimates.
- ![Accessibility 3 dark nutrition detail](screenshots/NUTRIENTS-001/attempt-01-guidance-ax3-dark.png) — adaptive text-first macro rows, visible card boundary, dark appearance, and scroll continuation.
- ![Custom food nutrient entry point](screenshots/NUTRIENTS-001/attempt-01-custom-food.png) — optional focused nutrient editor remains secondary to core custom-food fields.
- ![Custom nutrient editor](screenshots/NUTRIENTS-001/attempt-01-custom-nutrients.png) — visibly editable fields, explicit Done, and clear draft/save copy.
- ![Accessibility 3 dark custom nutrient editor](screenshots/NUTRIENTS-001/attempt-01-custom-nutrients-ax3-dark.png) — large text, dark appearance, editable fields, and reachable native completion.

Status: **ACCEPTED — ATTEMPT 01 / COMPLETE**.

Reason: optional facts remain unknown through API/cache/persistence when missing; logged entries keep immutable consumed snapshots; complete and partial states are explicit; actual macro/fiber values compare only with transparent general adult references; no opaque score or medical claim appears. Final critical/high visual review reached **3/3 APPROVE**. Validation: `just validate 300` passed with **140 hostless pass / 2 live skips**; app-hosted tests passed **167 / 2 skips**; functional UI passed **12/12**.

## REFINE-001 — Settings, Plan references, and reminders

Baselines:

- ![Settings baseline](screenshots/baseline/config-top.png)
- ![Reminders baseline](screenshots/baseline/config-reminders.png)

Accepted attempt 01 evidence:

- ![Hierarchical Settings](screenshots/REFINE-001/attempt-01-settings.png) — Plan, Profile, Reminders, and privacy grouped with useful summaries.
- ![Manual Plan and adult references](screenshots/REFINE-001/attempt-01-plan.png) — manual source, target context, calorie-goal-derived percent/gram ranges, and unverified-date language.
- ![Partial Plan comparison](screenshots/REFINE-001/attempt-01-plan-partial.png) — known values remain visible while incomplete comparison pauses.
- ![Explicit Plan editor](screenshots/REFINE-001/attempt-01-plan-editor.png) — Save/Cancel draft, visible target field, and live reference preview.
- ![Reminder summary](screenshots/REFINE-001/attempt-01-reminders.png) — exact meal times, weekly weight semantics, water interval, authorization, and next selected reminder.
- ![Reminder editor](screenshots/REFINE-001/attempt-01-reminder-editor.png) — independent exact meal times, weight cadence/time, water, Save/Cancel.
- ![Denied notification recovery](screenshots/REFINE-001/attempt-01-reminders-denied.png) — saved choices remain distinct from delivery and direct iOS Settings recovery is visible.
- ![Reminder editor AX3 dark](screenshots/REFINE-001/attempt-01-reminder-editor-ax3-dark.png) — adaptive large text and dark appearance.
- ![Reminder editor small layout](screenshots/REFINE-001/attempt-01-reminder-editor-small.png) — fixed 375 × 667 stress evidence with intact toolbar/actions.
- ![Populated Today clearance](screenshots/REFINE-001/attempt-01-today.png) — macro-only bar plus grams remain secondary; all four meal rows clear floating tab bar.
- ![Corrected nutrition denominator](screenshots/REFINE-001/attempt-01-nutrition-detail.png) — macro-only split is labeled separately from logged-energy adult-range shares.

Accepted attempt 02 evidence:

- ![Optional setup welcome](screenshots/REFINE-001/attempt-02-setup-welcome.png) — explicit supported scope, no early mutation, clear Continue/Keep Manual choices.
- ![Required body details](screenshots/REFINE-001/attempt-02-setup-body.png) — rationale before sensitive inputs, units, visible current/target values, and numeric entry.
- ![Infeasible-date recovery](screenshots/REFINE-001/attempt-02-setup-infeasible-date.png) — no extreme result; exact later-date recovery and disabled Continue.
- ![Transparent calculated review](screenshots/REFINE-001/attempt-02-setup-review.png) — recommendation plus equation, accepted values, routine, maintenance, pace, and limitations.
- ![Calculated review AX3 dark](screenshots/REFINE-001/attempt-02-setup-review-ax3-dark.png) — readable large text, reachable actions, dark appearance, and scroll continuation.
- ![Manual Plan setup entry](screenshots/REFINE-001/attempt-02-plan-manual-entry.png) — truthful Manual source and visible Calculate a starting goal action.
- ![Calculated Plan basis](screenshots/REFINE-001/attempt-02-plan-calculated.png) — Calculated source, target/forecast, accepted inputs, and exact breakdown.

Accepted attempt 03 evidence:

- ![Today food log in progress](screenshots/REFINE-001/attempt-03-today-food-log-in-progress.png) — explicit status and 44-point Mark Complete action.
- ![Genuine zero-intake confirmation](screenshots/REFINE-001/attempt-03-today-empty-confirmation.png) — blank log cannot become evidence without explicit zero-intake confirmation.
- ![Today food log complete](screenshots/REFINE-001/attempt-03-today-food-log-complete.png) — complete status has no redundant action.
- ![Today food log needs review](screenshots/REFINE-001/attempt-03-today-food-log-needs-review.png) — later food mutation reopens evidence and exposes Reconfirm.
- ![Needs-review meal context](screenshots/REFINE-001/attempt-03-today-food-log-needs-review-meal.png) — Almond Milk adds exactly 15 kcal and remains visible while log needs review.
- ![Adaptive collecting](screenshots/REFINE-001/attempt-03-adaptive-collecting.png) — exact window, earliest possible date, counts, and missing-date disclosure.
- ![Adaptive collecting bottom](screenshots/REFINE-001/attempt-03-adaptive-collecting-bottom.png) — reachable disable/method controls with focused tab bar hidden.
- ![Adaptive proposal](screenshots/REFINE-001/attempt-03-adaptive-proposal.png) — current goal/source, full candidate, difference, bounded step, and evidence counts.
- ![Adaptive proposal evidence](screenshots/REFINE-001/attempt-03-adaptive-proposal-evidence.png) — 28/35/42 observed estimates, trends, dates, expiry, and retained pace.
- ![Adaptive proposal actions](screenshots/REFINE-001/attempt-03-adaptive-proposal-actions.png) — Use, Decline, and Close outcomes are distinguished.
- ![Applied adaptive goal](screenshots/REFINE-001/attempt-03-adaptive-applied.png) — Adapted source, exact current goal, cadence, and exact revert.
- ![Applied adaptive goal AX3 dark](screenshots/REFINE-001/attempt-03-adaptive-applied-ax3-dark.png) — large-text dark layout.
- ![Applied cadence AX3 dark](screenshots/REFINE-001/attempt-03-adaptive-applied-ax3-dark-status.png) — readable Revert and weekly fresh-evidence status.
- ![Disable confirmation AX3 dark](screenshots/REFINE-001/attempt-03-adaptive-disable-confirmation-ax3-dark.png) — explicit destructive and safe-cancel actions plus evidence-reset consequence.

Status: **ATTEMPTS 01–03 ACCEPTED — REFINE SLICES A–D COMPLETE**. Final architecture/safety/native-UI/history judgments approved; final critical/high visual consensus **3/3 APPROVE**. Validation: 195 hostless pass / 2 skips, 250 app-hosted pass / 2 skips, functional UI 31/31, and exact-tree `just validate 300` passed.

## SETTINGS-DIRECT-EDIT-001

Accepted attempt 01 evidence:

- ![Actionable reminder summaries](screenshots/SETTINGS-DIRECT-EDIT-001/attempt-01-reminder-summaries.png) — every meal time/Off, Weight, and Water row has native full-row affordance and chevron; top Edit remains.
- ![Actionable reminder summaries AX3 dark](screenshots/SETTINGS-DIRECT-EDIT-001/attempt-01-reminder-summaries-ax3-dark.png) — title/value stack cleanly without compressed wrapping.

Status: **ACCEPTED — ATTEMPT 01 / COMPLETE**. Focused UI proves Meal, Weight, and Water taps open editor and Cancel preserves `Off`; Plan setup opens, advances, closes, and resumes from Settings. Final suite passed 22/22.

## BULK-AI-FOOD-001

Accepted attempt 01 evidence:

- ![Today bulk entry](screenshots/BULK-AI-FOOD-001/attempt-01-today-entry.png) — direct Log food remains primary beside Describe meal.
- ![Typed meal description](screenshots/BULK-AI-FOOD-001/attempt-01-describe.png) — editable typed input, meal destination, explicit Find Foods, and local/query privacy disclosure.
- ![Editable review top](screenshots/BULK-AI-FOOD-001/attempt-01-review-top.png) — source disclosure, exact progress, query/amount provenance, and selected nutrition record.
- ![Editable review lower](screenshots/BULK-AI-FOOD-001/attempt-01-review-lower.png) — serving basis, full-width removal, Add Food, and explicit atomic total.
- ![Review dark](screenshots/BULK-AI-FOOD-001/attempt-01-review-dark.png) and ![Review dark lower](screenshots/BULK-AI-FOOD-001/attempt-01-review-dark-lower.png) — dark appearance retains hierarchy and contrast.
- ![Describe AX3 dark](screenshots/BULK-AI-FOOD-001/attempt-01-describe-ax3-dark.png), ![Review AX3 dark](screenshots/BULK-AI-FOOD-001/attempt-01-review-ax3-dark.png), ![Review AX3 middle](screenshots/BULK-AI-FOOD-001/attempt-01-review-ax3-dark-middle.png), and ![Review AX3 lower](screenshots/BULK-AI-FOOD-001/attempt-01-review-ax3-dark-lower.png) — accessibility text keeps every edit/recovery/confirmation control reachable.

Status: **ACCEPTED — ATTEMPT 01 / COMPLETE**. Device walkthrough logged default Almond Milk from 15 to 30 kcal, exact +15. Final critical/high source review consensus **3/3 APPROVE**. Hostless 219 pass / 2 live skips; app-hosted 297 pass / 2 skips; final focused bulk/reminder/recovery tests and `just validate 300` passed.

Reminder customization follow-up was device-verified: passive meal rows expose saved times plus Enabled/Disabled; **Customize Meal Reminders** offers separate enablement and timing editors without unrelated Weight/Water controls. Verification captures remain in Xcode action artifacts; refreshed final capture belongs to ROBUSTNESS/FINAL evidence.

## AUXILIARY-001

Accepted attempt 01 evidence:

- ![Medium widget light](screenshots/AUXILIARY-001/attempt-01-widget-medium-light.png) — remaining calories lead; eaten/goal, water progress, Log food, and bounded water actions remain glanceable.
- ![Medium widget AX3 dark](screenshots/AUXILIARY-001/attempt-01-widget-medium-ax3-dark.png) — supported family stays readable at accessibility text size.
- ![Over-goal widget](screenshots/AUXILIARY-001/attempt-01-widget-over-goal.png) — red icon and explicit `kcal over` wording avoid color-only meaning.
- ![Live Activity Lock Screen](screenshots/AUXILIARY-001/attempt-01-live-lock-screen.png) and ![AX3 dark](screenshots/AUXILIARY-001/attempt-01-live-lock-screen-ax3-dark.png) — goal-aware status and one truthful Log food handoff.
- ![Dynamic Island compact](screenshots/AUXILIARY-001/attempt-01-live-compact.png) and ![expanded](screenshots/AUXILIARY-001/attempt-01-live-expanded.png) — compact calorie/water answers and expanded labels preserve system hierarchy.

Status: **ACCEPTED — ATTEMPT 01 / COMPLETE**. Live Activity lifecycle is explicit; cross-process widget water uses locked revision handoff into SwiftData; final critical/high source review consensus **3/3 APPROVE**. App-hosted 300 pass / 2 live skips; hostless 219 / 2 live skips; 45 broad UI tests passed with one unrelated timeout that passed focused rerun.

## ROBUSTNESS-001

Accepted attempt 01 stress evidence:

- ![Today normal](screenshots/ROBUSTNESS-001/today-normal-light.png), ![small](screenshots/ROBUSTNESS-001/today-small-light.png), and ![empty small](screenshots/ROBUSTNESS-001/today-empty-small.png) — standard hierarchy survives normal and compact layouts without fixture contamination.
- ![Over goal large](screenshots/ROBUSTNESS-001/today-over-goal-large.png) and ![dense large](screenshots/ROBUSTNESS-001/today-dense-large.png) — explicit extreme status and all meal summaries remain visible.
- ![Today AX3 dark](screenshots/ROBUSTNESS-001/today-ax3-dark.png), ![small AX3 dark](screenshots/ROBUSTNESS-001/today-small-ax3-dark.png), and ![dense AX3 dark](screenshots/ROBUSTNESS-001/today-dense-ax3-dark.png) — status/action and water controls adapt vertically; scroll proof covers lower actions.
- ![Weight AX3 dark](screenshots/ROBUSTNESS-001/weight-ax3-dark.png), ![Settings AX3 dark](screenshots/ROBUSTNESS-001/settings-ax3-dark.png), ![Meal editor AX3 dark](screenshots/ROBUSTNESS-001/meal-editor-ax3-dark.png), and ![Nutrition AX3 dark](screenshots/ROBUSTNESS-001/nutrition-ax3-dark.png) — domain screens retain readable values and navigation.
- ![Reminder editor small](screenshots/ROBUSTNESS-001/reminder-editor-small.png) — fixed 375×667 editor preserves Save/Cancel and all meal switches.

Status: **ACCEPTED — ATTEMPT 01 / COMPLETE**. Focused AX3 reachability test passed; final critical/high robustness review consensus **3/3 APPROVE**.

## WEIGHT-ENTRY-001

Accepted attempt 01 evidence:

- ![Low-friction Weight editor](screenshots/WEIGHT-ENTRY-001/attempt-01-editor.png) — latest reading default, visible exact field, direct coarse/fine controls, date/time, and explicit Save/Cancel.
- ![Weight editor AX3 dark](screenshots/WEIGHT-ENTRY-001/attempt-01-editor-ax3-dark.png) — 2 × 2 controls, readable field/unit, and intact date/time under large text.

Status: **ACCEPTED — ATTEMPT 01 / COMPLETE**. Focused weight, meal-keyboard, and Plan-keyboard UI proofs passed; final suite passed 14/14.
