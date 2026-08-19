# Count Calories

Native SwiftUI calorie tracker for daily and historical food logging, water, weight, explainable goals, optional personal macro/fiber targets, reminders, recent/frequent local shortcuts, barcode and cached remote nutrition lookup, typed/on-device dictated bulk meal review, widgets, Live Activities, and keyboard-free ±10/±1 amount adjustment.

## Development

Repository operations use `just` exclusively:

```sh
just iterate       # hostless tests + incremental compile
just check         # incremental compile
just test-unit     # deterministic hostless tests
just simulator-run # build, install, launch simulator app
just validate      # final unit/build/install/launch gate
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

Final results:

- `just validate 600`: **243 hostless executed (241 passed / 2 opt-in live skips)**; app + widget compile, simulator install, and launch passed.
- `just test-app-unit 900`: **351 passed / 2 opt-in live skips**.
- `TEST_CASE_TIMEOUT=60 just test-ui 2400`: **52/52 passed**.
- Original closure, diary, and final backlog-closure critical/high reviews each converged at **APPROVE / APPROVE / APPROVE**.

## Redesign evidence

Screenshot-driven final state and evidence live under `design-redesign/`:

- `design-redesign/FINAL-REPORT.md`
- `design-redesign/STATUS.md`
- `design-redesign/SCREENSHOTS.md`
- `design-redesign/02-design-log.md`
- `design-redesign/PRODUCT-BACKLOG.md`
- `design-redesign/experiments/`
