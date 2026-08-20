---
name: count-calories-meal-flow
description: Launch and exercise Count Calories in the configured iOS simulator, then verify that saving the default Almond Milk meal adds exactly 15 kcal. Use for simulator launch, meal-entry, or Apple Xcode MCP UI verification requests.
compatibility: macOS with Xcode beta, XcodeBridge, pi-mcp-adapter, and the configured iOS simulator.
---

# Count Calories Simulator Meal Flow

## Goal

Launch current app build in configured simulator, add default meal through real UI, and prove:

- daily calorie total increases by exactly 15 kcal;
- `Almond Milk` meal row appears;
- row shows `1× · 100 g` and `15 kcal` (accessibility value: `1× · 100 g, 15 calories`);
- no functional or visible layout failure occurred.

Compare before and after totals. Do not assume initial total is zero because simulator store persists.

## Constraints

1. Read `AGENT.md` and `WORKING_NOTES.md` first.
2. Use `just` for project operations. Never call `xcodebuild`, `simctl`, `devicectl`, or `scripts/iterate.zsh` directly.
3. Keep project open in Xcode with external-agent access enabled.
4. Use persistent `xcbridge connect` MCP configuration. Never replace it with direct `xcrun mcpbridge`.
5. Apple device interaction requires a separate subagent that loads Xcode's `device-interaction` skill. Do not synthesize UI events from main agent.
6. Derive every tap from center coordinates in latest hierarchy. Never reuse stale coordinates or guess from screenshot.
7. Always close interaction session with `DeviceInteractionEndSession`, including failure paths.

Xcode-exported subagent skill currently lives at:

```text
~/Library/Developer/Xcode/CodingAssistant/codex/skills/__xcode/device-interaction/SKILL.md
```

Read that file completely before delegation.

## Main-agent procedure

### 1. Build, boot, install, and launch

```bash
just simulator-run
```

Expected recipe stages: incremental simulator build, readiness, install, launch.

A launch from `just` can still appear as `NotRun` to Xcode's interaction service because Xcode does not own that launch. Continue with Xcode-owned launch below; this is not app failure.

### 2. Open Xcode interaction session

Through Xcode MCP:

1. Call `XcodeListWindows` and select tab whose workspace path ends in `count_calories.xcodeproj`.
2. Call `DeviceInteractionStartSession` with:
   - selected `tabIdentifier`;
   - unique Title Case `sessionIdentifier`;
   - simulator ID from `justfile` (`simulator := ...`), not a copied historical ID.
3. Save returned `interactionSessionKey`.
4. Call `DeviceInteractionInstallAndRun` with tab and interaction-session key. This gives Xcode ownership of app launch.

Do not perform touch events in main agent.

### 3. Delegate all interaction

Spawn fresh, read-only subagent with MCP plus file/image read access. Force-load Xcode skill using `/skill:device-interaction`. Give it exclusive interaction-session key and this task:

```text
Capture and read latest hierarchy and screenshot. If count_calories is backgrounded
or app switcher is visible, foreground its app card using hierarchy-derived center
coordinates and recapture. Record current daily-calorie-total. Tap add-meal / Log food using
latest hierarchy center, recapture, verify default Almond Milk at 100 g, tap save-meal /
Add using latest hierarchy center, and recapture. Success requires total delta +15
and visible meal-entry-Almond Milk showing 1× · 100 g and 15 kcal. Retry transient launch
or tap timing once. Do not modify files or end session; parent owns cleanup.
```

When no native subagent tool exists, a separate Pi process is acceptable:

```bash
pi -p --no-session --approve --thinking high \
  --tools read,mcp \
  --skill "$HOME/Library/Developer/Xcode/CodingAssistant/codex/skills/__xcode/device-interaction/SKILL.md" \
  "/skill:device-interaction Act as exclusive device-interaction subagent for session '<SESSION KEY>'. <TASK ABOVE>"
```

### 4. Required subagent interaction loop

For each step:

1. Call `DeviceInteractionSynthesize` without `interactionCommand`.
2. Read returned hierarchy file and screenshot.
3. Find target's current center coordinates.
4. Perform one interaction.
5. Capture again and verify transition before continuing.

Expected identifiers/labels:

- total: `daily-calorie-total`;
- add button: `add-meal` / `Log food`;
- save button: `save-meal` / `Add`;
- result row: `meal-entry-Almond Milk` / `Almond Milk`.

Default meal type depends on local time (`Breakfast`, `Lunch`, `Dinner`, or `Snack`). Do not hardcode meal type.

If app switcher is shown, hierarchy contains app card like:

```text
identifier: 'card:ch.elia.count-calories:...'
label: 'count_calories'
```

Tap that card's current center, then recapture app hierarchy before touching app controls.

Apple interaction command syntax comes from Xcode skill. Common tap form:

```text
t <x> <y>
```

### 5. Verify outcome

Pass only when latest hierarchy proves all:

- bundle identifier is `ch.elia.count-calories`;
- parsed calorie total equals previous total plus 15;
- `meal-entry-Almond Milk` exists;
- row details include `1× · 100 g` and `15 kcal`; accessibility value includes `1× · 100 g, 15 calories`;
- screenshot has no overlap, clipping, unreadable text, or unexpected blank state.

Record before total, after total, meal details, final hierarchy path, and final screenshot path.

### 6. Cleanup

Main agent calls:

```text
DeviceInteractionEndSession(interactionSessionKey)
```

Run cleanup even if delegation or verification fails.

## Troubleshooting

- MCP unavailable: run `/mcp reconnect xcode`; confirm bridge LaunchAgent is running.
- `NotRun` after `just simulator-run`: call `DeviceInteractionInstallAndRun` inside active interaction session.
- `RunningInBackground` or SpringBoard hierarchy: recapture, locate app card from hierarchy, tap its center once, recapture.
- Empty/launch hierarchy: wait briefly and recapture once.
- Tap misses: recapture because coordinates changed, then retry once.
- Never leave session open while diagnosing unrelated build/test failures.

## Historical manual run and current regression proof

Manual hierarchy-driven run verified 2026-08-02 on configured iPhone 17 Pro simulator:

- before: `0 / 1.700 kcal`;
- after: `15 / 1.700 kcal`;
- row: `Almond Milk`, `Snack`, `1x, 100 g, 15 kcal`;
- Xcode interaction session closed successfully.

Current deterministic UI coverage protects same contract: `testAddingDefaultMealUpdatesToday` asserts exact +15 kcal and `testMealDeleteRequiresCancelOrConfirmation` asserts Almond Milk `1× · 100 g` plus 15 calories. Latest whole-tree UI record is 52/52 in `design-redesign/FINAL-REPORT.md`. Rerun manual flow when explicitly requested; dated result above is historical evidence, not claim of a current simulator session.
