# Test, UI-journey, and observability production-readiness assessment

**Audit date:** 2026-08-20
**Status:** AUTOMATED CURRENT-RUNTIME GATE GREEN — PRODUCTION APPROVAL BLOCKED ON iOS 17 RUNNER / REMOTE ENFORCEMENT

## Decision

Count Calories had strong deterministic domain and persistence coverage plus unusually broad functional UI coverage, but prior green commands were not by themselves a production guard:

- `just test` ran hostless tests and compiled app only;
- `just validate` added simulator install/launch but omitted app-hosted and UI tests;
- UI tests used isolated in-memory data and did not prove any state survived process relaunch;
- widget/Live Activity/notification system boundaries had mostly model or visual evidence;
- production logs were concentrated in nutrition/cache paths and failures, with little mutation success/correlation evidence;
- many errors interpolated raw localized descriptions publicly.

This audit adds explicit production gate, high-value missing journeys, failure artifacts, and privacy-safe operational spans. It does **not** claim every possible state belongs in UI automation or every tap belongs in logs.

## Test-pyramid assessment

| Layer | What it protects | Current assessment |
|---|---|---|
| Hostless XCTest | Nutrition/API/cache contracts, calorie and amount math, history, diary eligibility, adaptive/calculated plans, reminders, ranking, targets, setup-store encoding | Strong, fast primary rule proof. |
| App-hosted XCTest | SwiftData transactions, rollback/idempotency, migration/backfill behavior, model compatibility, widget-water import, reminder replacement, external-surface snapshots, app-only observability categories | Strong current-schema integration proof. |
| Functional UI XCTest | Critical user journeys, sheet/navigation composition, persistence result, recovery states, confirmation/undo, keyboard, accessibility identifiers/values, AX layout reachability | Broad and behavior-focused after gaps below. |
| Release gate | Hostless + optimized Release-config app-hosted/full UI with test seams + signed production Release archive/app+widget/signature validation + App Store Connect IPA export + pure Release simulator build/install/launch plus post-bootstrap process-alive canary | Added as `just release-validate`; mandatory before production/distribution. |
| Physical/system smoke | Real camera, notification permission/delivery, Speech/Foundation Models, WidgetKit process, ActivityKit/Dynamic Island | Cannot be made fully deterministic in simulator XCTest; remains explicit release evidence where relevant. |
| Scheduled live API | Current Open Food Facts availability/schema | Opt-in only; must alert on drift but must not make deterministic release gate network-dependent. |

## Critical interaction-flow coverage

### Today and food

Covered:

- default Almond Milk save changes total by exactly +15 kcal;
- isolated file-backed store preserves meal and water across app terminate/relaunch;
- water add/remove result and persisted count;
- meal snapshot edit routing;
- amount adjustments, keyboard Done, unchanged servings;
- recent/frequent selection, cancel-without-log, remote result persistence;
- meal delete confirmation;
- genuine-zero completion, meal-induced Needs review, populated reconfirm back to Complete;
- incomplete calories remain truthful through shared accessibility contract.

### Scanner, barcode, and custom foods

Covered:

- deterministic scanner callback → verified fixture lookup → Log food → exact 189-kcal Today result;
- camera-denied recovery to manual barcode entry;
- scanner cancel preserves meal draft;
- barcode offline recovery and success;
- custom nutrient save and measured Daily Nutrition propagation.

Real camera image recognition remains physical-system evidence, not stable UI automation.

### Bulk describe/dictate

Covered:

- atomic multi-row commit and partial-failure blocking;
- durable draft choices, discard, fresh save, estimate acceptance;
- unavailable extraction manual/direct fallbacks;
- privacy/data controls;
- dictation denial, interruption, and resource backpressure;
- deterministic extraction/matching/ranking/learning/draft stores and batch rollback/idempotency.

Foundation Models and Speech framework runtime availability still needs compatible-device smoke; model output never owns nutrition.

### Weight, diary, and progress

Covered:

