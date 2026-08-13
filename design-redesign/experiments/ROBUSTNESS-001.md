# ROBUSTNESS-001 — Cross-product stress matrix

**Status:** ATTEMPT 01 ACCEPTED — COMPLETE
**Date:** 2026-08-13

## Scope

Exercise accepted primary surfaces across light/dark, normal/AX3 Dynamic Type, small/large iPhone, long/extreme/empty/dense data. Detailed matrix and findings: `docs/whole-app-robustness-assessment.md`.

## Accepted changes

- Food-log status/action stacks at accessibility sizes and uses narrow-width fallback at normal sizes.
- Water summary stacks above 44-point controls at accessibility sizes.
- Settings summary title/value/detail stack at accessibility sizes.
- Xcode previews suppress external App Group/widget/activity side effects, keeping fixture evidence deterministic.
- Added fixed-layout whole-app previews for small, empty, dense, and over-goal states.
- Added focused AX3 UI proof for food-log status/action, Nutrition, and Log food scroll reachability.

## Evidence

Retained under `design-redesign/screenshots/ROBUSTNESS-001/`:

- `today-normal-light.png`
- `today-small-light.png`
- `today-empty-small.png`
- `today-over-goal-large.png`
- `today-dense-large.png`
- `today-ax3-dark.png`
- `today-small-ax3-dark.png`
- `today-dense-ax3-dark.png`
- `weight-ax3-dark.png`
- `settings-ax3-dark.png`
- `meal-editor-ax3-dark.png`
- `nutrition-ax3-dark.png`
- `reminder-editor-small.png`

Earlier accepted component evidence supplements scanner, bulk review, widget, Live Activity, setup, Plan, and reminder AX3/dark states.

## Validation

- Incremental app + widget build passed.
- Focused `testTodayAccessibilityLayoutKeepsPrimaryControlsReachable` passed.
- Three independent critical/high robustness reviews: **APPROVE / APPROVE / APPROVE**.

## Decision

**ACCEPTED — ATTEMPT 01 / COMPLETE.** Historical next milestone FINAL-001 is now complete.
