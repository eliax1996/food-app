# REFINE-001 Slice D — evidence-gated calorie-plan adaptation specification

Specification date: 2026-08-11

## User problem

A calculated starting goal is still an estimate. Repeated food logs and weight measurements can reveal that observed energy balance differs from that estimate, but one scale reading, an unmarked partial food day, or a short plateau cannot identify why. Slice D may offer a small, inspectable goal proposal only after sustained evidence. It never diagnoses a cause, silently changes calories, rewrites raw logs, or turns missing data into zero.

## Scope and non-scope

Slice D supports an active Calculated or previously user-accepted Adapted plan from Slice C. Manual goals never become adaptive automatically. A person may keep Manual, disable check-ins, decline any proposal, edit manually, restore the saved calculated plan, or revert the latest applied proposal.

In scope:

- explicit on-device food-log completeness;
- deterministic weight-trend and observed-maintenance estimates;
- visible evidence readiness and disagreement states;
- no-more-than-weekly, small, user-confirmed proposals;
- exact apply/revert provenance and future-only goal revisions.

Out of scope:

- diagnosis, treatment, metabolic testing, body-composition inference, or claims about why a trend changed;
- HealthKit, wearable activity calories, exercise-calorie credits, server analysis, accounts, or analytics upload;
- automatic edits, catch-up reductions for a target date, retrospective meal/weight changes, or inferred complete days;
- children, pregnancy/breastfeeding, clinician-directed nutrition care, BMI below Slice C scope, or any unsupported calculated-plan population.

## Retained evidence and interpretation

Official pages were accessed 2026-08-11:

