# Count Calories

Native SwiftUI calorie tracker for daily food, water, weight, goals, reminders, barcode and remote nutrition lookup with offline query caching, widgets, Live Activities, and keyboard-free ±10/±1 amount adjustment.

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

## Completed Progress analytics milestone

`HISTORY-001` / `PROGRESS-001` / `WEIGHT-001` are **ACCEPTED — attempt 02**. Visible `History` became `Progress`. Calories show seven most recent recorded days, recorded-day average, profile-goal relation, orange bars, compact actual-day labels, and goal rule. Weight shows current/change/target text, fourteen raw readings, linear points, adaptive nonzero domain, and target rule. Empty Weight state leads directly to Record Weight; record/update sheet uses locale-consistent wheels plus Cancel/Save and save-only dismissal with rollback on failure.

Evidence: deterministic iPhone 17 Pro previews in `design-redesign/screenshots/HISTORY-001/attempt-02-calories.png`, `design-redesign/screenshots/WEIGHT-001/attempt-02-populated.png`, `design-redesign/screenshots/WEIGHT-001/attempt-02-empty.png`, and `design-redesign/screenshots/WEIGHT-001/attempt-02-editor.png`. `ProgressHistoryTests`: 16 pass. Aggregate: 106 pass / 2 opt-in skips. `just check` passed. Final `just test-ui 300` timed out before XCTest and reset simulator; UI suite is not green.

Next work is separate user-requested research on splitting navigation among calorie tracker, weight recording, and analytics. No split is pre-decided by this milestone.

## Active product redesign

Screenshot-driven redesign state and evidence live under `design-redesign/`:

- `design-redesign/STATUS.md`
- `design-redesign/SCREENSHOTS.md`
- `design-redesign/02-design-log.md`
- `design-redesign/PRODUCT-BACKLOG.md`
- `design-redesign/experiments/`
