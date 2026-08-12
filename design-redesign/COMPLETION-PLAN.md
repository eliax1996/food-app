# Product redesign completion plan

**Status:** IN PROGRESS
**Started:** 2026-08-09
**Last updated:** 2026-08-12 — BULK-AI-FOOD-001 accepted; AUXILIARY-001 next

## Goal

Finish the original autonomous iOS calorie-tracker redesign against its full Definition of Done—not only individual milestones. Leave Count Calories materially better, visually evidenced, independently reviewed, accessible, functionally verified, documented, and free of unresolved high-priority design work.

## Completed

- Verified real image input and Xcode/simulator tooling in `00-environment.md`.
- Captured nine original baseline screenshots and completed baseline architecture/design audit.
- Added deterministic DEBUG-only review states for empty, normal, near-target, exceeded, and long-content days.
- Researched current calorie-tracker and dedicated-weight product patterns with retained sources.
- Redesigned and accepted:
  - Today dashboard, calorie status, water actions, and meal summaries;
  - meal editor and food selection;
  - custom-food/barcode tool presentation;
  - cached Open Food Facts remote search;
  - keyboard-secondary amount adjustment;
  - calorie and weight Progress analytics;
  - dedicated Weight Log and `Today | Weight | Progress | Settings` navigation.
- Preserved accepted, rejected, and superseded experiment screenshots.
- Added deterministic hostless, app-hosted persistence, and UI regression coverage.
- Completed STATES-001 truthful remote loading/empty/offline recovery, scanner permission/availability recovery, and inline barcode lookup recovery.
- Accepted NUTRIENTS-001 optional macro/fiber API mapping, persistence snapshots, coverage-gated daily balance, custom-food entry, and transparent general-adult comparison.
- Latest accepted nutrient milestone: exact-tree `just validate 300` passed; 140 hostless tests passed with 2 opt-in live skips; app-hosted tests passed 167 with 2 skips; explicit functional UI target passed 12/12.

## Missing before whole-product DONE

1. **STATES-001 — COMPLETE: empty/loading/error/offline/permission states**
   - Accepted attempt 04 with live remote offline, scanner permission, dark/large-text scanner, and barcode loading/offline evidence.
   - Remote and barcode failures preserve usable local content; scanner denial provides Settings/manual recovery.
   - Notification authorization and reminder persistence intentionally continue under REFINE-001 with the broader reminder redesign.

2. **NUTRIENTS-001 — COMPLETE: daily macros, fiber, coverage, and measured guidance**
   - Optional carbohydrate, protein, fat, and fiber survive v3.6/v2/search, cache projection migration, Food serving persistence, and immutable consumed PlateEntry snapshots without inventing missing values.
   - Today and daily detail expose measured grams, macro-energy split, Fiber, explicit coverage, methodology, and at most two neutral range-citing suggestions.
   - Macro and Fiber comparisons require 100% relevant coverage. Reported calories remain budget-authoritative and provide the adult-range denominator; the colored 4/4/9 macro-only split stays separately normalized.
   - Focused custom-food nutrient editor, complete/partial/dark/AX3 evidence, hostless/app-hosted tests, 12/12 UI target, and 3/3 critical/high visual approval are accepted.
   - Calorie-goal-derived theoretical gram ranges requested for Plan remain tracked as NUTRITION-GOALS-001 inside REFINE-001.

3. **REFINE-001 — COMPLETE: onboarding, goals, hierarchical Settings, reminders, and adaptation**
   - Attempts 01–03 accepted: transparent Plan references, exact reminders, calculated setup, direct entry, explicit complete-day evidence, evidence-gated proposal-only adaptation, and exact revert.
   - Final Slice D visual consensus: 3/3 APPROVE; hostless 195/2 skips, app-hosted 250/2 skips, functional UI 31/31.

4. **BULK-AI-FOOD-001 — COMPLETE: typed/dictated bulk logging with editable review**
   - Typed descriptions and explicit Dictate intent feed availability-gated on-device extraction; iOS 17–25 retain direct/manual paths.
   - Provisional query/amount/unit rows remain editable; calories, nutrients, barcode, and identity come only from verified saved/custom/Open Food Facts records.
   - Bounded local learning/drafts, stale-result rejection, explicit estimate acceptance, custom recovery, and one atomic idempotent batch transaction are implemented.
   - Attempt-01 light/dark/AX3 evidence, 297 app-hosted pass / 2 live skips, 219 hostless pass / 2 live skips, focused reminder/bulk UI proofs, and 3/3 final critical/high review approval are recorded.

5. **AUXILIARY-001 — Widget and Live Activity**
   - Audit user-facing widget and Live Activity surfaces.
   - Improve or explicitly accept them with visual evidence and documented scope.

6. **CONSISTENCY-001**
   - Compare all accepted screens together.
   - Reconcile terminology, typography, spacing, iconography, chart language, actions, empty states, navigation, and destructive behavior.

