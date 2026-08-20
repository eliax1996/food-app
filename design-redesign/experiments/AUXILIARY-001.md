# AUXILIARY-001 — Widget and Live Activity

**Status:** ATTEMPT 01 ACCEPTED — COMPLETE
**Date:** 2026-08-13

## Problem

Existing auxiliary surfaces predated accepted Today hierarchy. Small widget clipped values/actions even at normal text, Live Activity started implicitly with no stop action, both surfaces emphasized consumed calories instead of remaining/over status, goal attributes could become stale, and identical water buttons had different persistence semantics.

Assessment: `docs/widget-live-activity-assessment.md`.

## Hypothesis

One readable medium widget and an explicit, bounded Live Activity will make glanceable tracking faster without occupying persistent system UI unexpectedly or presenting display-only mutations as saved facts.

## Accepted implementation

- Widget now supports the medium family only because three interactive actions plus truthful calorie/water context cannot fit small at supported text sizes.
- Primary widget answer is remaining/over calories, followed by eaten/goal and `x of y` water progress.
- Widget retains **Log food** deep link and bounded water decrement/increment.
- App Group summary adds backward-compatible goal and revision fields.
- Cross-process file lock and revision handshake prevent app mirroring from overwriting pending widget water changes.
- Root app imports pending widget water into SwiftData on launch/foreground, independent of Today view lifecycle.
- Widget water intent immediately refreshes active Live Activity from committed shared summary.
- Live Activity no longer starts during normal Today synchronization. User explicitly starts/stops it from Today toolbar menu.
- Live Activity dynamic content owns current calorie/water goals, so accepted plan changes update status without stale immutable attributes.
- Lock Screen and Dynamic Island show remaining/over status, water goal context, and one truthful **Log food** handoff. Display-only water controls were removed.

## Evidence

- `attempt-01-widget-medium-light.png`
- `attempt-01-widget-medium-ax3-dark.png`
- `attempt-01-widget-over-goal.png`
- `attempt-01-live-lock-screen.png`
- `attempt-01-live-lock-screen-ax3-dark.png`
- `attempt-01-live-compact.png`
- `attempt-01-live-expanded.png`

All files: `design-redesign/screenshots/AUXILIARY-001/`.

## Validation

- Incremental app + widget build passed on iOS 17 deployment target.
- App-hosted suite passed 300 tests / 2 opt-in live skips.
- Hostless suite remained 219 / 2 opt-in live skips.
- Focused UI test proved explicit **Start Live Activity** entry.
- Broad functional suite executed 45 passing tests; one unrelated amount test exceeded its one-minute allowance, then passed focused rerun.
- Xcode snippets proved update-without-start leaves zero activities and explicit start/stop transitions `false → true → false`.
- Final critical/high source review consensus: **APPROVE / APPROVE / APPROVE**.

## Decision

**ACCEPTED — ATTEMPT 01 / COMPLETE.** Historical next milestone was CONSISTENCY-001; it and later closure work are complete.
