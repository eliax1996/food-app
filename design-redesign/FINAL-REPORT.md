# Count Calories redesign — final report

**Status:** COMPLETE

**Closure milestone:** FINAL-001

**Post-closure milestone:** COMPETITOR-GAP-001

**Date:** 2026-08-18

## Outcome

Count Calories moved from functional but flat calorie logging to coherent native product centered on fast, truthful daily decisions:

```text
Today | Weight | Progress | Settings
```

Program meets redesign Definition of Done: primary journeys implemented and retained, normal and stress layouts inspected, safety and persistence boundaries hardened, independent critical/high review converged, final app-hosted/hostless/UI gates passed, and current documentation agrees.

## Baseline → final

| Area | Baseline | Final |
|---|---|---|
| Daily answer | Percentage and flat intake rows competed with tools | Remaining/over calories leads; eaten/goal, water, food-log evidence, nutrition, and four meal summaries follow |
| Food logging | Hidden/limited selection and keyboard-heavy correction | Search-first local/remote discovery, recents, scanner/manual fallback, exact fields, presets, and keyboard-free ±10/±1 |
| Multi-food meals | One item per flow | Typed or on-device dictated description → provisional editable verified rows → one atomic confirmation |
| Nutrition | Calories only | Immutable logged macro/fiber snapshots, explicit coverage, measured facts, and transparent adult references without opaque score |
| Weight/history | Sparse combined history | Dedicated Weight Log CRUD, separate target-aware calorie/weight Progress analytics, and read-only meal-grouped Food Diary detail for selected recorded calorie days |
| Plan | Manual goal fields | Optional explainable calculated plan, infeasible recovery, Manual/Calculated/Adapted provenance, proposal-only evidence-gated adaptation, exact revert |
| Reminders | Fixed/basic controls | Independent exact meal, water, daily/weekly weight intent; permission-aware scheduling and retryable errors |
| Auxiliary surfaces | Secondary consumed-calorie presentation | Goal-aware medium widget and explicit Live Activity matching Today hierarchy |
| Robustness | Normal-state layouts | Light/dark, normal/AX3, small/large, empty/dense/extreme fixtures and deterministic UI coverage |

Baseline evidence remains under [`screenshots/baseline/`](screenshots/baseline/). Final evidence is indexed in [`SCREENSHOTS.md`](SCREENSHOTS.md).

## Final representative evidence

![Final Today](screenshots/final/today-light.png)

![Final Log food](screenshots/final/log-food-light.png)

![Final bulk review](screenshots/final/bulk-review-light.png)

![Final Weight Log](screenshots/final/weight-log-populated-light.png)

![Final calorie progress](screenshots/final/progress-calories-light.png)

![Final Settings](screenshots/final/settings-light.png)

![Final Accessibility 3 dark Today](screenshots/final/today-ax3-dark.png)

Widget and Live Activity evidence:

![Final medium widget](screenshots/final/widget-medium-light.png)

![Final Live Activity](screenshots/final/live-activity-light.png)

## Primary journey proof

Final walkthrough and deterministic fixtures cover:

1. Today status, water, food-log evidence, Nutrition, meals, and root navigation.
2. Log food with default Almond Milk at 100 g / 15 kcal.
3. Bulk meal review with editable query, amount, source, and atomic total.
4. Empty/populated Weight Log and calorie/weight Progress.
5. Progress calorie selection → View Day → read-only meal-grouped Food Diary → adjacent recorded day.
6. Settings → Plan and Settings → Reminders.
7. Widget and explicit Live Activity.
8. Accessibility 3 dark Today and Food Diary reachability.

Default Almond Milk arithmetic is protected at domain and UI levels: one save changes Today by exactly **+15 kcal**.

## Post-closure competitor gap

Fresh category reassessment selected date-first historical food detail as clearest retained gap. COMPETITOR-GAP-001 adds **View Day** from a selected Progress calorie point into a native read-only diary with localized date, assessed calorie completeness, meal ordering, immutable logged snapshots, and previous/next recorded-day navigation. It does not mix food, water, and weight history or imply historical mutation/copy.

