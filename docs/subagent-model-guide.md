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
- Outcome: handled broad slices effectively, but parent caught speculative nested schema assumptions, missing page-size/TTL/snapshot details, and an Xcode UI-host blocker. Focused follow-up corrected schema/policy; later whole-product exact-tree UI suites passed the affected behavior.
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

### 2026-08-08 — Luna `max`: AMOUNT-EDITOR-001 bounded arithmetic, UI, and tests

- Shape: bounded amount-adjustment implementation, focused rules, diagnostic UI coverage, and strict MCP visual flow.
- Outcome: Luna `max` handled bounded arithmetic/UI/tests with exact `just` commands; product compiled/unit green; host blocker properly isolated.
- Validation: focused amount tests 5 pass; aggregate 90 pass / 2 opt-in skips; `just check` passed. Feature-local XCTest hosting was blocked, but later whole-product exact-tree UI suites passed amount behavior.
- Instruction-following: strict Luna MCP flow delivered useful measured evidence, though parent cleanup found interaction session already invalid/closed.
- Strength: efficient bounded implementation and useful normal, milliliter, and Accessibility3 evidence without overstating XCTest status.
- Weakness: Xcode test hosting remained unavailable after bounded recovery; parent had to separate runtime launch success from UI-suite proof.
- Policy effect: keep Luna `max` for bounded arithmetic/UI/test work; report MCP evidence and XCTest-host status separately, never as one green UI result.

### 2026-08-08 — Terra `high`: Progress analytics broad slice

- Shape: bounded but cross-cutting Progress milestone spanning tab/title composition, calorie and weight SwiftUI presentation, tracking/domain rules, previews, tests, and diagnostic UI coverage.
- Outcome: delivered initial seven-day calorie and fourteen-reading weight analytics, target-aware summaries/charts, empty Weight action, and weight record/update flow. Broad pass exposed visual defects: weak one-line gray summary, overlapping full month-day labels, and stale parent-computed sheet header.
- Validation: broad implementation established focused `ProgressHistoryTests` and diagnostic Progress weight UI coverage; parent review rejected attempt 01 and required focused correction.
- Instruction-following: handled wider integration boundary, but broad visual pass was not acceptance-ready until hierarchy, labels, and sheet-header ownership were corrected.
- Strength: effective at connecting production UI, persistence-facing state, domain filtering/limits, and deterministic evidence in one bounded slice.
- Weakness: first pass under-specified visual density and localized sheet state; parent visual review was necessary.
- Token/quota note: Terra `high` was justified by cross-file integration scope; use narrower model for correction once defect boundary is known.
- Policy effect: accept broad Terra integration only after explicit visual review and domain-rule checks; split follow-up into focused corrections rather than repeating broad pass.

### 2026-08-08 — Luna `max`: Progress focused correction and diagnosis

- Shape: focused correction after Terra broad slice: summary hierarchy, compact actual-day labels, locale-consistent wheel/header behavior, label/locale test defects, and bounded UI diagnosis.
- Outcome: attempt 02 accepted for `HISTORY-001` / `PROGRESS-001` / `WEIGHT-001` with deterministic iPhone 17 Pro preview evidence. Fresh Banana diagnosis passed `100 g / 1 / 89 kcal` with keyboard hidden.
- Validation: `ProgressHistoryTests` 16 pass; aggregate 106 pass / 2 opt-in skips; `just check` passed. Feature-local XCTest hosting timed out; later whole-product exact-tree UI suites passed Progress behavior.
- Instruction-following: preserved accepted/rejected screenshot distinction, corrected test defects instead of weakening assertions, and reported XCTest-host timeout separately from product evidence.
- Strength: efficient at precise visual correction and focused diagnosis after broad integration supplied concrete failures.
- Weakness: could not obtain final XCTest proof because simulator test hosting timed out; manual/preview evidence and automated domain results remained separable.
- Token/quota note: Luna `max` fit focused correction and diagnosis without another broad-model pass.
- Policy effect: route similar post-review UI corrections and bounded diagnostic flows to Luna `max`; keep deterministic tests and host status separate in acceptance records.

### 2026-08-08 — Model `openai-codex/gpt-5.6-luna` `max`: bounded TRACKING UI and documentation close

- Shape: bounded acceptance-flow review plus owned documentation updates.
- Outcome: effective for focused UI verification and concise cross-file docs closure.
- Strength: kept exact acceptance evidence, architecture boundaries, and rejected/superseded visual history distinct.
- Weakness: long XCTest outer tasks can exhaust budget even when bounded UI assertions are sound.
- Policy effect: empirical entry only; no standing model-policy change.

### 2026-08-08 — Model `openai-codex/gpt-5.6-terra` `high`: cross-file SwiftData/order/DST integration

