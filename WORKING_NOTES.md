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
- Serialized `just` operations with a cross-process lock and added explicit configured-simulator shutdown.
- Added isolated persistent simulator/device caches, fast unit/selected-test loops, and explicit slow UI/performance validation.
- Added hostless `CaloriesCore`, `ReminderCore`, and `TrackingCore` package targets over production domain sources; warm core tests complete in under one second.
- Split compile-only, UI smoke, and launch-performance work into separate bounded recipes.
- Added independent breakfast, lunch, snack, dinner, and water reminder controls in Config.
- Added conditional local-notification scheduling: fixed missing-meal windows and daytime water reminders based on latest glass, with daily-goal suppression.
- Added deterministic reminder planner tests and UI control coverage.
- Split catch-all app source into `App`, `Features`, `Models`, `Services`, and `Tracking` ownership boundaries.
- Added seeded previews for complete app, each primary tab, meal editor, counter components, and history chart.
- Added hostless tracking tests for calorie scaling, meal windows, daily aggregation, history limits, and widget deep links, plus app-hosted legacy model tests.
- Completed three independent read-only architecture/test reviews: no actionable finding was shared by all three; one approved and two reported non-overlapping residual suggestions.
- Added Open Food Facts v3.6 structured-nutrition client as primary, retained v2 as delayed fallback, and bounded lookup with a six-second UX deadline.
- Replaced nullable nutrition domain fields with nonoptional `FoodNutrition` and explicit found/incomplete/not-found results; retained legacy cache decoding.
- Sampled 14 barcodes against both API versions, documented field presence/rate-limit evidence and SDK assessment, and added deterministic plus opt-in live API tests.
- Completed final three-reviewer nutrition pass: two approved; one suggested undocumented v2 `energy-kcal_100ml`, contradicted by official v2 schema and sampled beverage responses using `energy-kcal_100g`; no shared actionable finding remained.

## Required Validation

After app/UI edits: run `just check`. Nutrition, reminder, and tracking rules run hostlessly through `just test-unit`. After core behavior edits: run `just iterate` or the narrowest `just test-one` filter. Prefer these deterministic checks throughout the edit loop instead of repeatedly paying for simulator UI startup.

Before completing any non-documentation feature or bug fix that changes app behavior: run `just validate` for hostless tests, app compilation, installation, and launch, then run expensive `just test-ui` once against the final artifact. Rerun UI proof after any product fix or later artifact-changing edit. Add stable UI coverage for critical new user flows while keeping most behavioral coverage in unit tests.

When simulator infrastructure is unavailable, run `just device-validate` on the configured physical iPhone and report unavailable UI-test proof separately.

## Architecture Direction

- Keep `App/ContentView.swift` limited to tab and deep-link composition.
- Organize UI feature-first under `Features`; keep shared models, app-wide services, and independently testable domain rules separate.
- Give primary screens and independently useful UI portions local `#Preview` definitions backed by `App/PreviewData.swift` when persistence data is needed.
- Split by ownership and reasons to change, not one file per tiny type or arbitrary line-count limits.

## Pending Test Coverage

- The meal-addition flow was verified through Xcode MCP: the default Almond Milk meal saves as 15 kcal and updates today's total. Repeat it with `/skill:count-calories-meal-flow` from `.pi/skills/count-calories-meal-flow/SKILL.md`.
- `count_caloriesUITests` contains the deterministic meal-addition flow. It uses the `-ui-testing` launch argument for an in-memory store and asserts that the default Almond Milk meal updates today's total to 15 kcal.
- Beverage mapping is covered for both API generations with La Nostra Limonata: 275 ml and 176 kcal per package. App-hosted tests cover fractional quantity and volume-unit persistence.
- `OpenFoodFactsLiveTests` contains two opt-in integration checks. Run only ad hoc with `RUN_OPEN_FOOD_FACTS_LIVE_TEST=1 just test-one OpenFoodFactsLiveTests`; both v3.6 and v2 checks passed after implementation.
- The Xcode 27 simulator UI-test runner remains intermittent: it can complete assertions, fail to obtain the app process handle, or stall before XCTest progress. `just test-ui` restarts the simulator, runs both functional UI flows while excluding launch performance, and has a 90-second process-group deadline; it is intentionally excluded from the fast correctness gate until the beta test host is dependable.
- Current architecture change passed `just validate`, hostless tests, app compilation, install, and normal launch. Three bounded `just test-ui` attempts stalled before XCTest progress, including one after `just recover`; a later app-hosted retry reported `Application launch ... did not return a process handle`. `just simulator-run` then launched app normally, isolating failure to Xcode test hosting.
- Current Open Food Facts change passed 45 hostless tests (2 live checks skipped by default), both opt-in live API checks, app-hosted tests after one infrastructure retry, `just validate`, and normal simulator launch. Two final `just test-ui` attempts stalled before XCTest progress; normal launch succeeded immediately afterward.