![Historical Food Diary](screenshots/COMPETITOR-GAP-001/attempt-01-diary-light.png)

![Historical Food Diary at Accessibility 3 in dark appearance](screenshots/COMPETITOR-GAP-001/attempt-01-diary-ax3-dark.png)

Research and contract: [`../docs/historical-calorie-diary-assessment.md`](../docs/historical-calorie-diary-assessment.md). Experiment: [`experiments/COMPETITOR-GAP-001.md`](experiments/COMPETITOR-GAP-001.md).

## Product and safety guarantees

Final closure hardening preserves these invariants:

- iOS 17 minimum remains supported; Foundation Models/Speech paths stay availability-gated with typed/manual fallbacks.
- Language model extracts provisional query/amount structure only. Selected food records own calories and nutrients.
- Food calories are bounded to 0...5,000 per item; nonfinite or unsupported serving math cannot save.
- Invalid legacy calories make Today, meals, history, widget, and Live Activity calorie state visibly incomplete rather than silently low.
- Bulk confirmation requires durable precommit state and one idempotent atomic transaction; no partial insertion.
- Persistent-store failure shows retry instead of deleting data or crashing.
- Reminder replacement is serialized, capacity-aware, rollback-capable, authorization-aware, and failure-visible.
- Missing nutrient facts stay unknown; incomplete or invalid energy suppresses guidance.
- Meal text/audio and learned corrections remain local and clearable; only derived search queries may reach Open Food Facts.

## Independent review

Three independent reviewers received identical neutral criteria and current final diff. They inspected only critical/high user-impact correctness, persistence, nutrition truthfulness, privacy, platform compatibility, reminder/widget/Live Activity, accessibility, and core journeys.

Final result:

```text
Reviewer 1: APPROVE
Reviewer 2: APPROVE
Reviewer 3: APPROVE
```

No unresolved critical/high design or engineering finding remains. Post-closure diary review independently converged at **APPROVE / APPROVE / APPROVE** under identical critical/high criteria.

## Final validation

Current exact-tree gates after COMPETITOR-GAP-001:

| Gate | Result |
|---|---|
| `just validate 300` | Passed: 228 hostless tests, 2 opt-in live skips; app + widget compile, install, launch passed |
| `just test-app-unit 600` | Passed: 315 tests, 2 opt-in live skips |
| `TEST_CASE_TIMEOUT=60 just test-ui 1800` | Passed: 47/47 functional UI tests |
| `git diff --check` | Passed |

Live Open Food Facts tests remain intentionally opt-in; deterministic mocked/cache/API-contract tests run in normal gates.

## Deferred, not blocked

No high-priority redesign work remains. Separate evidence-backed future opportunities:

- historical diary create/edit/delete/copy only after snapshot, attestation, destination, duplicate, confirmation, undo, and goal-history rules are specified;
- optional personal macro targets with distinct safety contract;
- HealthKit/account/cross-device consistency.

Rejected directions remain rejected: LLM-authored nutrition, silent bulk logging, cloud upload of full meal text, scanner-only entry, opaque scores, and reminder-window claims without stronger evidence.

## Evidence map

- Current status: [`STATUS.md`](STATUS.md)
- Visual index: [`SCREENSHOTS.md`](SCREENSHOTS.md)
- Design decisions: [`02-design-log.md`](02-design-log.md)
- Durable backlog: [`PRODUCT-BACKLOG.md`](PRODUCT-BACKLOG.md)
- Closure experiment: [`experiments/FINAL-001.md`](experiments/FINAL-001.md)
- Post-closure experiment: [`experiments/COMPETITOR-GAP-001.md`](experiments/COMPETITOR-GAP-001.md)
- Full completion plan: [`COMPLETION-PLAN.md`](COMPLETION-PLAN.md)

## Final decision

**Original autonomous Count Calories redesign and queued COMPETITOR-GAP-001 iteration are COMPLETE.**
