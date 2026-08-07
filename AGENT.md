# Count Calories

## Goal

Build a focused iOS calorie tracker that lets people record foods, water, weight, and daily goals quickly. Barcode scans automatically retrieve nutrition data, cache the product, and open Add Meal with its reported serving or package amount. Use grams for food and milliliters for beverages. Let users confirm amount and choose portions in quarter steps from 0.25 through 4, while allowing larger values through direct entry. Offer opt-in meal and water reminders that users can control by reminder type.

Prioritize a fast, dependable user experience. Preserve offline access for products that have already been scanned.

## Structure

- `count_calories/ContentView.swift`: app entry point, SwiftData models, and primary SwiftUI screens, including reminder controls.
- `count_calories/ReminderNotifications.swift`: deterministic meal/water reminder planning, notification permission handling, and local-notification scheduling.
- `count_calories/Nutrition/`: independent nutrition lookup domain.
- `Package.swift`: hostless `CaloriesCore` package that compiles the production nutrition sources directly for fast macOS tests.
- `FoodNutrition.swift`: normalized, Codable nutrition data per 100 g/ml plus serving amount and unit.
- `OpenFoodFactsClient.swift`: Open Food Facts barcode API client and response decoding.
- `NutritionCache.swift`: persistent, byte-bounded LRU cache and cache-first lookup service.
- `count_caloriesWidget/`: WidgetKit extension and shared widget summary storage.
- `CaloriesActivityAttributes.swift`: Live Activity attributes shared by the app and widget.
- `count_caloriesTests/`: XCTest coverage for nutrition lookup, decoding, persistence, and eviction.
- `justfile`: supported build, install, launch, and simulator operations.

The app is a SwiftUI and SwiftData project targeting iOS 17+. Xcode filesystem-synchronized groups automatically include Swift files created beneath target source directories.

## Operations

Use `just` as the only entrypoint for project operations. Do not invoke `scripts/iterate.zsh`, `xcodebuild`, `simctl`, `devicectl`, or installation commands directly. Improve the `justfile` and its internal helper first when a repeatable operation is absent. The helper deliberately rejects direct invocation so every caller gets the same destinations, caches, and timeouts.

- `just iterate`: preferred edit loop; run hostless core tests and incrementally compile the app without booting or installing.
- `just check`: incrementally compile without tests, simulator boot, installation, or launch.
- `just test-unit`: run deterministic nutrition tests directly on macOS against the production source files.
- `just test-one Class[/method]`: incrementally compile and run one hostless test filter.
- `just test-rerun`: rerun the already-built hostless tests only when sources have not changed.
- `just test-app-unit`: explicitly verify the duplicate app-hosted XCTest integration when needed.
- `just test-ui`: run only the functional UI smoke test behind a clean simulator restart.
- `just test-performance`: run launch measurement explicitly; performance tests never belong in the edit loop or correctness gate.
- `just test`: run the automated correctness gate: hostless unit tests and an incremental app compile.
- `just validate`: run unit tests, compile, install, and launch in the simulator. Xcode 27 UI-test hosting is intentionally explicit because it can stall before XCTest starts.
- `just simulator-build`, `just simulator-install`, `just simulator-run`: incremental simulator app operations.
- `just build`, `just install`, `just launch`, `just run`: incremental physical-iPhone operations.
- `just device-test`, `just device-validate`: complete physical-iPhone validation operations.
- `just provision`: explicitly allow Apple provisioning updates after a normal physical build reports a signing problem; normal iterations intentionally avoid provisioning network work.
- `just doctor`: bounded checks for Xcode, the configured simulator, and the paired iPhone.
- `just simulator-reset`: restart the configured simulator without erasing its data or build caches.
- `just clean`: remove the isolated simulator and device derived-data caches.
- `just recover`: restart the simulator and clear derived data only after a genuinely stale build/test session.

Keep `justfile` variables centralized for Xcode paths, bundle identifiers, device IDs, simulator IDs, timeouts, and derived data locations. Simulator and physical-device derived data are intentionally isolated under one root so switching SDKs cannot churn or lock the other destination's build database. Add a named recipe for new recurring tasks, including tests.

