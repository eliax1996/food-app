# [HISTORY-001] Progress and weight

## Baseline

Screenshots:

- `../screenshots/baseline/history-calories.png`
- `../screenshots/baseline/history-weight-empty.png`

Problems:

- Raw calorie bars lack target rule, average, adherence, or period context.
- Every value/date is annotated; fourteen days will become noisy.
- Weight reuses calorie histogram language despite being continuous trend data.
- `Current weight 70,0 kg` looks informational rather than clearly actionable.
- Empty Weight state consumes large card without explaining why logging helps.
- `History` describes storage, not user outcome; `Progress` is clearer.

Competitive evidence:

- Foodnoms Insights shows weight trend, macro adherence, calorie balance, and streak as interpreted outcomes.
- Cronometer places nutrient values against explicit targets.
- Category convention: history earns its place by explaining trend/goal relationship, not merely replaying records.

Native direction:

- Retain segmented metric switcher.
- Calories: seven-day bars plus profile-goal `RuleMark`, period average, and concise target context.
- Weight: line/point chart with current value, change over period, and target rule.
- Make Record Weight an explicit labeled action.
- Use native Chart, List, semantic colors, and adaptive labels; avoid dashboard-card mosaic.

Success criteria:

- User understands direction and goal relationship in under three seconds.
- Axis labels remain readable with seven/fourteen days.
- Empty state offers clear Record Weight action.
- Weight chart never starts at zero merely because calorie bars do.
- Large values, negative/positive change, and Dynamic Type do not clip.

Status: baseline only; implementation blocked until required Earth subagent quota is available.
