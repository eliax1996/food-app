# Working notes

## Current milestone

`TRACKING-IA-001` — **ACCEPTED — ATTEMPT 01 / COMPLETE**.

Final root:

```text
Today | Weight | Progress | Settings
```

## Architecture

- **Today:** current-day calorie, food, and water actions.
- **Weight / Weight Log:** raw measurements, basic seven-reading raw chart, current/recent-seven/target context, same-day preservation, independent date/time backdating, edit, confirmed delete, stacked undo, and useful one-reading prompt.
- **Progress:** fuller fourteen-reading weight analytics only. No weight CRUD. `View full trends` routes directly to Progress / Weight.
- **Settings:** target weight, age, daily calorie goal, target date, and reminders. No current-weight field or save path.
- No historical calorie CRUD or generic Calories/Water/Weight table. Future calorie history is separate date-first day diary.

## Final results

- `just validate 300`: **passed**.
- Hostless validation: **125 passed / 2 opt-in live skips**.
- Simulator build, install, and launch: **passed**.
- `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`.
- Explicit UI target: **6/6 passed**, covering four tabs; one-reading prompt → two-reading chart; two same-day readings; backdated date regrouping; edit; delete cancel/confirm/undo; Settings; and direct `View full trends` → `Progress` / `Weight`.
- App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and passed again in an integrated run.
- One later standalone `just test-app-unit 300` timed out before XCTest. External Xcode 27 host instability; not a red product gate.

## Visual evidence

Accepted TRACKING visual files are only `design-redesign/screenshots/TRACKING-IA-001/attempt-01-*`.

- `superseded-three-tab-*` files remain historical.
- `rejected-one-reading-chart.png` remains rejected evidence.

## Next work

1. empty/error/loading states
2. global consistency, dark mode, Dynamic Type, and small-device checks
