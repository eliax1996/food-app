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

## Accepted TRACKING-IA-001 milestone

`TRACKING-IA-001` is **ACCEPTED — ATTEMPT 01 / COMPLETE**. Final root is:

```text
Today | Weight | Progress | Settings
```

- **Today:** current-day calorie, food, and water actions.
- **Weight / Weight Log:** raw measurement CRUD, independent date/time backdating, same-day preservation, confirmation plus undo, summary, and basic seven-reading raw chart. One reading shows useful prompt; two or more show chart context.
- **Progress:** fuller fourteen-reading weight analytics and interpretation; no weight CRUD. `View full trends` routes directly to Progress / Weight.
- **Settings:** target weight, age, daily calorie goal, target date, and reminders; no current-weight field or save path.
- No historical calorie CRUD or generic Calories/Water/Weight table. Future calorie history remains a separate date-first day diary.

Final results:

- `just validate 300`: **passed**.
- Hostless validation: **125 passed / 2 opt-in live skips**.
- Simulator build, install, and launch: **passed**.
- `scripts/iterate.zsh` scopes `test-ui` to `count_caloriesUITests` and excludes performance tests; app units remain `test-app-unit`.
- Explicit UI target: **6/6 passed**, covering four tabs; prompt → chart; two same-day readings; backdated regrouping; edit; delete cancel/confirm/undo; Settings; and direct `View full trends` → Progress / Weight.
- App-hosted persistence tests passed after final duplicate-profile/future-row correctness fixes and again in an integrated run.
- One later standalone `just test-app-unit 300` timed out before XCTest due to external Xcode 27 host instability; not a red product gate.

Accepted TRACKING visual files are only `design-redesign/screenshots/TRACKING-IA-001/attempt-01-*`. `superseded-three-tab-*` files remain historical; `rejected-one-reading-chart.png` remains rejected evidence.

Next component: empty/error/loading states, then global consistency, dark mode, Dynamic Type, and small-device checks.

## Active product redesign

Screenshot-driven redesign state and evidence live under `design-redesign/`:

- `design-redesign/STATUS.md`
- `design-redesign/SCREENSHOTS.md`
- `design-redesign/02-design-log.md`
- `design-redesign/PRODUCT-BACKLOG.md`
- `design-redesign/experiments/`
