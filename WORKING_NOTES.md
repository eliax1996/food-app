# Completed Work

## Goal

Keep calorie, water, weight, and nutrition recording fast while supporting opt-in, independently controlled meal and water reminders.

## Completed Judge Feedback

- Added actionable SwiftData save error handling and logging.
- Added corrupt-cache recovery and deterministic failure-path coverage.
- Added camera barcode scanning, automatic post-scan lookup, and scanner failure handling.
- Added Open Food Facts serving/package amount and g/ml normalization, including legacy-cache metadata refresh with offline fallback.
- Added editable fractional portions with a 0.25...4 quarter-step slider and persisted values above that range.
- Made default Almond Milk UI-test selection deterministic and synchronized assertions with enabled controls and static text.
- Completed a three-agent judge review with no shared actionable findings.
- Added physical-device validation and fixed target-specific bundle identifiers.
- Made `just` the sole operations entrypoint and added a bounded internal iteration helper.
- Added isolated persistent simulator/device caches, fast unit/selected-test loops, and explicit slow UI/performance validation.
- Added a hostless `CaloriesCore` Swift package over the production nutrition sources; warm core tests complete in under one second.
- Split compile-only, UI smoke, and launch-performance work into separate bounded recipes.
- Added independent breakfast, lunch, snack, dinner, and water reminder controls in Config.
- Added conditional local-notification scheduling: fixed missing-meal windows and daytime water reminders based on latest glass, with daily-goal suppression.
- Added deterministic reminder planner tests and UI control coverage.

## Required Validation

After app/UI edits: run `just check`. Reminder planner tests require `just test-app-unit`. After core behavior edits: run `just iterate` or the narrowest `just test-one` filter.

Before completion: run `just validate` for hostless tests, app compilation, installation, and launch. Run `just test-ui` separately for UI behavior changes.

When simulator infrastructure is unavailable, run `just device-validate` on the configured physical iPhone.

## Pending Test Coverage

- The meal-addition flow was verified through Xcode MCP: the default Almond Milk meal saves as 15 kcal and updates today's total. Repeat it with `/skill:count-calories-meal-flow` from `.pi/skills/count-calories-meal-flow/SKILL.md`.
- `count_caloriesUITests` contains the deterministic meal-addition flow. It uses the `-ui-testing` launch argument for an in-memory store and asserts that the default Almond Milk meal updates today's total to 15 kcal.
- Beverage mapping is covered with a representative La Nostra Limonata payload: 275 ml and 176 kcal per package. App-hosted tests cover fractional quantity and volume-unit persistence.
- The Xcode 27 simulator UI-test runner remains intermittent: it can complete assertions, fail to obtain the app process handle, or stall before XCTest progress. `just test-ui` restarts the simulator and has a 90-second process-group deadline; it is intentionally excluded from the fast correctness gate until the beta test host is dependable.
