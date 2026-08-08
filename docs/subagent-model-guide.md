# Subagent model selection guide

Living empirical record. Update after meaningful delegated work. `AGENT.md` owns normative rules; this file records why they exist and when to revise them.

## Current matrix

| Model | Minimum effort | Default task class | Upgrade trigger |
|---|---:|---|---|
| `openai-codex/gpt-5.6-luna` | `max` only | Small–medium bounded implementation, focused tests/docs/review, straightforward MCP sequence | Major defect, incomplete integration reasoning, or scope broadens → Terra `high` |
| `openai-codex/gpt-5.6-terra` | `high` | Medium–large bounded multi-file work, integration, nontrivial debugging, Luna follow-up | Ambiguity, cross-cutting architecture, repeated failure → Sol |
| `openai-codex/gpt-5.6-sol` | Any | Ambiguous/high-risk synthesis, architecture, broad diagnosis, repeated failure | Increase effort based on evidence; `max` only for hardest work |

## Sizing heuristics

### Luna `max`

Prefer when prompt can state all of:

- one clear outcome;
- one to three cohesive owned files or read-only evidence set;
- no unresolved architecture choice;
- exact validation command;
- parent can verify result cheaply.

Examples: one SwiftUI component refinement, focused unit test, documentation update, simulator launch/navigation/screenshots, one-screen visual judge.

### Terra `high+`

Prefer when task remains bounded but needs:

- several interacting files;
- state/persistence/API integration;
- nontrivial diagnosis;
- longer MCP journey with branches;
- correction after Luna exposed a substantial defect.

Start `high`. Use `max` only when broader context or diagnosis clearly needs it.

### Sol

Prefer when task has:

- unresolved product/architecture decisions;
- broad cross-feature consequences;
- high-risk migration or concurrency behavior;
- contradictory evidence;
- repeated failures after cheaper models;
- large synthesis across code, tests, screenshots, and research.

Use low/medium for narrow analysis, high for complex implementation, max for hardest synthesis.

## Token discipline

1. Parent defines boundary before launch.
2. Attach only relevant files/screenshots/failures.
3. Assign exclusive files and prohibit unrelated edits.
4. Request smallest complete change and concise report.
5. Require exact `just` validation; parent reruns it if agent drifts.
6. Review once. Fix tiny defects in parent; send only major defects to another agent.
7. Upgrade model only after evidence, not preemptively.
8. Stop aesthetic/reviewer loops when feedback no longer identifies a user-visible problem.
9. Require MCP agents to classify UI-test candidacy. Before repeating behavioral proof, spend CPU once on deterministic XCTest coverage instead of more agent tokens.

## Observed results

### 2026-08-08 — Terra `high`: Meal numeric-field refinement

- Shape: one SwiftUI file, explicit visual/accessibility requirements.
- Outcome: successful implementation; compile passed; parent visual review found intended improvement.
- Strength: followed bounded UI requirements and preserved surrounding flow.
- Weakness: reported `just simulator-build` instead of requested exact `just check`.
- Token/quota note: task was likely small enough for Luna `max`.
- Policy effect: default similar one-file work to Luna; parent reruns exact validation.

### 2026-08-08 — Terra `high`: deterministic review appearance controls

- Shape: one app-entry file, DEBUG-only environment behavior.
- Outcome: implementation compiled and worked on HOME.
- Strength: direct, production-isolated implementation.
- Weakness: invoked direct `xcodebuild`, violating repository `just` policy despite prompt.
- Token/quota note: unnecessary Terra use for small isolated task.
- Policy effect: prompts must restate `just`-only prohibition; parent inspects command compliance.

### 2026-08-08 — Terra `high`: Meal and food-search MCP sequences