- MacroFactor, [weight logging frequency](https://help.macrofactorapp.com/en/articles/109-how-frequently-do-i-need-to-log-my-weight-for-the-expenditure-algorithm-and-weekly-coaching-updates): once weekly is described as a practical minimum and daily as preferable.
- MacroFactor, [nutrition logging frequency](https://help.macrofactorapp.com/en/articles/110-how-frequently-do-i-need-to-log-my-nutrition-for-the-expenditure-algorithm-and-weekly-coaching-updates): at least four days in each seven-day period, ideally daily; updates should hold instead of using insufficient data.
- MacroFactor, [partially logged days](https://help.macrofactorapp.com/en/articles/29-how-do-macrofactor-s-coaching-algorithms-deal-with-partially-logged-days): partial days can materially distort expenditure estimates and should be identified or excluded rather than treated as complete.
- MacroFactor, [weekly adjustment behavior](https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal): updates use logged intake plus trended weight, require approval at weekly check-in, smooth short-term changes, and may hold while evidence is insufficient.
- Foodnoms, [Calibrated Energy](https://foodnoms.com/help/calibrated-energy): publishes the intake-minus-weight-trend energy-balance formula, 7,700 kcal/kg approximation, 28/35/42-day corroboration, seven-day smoothing, at least 14 food-log days in 28, recent distributed weigh-ins, roughly 75-kcal noise range, weekly review, and proposal-only application.
- Sanghvi et al., [Validation of an inexpensive and accurate mathematical method to measure long-term changes in free-living energy intake](https://pubmed.ncbi.nlm.nih.gov/26040640/): retained as research support for estimating long-term energy balance from repeated body-weight observations; it does not validate Count Calories’ exact implementation or thresholds.
- Slice C sources and supported-population rules remain in `calculated-plan-specification.md`.

Competitor implementations are category evidence, not independent validation of Count Calories. Exact thresholds below are deliberately conservative product choices unless a source is named.

## Explicit evidence model

### Complete food-log day

Meal presence does not prove a complete day. A day enters adaptation only when the user explicitly marks its food log complete. Completion means “I am done logging this day,” not “this intake is nutritionally accurate.”

Persist one completion record per civil day with:

- stable ID;
- local day components, calendar identifier, and time-zone identifier;
- attested timestamp;
- nonnegative calorie total captured at attestation;
- deterministic snapshot of every included `PlateEntry` stable ID, exact timestamp bit pattern, and calorie value;
- evidence-schema version and canonical snapshot revision.

Rules:

1. Blank days stay missing, never zero. A user may explicitly attest a genuine zero-intake day.
2. Existing historical days are never auto-attested. A person may mark only today or yesterday, limiting recall-based reconstruction.
3. Adding/deleting an entry or changing an adaptation-relevant calorie/timestamp after attestation makes affected source/destination completion records stale. Stale days are excluded until explicitly reconfirmed. Name or nutrient edits that preserve calories and timestamp do not alter this energy-balance evidence.
4. Current day is always excluded from analysis even if marked complete; it first becomes eligible after the next local day begins.
5. Invalid, negative, nonfinite, or overflowing daily totals fail closed.
6. Raw food entries remain unchanged.

`PlateEntry` therefore needs a migration-safe stable UUID plus creation/mutation metadata for audit. Before adaptation can be enabled, one staged migration scans every Plate and Weight row, preserves every valid ID, assigns fresh IDs only where identity is missing, and then refetches to verify uniqueness without changing weight sequence/order. Any collision, failed backfill, or unstable refetch pauses adaptation; existing colliding IDs are never silently rewritten. Snapshot comparison, not a process-random hash, determines staleness across launches.

### Weight evidence

Raw `WeightEntry` records remain authoritative and untouched. Analysis:

- ignores future, nonfinite, nonpositive, below-20 kg, or above-500 kg values;
- groups by local civil day and uses the median when multiple valid readings share a day, so extra same-day readings do not gain extra influence;
- snapshots stable ID, sequence, exact date bit pattern, and exact kilogram bit pattern so every adaptation-relevant edit/delete is detectable;
- never silently deletes an outlier. Implausible estimates or disagreement produce a hold state and ask the user to review measurements.

### Evidence epoch

An epoch captures one accepted calculated basis/target/pace context, calendar identifier, time zone, algorithm version, starting goal/source, adaptive revisions within that basis, and start instant. Evidence before the epoch cannot generate a proposal.

Start a new epoch when the user:

- enables adaptive check-ins;
- accepts/redoes/restores a calculated plan;
- manually edits calories, target, rate, or date;
- reverts an applied proposal;
- changes calendar or time zone used by the epoch;
- disables and later re-enables check-ins;
- encounters an incompatible evidence/algorithm migration.

Starting an epoch never deletes raw logs, completion history, proposal history, or the saved Slice C calculation. It prevents different manual/calculated bases or calendars from being presented as one observation period. Applying an adaptive step deliberately appends a revision inside the same epoch: observed maintenance uses complete actual intake rather than the goal, while target, pace, scope, and calculated basis stay unchanged. Weekly fresh-evidence and corroboration rules evaluate behavior after each step. Manual edit, redo, restore, target/pace change, or revert starts a new epoch.

## Readiness thresholds

Analysis uses six consecutive seven-local-day blocks ending yesterday: 42 calendar days total. This six-week first-proposal wait is a conservative Count Calories choice intended to avoid reacting to a short plateau.

Every one of the 42 civil days must have an explicitly complete, nonstale food log. Count Calories does not average a selected subset and assume it represents missing days; users may enter a reviewed estimate for an unusual day, but the app never imputes it. This all-days requirement is stricter than Foodnoms’ 14-of-28 minimum and MacroFactor’s four-of-seven operating guidance because this first implementation has no validated missing-intake model.

Across the full epoch window require:

- at least eight distinct weigh-in days and at least six in the newest 28 days;
- at least one valid weigh-in in each seven-day block;
- for each nominal 28/35/42-day window, a valid weigh-in within its first three civil days;
- a common final valid weigh-in within the final three civil days;
- no gap between consecutive weigh-in days greater than ten calendar days.

Missing a threshold yields an exact collection status, never an estimate based on filled-in intake.

The UI reports counts and dates, not a statistical “confidence percentage.” User-facing states are:

- **Off** — check-ins not enabled;
- **Collecting** — exact food/weight/window requirements still missing;
- **Check data** — enough counts, but windows disagree, evidence changed, or an estimate is unsupported;
- **Up to date** — evidence agrees and difference is within the noise range;
- **Proposal ready** — one persisted, unapplied proposal;
- **Applied** — latest proposal accepted, with exact revert available while its revision remains current;
- **Paused** — Manual source, changed scope, target reached, unsupported BMI/calories, calendar/time-zone change, or incompatible data.

## Deterministic trend method

For each nominal trailing window of 28, 35, and 42 local-calendar days ending yesterday:

1. Build one median weight per valid weigh-in day.
2. Select the first actual weigh-in day within the nominal window’s first three days and the last actual weigh-in day within its final three days. That closed civil-day range is the window’s exact trend-supported interval.
3. Piecewise-linearly interpolate between every pair of consecutive actual daily-median weigh-ins inside those boundaries. Every interior measurement remains a knot; never replace the interval with one boundary-to-boundary line and never extrapolate.
4. Compute centered seven-day arithmetic means only where all seven interpolated civil-day values exist.
5. Fit an ordinary least-squares line to smoothed kilograms versus integer local-calendar day index.
6. The fitted slope is kilograms per day. Reject insufficient points, zero day variance, overflow, and every nonfinite intermediate.
7. Average calories across every civil day in that exact first-to-last measurement interval. Every day must have a complete, nonstale attestation; intake and weight periods can never differ.

For each window `W`:

```text
mean logged intake W = sum(calories on every trend-supported day) / trend-supported day count
weight energy W       = fitted kilograms/day × 7,700 kcal/kg
observed maintenance W = mean logged intake W − weight energy W
```

A negative weight slope therefore raises estimated maintenance above logged intake; a positive slope lowers it. The 7,700 value remains a static planning approximation, not a dynamic physiology model.

### Corroboration

All three estimates must be finite and between 800 and 6,000 kcal/day. The 28-day estimate is usable only when:

- maximum minus minimum of 28/35/42 estimates is at most 100 kcal/day; and
- all three weight slopes have the same direction when “stable” means an absolute trend below 0.05 kg/week.

The 100-kcal agreement and 0.05-kg/week direction thresholds are conservative product choices. Disagreement does not select whichever window produces the preferred outcome; it yields **Check data**. The UI names possible measurement noise, incomplete/inconsistent logging, and expenditure uncertainty without asserting any one cause.

## Proposal calculation

Only an active Calculated/Adapted plan with intact `StoredCalculatedPlan` metadata is eligible. Preserve the accepted Slice C pace adjustment; do not derive a new pace from recent weight or target date.

```text
accepted pace adjustment = exact persisted `StoredCalculatedPlan.plan.dailyAdjustmentCalories`

Lose candidate    = observed maintenance 28 − accepted pace adjustment
Maintain candidate = observed maintenance 28
Gain candidate    = observed maintenance 28 + accepted pace adjustment

raw difference = unrounded candidate − current daily goal
```

Rules, in order:

1. Revalidate Slice C supported-population inputs and latest valid weight. Current and target BMI must remain at least 18.5. If scope changed or cannot be confirmed, pause.
2. Stop goal-mode proposals when latest weight has reached/passed Lose or Gain target. Offer plan review; do not switch to Maintain silently.
3. Validate unrounded observed maintenance at 800–6,000 and full candidate at Count Calories’ 1,000–5,000 product bounds. Never clamp an unsupported estimate.
4. If `abs(raw difference) <= 75 kcal/day`, emit **Up to date**, not a proposal. This uses Foodnoms’ published approximate noise range as a conservative product deadband.
5. If `abs(raw difference) > 400 kcal/day`, emit **Check data**. Count Calories does not expose or step toward a discrepancy this large without a new reviewed setup/evidence period.
6. Otherwise propose at most 100 kcal/day toward the candidate. Round the signed step to nearest 10 kcal using ordinary half-away-from-zero behavior.
7. Validate resulting goal again at 1,000–5,000 before proposal creation.
8. Sum absolute accepted adaptive steps in trailing 28 local days. A new step may not take that sum above 200 kcal/day; pause until enough time passes rather than silently shrinking below an explained step.

The ±100 per proposal and 200-per-28-days cumulative bounds are conservative Count Calories product choices, intentionally smaller than Foodnoms’ published 400-kcal calibration cap.

Proposal review shows:

- current goal and source;
- 28/35/42 observed-maintenance estimates;
- complete-day count and weigh-in count/span;
- observed weight trend in kg/week or lb/week;
- retained desired pace adjustment;
- full candidate, deadband/cap decisions, exact proposed step, and resulting goal;
- evidence dates and creation/expiry date;
- limitations and neutral alternative explanations;
- `Use … kcal`, `Decline this check-in`, and nonmutating Close actions.

No color is the sole carrier of direction or readiness.

## Cadence, staleness, and lifecycle

A new evaluation can create at most one pending proposal and no more than once every seven local-calendar days. After any accepted or declined check-in, another proposal requires:

- seven local days elapsed;
- at least seven newly complete civil food days whose day keys are strictly after the decision’s effective day; and
- at least one valid weigh-in civil day strictly after that decision day.

Backdated insertion/attestation timestamps do not satisfy fresh-evidence requirements; evidence civil dates do. Creation and mutation timestamps remain audit/staleness metadata.

A pending proposal expires after seven local days. Its evidence signature covers every Plate entry, completion record, and Weight entry from epoch start through proposal creation—not only rows selected by the estimator—plus latest valid weight and target/scope inputs. Any added, deleted, or adaptation-relevant changed evidence through apply time invalidates the signature. Apply always recomputes the signature and latest-weight target/BMI checks, so a new reading can never be ignored because it was absent from the original snapshot. Plan revision, calendar/time zone, supported scope, or algorithm-version changes also stale it. Close leaves it pending. Decline records the signature so identical evidence cannot regenerate the same proposal.

State transitions:

```text
collecting/check-data/up-to-date
  → pending
      ├─ close → pending
      ├─ decline → declined
      ├─ evidence/plan/version change → superseded
      ├─ seven local days → expired
      └─ explicit apply → applied
                            └─ exact revert while applied revision is current → reverted
```

Generation, apply, decline, and revert are idempotent. Stable operation keys are deterministic and persisted: generation uses epoch ID + full evidence signature + algorithm version; apply/decline use proposal ID + action; revert uses applied revision ID + action. A retry or repeated tap reuses that key, and the coordinator returns the recorded result instead of creating another event, including after relaunch.

## Plan revisions, apply, and revert

Manual/Calculated alone cannot truthfully describe an applied adaptive goal. Add source **Adapted** and retain the original stored calculated basis unchanged. Raw source decoding must also represent **Unknown** explicitly; unknown/future/corrupt values preserve calories, pause adaptation, and display “Unknown source”—they never fall back to or display Manual.

Persist immutable goal revisions/events with unique stable IDs, effective local day/instant, monotonic sequence, calories, source, reason, plan/evidence epoch, and prior revision. Existing profiles receive one migration revision at first Slice D use; no past goal history is fabricated.

All stable-identity backfill plus writes to completion/attestation records, adaptation-relevant Plate calories/dates, Weight kilograms/dates, calorie goal, source, target context, calculated basis, epoch, proposal, or revision route through one serialized `PlanEvidenceMutationCoordinator` backed by a dedicated model actor/context. Replace direct field writes and the current standalone calculated/manual/restore mutators; relevant setters are not accessible to views. Every identity/completion/food/weight mutation increments a persisted evidence revision in the same save. Stable Plate/Weight IDs become immutable after successful migration.

Proposal generation enters that same actor with an expected plan revision and evidence revision, computes from a fresh dedicated-context fetch, recomputes the full evidence signature immediately before commit, and creates nothing if either revision/signature changed. Apply repeats those compare-and-set checks. Stable operation keys, expected current revision/proposal IDs, and unique constraints on new operation/revision IDs prevent duplicates; the dedicated context keeps unrelated dirty models out of the save and rolls back on failure.

Applying a proposal is one coordinator transaction that:

1. verifies proposal is still pending/current;
2. saves exact pre-apply profile/goal source snapshot;
3. appends Adapted goal revision and proposal decision;
4. changes only current/future `dailyCalorieGoal` and source;
5. leaves target, raw food logs, raw weight logs, and `calculatedPlanData` unchanged.

Failure rolls back the dedicated context and leaves old goal and pending proposal intact with a visible retryable error.

Goal changes take effect immediately for the current civil day in the epoch’s calendar/time zone, never for an earlier civil day. Revisions persist that day’s start plus acceptance instant and monotonic sequence; highest sequence wins when apply/revert/manual actions share a day. Historical comparison therefore treats the latest accepted same-day revision as that whole day’s goal and explains this current-day behavior before confirmation.

Revert is available only while the applied revision remains current. It restores the exact saved pre-apply calories/source, appends a revert event, supersedes pending analysis, and starts a new evidence epoch. A later manual edit, calculated redo/restore, or subsequent accepted adaptation prevents an older revert from overwriting newer intent. `Restore calculated plan` remains a separate explicit route back to the original stored Slice C recommendation.

Historical goal comparisons use the highest-sequence revision effective for each day when available. Days before migration revision must be labeled as lacking historical goal context rather than compared to a fabricated value.

## Native hierarchy and interaction

- Plan adds **Goal check-ins** with current status and one navigation row.
- Enabling check-ins is explicit and explains the six-week evidence requirement before starting an epoch.
- Today exposes compact `Food log: In progress / Complete / Needs review` status. Mark Complete is a 44-point button; editing that day reopens it automatically.
- Check-in detail prioritizes status, exact missing evidence, and next eligible date. Formula/method and included-day review use progressive disclosure.
- Proposal review is a focused explicit transaction. Swipe dismissal never applies.
- Dynamic Type, dark mode, small devices, VoiceOver reading order, Reduce Motion, localized units, and non-Gregorian calendars remain supported.
- VoiceOver announces proposal direction, old/new values, evidence counts/dates, state, and consequences without relying on arrows or color.

## Privacy and wording

All attestations, weights, revisions, estimates, and proposals remain on device. No new permission or network request is added. Do not log profile, intake, or weight values to diagnostics.

Use “observed estimate,” “evidence agrees,” “check data,” and “proposal.” Avoid “metabolism changed,” “you failed,” “true expenditure,” “accurate logging,” “plateau proves,” or any claim that one cause is known.

Standard limitation copy:

> Food logs and scale weight can vary. This estimate cannot tell whether a difference comes from measurement noise, logging gaps, routine changes, or energy-needs uncertainty. It is general planning information, not medical advice.

## Migration and fail-closed behavior

- Existing profiles retain calorie goal, raw source, target, calculated basis, food logs, and weight order byte-for-value.
- Before opt-in, staged identity validation backfills missing identity in either entity, then refetches and verifies all Plate/Weight IDs are unique. Valid IDs and every Weight sequence remain unchanged. Any collision, save error, or unstable refetch pauses adaptation rather than rewriting evidence.
- Existing days begin unattested. No adaptive opt-in, epoch, estimate, proposal, or history is fabricated.
- New model fields use explicit compatibility defaults, but defaults alone never count as completed identity migration.
- Unknown source or corrupt adaptation/evidence payloads disable proposals, preserve current goal, and never relabel it Manual.
- Algorithm-version changes supersede pending proposals and require a new compatible evaluation.
- Test/design-review stores remain DEBUG-only and isolated from standard production defaults.

## Deterministic acceptance

### Hostless domain

1. Local-calendar 28/35/42 windows cover DST, leap day, non-Gregorian calendar, future records, and invalid/nonfinite dates without fixed-second arithmetic.
2. Complete, missing, zero-intake, stale, reconfirmed, added, edited, deleted, and moved food-day snapshots behave exactly; missing never becomes zero.
3. Same-day median weights, interpolation, seven-day smoothing, OLS slope, estimate signs, and 7,700 formula match published vectors.
4. All-42-day food coverage, every weight count/boundary/span/gap, exact coincident intake/trend interval, agreement, direction, deadband, 400 discrepancy, 100 step, 200 cumulative cap, calorie/BMI bound, and rounding edge have coverage.
5. Lose/Maintain/Gain preserve accepted pace semantics; target reached and unsupported scope produce no proposal.
6. Cadence, fresh-evidence requirements, expiry, decline signature, data edits, plan changes, and algorithm changes are deterministic and idempotent.

### Persistence/app-hosted

7. Existing-store migration fabricates no completion/proposal/history, backfills missing Plate or Weight identity through the coordinator, makes migrated IDs immutable, detects collisions, and preserves stable weight ordering and plan values.
8. Completion snapshots, full evidence signatures, epochs, revisions/sequences, proposals, decisions, and exact pre-apply snapshots round-trip.
9. Serialized compare-and-set apply/revert are atomic across failure, relaunch, repeated taps, and overlapping tasks. Same-day precedence is deterministic; newer user intent blocks stale revert.
10. Manual edit, calculated redo/restore, entry edit/delete/date move, timezone change, and corrupt payload fail closed and supersede pending proposals.

### Functional/accessibility/visual

11. Marking a day complete never saves or changes food; later edit visibly returns it to Needs review.
12. Collecting/check-data states expose exact requirements and never show a calorie proposal.
13. Proposal Close and Decline preserve current goal. Apply requires explicit confirmation; relaunch shows Adapted source; Revert restores exact prior value.
14. Manual goals never show an adaptive proposal. No UI implies delivery, diagnosis, certainty, or automatic change.
15. Normal, dark, Accessibility Dynamic Type, small-device, collecting, disagreement, proposal, applied, and stale states receive durable screenshot review.
16. Exact-tree validation, focused hostless/app-hosted tests, and full functional UI suite pass before Slice D acceptance.

## Implementation result

REFINE-001 attempt 03 implemented and accepted Slice D. Identity migration, complete-day attestation, 28/35/42-day evidence, proposal generation, apply/decline/disable, Adapted source, retained goal revisions, exact revert, compare-and-set serialization, failure rollback, UI states, and durable evidence passed deterministic/app-hosted/functional/visual review. BACKLOG-CLOSURE-001 later upgraded food attestations to full logged-snapshot schema 2 for historical mutations without weakening fail-closed behavior. No adaptive-plan item remains open.
