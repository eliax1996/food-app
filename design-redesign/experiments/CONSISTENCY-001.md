# CONSISTENCY-001 — Whole-app consistency

**Status:** ATTEMPT 01 ACCEPTED — COMPLETE
**Date:** 2026-08-13

## Scope

Compare accepted app, widget, and Live Activity surfaces together. Reconcile terminology, hierarchy, typography, spacing, iconography, actions, empty/loading/error states, navigation, destructive behavior, and accessibility semantics. Detailed assessment: `docs/whole-app-consistency-assessment.md`.

## Review result

Root navigation, native grouped-form rhythm, semantic color roles, numeric typography, chart language, transactional Save/Cancel behavior, and destructive confirmations form one coherent system. Two actionable inconsistencies remained:

1. Meal detail mixed **Add Food/Add food** with accepted **Log food**, while bulk review reused **Add Food** for a non-persisting row action.
2. Arbitrary water deep-link deltas could bypass the `0...30` bound enforced by Today and widget controls.

## Accepted changes

- Meal detail empty recovery and toolbar now say **Log food**.
- Bulk review row insertion now says **Add another food**; final atomic action remains `Log N Foods`.
- Water deep links accept only one-glass `-1`/`1` adjustments.
- Today defensively clamps all adjustment requests to `0...30`.
- Deep-link tests cover oversized positive/negative rejection.

## Accepted intentional differences

- Root tab **Weight** opens CRUD screen **Weight Log**.
- Bulk provisional rows use numbered `Food N` sections and plural final confirmation.
- Alert action capitalization follows native dialog conventions.
- Red destructive goal-check-in actions retain explicit confirmation and safety friction.
- Medium-only widget remains accepted accessibility scope.

## Validation

- Incremental app + widget build passed.
- App-hosted affected suite passed 300 / 2 opt-in live skips.
- Hostless suite passed 219 / 2 opt-in live skips.
- Focused atomic bulk UI passed after copy change.
- `git diff --check` passed.
- Final independent critical/high consistency review: **APPROVE / APPROVE / APPROVE**.

## Decision

**ACCEPTED — ATTEMPT 01 / COMPLETE.** Next: ROBUSTNESS-001.
