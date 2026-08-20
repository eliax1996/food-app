# REFINE-001 Slice C — calculated plan specification

Specification date: 2026-08-10

## User problem

Count Calories preserves a manual calorie goal but cannot explain how someone might choose one. Slice C adds an optional, inspectable starting estimate without interrupting existing users, inventing missing body inputs, or turning a target date into an unsafe calorie target.

## Supported population

Automated calculation is limited to people who meet every condition below:

- age 19–78, matching ages represented in the original Mifflin–St Jeor derivation sample;
- not pregnant or breastfeeding;
- not using a clinician-prescribed calorie target or requiring clinical nutrition care;
- current BMI at least 18.5; any lose/maintain target must also remain at least 18.5;
- willing to select one of the equation’s published female or male constants.

The calculator is an estimate for generally healthy adults, not diagnosis or treatment. Anyone outside scope keeps or enters a manual goal. High BMI alone does not block calculation because the derivation included normal-weight and obese adults. No UI calls BMI a personal ideal.

Technical input-integrity bounds are age 19–78, weight 20–500 kg, and height 100–250 cm. These broad bounds prevent malformed/nonfinite arithmetic; they are not claims that every combination was represented in the derivation sample. Results outside Count Calories’ 1,000–5,000 kcal product domain are unsupported rather than clamped or silently changed.

## Sources and interpretation