- Shape: launch, navigate, search/select, mutate draft, cancel, capture hierarchy/screenshots.
- Outcome: strong. Found real narrow-hit bug, verified fix, arithmetic, no-save behavior, and touch frames.
- Strength: careful hierarchy-derived interaction and useful defect reporting.
- Weakness: occasional session-key/start confusion; some transient Xcode captures misclassified until settled recapture.
- Token/quota note: several sequential Terra calls exhausted provider usage limit.
- Policy effect: use Luna `max` for straightforward MCP flows; reserve Terra for complex branches/failures.

### 2026-08-08 — Terra `high`: Accessibility Menu correction

- Shape: one SwiftUI file after Accessibility3 screenshot exposed malformed Picker.
- Outcome: compile-safe Menu-row replacement with normal-size segmented behavior preserved.
- Strength: focused correction and adaptive control design.
- Weakness: again ran a different `just` recipe than requested.
- Token/quota note: final runtime retest blocked when Terra quota exhausted.
- Policy effect: separate implementation and verification across cheaper Luna calls where possible; avoid repeated Terra microtasks.

### 2026-08-08 — Luna `max`: Food Tools one-file affordance fix

- Shape: one SwiftUI file, exact disabled-state styling/footer requirement.
- Outcome: correct minimal implementation; parent review accepted code.
- Validation: agent ran `just simulator-build` instead of exact requested `just check`.
- Strength: concise report and direct bounded change.
- Weakness: repeated validation-command drift also observed with Terra.
- Token/quota note: appropriate task size for Luna.
- Policy effect: keep Luna default for one-file fixes; parent always verifies exact required recipe.

### 2026-08-08 — Luna `max`: UI-test promotion and green loop

- Shape: add stable identifiers, food-search/cancel UI test, step diagnostics, run full UI suite.
- Outcome: test code was strong and later passed. Luna added `XCTContext` phases and precise diagnostics.
- Validation: first 90-second run hit host launch failure; follow-up with 240-second loops exhausted a 25-minute parent bound and left an orphaned xcodebuild, later cleared by recovery.
- Strength: deterministic assertions, no sleeps, useful development diagnostics.
- Weakness: ineffective at converging persistent Xcode test-host infrastructure; process cleanup escaped parent timeout.
- Token/quota note: max effort spent heavily on host stalls rather than product code.
- Policy effect: Luna may author UI tests, but escalate repeated host/bootstrap failures to Terra `high`; parent checks lock/orphan state after timed-out subagents.

### 2026-08-08 — Terra `high`: UI-test host escalation

- Shape: diagnose Luna's stalled UI-test loop, recover Xcode host, prove new and full suites.
- Outcome: no source edits needed. New test 1/1 passed; functional UI 3/3 passed; full result 52 passed, 0 failed, 2 live skips.
- Validation: used `just` only, inspected results, performed documented recovery, reran to green.
- Strength: correctly separated product/test success from host launch/preflight failures and converged after recovery.
- Weakness: attempted nonexistent focused recipe once before full runs.
- Token/quota note: Terra was justified by infrastructure ambiguity after Luna failure.
- Policy effect: use Terra `high` for repeated Xcode test-host diagnosis; consider adding focused UI recipe when authoring volume grows.

### 2026-08-08 — Sol `max`: long-horizon redesign orchestration

- Shape: architecture, code, research, visual evidence, iterative judging, integration.
- Outcome: effective for broad synthesis and resolving conflicting reviewer feedback.
- Strength: strong cross-component reasoning and parent integration.
- Weakness: high context/token cost; poor choice for routine bounded execution.
- Policy effect: retain Sol for parent orchestration and hardest subproblems, delegate bounded execution downward.

### 2026-08-08 — Luna `max`: Accessibility3 Meal MCP retest