- Shape: cross-file SwiftData persistence, navigation order, and date/time correctness integration.
- Outcome: succeeded across SwiftData, root order, duplicate-profile, future-row, and DST-sensitive behavior.
- Strength: connected persistence and UI architecture across interacting files.
- Policy effect: empirical entry only; no standing model-policy change.

### 2026-08-08 — Model `openai-codex/gpt-5.6-sol` `high`: architecture review

- Shape: high-level review of weight persistence and date/time architecture.
- Outcome: found exact-timestamp and DST blockers, plus useful architecture findings for correction and acceptance.
- Strength: surfaced cross-cutting risks that narrow implementation review could miss.
- Policy effect: empirical entry only; no standing model-policy change.

### 2026-08-10 — Luna `max`: bounded visual acceptance groups

- Shape: two to four final screenshots with neutral critical/high criteria.
- Outcome: fast, concise judgments found a real conflicting-percentage presentation and approved the corrected grams-versus-logged-energy design, reminder states, and Weight editor.
- Strength: strong pixel-level hierarchy/value consistency when evidence sets stayed small.
- Weakness: nine-image and repository-wide prompts repeatedly exceeded 240–300 second bounds without output.
- Policy effect: keep Luna `max` for small visual groups; split broad evidence instead of extending timeout.

### 2026-08-10 — Sol `medium`: bounded critical code reviews

- Shape: two to four attached interacting Swift files, no tools, critical/high correctness only.
- Outcome: completed quickly and found three material issues: unsupported goal-history copy/swipe transaction semantics, AMDR denominator misuse, and missing reminder reschedule after authorization recovery. Follow-up reviews approved fixes.
- Strength: high signal on cross-file semantics, safety, and state transitions at modest effort.
- Weakness: initial isolated reminder review missed parent Config rescheduling context, so parent still had to evaluate finding scope.
- Policy effect: after one bounded Luna code-review timeout, prefer Sol `medium` with attached files for critical cross-file read-only review; parent supplies all interacting owners and verifies every finding.

### 2026-08-11 — Sol `medium` + Luna `max`: calculated-plan acceptance

- Shape: safety-sensitive cross-file read-only review followed by bounded screenshot groups.
- Outcome: Sol found acceptance-reconciliation, stale restore, arbitrary-rate, calendar-default, rationale-order, nonfinite-date, and boundary-test blockers; two correction rounds ended `APPROVE`. Luna approved focused one-to-two-image groups.
- Strength: Sol medium remained high-signal for calculation/state semantics; Luna remained accurate when each visual prompt held at most two images.
- Weakness: Luna timed out on broader three/four-image groups. One Sol visual pass falsely reported clipped Back/Close controls that direct pixels and focused Luna review showed fully visible.
- Policy effect: use Sol medium for safety/state code review, but require direct pixel verification for visual findings; keep Luna visual groups to one or two images.

### 2026-08-12 — Luna `max` + Terra `high`: adaptive-plan review and simulator evidence

- Shape: safety-critical persistence review, bounded hierarchy-driven collecting/proposal/applied/Today flows, and repeated critical/high visual judgments.
- Outcome: Terra found real cross-cutting defects in Revert availability, calendar epochs, proposal integrity, stale action handling, exact evidence guidance, and historical goal context. Luna produced reliable hierarchy/frame evidence and identified tab-bar/44-point/confirmation issues. Focused fixes ended with 3/3 visual APPROVE and 31/31 UI.
- Validation: parent ran all `just` gates. Xcode full-suite adaptive fixtures intermittently exposed launch/preparation timing despite focused passes; deterministic fixture paths and tests were adjusted, and final full suite passed.
- Strength: Terra high-signal architecture review; Luna precise device measurements and bounded flow reporting.
- Weakness: broad parallel reviewer calls can timeout empty; repeated simulator sessions over-capture and consume substantial time. Xcode UI timing may differ between focused and full suite.
- Policy effect: no standing model change. Keep Terra for safety-critical integration review, Luna for bounded MCP, and require full-suite proof after focused green.

### 2026-08-13 — Sol `medium`: FINAL-001 diff-only critical/high review loops

- Shape: three identical neutral read-only reviews over attached 70–75 KiB final diff; no repository tools.
- Outcome: completed reliably where repository-wide Luna/Terra/Sol tool-enabled prompts timed out empty. Review rounds found real bulk durability, calorie completeness, reminder replacement/concurrency/capacity, widget migration, Live Activity ordering, and stale-settings defects; final round reached 3/3 APPROVE.
- Validation: parent verified every finding, applied scoped fixes, then ran exact `just` gates.
- Strength: high-signal cross-cutting semantics at bounded context and medium effort.
- Weakness: reviewers sometimes surfaced distinct rather than consensus findings, requiring parent scope judgment and repeated neutral rounds; attached diff cannot inspect omitted unchanged context.
- Token/quota note: three parallel repository-wide reviewers each timed out at 900 seconds with empty output; attached-diff Sol medium completed within bounds.
- Policy effect: for broad closure review, first attach a bounded final diff to Sol medium; use repository tools only when call-site context is genuinely absent, and parent verifies against full tree.