- latest-weight default, coarse/fine controls, keyboard Done;
- add/edit/backdate/same-day/delete/undo Weight lifecycle and Progress handoff;
- chart point inspection;
- diary access without complete trend;
- historical add/edit/copy/delete/undo/navigation;
- provenance, duplicate/future/stale-command/collision, exact raw undo, attestation, and retained-goal persistence rules.

### Settings, plans, targets, reminders

Covered:

- calculated setup skip, required inputs, pace/review/apply, resume;
- adaptive collecting/proposal/apply/partial cap/revert/decline/unknown/manual;
- personal-target save/clear and complete-coverage comparison;
- reminder editor separation and cancel isolation;
- denied notification access: Save preserves enabled breakfast intent, truthful denied state, and file-backed relaunch persistence;
- planner/manager tests cover exact times, DST, suppression, pending cap, generation ordering, add failure, and rollback.

Actual iOS notification prompt/delivery remains physical-system smoke.

### Widget and Live Activity

App and extension now compile one shared `WidgetDailySummary`/water-mutation core in hostless/app-hosted tests. App and widget water actions mutate same locked App Group summary first, then app imports by revision CAS; mismatched acknowledgment rereads/retries and app mirroring preserves newer pending revisions. Coverage protects bounds, revision overflow, legacy decode, summary projection, incomplete-calorie wording, import-only-when-pending, corrupt-payload intent failure plus app-truth rebuild, static `4 → widget 5 → app +1 = 6`, and newer-revision rejection. Widget intents throw on lock/encode failure instead of falsely reporting success. Release archive validates embedded extension.

External-surface parent span now waits for reminder and Live Activity child tasks, then records success/partial/cancelled. Widget water → Live Activity logs carry parent/child IDs. Remaining system-only proof: real WidgetKit rendering and ActivityKit presentation on supported device.

## UI-test quality

### Strengths

- Assertions target observable outcomes: calorie deltas, rows, persisted state, disabled/available actions, navigation destinations, saved values, confirmations, and undo.
- Stable accessibility identifiers are product accessibility contracts, not coordinate-only selectors.
- Async waits use predicates/expectations; arbitrary sleeps are avoided except bounded app-state handoffs.
- Fixtures isolate network, camera, microphone, Foundation Models, permissions, time-sensitive adaptive states, and persistent sessions.
- New file-backed UI mode uses session-isolated SwiftData URL and explicit first-launch reset; second launch preserves real file state.
- Every recorded UI failure now attaches screenshot, accessibility hierarchy, and bounded journey trace to `.xcresult`.
- Failed simulator tests also capture filtered app unified logs under derived-data diagnostics.

### Deliberate limits

UI tests should not duplicate every numeric/domain boundary. Invalid/nonfinite/overflow/calendar/CAS/migration rules belong in unit/app-hosted tests. Pixel contrast, exact Dynamic Type wrapping, WidgetKit/Dynamic Island rendering, real permissions, and live service behavior need visual/device/scheduled evidence. Performance remains separate from correctness.

## Operational logging contract

### What is logged

Every important state-changing or integration operation emits:

```text
operation_start
operation_success | operation_failure | operation_partial | operation_noop | operation_cancelled
```

Safe fields:

- fixed operation and source names;
- random operation ID;
- parent operation ID for Today → widget/reminders/Live Activity fan-out;
- stable error category;
- rollback/partial component;
- generation-independent safe counts, page, HTTP status, barcode/query length, cache bytes/entries.

Instrumented boundaries include:

- persistent-store open and setup draft persistence;
- meal/water/food-log mutations, custom/remote/barcode food save;
- bulk extraction, dictation, drafts, commit, learning cleanup;
- diary and weight add/edit/copy/delete/restore;
- profile, plan, personal targets, adaptive actions;
- reminder authorization/preferences/rescheduling/supersession;
- widget summary write/import/acknowledgment, corruption fail-closed intent, and app-truth rebuild;
- Today external-surface fan-out;
- Live Activity start/synchronize/stop;
- scanner start and nutrition/search/cache transport decisions.

