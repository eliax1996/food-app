# TRACKING-IA-001 — Revised tracking navigation and Weight Log

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Access/decision date:** 2026-08-08
**Scope:** root navigation, Weight Log information architecture, weight CRUD safety, Progress handoff, Settings boundary.

## Decision history

Original `eae1c92` assessment selected a drill-down-only architecture:

```text
Today | Progress | Settings
```

Initial nutrition evidence favored nested Weight. MacroFactor, Foodnoms, MyFitnessPal, and Cronometer keep broad daily-log and analytics destinations top-level and place weight capture/history under those surfaces or a global add action.

Explicit user feedback overrode that choice by prioritizing discoverability. Dedicated-weight precedent now wins: Happy Scale separates Summary, Reports, Logbook, and Settings; Weight Diary Lite exposes graph, summary, and full-log modes; Weigh In separates record, history, and progress actions. The original assessment is superseded transparently, not treated as final.

Final root order:

```text
Today | Weight | Progress | Settings
```

Nutrition references remain relevant for Today/Progress placement and for rejecting generic mixed history. Dedicated-weight sources justify the discoverable Weight root.

## Final information architecture

### Today

Daily calorie budget, meals/food, water, and existing current-day actions. User-facing `Counter` label is now `Today`.

### Weight — navigation title `Weight Log`

Root destination for raw weight measurements and compact context.

- Toolbar `+` is the add / `Record Weight` action.
- Summary shows current value, recent-seven-reading context, and target.
- Compact basic native line + point chart uses latest seven raw readings and a target rule when target is valid.
- Explicit chart endpoint dates appear only when at least two readings exist.
- One reading shows a useful prompt instead of a single dot/dead chart.
- Measurements are grouped by local calendar date, newest date section first, newest rows first.
- Every raw reading remains visible, including multiple readings on one day.
- Add defaults to current date/time and allows independent date and time backdating.
- Row tap opens editor for value/date/time and changes only that raw record.
- Delete requires explicit confirmation. Confirmed deletions use stacked undo; cancel preserves data.
- `View full trends` selects `Progress` with `Weight` selected.

Weight is not a generic calorie journal.

### Progress

Analytics-only destination. Weight view owns fuller fourteen-reading analytics and interpretation. It has no weight create, edit, or delete controls. It must not mutate or collapse Weight Log readings.

### Settings

Retains target weight, age, daily calorie goal, target date, and reminders. No current-weight recording field or save path.

### Calorie boundary

No calorie CRUD was included in TRACKING-IA-001. COMPETITOR-GAP-001 and BACKLOG-CLOSURE-001 later implemented separate date-first diary detail and contracted known-snapshot mutations. Generic Calories/Water/Weight table remains rejected.

## Research sources

All sources below are current verified official URLs accessed 2026-08-08.

### Dedicated-weight precedent

- [Happy Scale App Store](https://apps.apple.com/us/app/happy-scale/id532430574)
- [Happy Scale support](https://happyscale.com/support)
- [Weight Diary Lite App Store](https://apps.apple.com/us/app/weight-diary-lite/id468520999)
- [Weight Diary Lite vendor](https://www.curlybrace.co.uk/weightdiaryfree)
- [Weigh In App Store](https://apps.apple.com/us/app/weigh-in-weight-tracker/id1082115351)
- [Weigh In official site](https://weighin.app/)
- [Monitor Your Weight App Store](https://apps.apple.com/us/app/monitor-your-weight/id413313086)
- [Monitor Your Weight official site](https://monitoryourweight.com/)

Monitor Your Weight is legacy caveat: listing contains older screenshot assets. It is retained as comparison evidence, not decisive current workflow proof.

### Nutrition references that remain relevant

- [MacroFactor Dashboard](https://help.macrofactorapp.com/en/articles/22-get-to-know-your-dashboard)
- [MacroFactor weight logging](https://help.macrofactorapp.com/en/articles/15-log-your-weight)
- [MacroFactor past days](https://help.macrofactorapp.com/en/articles/228-log-food-to-previous-days)
- [Cronometer mobile diary](https://support.cronometer.com/hc/en-us/articles/360018593112-Mobile-Diary-Overview)
- [Cronometer mobile charts](https://support.cronometer.com/hc/en-us/articles/360019864311-Mobile-Charts)
- [MyFitnessPal Today](https://support.myfitnesspal.com/hc/en-us/articles/39985611667341-Your-Today-tab)
- [MyFitnessPal Progress](https://support.myfitnesspal.com/hc/en-us/articles/45246617814669-Introducing-Progress-Overview-Your-Progress-Personalized)
- [MyFitnessPal weight recording](https://support.myfitnesspal.com/hc/en-us/articles/360032624431-How-do-I-record-my-weight-and-other-measurements)
- [Foodnoms weight tracking](https://foodnoms.com/help/track-weight)

## Requirements and acceptance gates

- Root tabs are exactly `Today`, `Weight`, `Progress`, `Settings`, in that order.
- Weight navigation title is `Weight Log`; toolbar add is discoverable.
- Summary exposes current, recent seven, and target context.
- Weight chart uses raw seven-reading line + points and target rule. Endpoint dates are shown only with at least two readings. One reading shows prompt.
- Grouped measurement sections and rows are newest-first.
- Add supports independent date/time backdating.
- Row edit supports value/date/time correction.
- Multiple same-day measurements remain distinct.
- Delete confirms and provides stacked undo.
- `View full trends` selects Progress / Weight.
- Progress owns fuller fourteen-reading analytics and has no CRUD.
- Settings has no current-weight field.
- No calorie CRUD or generic mixed table.
- Dynamic Type, VoiceOver, localization, dark mode, and 44-point controls remain usable.

## Evidence

Accepted TRACKING-IA-001 visual files are only these attempt-01 files under `../screenshots/TRACKING-IA-001/`:

- `attempt-01-four-tabs.png`
- `attempt-01-weight-populated.png`
- `attempt-01-weight-empty.png`
- `attempt-01-weight-accessibility3.png`
- `attempt-01-weight-dark.png`

Superseded three-tab functional history is retained as historical evidence only:

- `superseded-three-tab-two-same-day.png`
- `superseded-three-tab-backdated.png`
- `superseded-three-tab-editor.png`
- `superseded-three-tab-delete-confirmation.png`

Rejected evidence retained:

- `rejected-one-reading-chart.png` — single point produced dead chart with no useful trend. Replaced by a prompt until two readings.

## Final results

- `just validate 300`: **passed**.
- Hostless validation: **125 passed / 2 opt-in live skips**.
- Simulator build, install, and launch: **passed**.
- `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`.
- Explicit UI target: **6/6 passed**, covering four tabs; one-reading prompt → two-reading chart; two same-day readings; backdated date regrouping; edit; delete cancel/confirm/undo; Settings; and direct `View full trends` → `Progress` / `Weight`.
- App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and passed again in an integrated run.
- One later standalone `just test-app-unit 300` timed out before XCTest. This is external Xcode 27 host instability, not a red product gate.

## Historical sequencing resolution

STATES-001, CONSISTENCY-001, ROBUSTNESS-001, and FINAL-001 later completed empty/error/loading, global consistency, dark mode, Dynamic Type, and small-device checks. No follow-up remains.