### 2026-08-20 — Model/effort metadata not retained: BACKLOG-CLOSURE-001 review and device loops

- Shape: hierarchy-driven light/AX3-dark evidence capture plus repeated neutral repository-wide critical/high review of historical mutation, personal targets, ranking, accessibility, and external-surface ordering.
- Outcome: device sessions produced retained evidence and were closed; successive reviewers found 22 material correctness issues, all fixed before final 3/3 approval. Detailed findings and final proof remain in `../design-redesign/experiments/BACKLOG-CLOSURE-001.md`.
- Validation: parent ran final hostless, app-hosted, functional UI, build/install/launch, and diff gates.
- Instruction-following: review/device outcomes were retained, but invocation model and effort were not written durably. This audit does not reconstruct missing metadata from filenames.
- Strength: independent loops exposed migration, identity, exact undo, CAS, parsing, synchronization, and overflow defects that narrow tests initially missed.
- Weakness: absent model/effort metadata prevents empirical comparison and violated this guide’s recording intent.
- Token/quota note: many broad reviewer rounds were required; retained outputs show several empty/time-limited attempts.
- Policy effect: every future delegated invocation record must include model and effort when started, not only after completion; parent should append this guide before deleting task notes.

### 2026-08-20 — Sol `medium`: full Markdown closure re-audit

- Shape: three identical neutral repository-wide passes over 54 tracked Markdown files, with source/test cross-checks for uncertain implementation claims.
- Outcome: first complete passes exposed unsupported adaptive wording, superseded bulk override requirements, obsolete labels/reminder language, stale milestone phrasing, and broken ephemeral/relative evidence paths. After corrections, later passes found exact-time terminology drift, stale current Log food labels, and ambiguous platform-diagnostic debt framing. Final fresh pass reached 3/3 APPROVE with 0 active items and 0 broken links.
- Validation: parent ran mechanical checklist/link/evidence-path audits, `git diff --check`, focused cache measurement, and full `just test-unit 600` (243 executed, 241 pass / 2 opt-in skips).
- Instruction-following: all completed reviewers reported file count, exclusions, unchecked count, unresolved count, and broken-link count. One earlier Luna `max` process timed out empty; two peers completed.
- Strength: Sol medium finished full-tree documentation/source reconciliation reliably and found precise cross-file contradictions.
- Weakness: one-finding-at-a-time convergence required repeated full passes; parallel calls consume substantial wall time.
- Token/quota note: final three-way Sol pass completed within bounded process timeout; initial parallel Luna pass produced one empty timeout.
- Policy effect: use Sol medium for finite repository-wide documentation reconciliation when every file must be read; retain exact model/effort and audit counters immediately.

### 2026-08-20 — Terra `high` + Luna `max`: production test and observability audit

- Shape: parallel feature/test matrix, UI-journey/gate audit, logging/privacy audit, then repeated identical critical/high whole-tree reviews.
- Outcome: reviewers found real release-gate, file-backed relaunch, reminder-save, scanner-success, widget storage/race/completeness, external fan-out, cache rollback, setup ordering, Release configuration, failure-artifact, and log-correlation gaps. Parent fixed code-level findings and added durable assessment. Final committed-tree source review reached 3/3 APPROVE. Remaining shared finding is external: no configured/required iOS 17 self-hosted gate, so production approval stays blocked.
- Validation: 254 hostless executed (252 pass / 2 skips), 376 app-hosted pass / 2 skips, optimized Release-config 55/55 UI, signed app/widget archive signatures, and pure Release bootstrap canary passed on iOS 27. Strict `just release-validate` correctly rejects iOS 27 before production gate.
- Instruction-following: agents remained read-only and cited exact files/tests. Repeated passes were high-signal but continued surfacing one additional integration edge per round.
- Strength: Terra found cross-process water loss, false parent success, Release-vs-Debug gaps, rollback loss, incomplete-calorie activity propagation, and unenforced minimum-OS proof. Luna produced broad logging inventory and privacy-safe taxonomy quickly.
- Weakness: repository-wide review loops are expensive and external CI/branch settings cannot be repaired from source-only agents.
- Token/quota note: parallel reviews completed within 2,400-second bounds; full optimized UI runs dominate wall time, not model calls.
- Policy effect: use specialized Terra/Luna audits before one final identical review round; distinguish source-code approval from external release-enforcement blockers explicitly.

Do not change standing model policy absent repeated evidence.

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