- Shape: existing-session navigation, large-text sheet inspection, two Menu checks, screenshots/hierarchy, no mutation.
- Outcome: successful sequence. Verified readable Meal and Serving Presets Menu rows, all options, exact fields, total, and reachability; no clipping remained.
- Validation: parent inspected full screenshots and corrected verdict to PASS.
- Instruction-following: respected existing session, hierarchy coordinates, no save/edit/end.
- Strength: handled a multi-step straightforward MCP flow without Terra quota and returned useful frames/artifacts.
- Weakness: labeled Lunch as a defect because prompt expected Breakfast, overlooking time-based meal suggestion at 12:19. Took many settled/transition captures and roughly three minutes for a bounded flow.
- Token/quota note: max effort appears capable but can over-execute; prompts should avoid false expected values and request a strict capture budget.
- Policy effect: Luna `max` remains default for straightforward MCP. Parent must validate domain expectations; cap retries/captures explicitly. Repeated behavioral flows must become UI tests instead of another MCP run.

### 2026-08-08 — Terra `high`: FOOD-REMOTE-SEARCH-001 broad implementation slices

- Shape: broad multi-file search-client, cache, service, coordinator, and UI integration work.
- Outcome: handled broad slices effectively, but parent caught speculative nested schema assumptions, missing page-size/TTL/snapshot details, and an Xcode UI-host blocker. Focused follow-up iterations corrected schema and policy gaps; final UI-host attempts remained infrastructure-blocked before XCTest.
- Instruction-following: parent review was required to narrow architecture and separate product behavior from UI-host failure.
- Strength: covered broad architecture quickly.
- Weakness: broad pass left important contract details and host diagnosis unresolved.
- Token/quota note: broader model was justified for integration, but focused corrections were cheaper than another broad pass.
- Policy effect: use Terra `high` for bounded integration after Luna failure or when broad context is required; require explicit schema, pagination, TTL, snapshot, and host-evidence checks.

### 2026-08-08 — Luna `max`: FOOD-REMOTE-SEARCH-001 coordinator refactor/test and strict MCP visual flows

- Shape: focused coordinator refactor/test plus hierarchy-driven Xcode MCP interaction and visual evidence capture.
- Outcome: succeeded. Coordinator behavior and focused tests were completed; strict visual flow selected Remote Oat Drink, verified 250 ml / 100 kcal, keyboard dismissal, an exact 100 kcal daily-total increase, persistence, and concise accepted screenshot evidence.
- Validation: used exact requested `just` commands and returned concise evidence. Final UI-test-host failures were reported separately rather than called green.
- Instruction-following: respected focused ownership, deterministic fixture boundaries, and strict MCP interaction requirements.
- Strength: precise state-transition work and disciplined visual proof.
- Weakness: final XCTest proof remained dependent on external Xcode host availability.
- Token/quota note: Luna `max` fit focused refactor, test, and MCP work without broad-model cost.
- Policy effect: default similar focused coordinator/test or strict MCP tasks to Luna `max`; preserve separate reporting for manual proof and XCTest-host blockers.

## Criteria change log

### 2026-08-08 v1

- Terra `high` was used for all bounded implementation/MCP work.
- Evidence: capable but expensive; repeated calls exhausted quota; validation-command drift occurred.

### 2026-08-08 v2

- Luna `max` becomes default small–medium delegate.
- Terra restricted to `high+` and broader bounded tasks/escalation.
- Sol effort selected by ambiguity/risk.
- Added explicit token discipline and empirical review loop.

### 2026-08-08 v3

- Luna `max` validated for straightforward multi-step MCP work.
- MCP prompts now avoid brittle expected state when behavior is time-dependent.
- Request bounded captures/retries to offset Luna max over-execution.

### 2026-08-08 v4

- Repeated MCP behavioral proof now promotes to deterministic UI tests.
- UI-test agents own a higher-timeout diagnose/fix/run loop and step diagnostics.
- Luna can author UI tests; Terra `high` handles persistent Xcode host/bootstrap escalation.
- Parent checks repository lock and orphaned processes after subagent timeout.

## Record template

```md
### YYYY-MM-DD — Model `effort`: task

- Shape:
- Outcome:
- Validation:
- Instruction-following:
- Strength:
- Weakness:
- Token/quota note:
- Policy effect:
```
