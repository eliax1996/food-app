# [HISTORY-001 / PROGRESS-001 / WEIGHT-001] Progress analytics

## Baseline

Screenshots:

- `../screenshots/baseline/history-calories.png`
- `../screenshots/baseline/history-weight-empty.png`

Problems:

- Raw calorie bars lacked target rule, average, adherence, or period context.
- Every value/date was annotated; fourteen days would become noisy.
- Weight reused calorie histogram language despite being continuous trend data.
- `Current weight 70,0 kg` looked informational rather than clearly actionable.
- Empty Weight state consumed large card without explaining why logging helps.
- `History` described storage, not user outcome; `Progress` was clearer.

## Accepted implementation

Visible `History` was renamed `Progress` in tab and navigation title.

### Calories

- Use most recent seven recorded days.
- Put recorded-day average in prominent summary.
- State explicit relation between average and profile daily goal.
- Use orange bars, one goal rule, seven compact actual day labels, and no bar annotations.

### Weight

- Show current, change, and target text.
- Use latest fourteen raw readings with linear line and points.
- Use adaptive nonzero domain rather than forcing zero-based weight scale.
- Show target rule when valid target exists.
- Give empty Weight state useful copy and direct `Record weight` action.

### Recording behavior

- Record/update sheet uses `Cancel` and `Save`.
- Wheel values and header use locale-consistent formatting.
- Only successful Save dismisses sheet; save failure rolls back context and keeps draft visible.

### Domain rules

- Calorie and weight inputs filter invalid values, sort chronologically, and enforce seven/fourteen item limits.
- Duplicate weight timestamps remain; no value tie-breaker removes or reorders them.
- Averages convert to `Double` before summing to avoid integer overflow/rounding behavior.

## Attempts

### Attempt 01 — rejected

Retained screenshot: `../screenshots/HISTORY-001/attempt-01-calories.png`.

Rejected for weak one-line gray summary, overlapping full month-day labels, and stale parent-computed sheet header. Retain screenshot as rejected evidence; do not treat it as accepted design.

### Attempt 02 — accepted

Deterministic iPhone 17 Pro preview evidence:

- `../screenshots/HISTORY-001/attempt-02-calories.png`
- `../screenshots/WEIGHT-001/attempt-02-populated.png`
- `../screenshots/WEIGHT-001/attempt-02-empty.png`
- `../screenshots/WEIGHT-001/attempt-02-editor.png`

Attempt 02 corrected summary hierarchy, compact actual-day labels, locale/header behavior, and recording affordance. `HISTORY-001`, `PROGRESS-001`, and `WEIGHT-001` analytics are **ACCEPTED — attempt 02**.

## Evidence and validation

- `ProgressHistoryTests`: 16 pass.
- Aggregate: 106 pass / 2 opt-in skips.
- `just check` passed.
- Diagnostic Progress weight UI test added.
- Label/locale test defects corrected.
- Fresh Banana diagnosis passed `100 g / 1 / 89 kcal` with keyboard hidden.
- Final `just test-ui 300` timed out before XCTest and reset simulator. UI suite is not green.

## Next work

Separate user-requested feature: research possible navigation split among calorie tracker, weight recording, and analytics. Do not pre-decide or design that split in this milestone.
