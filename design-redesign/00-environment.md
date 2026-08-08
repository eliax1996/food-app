# Redesign environment

Recorded: 2026-08-08

## Active model

- Provider: `openai-codex`
- Model: `gpt-5.6-sol`
- Reasoning: `max`
- Image input: **VERIFIED**

## Image verification

Xcode device interaction captured the running Counter screen at:

`design-redesign/screenshots/baseline/counter-empty.png`

The PNG was loaded directly through Pi's image-reading tool. Pixel-visible details independently observed from the image included:

- pale grouped iOS background and large black `Calories` navigation title;
- white rounded Today, Water, and Meals surfaces;
- orange/gray calorie progress and blue/gray water progress;
- large empty-meal state with outlined fork-and-knife symbol;
- floating native tab bar overlapping the `New food` numeric rows.

This verification used the image itself, not its filename, metadata, or accessibility hierarchy.

## Xcode MCP

Connected workspace tab: `windowtab3`

Working capabilities inspected:

- list Xcode windows, schemes, and run destinations;
- build/run current project;
- run selected/all tests and inspect logs/results;
- render SwiftUI previews;
- start/end device interaction sessions;
- install and launch through Xcode ownership;
- capture simulator screenshot plus accessibility hierarchy;
- synthesize touch, swipe, keyboard, hardware-button, and orientation events.

## Simulator and screenshot mechanism

- Simulator: iPhone 17 Pro, iOS 27.0
- Device ID: `B171D474-2B64-4D85-B15C-F231E745BD0F`
- Screenshot mechanism: `xcode_DeviceInteractionSynthesize` in an exclusive device-interaction session
- Interaction mechanism: hierarchy-derived center coordinates only
- Hierarchy and screenshot capture verified against running bundle `ch.elia.count-calories`

## Build mechanism

- Repository operations: `just` recipes only, per `AGENT.md`
- Runtime ownership for visual review: Xcode MCP `DeviceInteractionInstallAndRun`
- Fast compile gate: `just check`
- Core gate: `just test-unit` / `just iterate`
- Final product gate: `just validate`

## Interaction and navigation

Apple device events must be delegated to a separate Pi process loading Xcode's `device-interaction` skill. Main agent owns session start, install/run, code changes, artifact copying, and session cleanup.

## Subagents

Available:

- separate read-only Pi processes;
- Xcode MCP-capable device-interaction subagents;
- independent product-design, competitive, native-iOS, and visual-judge prompts;
- vision-capable current model with direct PNG inspection.

No built-in Agent tool is exposed in this harness; separate `pi --no-session` processes are supported fallback.

## Fallback mechanisms

- `just simulator-run`, `just check`, `just validate`, and bounded test recipes;
- SwiftUI preview rendering through Xcode MCP;
- screenshot and hierarchy artifacts from Xcode device interaction;
- file-level image inspection through Pi.

Direct `xcodebuild`, `simctl`, `devicectl`, and helper-script invocation are intentionally not used because repository policy requires `just` as sole project-operation entrypoint.