Use `just check` for most app/UI edits, `just test-one` while changing one covered core behavior, and `just iterate` when an edit needs both core regression coverage and app compilation. Use `just simulator-run` only when visual or runtime behavior needs inspection. Before declaring implementation complete, validate the exact working tree with `just validate`; use `just device-validate` when simulator infrastructure is unavailable. Run `just test-ui` separately when UI behavior changes, but report Xcode test-host infrastructure failures independently from compilation or unit-test results. Documentation-only changes do not require validation.

Every potentially blocking external tool is protected by a process-group timeout. Defaults are 60 seconds for iteration, 90 seconds for validation/UI operations, and 30 seconds per ordinary XCTest method, with a 60-second hard per-test maximum. Override command deadlines with `ITERATION_TIMEOUT=...` or `VALIDATION_TIMEOUT=...`, or pass the timeout as the recipe's final positional argument. Do not remove or repeatedly increase the timeout while diagnosing a stall.

Use this completion sequence for every implementation: inspect the affected code and existing tests, make the smallest correct change, add or update deterministic tests for changed observable behavior, then run `just validate` or `just device-validate`. Fix any failures or warnings and repeat validation after each subsequent code or build-affecting configuration edit. Report the command and its outcome when work is complete.

Keep this document current. When code, project operations, validation commands, architecture, product direction, or engineering practices change, update the affected `AGENT.md` guidance in the same change. Do not retain instructions that no longer describe the repository.

## Escalation

When the same implementation problem remains unresolved after three or four focused edit-and-validate iterations, launch a `general` subagent using GPT-5.6 Sol at default effort. Begin its prompt with a clear statement of the problem, the required end state, relevant constraints, failed attempts, and validation failures. Ask it to diagnose and implement the smallest complete fix, then independently verify it. Do not escalate routine failures that have an obvious next correction.

## Xcode MCP Bridge

Use the persistent local XcodeBridge service for agent access to Xcode and the iOS Simulator. It maintains one Xcode MCP connection, avoiding Xcode's repeated per-process approval prompts when OpenCode restarts.

- Keep the project open in Xcode and leave `Xcode > Settings > Intelligence > Allow external agents to use Xcode tools` enabled.
- The bridge is installed at `~/.local/share/XcodeBridge/` and runs as the per-user LaunchAgent `io.positron.xcodebridge`.
- The LaunchAgent starts it automatically. To restart it after a failure, run `launchctl kickstart -k gui/$(id -u)/io.positron.xcodebridge`.
- Confirm the service is running with `launchctl print gui/$(id -u)/io.positron.xcodebridge` and confirm OpenCode can connect with `opencode mcp list`. The `xcode` server must report `connected`.
- OpenCode connects through `~/.local/share/XcodeBridge/build/Build/Products/Release/XcodeBridge.app/Contents/Resources/xcbridge connect`. Do not replace this with a direct `xcrun mcpbridge` configuration, because doing so reintroduces the repeated Xcode permission prompt.
- The bridge uses Xcode beta through `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`. The stable Xcode command-line tools are not currently selected.
- After changing OpenCode MCP configuration, restart OpenCode before attempting Xcode operations.
- For exploratory end-to-end verification, use the Xcode MCP tools to build and launch on a simulator, inspect the accessibility hierarchy, then interact only using coordinates from the latest hierarchy. Turn stable, important workflows into XCTest UI tests; MCP interaction is a verification aid, not a replacement for committed test coverage.
- For repeatable meal-entry verification, load `/skill:count-calories-meal-flow`; its project runbook is `.pi/skills/count-calories-meal-flow/SKILL.md`.

## Continuity

Do not stop at a partial implementation when the requested work is actionable. Keep a concise `WORKING_NOTES.md` with the active goal, shared judge feedback, unresolved work, and required validation. Read it at the beginning of substantive work and after context compaction. Update it as work is completed or new shared feedback is found.

Periodically run three independent, read-only LLM-as-judge reviews against this document. Give each reviewer only the repository path and evaluation criteria, collect their results without priming them, and address findings shared by all three. Repeat review and implementation until they agree on the final evaluation.