- Mifflin et al., [A new predictive equation for resting energy expenditure in healthy individuals](https://pubmed.ncbi.nlm.nih.gov/2305711/): 498 healthy female/male subjects, ages 19–78; published weight/height/age equations; `R² = 0.71`.
- NIDDK, [Body Weight Planner](https://www.niddk.nih.gov/bwp): adult-only; excludes pregnancy/breastfeeding; identifies goals below 1,000 kcal/day as unable to meet food-group and nutrient recommendations; recommends more time, activity change, or a different goal instead of retaining an extreme date.
- CDC, [Steps for Losing Weight](https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html): gradual loss around 1–2 lb/week is more likely to be maintained; unrealistic goals can be discouraging.
- MyFitnessPal, [Initial goals](https://support.myfitnesspal.com/hc/en-us/articles/360032625391-How-does-MyFitnessPal-calculate-my-initial-goals): category convention separates maintenance estimate, rate adjustment, and goal weight; goal weight does not force initial calories.
- Yazio, [Calorie calculation](https://help.yazio.com/hc/en-us/articles/4410156873233-How-does-Yazio-calculate-my-calorie-goal) and [activity examples](https://help.yazio.com/hc/en-us/articles/360005363638-Which-activity-level-should-I-choose): currently publishes Mifflin–St Jeor, four routine-based activity factors, and moderate adjustment semantics.
- NIDDK’s dynamic planner demonstrates that body-weight change is not truly linear. Slice C’s date is therefore labeled a rough planning forecast, never a promise.

Competitor multipliers and static energy conversion are category conventions, not equivalent to validation of Mifflin–St Jeor itself. UI exposes both and preserves manual control.

## Required inputs

1. **Goal mode:** Lose, Maintain, or Gain.
2. **Current weight:** canonical kilograms; entered as kg or lb.
3. **Target weight:** required for Lose/Gain; Maintain uses current weight.
4. **Age:** whole years.
5. **Height:** canonical centimeters; entered as cm or ft/in.
6. **Equation constant:** explicitly named `Female equation (−161)` or `Male equation (+5)`. This is not labeled gender identity. Copy explains the published equation has only these constants and manual mode remains available.
7. **Daily routine:** one of four concrete work/day patterns. Planned workouts are excluded to avoid double counting.
8. **Pace basis:** preferred weekly rate or desired target date for Lose/Gain.
9. **Preferred display units:** metric or US customary. Changing display units must preserve canonical values within display-roundtrip tolerance.
10. **Eligibility acknowledgment:** direct confirmation that supported-population scope fits. This is not consent to medical treatment.

Sensitive-input explanations appear before use. No value is inferred from device data, name, gender identity, or target.

## Calculation

### Resting estimate

For weight `W` in kilograms, height `H` in centimeters, and age `A`:

```text
female equation: RMR = 10W + 6.25H − 5A − 161
male equation:   RMR = 10W + 6.25H − 5A + 5
```

Keep full `Double` precision. Reject nonfinite or nonpositive results.

### Daily-routine estimate

```text
Low       1.25  mostly sitting, such as desk work
Moderate  1.38  much of day standing, such as teaching or retail
High      1.52  much of day walking, such as delivery or floor work
Very high 1.65  sustained manual labor
maintenance = RMR × selected factor
```

Routine excludes separately logged workouts and tracker calories. Count Calories does not add exercise-calorie credits; that direction is explicitly rejected from current scope because no trusted activity source/contract exists.

### Pace and adjustment

Preferred rates are 0.25 or 0.50 kg/week. Desired-date mode derives:

```text
weeks = positive local-calendar days to target ÷ 7
required rate = abs(target − current) ÷ weeks
```

Dates are local-calendar days, not fixed 24-hour intervals. A date is infeasible when it is not future, produces a rate above 0.50 kg/week, or would generate a result outside calorie bounds. Earliest feasible date uses `ceil(abs(target − current) ÷ 0.50 × 7)` local-calendar days.

Initial energy adjustment uses a transparent static planning approximation:

```text
daily adjustment = weekly kg × 7,700 kcal/kg ÷ 7 days
Lose: goal = maintenance − adjustment
Gain: goal = maintenance + adjustment
Maintain: goal = maintenance
```

This conversion supports an initial estimate only. It does not predict dynamic physiology. The breakdown names the approximation.

### Bounds and rounding

- Never return a recommendation below 1,000 kcal/day.
- Never return a recommendation above 5,000 kcal/day; this is Count Calories’ product input domain, not a medical upper limit.
- Never clamp an infeasible result to a bound. Return a typed issue and preserve manual goal.
- Round a valid final recommendation to nearest 10 kcal using ordinary half-away-from-zero behavior; display unrounded component estimates rounded to whole kcal.
- Rounding must not move a pre-boundary-invalid result into validity.
- All finite/domain/relationship checks run before date or calorie math.

Goal relationships must agree: Lose target < current, Gain target > current, Maintain target = current. No recommendation is emitted for a contradictory draft.

## Setup state machine and migration

```text
new install with no UserProfile + no setup marker
  → present Welcome
      ├─ Keep manual → create/preserve default manual profile; status Skipped
      └─ Continue → In progress; persist canonical draft + current step
            ├─ Cancel → retain draft/status; app remains usable
            ├─ unsupported/infeasible → explain recovery; no profile goal mutation
            └─ Use calculated goal → one explicit SwiftData save; status Completed

existing UserProfile + no setup marker
  → migrate marker to Legacy manual; never auto-present; preserve goal byte-for-value

Settings/Plan
  → Start or Resume setup with existing/profile draft preselected
```

UI tests and design-review fixtures use explicit launch state; production migration rules remain unchanged.

Persisted profile metadata after explicit acceptance:

- source = Calculated;
- equation, activity, goal mode, height, pace basis/rate, last calculated recommendation, and calculation components;
- canonical current/target weights, age, target/forecast date, and selected display units.

Manual Plan edit changes source to Manual but retains last valid calculated recommendation and inputs. `Restore calculated goal` is explicit and restores the retained recommendation; it never recalculates from changed weight in the background. Redo setup recalculates from visible values.

Existing profiles migrate with source Manual and no fabricated calculation metadata. Existing `dailyCalorieGoal`, age, weights, target, and date remain unchanged.

## Native setup hierarchy

- Welcome/scope.
- Goal.
- Body details and units.
- Equation input.
- Daily routine.
- Pace/date.
- Review and transparent breakdown.

Each screen has one purpose, native navigation title, Back/Cancel or Continue, 44-point controls, inline validation, Dynamic Type, dark mode, and keyboard Done. Review offers `Use calculated goal` and `Keep manual goal`; neither wording implies medical approval. Swipe dismissal is disabled while setup has an unsaved draft.

## Privacy

All inputs, draft state, and calculations stay on device. No HealthKit request, account, analytics upload, or network request is added. Equation constant is stored only to reproduce the breakdown; app does not label it gender identity.

## Deterministic acceptance

1. Both published Mifflin–St Jeor equations match known vectors.
2. Every activity factor, goal mode, unit conversion, relationship rule, bound, rounding edge, nonfinite input, age scope, BMI floor, rate, and date path has hostless coverage.
3. DST transition and non-Gregorian/local-calendar date operations remain finite and future-only.
4. Existing profile migration preserves manual goal exactly and suppresses automatic setup.
5. New-install Skip, resume, infeasible recovery, calculated acceptance, manual override, and restore paths have deterministic state/UI coverage.
6. No numeric keyboard lacks Done; Done never commits setup.
7. Plan shows Manual or Calculated truthfully and exposes calculation breakdown only when real metadata exists.
8. Normal, dark, Accessibility Dynamic Type, small-device, unsupported, and infeasible states receive rendered review.
9. Exact-tree `just validate`, focused tests, app-hosted tests, and final functional UI suite pass before acceptance.

## Implementation result

REFINE-001 attempt 02 accepted Slice C on 2026-08-11. Optional setup ships with explicit supported-scope acknowledgment, no default height/equation/routine assumption, metric/US entry, exact rate or target-date paths, typed unsafe/infeasible recovery, transparent review, persisted resume, Manual migration, explicit calculated acceptance, manual override, and restore.

Independent code review blockers covering acceptance reconciliation, stale restore context, arbitrary rates, fixed-second dates, rationale order, nonfinite dates, and boundary coverage were fixed; final review approved. Accepted normal, infeasible, AX3-dark, Manual Plan, and Calculated Plan evidence is indexed under `design-redesign/screenshots/REFINE-001/`.

Final gates: 178 hostless pass / 2 live skips, 210 app-hosted pass / 2 live skips, exact-tree simulator validation passed, and functional UI passed 22/22. User-requested direct Settings entry is accepted separately as SETTINGS-DIRECT-EDIT-001.
