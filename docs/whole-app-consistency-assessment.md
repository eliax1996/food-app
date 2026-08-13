# Whole-app consistency assessment

**Work item:** CONSISTENCY-001
**Date:** 2026-08-13

## Scope

Compare accepted app, widget, and Live Activity surfaces together. Audit terminology, typography, spacing, iconography, action hierarchy, navigation, empty/loading/error states, destructive behavior, accessibility wording, and shared calorie/water semantics. ROBUSTNESS-001 owns device-size and stress matrices; FINAL-001 owns refreshed full screenshot set.

## Evidence reviewed

- 126 retained accepted/baseline image files across all component folders.
- Representative current accepted surfaces: Today, Log food, Choose food, Food tools, Progress, Weight Log, Settings, Plan, Reminders, Goal check-ins, Nutrition balance, bulk review, widget, and Live Activity.
- Current SwiftUI action/title/state strings across all feature files.
- Three independent neutral source/evidence audits.

## Consistency system observed

### Navigation

- Root order and nouns are stable: **Today | Weight | Progress | Settings**.
- Root pages use large titles; pushed details use inline titles; modal work uses explicit Cancel/Save/Add/Done appropriate to transaction.
- Weight CRUD stays in Weight Log; Progress remains analytics-only.
- Settings uses summary rows into focused detail/edit surfaces.

### Information hierarchy

- Remaining/over calories lead Today, widget, and Live Activity.
- Orange represents calorie progress; blue represents water and weight; red is reserved for over-goal/destructive/error meaning with text or icon, never color alone.
- Forms use native grouped sections, standard row rhythm, monospaced numeric values, and secondary explanatory text.
- Charts use native axes and expose exact values through selection and accessibility.

### Action language

- **Log food** means begin or complete intake logging.
- **Describe meal** means start provisional typed/dictated extraction.
- **Add another food** means add a provisional row inside bulk review, not persist intake.
- Save/Cancel remain explicit for editable transactions; Done closes subordinate editors after draft application.
- Delete, discard, clear, disable, decline, and revert retain confirmation when destructive or health-sensitive.

### States

- Empty states pair plain explanation with direct recovery.
- Loading is scoped to current operation and preserves existing rows where possible.
- Network, permission, and unavailable-system states identify cause and offer contextual recovery.
- Unknown nutrition remains unknown; provisional model/default amounts stay visibly review-gated.

## Findings and fixes

### 1. Food action terminology drift

Meal detail used `Add Food` / `Add food`, while Today, modal title, widget, and Live Activity used accepted `Log food`. Bulk review also used `Add Food` for a non-persisting row action.

Fix:

- Meal detail empty and toolbar actions now use **Log food**.
- Empty copy now says **Log food when you're ready.**
- Bulk review row action now says **Add another food**, preserving semantic distinction from final `Log N Foods` confirmation.

### 2. Water bounds differed by entry path

Today and widget controls cap water at 30, but arbitrary `countcalories://water?delta=` values could exceed cap through deep links.

Fix:

- Deep links now accept only `-1` or `1`.
- Today adjustment clamps to `0...30` defensively.
- Deterministic tests reject unsupported large deltas.

## Accepted non-findings

- `Weight Log` title differs intentionally from root tab `Weight`: screen owns CRUD, tab names domain.
- Title-case action labels inside confirmation dialogs follow native alert conventions; in-content actions remain sentence case where appropriate.
- Bulk-review `Food 1` section labels and final plural `Log N Foods` are task-specific and not conflicting navigation nouns.
- Destructive `Disable goal check-ins` remains red and confirmed; its location below status is intentional safety friction.
- Medium-only widget is accepted scope because small family cannot fit truthful context plus three actions at supported text sizes.

## Validation

- Incremental app + widget build passed.
- App-hosted suite passed 300 tests / 2 opt-in live skips before this slice; affected suite passed after consistency fixes.
- Focused atomic bulk UI passed after action-copy change.
- AUXILIARY exact-tree validation remained 219 hostless / 2 opt-in live skips plus install/launch.
- Initial independent audit found food-copy drift, water deep-link bounds, and one approval. Findings fixed.
- Final independent critical/high consistency review: **APPROVE / APPROVE / APPROVE**.