Use:

```sh
just simulator-logs
```

Failed simulator tests automatically retain same subsystem logs.

### What is intentionally not logged

- meal descriptions or dictated text/audio;
- food names or search queries;
- full barcodes;
- calorie, water, macro, profile, target, or weight values;
- exact user dates/times;
- raw/localized error descriptions;
- navigation taps, Cancel without mutation, every field edit, renders, or hot-path updates.

Logging every tap or enough health data to replay full app state would be noisy and privacy-invasive. Correct goal: reconstruct **which mutation/integration was attempted, causal fan-out, outcome, failure class, and rollback**, then inspect persisted state with user consent if deeper diagnosis is needed.

## Remaining production risks and required evidence

1. **Prior-release store migration fixture:** current app-hosted tests reopen current-schema files and deeply test migration logic, but repository does not retain binary stores from every shipped historical schema. Before next schema-changing release, capture versioned sanitized store fixtures and open them with production container configuration.
2. **Minimum-OS runtime:** app, widget, app tests, and UI-test targets compile with iOS 17 deployment. Current local machine has only iOS 27 simulator. Workflow requires self-hosted `count-calories-ios17` runner and `IOS17_SIMULATOR_ID`; gate verifies selected runtime is actually iOS 17 before testing. Branch protection must require its check. Until runner/check exists and passes, minimum-runtime release proof is outstanding.
3. **WidgetKit/ActivityKit process behavior:** shared core tests + Release archive + retained visuals do not execute every system-hosted lifecycle. Run supported-device widget/Live Activity smoke for releases touching those surfaces.
4. **Notification delivery:** deterministic manager and denied-state UI tests cannot prove Focus/scheduled-summary/system delivery. Run permission/pending-request smoke when notification integration changes.
5. **Speech/Foundation Models/camera:** fixture tests prove app state machine and fallbacks; compatible-device smoke proves Apple framework runtime.
6. **Live Open Food Facts:** deterministic transport fixtures remain release authority. Run opt-in live contract on schedule and alert maintainers; do not make release correctness depend on network uptime.

## Production release rule

A production candidate is not approved by `just test` or `just validate` alone. Required local automated gate:

```sh
just release-validate
```

Pull requests to `main` and `v*` tags also have `.github/workflows/release-validation.yml`, targeting self-hosted iOS 17 runner and failing if selected simulator is not iOS 17. Repository owner must configure runner variable and require **Release validation** in branch protection; workflow file alone cannot enforce remote repository settings. Then run only relevant physical/system smoke from residual list above. Any code/build-affecting fix invalidates release result and requires rerun.

## Final validation

Current code/test artifact results on available iOS 27 simulator:

| Gate | Result |
|---|---|
| `just test-unit 600` | 254 executed — 252 passed / 2 opt-in live skips |
| `just test-app-unit 900` | 376 passed / 2 opt-in live skips |
| Release-config app-hosted phase | Passed under optimization with `RELEASE_VALIDATION` seam only; no `DEBUG` condition |
| Release-config functional UI | 55/55 passed |
| Signed production archive | App + embedded widget present; both signatures passed strict verification |
| Pure Release simulator | Built, installed, launched without test arguments, remained alive after bootstrap canary |
| `just simulator-logs 60` | Passed; correlated operation/parent IDs visible with no user-entered values |
| `just release-validate 60` | **Failed closed before tests:** configured simulator is iOS 27, production gate requires iOS 17 |

Current-runtime `just release-config-check` passed end to end after its authoring loop exposed and fixed a testability flag, test-harness path, and one flaky target-field input. Final repeat completed all optimized tests, archive/signature checks, and pure Release bootstrap canary in one command.

Production status remains **BLOCKED**, not green: no local iOS 17 runtime; self-hosted `count-calories-ios17` runner, `IOS17_SIMULATOR_ID`, required branch/tag status, and successful App Store Connect IPA export still need external configuration/execution. Historical binary SwiftData fixtures also remain required before next schema-changing release.
