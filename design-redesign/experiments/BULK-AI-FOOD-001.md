# BULK-AI-FOOD-001 — typed and dictated bulk logging

**Status:** ATTEMPT 01 ACCEPTED — COMPLETE
**Started:** 2026-08-12

## User problem

Single-food search repeats too much work for a multi-item meal. Natural typed or dictated description can automate decomposition and food lookup, but language-model guesses must not become nutrition facts or bypass review.

## Research and contract

- Competitor and Apple-framework assessment: `../../docs/bulk-ai-food-logging-assessment.md`.
- Approved implementation contract: `../../docs/bulk-ai-food-logging-specification.md`.
- Verified first-party evidence covers MyFitnessPal voice capture/results/edit/log, MacroFactor database-grounded inspectable AI plate, Foodnoms typed-summary/privacy behavior, Apple Foundation Models guided generation/availability/safety, and SpeechAnalyzer locale/assets/audio lifecycle.

## Attempt 01 decision

Build staged native flow:

```text
Describe (type or optional on-device dictation)
→ SystemLanguageModel guided extraction into provisional query/amount/unit rows
→ concurrent retained/saved/cache/Open Food Facts matching
→ explicit item-level review and edits
→ one atomic batch confirmation
```

Guardrails:

- language model never supplies calories, nutrients, barcode, or product identity;
- raw description, audio, extraction, and corrections stay local; only derived row queries may reach Open Food Facts;
- every failed row remains visible and recoverable;
- no partial `PlateEntry` insertion;
- retained corrections and match choices use bounded, clearable LRU storage;
- iOS 17–25/ineligible/model-unavailable paths retain manual rows and direct Log food.

## Completed slices

1. Deterministic extraction/review values, validators, matching/ranking, learning/draft LRU, and atomic idempotent batch persistence.
2. Typed Foundation Models Describe/Review UI, saved/custom/manual recovery, explicit estimate acceptance, and stale-result protection.
3. SpeechAnalyzer dictation with permission/assets/interruption/backpressure recovery and retained finalized text.
4. Fixtures, hostless/app-hosted/UI coverage, light/dark/AX3 evidence, independent review, validation, and docs closure.

## Attempt log

### 2026-08-12 — research/specification

Research and detailed contract completed before code. Implementation started with hostless safety foundations and coordinator transaction; UI followed only after deterministic gates passed.

### 2026-08-12 — accepted implementation

Attempt 01 now includes availability-gated typed/dictated extraction, editable review, verified saved/cache/Open Food Facts/custom nutrition, bounded clearable learning and seven-day draft, durable operation/date/row identity, and one atomic coordinator transaction. Estimates/default amounts need explicit acceptance; invalid visible amounts block readiness; remembered barcode data cannot bypass current-record verification; post-commit learning uses frozen committed rows; draft cleanup is attempted independently from learning failure.

Reminder follow-up replaced ambiguous per-meal navigation with passive Breakfast/Lunch/Snack/Dinner time + Enabled/Disabled summaries and one **Customize Meal Reminders** action. Menu choices separate per-meal switches from notification time controls.

Validation on final reviewed tree: `just validate 300` passed with 219 hostless tests / 2 opt-in live skips; app-hosted target passed 297 / 2 skips; full functional UI passed 44/44. Final three independent critical/high source reviews: **APPROVE / APPROVE / APPROVE**.
