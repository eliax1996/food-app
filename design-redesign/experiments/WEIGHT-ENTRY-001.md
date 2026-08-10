# WEIGHT-ENTRY-001 — Low-friction weight and numeric entry

**Status:** ACCEPTED — ATTEMPT 01 / COMPLETE
**Started:** 2026-08-10

## Trigger

User requested fewer weight-recording actions, latest-measure defaults, direct `±1` / `±0.1` controls, and an obvious way to close every numeric keyboard.

## Baseline

- Weight tab → toolbar add → editor → Save already required only two deliberate actions, but new entries used profile setup weight even when newer measurements existed.
- Weight required exact decimal-pad editing and exposed no coarse/fine controls.
- Weight, meal amount/servings, and Plan target weight used number-only keyboards without a keyboard dismissal action.
- Food Tools and optional nutrient editors already used native keyboard Done.

## Apple guidance

Queried Apple Developer Documentation through Xcode on 2026-08-10.

- SwiftUI `ToolbarItemPlacement.keyboard` places actions above the software keyboard and explicitly supports focus-dependent keyboard bars.
- SwiftUI `Stepper` guidance supports bounded granular increment/decrement, but one Stepper exposes one step size. Four explicit semantic buttons better preserve requested coarse/fine deltas without another mode or menu.
- Existing Apple HIG entering-data and accessibility decisions still apply: reduce typing, keep exact entry available, use familiar controls, provide clear completion, and preserve 44-point app-owned targets.

## Hypothesis

Using the latest valid chronological reading as draft default plus four direct adjustments will turn common check-ins into open → optional one-tap nudge → Save. Native keyboard Done will remove number-pad dead ends without conflating keyboard dismissal with form Save.

## Attempt 01

### Changes

- Added deterministic `WeightEntryDraft` rules:
  - latest valid nonfuture measurement;
  - valid profile current-weight fallback;
  - 70 kg final fallback;
  - finite one-decimal adjustment with invalid/nonpositive rejection.
- New weight editor opens directly from Weight and still saves in two deliberate actions.
- Added `−1`, `−0.1`, `+0.1`, and `+1` kg controls; normal layout is one row, Accessibility sizes use 2 × 2.
- Kept exact decimal entry, date, time, Save, and Cancel.
- Added native keyboard Done to Weight, Meal amount/servings, and Plan target weight. Food Tools/custom nutrients already had Done. Done clears focus only.
- Added deterministic tests and focused UI coverage for latest default, all four controls, target size, keyboard dismissal, unchanged values, meal keyboard dismissal, and Plan keyboard dismissal.

### Evidence

- `../screenshots/WEIGHT-ENTRY-001/attempt-01-editor.png`
- `../screenshots/WEIGHT-ENTRY-001/attempt-01-editor-ax3-dark.png`

Direct pixel review: input is visibly editable, value/unit hierarchy is clear, four actions fit without crowding, date/time remain secondary, and AX3 dark reflows controls to 2 × 2 without clipping.

One independent critical/high visual judge returned `APPROVE`. One bounded code reviewer returned `APPROVE` for chronology, bounds, action count, focus semantics, accessibility, and tests.

### Focused validation

- `just test-one WeightEntryDraftTests 180`: 4/4 passed.
- `just iterate 240`: 157 tests executed, including 2 live skips; app compile passed.
- `testWeightEditorUsesLatestReadingAdjustmentsAndKeyboardDone`: passed.
- `testAmountAdjustmentsKeepServingCountAndAvoidKeyboard`: passed with new keyboard Done assertion.
- `testRootTabsAndSettingsRemainAvailable`: passed with new Plan keyboard Done assertion.

### Final validation

- `just validate 300`: passed; 157 hostless tests executed, including 2 live skips; simulator build/install/launch passed.
- `just test-app-unit 420`: passed; 184 tests passed / 2 live skips.
- `just test-ui 600`: passed 14/14. Xcode emitted its existing source-less `Invalid frame dimension (negative or non-finite).` diagnostics while numeric keyboards opened; all keyboard flows and screenshots passed with no visible defect.

### Decision

**ACCEPTED — ATTEMPT 01 / COMPLETE.** Common weight entry is direct, latest-data-aware, keyboard-optional, exact-entry capable, accessible, and fully validated.