### Xcode Recovery

Treat low CPU with no new output as a stalled operation when `xcodebuild` has already reached app/test-bundle validation or module pruning but XCTest never prints test progress. Other indicators are an interrupted prior command and stale simulator test-host processes.

Do not wait indefinitely or repeatedly increase the timeout. The operation wrapper terminates the complete child process group at its deadline, and a timed-out simulator test resets the simulator for the next iteration. Retry once. Use `just simulator-build` to distinguish compilation from test-host startup: a successful simulator build proves compilation works. Run `just recover` only if the bounded retry still demonstrates stale build state, because recovery intentionally discards the incremental cache. If the retry reports `Early unexpected exit ... before establishing connection`, investigate the XCTest host/bootstrap separately; do not describe it as a compilation failure or keep clearing build caches.

The app running normally in the configured simulator can prevent XCTest from relaunching the same bundle as its instrumented test host. Every simulator test recipe therefore terminates the app before invoking XCTest. Preserve this preflight and the timeout-triggered simulator reset when changing the test workflow.

## Engineering Style

Make the smallest correct change. Keep code direct, cohesive, and easy to read.

Before adding code, always ask: **Can this be done simpler and more direct?**

When removing or replacing code, always ask: **Can some piece of code be written in a simpler way?**

- Prefer standard Apple frameworks and existing app patterns over dependencies or abstractions.
- Keep code in one type or function unless extracting it provides a concrete reuse or clarity benefit.
- Scope types, helpers, and extensions as narrowly as their use allows. Prefer `private` or `fileprivate` implementation details over expanding module-wide visibility.
- Split files by coherent semantic meaning: keep closely related models, API decoding, cache behavior, and UI concerns together, while separating concepts that evolve independently.
- Avoid both extremes: do not create one-file-per-tiny-type boilerplate, and do not mix unrelated layers or concepts in a large catch-all file. A file should provide useful context for one cohesive feature or domain responsibility.
- Keep similarly abstract concepts together. Do not pollute a file's context by combining UI presentation, persistence mechanics, network transport, and unrelated business rules without a clear reason.
- Use descriptive names and explicit data ownership.
- Avoid speculative compatibility code and unused generalization.
- Treat warnings as defects. Keep formatting and access control consistent with nearby code.
- Add comments only for non-obvious decisions or constraints.
- Handle network failures, malformed data, missing nutrition fields, and unavailable services explicitly.

## Logging

Design observable features. Add concise, structured `Logger` events at meaningful boundaries so failures can be understood from device logs without reproducing them manually.

- Log lookup source decisions: cache hit, cache miss, remote success, remote not found, and remote failure.
- Log operational context such as barcode length or HTTP status, never full user-entered data or sensitive personal information.
- Log cache writes and evictions with entry counts or byte usage when that helps diagnose behavior.
- Do not log on every render, normal UI interaction, or hot path without a diagnostic purpose.

## Tests

Write useful tests alongside behavior changes. Prefer deterministic unit and integration-style tests with mocked network responses over live network tests. Keep live API checks opt-in.

Before writing each test, ask:

1. **What is this test protecting from a regression?**
2. **Is this extremely coupled and will cause a 1 to 1 modification to the code?**

If a test only restates private implementation steps, replace it with a test of observable behavior. Test public outcomes, error handling, persistence boundaries, and important edge cases.

Reminder coverage should protect fixed meal windows, suppression after matching records, elapsed-time water scheduling, daily water-goal suppression, independent preferences, and the pending-notification limit.

Nutrition coverage should protect at least:

- Open Food Facts payload decoding into normalized nutrition, package/serving amount, and g/ml unit fields.
- Unknown products and malformed or invalid barcodes.
- Cache-first behavior preventing unnecessary requests.
- Cache persistence across service/cache recreation.
- LRU eviction when the configured byte budget is exceeded.

Keep `just test` as the bounded automated correctness gate and keep UI/performance checks available as explicit recipes. Run the relevant tests before declaring work complete.
