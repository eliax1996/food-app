# Working notes

## Current program

Original autonomous product redesign — **COMPLETE**.

Durable scope and live phase tracker: `design-redesign/COMPLETION-PLAN.md`.

## Completed core milestones

- Today dashboard, calorie/water hierarchy, meal grouping
- Meal editor, local/remote food search, custom/barcode tools
- Cached Open Food Facts search and keyboard-secondary amount controls
- Progress analytics
- Dedicated Weight Log
- Root `Today | Weight | Progress | Settings`

Latest accepted milestone: BACKLOG-CLOSURE-001, following COMPETITOR-GAP-001 historical Food Diary and FINAL-001 whole-product closure. Final report: `design-redesign/FINAL-REPORT.md`.

## Current component

Product feature queue remains empty. Post-closure test/observability hardening is implemented and documented in `docs/test-observability-production-readiness-assessment.md`.

Historical diary mutations, personal nutrition targets, frequent-food ranking, shared calorie accessibility semantics, and Today external-surface extraction are implemented. HealthKit/accounts/sync, streak/coaching, exercise credits, duplicate shortcuts, photo/cloud AI, reminder windows, and extra amount variants are explicitly rejected from current scope. No feature queue remains.

## Final validation

- hostless: 254 executed — 252 passed / 2 opt-in live skips
- app-hosted: 376 passed / 2 opt-in live skips
- optimized Release-config functional UI: 55/55 passed
- signed archive/signatures and pure Release simulator bootstrap canary: passed
- final backlog-closure independent critical/high review: 3/3 APPROVE
- production-readiness source review: 3/3 APPROVE; external iOS17/branch/signing/device blockers retained
- app + widget compile, simulator install/launch, and `git diff --check`: passed

## Immediate action

Before production: configure self-hosted iOS 17 runner + `IOS17_SIMULATOR_ID`, require **Release validation** for branch/tag protection, run exact-tree `just release-validate`, and retain exported IPA result. Current local iOS 27 checks do not waive this blocker.