7. **ROBUSTNESS-001**
   - Exercise primary surfaces in light and dark appearance.
   - Test normal and Accessibility Dynamic Type.
   - Test small and large iPhone layouts.
   - Test long names, extreme values, empty data, and dense data.

8. **FINAL-001**
   - Perform clean build/install/launch and full primary-journey walkthrough.
   - Capture final screenshots under `screenshots/final/`.
   - Compare baseline versus final.
   - Obtain independent whole-product product-design, native-iOS, and nutrition-competitiveness judgments.
   - Fix every critical/high-impact finding or document explicit external blocker.

9. **Closure documentation and gates**
   - Reconcile stale historical/current test statements.
   - Update `STATUS.md`, `SCREENSHOTS.md`, design log, backlog, and experiment records.
   - Create `FINAL-REPORT.md` with actual evidence links.
   - Run final bounded `just` validation suites.
   - Ensure `STATUS.md` contains no unresolved high-priority design work.

## Iteration protocol

For each component:

1. Observe running UI and capture baseline/current state.
2. Read implementation and dependent behavior.
3. Research relevant current native/category patterns.
4. Obtain independent product, competitive, and native-iOS critique.
5. State hypothesis and measurable acceptance criteria.
6. Implement smallest coherent improvement.
7. Build and run through `just`/Xcode MCP.
8. Capture and directly inspect screenshot.
9. Obtain independent visual judgment.
10. Iterate only on identifiable user-visible problems.
11. Add deterministic tests for repeated or critical behavior.
12. Update this file, `STATUS.md`, evidence index, and experiment log.

## Live phase tracker

| Phase | Status | Accepted evidence / blocker |
|---|---|---|
| Completion audit | COMPLETE | Original program correctly classified incomplete; this plan created. |
| STATES-001 | COMPLETE | Accepted attempt 04. Post-fix live remote screenshot proves one `69.7 × 44.0` Retry; scanner permission plus AX3-dark and barcode loading/offline evidence accepted; functional UI target passed 11/11. |
| NUTRIENTS-001 | COMPLETE | Accepted attempt 01: optional API/cache facts, immutable snapshots, custom entry, coverage-gated balance, 3/3 critical/high visual approval, 140 hostless pass / 2 skips, 167 app-host pass / 2 skips, and 12/12 UI. |
| REFINE-001 | COMPLETE | Attempts 01–03 accepted: Plan references, reminders, hierarchical Settings, direct entry, optional calculator, explicit complete-day evidence, bounded proposal-only adaptation, Adapted source, exact revert, 3/3 visual approval, and 31/31 UI. |
| BULK-AI-FOOD-001 | COMPLETE | Attempt 01 accepted: typed/dictated local extraction, editable verified review, bounded local learning/drafts, custom recovery, atomic idempotent persistence, and 3/3 final critical/high approval. |
| AUXILIARY-001 | PENDING | No widget/Live Activity visual audit yet. |
| CONSISTENCY-001 | PENDING | Requires completed component set. |
| ROBUSTNESS-001 | PENDING | Partial Meal/Amount/Weight evidence only. |
| FINAL-001 | PENDING | `screenshots/final/` currently empty. |
| FINAL-REPORT | PENDING | File does not yet exist. |

## Refine

**Execution status:** COMPLETE. Attempts 01–03 Slices A–D accepted.

### 1. Competitor and safety research

Perform current, source-linked, screenshot-backed research before choosing UI or formulas:

- onboarding and calorie-goal setup in MacroFactor, MyFitnessPal, Lose It!, YAZIO, Lifesum, Cronometer, and Foodnoms;
- target-date feasibility, weight-loss-rate safeguards, maintenance/gain modes, manual overrides, and explanation quality;
- activity-level selection language and examples;
- weigh-in reminders, trend smoothing, adaptive expenditure/goal tuning, plateaus, and inaccurate-log handling;
- meal reminder scheduling and whether strong products use fixed events, configurable times, windows, or context-aware reminders;
- Apple Health/HealthKit and native iOS permission/settings patterns where relevant;
- authoritative calorie-estimation and safe-rate sources. Record formula assumptions, population limits, contraindications, and when professional advice is appropriate.

Separate category conventions, product-specific styles not to copy, and opportunities. Use independent product-design, nutrition-safety, and native-iOS critiques.

### 2. Welcome/setup flow — ATTEMPT 02 COMPLETE

Design a calm native welcome flow that asks only information required to produce an explainable plan. Candidate inputs, subject to research:

- goal mode: lose, maintain, or gain weight;
- current and target weight;
- desired target date or preferred weekly rate, with immediate feasibility feedback;
- age;
- height and any additional physiological input genuinely required by selected validated energy equation—never silently assume missing values;
- activity level with concrete descriptions: sedentary, light, moderate, and heavy/very active;
- preferred units;
- optional conservative safety margin, clearly defined and bounded so it cannot create an unsafe target;
- reminder preferences, including weight check-ins.

Use progressive disclosure, large native selection rows, clear back/continue controls, inline summaries, full VoiceOver labels, and no decorative questionnaire chrome. Preserve partially entered setup. Explain why each sensitive value is requested.

