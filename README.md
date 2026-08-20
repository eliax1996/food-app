# Count Calories

Native SwiftUI calorie tracker for daily and historical food logging, water, weight, explainable goals, optional personal macro/fiber targets, reminders, recent/frequent local shortcuts, barcode and cached remote nutrition lookup, typed/on-device dictated bulk meal review, widgets, Live Activities, and keyboard-free ±10/±1 amount adjustment.

## Development

Repository operations use `just` exclusively:

```sh
just iterate       # hostless tests + incremental compile
just check         # incremental compile
just test-unit     # deterministic hostless tests
just simulator-run   # build, install, launch simulator app
just validate        # development hostless/build/install/launch gate
just release-validate # production gate: hostless + app-hosted + UI + install/launch
just simulator-logs  # recent privacy-safe app operation logs
```

See `AGENT.md` for complete engineering, testing, simulator, continuity, delegation, and milestone-commit rules. Accepted green features should be committed as focused local milestones; unfinished work and `.TASK_NOTES.md` stay out.

## Agent delegation

Delegate clearly bounded work aggressively, then review every result in parent context.

| Task shape | Model | Allowed effort |
|---|---|---|
| Small–medium, well-defined implementation, review, docs, or MCP flow | GPT-5.6 Luna | `max` only |
| Medium–large bounded integration/debugging or Luna escalation | GPT-5.6 Terra | `high` or above |
| Ambiguous, cross-cutting, architecture-heavy, high-risk, repeated failure | GPT-5.6 Sol | Match task complexity |

Use least costly allowed configuration likely to finish correctly. Give agents exclusive scope, exact acceptance criteria, and exact `just` validation. Parent inspects diffs/evidence, fixes small defects, and delegates major follow-up work.

Empirical strengths, weaknesses, quota behavior, and policy changes are tracked in `docs/subagent-model-guide.md`. Keep that record and `AGENT.md` current as evidence changes model selection.

## MCP and durable QA

Use Xcode MCP once to explore or visually inspect a flow. If the same flow must be repeated to prove behavior—or it protects a critical journey—promote it to deterministic XCTest UI coverage before another manual proof. UI tests may cost CPU, but replace repeated agent navigation and save tokens/time. Test-authoring subagents must add step diagnostics and run/fix the created tests to green with a higher bounded timeout (`just test-ui 240` by default), not stop after generating code or the first failure. Keep tests isolated from live network, camera, permissions, wall clock, and uncontrolled persisted state.

## Production guard and observability

`just test` and `just validate` remain fast development gates. Production candidates require `just release-validate`, which runs hostless, optimized Release-config app-hosted/UI, signed production Release archive/app+widget checks, App Store Connect IPA export, then pure Release simulator install/launch with post-bootstrap process-alive canary. State-changing operations emit correlated privacy-safe start/result events; `just simulator-logs` displays them. User-entered health/meal values and raw errors are never logged. Full coverage matrix and unavoidable system-boundary smoke requirements: [`docs/test-observability-production-readiness-assessment.md`](docs/test-observability-production-readiness-assessment.md).

## Product redesign

Original autonomous redesign and finite Markdown-backlog closure are **COMPLETE**. Final report, baseline comparison, screenshots, independent review, candidate dispositions, and exact validation: [`design-redesign/FINAL-REPORT.md`](design-redesign/FINAL-REPORT.md).

Final root is:

```text
Today | Weight | Progress | Settings
```

- **Today:** current-day calorie, food, and water actions.
- **Weight / Weight Log:** raw measurement CRUD, independent date/time backdating, same-day preservation, confirmation plus undo, summary, and basic seven-reading raw chart. One reading shows useful prompt; two or more show chart context.
- **Progress:** fuller fourteen-reading weight analytics and interpretation; direct Food Diary works with empty/incomplete history, while selected complete days retain contextual View Day. Known food snapshots support add/edit/copy/delete/undo and recorded-day navigation. No weight CRUD. `View full trends` routes directly to Progress / Weight.
- **Settings:** target weight, age, daily calorie goal, target date, optional user-entered macro/fiber targets, and reminders; no current-weight field or save path.
- No generic Calories/Water/Weight table. Historical food stays separate and date-first; unknown legacy aggregates remain visible but cannot be falsely edited/copied as item snapshots.

Current automated results:

- hostless: **254 executed (252 passed / 2 opt-in live skips)**;
- app-hosted: **376 passed / 2 opt-in live skips**;
- optimized Release-config functional UI: **55/55 passed**;
- signed production archive: app/widget structure and strict signatures passed;
- pure Release simulator app: built, installed, launched, and remained alive after bootstrap canary.

Production-readiness source review reached **3/3 APPROVE**. Production approval remains blocked until required iOS 17 self-hosted workflow/branch protection runs `just release-validate`; local machine has only iOS 27 runtime. Original closure, diary, and backlog-closure reviews remain accepted; current assessment is linked above.

## Redesign evidence

Screenshot-driven final state and evidence live under `design-redesign/`:

- `design-redesign/FINAL-REPORT.md`
- `design-redesign/STATUS.md`
- `design-redesign/SCREENSHOTS.md`
- `design-redesign/02-design-log.md`
- `design-redesign/PRODUCT-BACKLOG.md`
- `design-redesign/experiments/`