Attempt 02 deliberately omitted a separate “safety margin”: research did not establish a user-understandable validated meaning beyond bounded pace and calorie rules, so another adjustment would add false precision. Reminder choices also remain in their accepted contextual Settings editor instead of lengthening prerequisite setup.

### 3. Explainable daily calorie-goal calculator — ATTEMPT 02 COMPLETE

Research and specify before implementation:

- validated resting-energy equation and required inputs;
- transparent activity multiplier/range;
- target-date/rate energy adjustment;
- conservative rounding and user-controlled safety margin semantics;
- safe minimum/maximum and rate constraints, with infeasible-date handling instead of producing extreme calories;
- uncertainty language: result is an estimate, not a diagnosis;
- maintenance and weight-gain behavior;
- manual goal override and ability to restore calculated recommendation;
- exact calculation breakdown visible on demand;
- a companion theoretical nutrition composition for the selected calorie goal: adult macro reference ranges in both percent and derived grams using 4/4/9 kcal factors, plus fiber at 14 g/1,000 kcal;
- side-by-side reference-versus-real daily nutrient comparison, gated on complete relevant coverage and explicitly labeled general population guidance rather than a universal “ideal”;
- migration from existing `dailyCalorieGoal` without silently replacing user choice.

Add deterministic domain tests for units, boundaries, impossible dates, finite math, rounding, safety clamps, localization/calendar behavior, and migration.

### 4. Weight reminders and adaptive tuning

Add optional weight-entry reminders with configurable frequency/time and explain:

- consistent measurements help estimate trend and later tune calorie goals;
- single readings fluctuate and must not trigger plan changes;
- tuning requires sufficient recent measurements and food-log coverage;
- when trend differs from plan, neutrally suggest checking measurement consistency and logging completeness before changing calories;
- a stalled trend may indicate noisy/inaccurate measurements, incomplete intake logs, or an overestimated daily goal—never state one cause as fact;
- proposed calorie changes must be small, explainable, bounded, user-confirmed, reversible, and never applied silently.

Specification accepted in `../docs/adaptive-calorie-plan-specification.md`: 42 explicit complete days, distributed weigh-ins, coincident 28/35/42-day trend/intake estimates, evidence agreement, weekly fresh-evidence cadence, ±100 kcal proposal, 200 kcal/28-day cumulative bound, serialized mutation gateway, and exact revert. Keep raw logs intact; adaptive analysis consumes snapshots/trend and never overwrites measurements.

### 5. Configurable meal reminder times — ATTEMPT 01 COMPLETE

Competitor research supported exact times over ambiguous windows. Implemented design:

- independent Breakfast, Lunch, Snack, and Dinner reminder toggles;
- editable exact local time per meal, with legacy defaults;
- clear “only when not logged” behavior;
- local-calendar, timezone, DST, and overnight-window rules;
- collision/deduplication policy and system pending-notification cap;
- immediate preview of next reminder;
- denied-notification recovery without misleading enabled state.

Add deterministic schedule tests for custom windows, boundary minutes, DST, elapsed windows, existing meal suppression, preference independence, and rescheduling after edits.

### 6. Hierarchical Settings redesign

Design hierarchy after setup specification, likely:

1. **Plan** — current calorie goal, goal mode, target/rate/date, calculation summary, manual/calculated status, and calorie-goal-derived macro/fiber reference composition versus measured actuals.
2. **Profile & activity** — inputs used by calculation.
3. **Weight & adaptation** — weigh-in reminders, trend/tuning explanation, adjustment consent.
4. **Meal & water reminders** — compact summaries leading to focused editors.
5. **App preferences** — units and future display options.

Provide **Review or redo initial setup** using existing values preselected. Never discard settings until explicit confirmation. Decide one consistent save model: focused editor Save/Cancel or reliable immediate persistence, not a mixture. Include saved/error feedback and rollback.

### 7. Required critique, specification, and iteration artifacts

Before coding each Refine feature:

- append research URLs and screenshot findings;
- critique current app against findings;
- write user problem, scope/non-scope, data model, state machine, formulas, safety rules, accessibility, migration, privacy, and acceptance tests;
- use independent judges and preserve rejected attempts;
- implement one coherent slice at a time;
- build, run, capture, inspect, judge, and iterate;
- promote repeated setup/reminder/goal flows to deterministic UI tests;
- keep this plan, STATUS, backlog, experiments, screenshot index, and final report current.

### Refine guardrails

- No opaque “AI” recommendation or unexplained food/health score.
- No shaming language.
- No automatic calorie reduction from one weigh-in or short plateau.
- No unsafe target generated to satisfy an aggressive date.
- No medical diagnosis.
- No hidden assumptions for missing height/physiological/activity data.
- User can inspect, decline, override, and revert recommendations.

## Current next action

Commit accepted BULK-AI-FOOD-001 and reminder customization work. Then execute AUXILIARY-001 widget/Live Activity audit before CONSISTENCY-001, ROBUSTNESS-001, and FINAL-001.
