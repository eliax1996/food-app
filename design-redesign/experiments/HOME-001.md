# [HOME-001] Today dashboard

## Baseline

Screenshots:

- `../screenshots/baseline/counter-normal.png`
- `../screenshots/baseline/counter-entry-tools.png`

Problems:

- Percentage dominates useful remaining-calorie answer.
- Flat meals hide structure and subtotals.
- Daily dashboard includes custom-food and barcode forms.
- Core add action weak; lower forms sit beneath floating tab bar.

---

## Attempt 01

Screenshots:

- `../screenshots/HOME-001/attempt-01.png`
- `../screenshots/HOME-001/attempt-01-meals.png`

### Hypothesis

Remaining calories plus native meal sections will improve first-glance hierarchy.

### Changes

New calorie header, water progress, per-meal sections and local add rows, Food Tools sheet.

### Judge feedback

Device review found correct totals but 0/8 water due deterministic-state race, redundant header symbols, duplicate automation identifiers, 36pt toolbar action, and tab overlap.

### Own visual assessment

Status improved materially. Meal sections too tall; icon language noisy.

### Decision

ITERATE

### Reason

Daily state invalid and lower meal actions obscured.

---

## Attempt 02

Screenshots:

- `../screenshots/HOME-001/attempt-02.png`
- `../screenshots/HOME-001/attempt-02-meals.png`

### Hypothesis

Header plus actions will reduce vertical cost while preserving per-meal logging.

### Changes

Removed add rows, added header plus buttons, removed decorative meal icons, enlarged Food Tools sheet.

### Judge feedback

Water seed still overwritten by widget state. Header buttons measured only 19pt. Tab overlap persisted.

### Own visual assessment

Cleaner, but plus actions too weak and section spacing still excessive.

### Decision

ITERATE

---

## Attempt 03

Screenshots:

- `../screenshots/HOME-001/attempt-03.png`
- `../screenshots/HOME-001/attempt-03-meals.png`

### Hypothesis

Deterministic side-effect isolation, compact section spacing, and 44pt meal actions will make state valid and interaction robust.

### Changes

Disabled widget/reminder side effects in DEBUG review mode, fixed water lookup, 16pt section spacing, blue 44pt meal actions, unique summary identifier.

### Judge scores

Three independent overall scores: `7.0`, `7.0`, `7.0`.

### Judge feedback

All three flagged meal content intersecting floating tab bar. Secondary findings: weak add affordance, bulky water, low-contrast secondary text.

### Own visual assessment

Correct and clearer, but vertically fragmented. Judges' overlap finding visible in screenshot.

### Decision

ITERATE

---

## Attempt 04

Screenshot: `../screenshots/HOME-001/attempt-04.png`

### Hypothesis

Bottom safe-area inset on List will protect content from floating tab bar.

### Changes

Added clear bottom inset; strengthened meal headers.

### Judge feedback

Inset only added scrollable tail. Dinner still intersected tab by 39pt.

### Decision

REJECTED

### Reason

No visible improvement.

---

## Attempt 05

Screenshot: `../screenshots/HOME-001/attempt-05.png`

### Hypothesis

Native visible tab-bar material will prevent visible content collision.

### Changes

Requested regular tab-bar material/background.

### Judge feedback

iOS 27 floating tab remained unchanged; Dinner still obscured.

### Decision

REJECTED

### Reason

No effect; modifier removed.

---

## Attempt 06

Screenshots:

- `../screenshots/HOME-001/attempt-06.png`
- `../screenshots/HOME-001/attempt-06-breakfast.png`

### Hypothesis

One compact Meals group will fit all daily meal state above tab bar while retaining detail/edit flow through navigation.

### Changes

Combined calories and water into one summary surface, compacted calorie header, added full-width Log Food row, converted four meal sections into summary navigation rows, added meal detail screen with edit/delete/add behavior.

### Judge feedback

All four meal summaries became readable. Meal-detail navigation passed. Only lower More Ways section intersected tab.

### Own visual assessment

Large improvement in density, scanability, and native feel. Food names and totals remain visible.

### Decision

ITERATE

---

## Attempt 07

Screenshot: `../screenshots/HOME-001/attempt-07.png`

### Hypothesis

Moving secondary food tools into toolbar menu will eliminate final tab collision and clarify daily hierarchy.

### Changes

Removed More Ways list section; added native secondary menu. All primary content ends 32pt above tab bar.

### Judge scores

Three independent overall scores: `8.0`, `8.0`, `8.4`.

### Judge feedback

Hierarchy and native feel improved. Shared concerns: water control clarity/touch prominence and faint supporting text.

### Decision

ITERATE

---

## Attempt 08

Screenshot: `../screenshots/HOME-001/attempt-08.png`

### Hypothesis

Large explicit water buttons will resolve action clarity and touch concerns.

### Changes

Replaced Stepper with large bordered decrement/increment buttons; removed duplicate toolbar Log Food action.

### Own visual assessment

84×74 controls overwhelmed summary and broke visual balance.

### Decision

REJECTED

---

## Attempt 09

Screenshot: `../screenshots/HOME-001/attempt-09.png`

### Hypothesis

Regular circular button style will preserve clarity with less visual weight.

### Changes

Reduced bordered water controls.

### Judge feedback

Measured accessibility frames were 18×18 and 31×31, below target and asymmetric.

### Decision

REJECTED

---

## Attempt 10

Screenshot: `../screenshots/HOME-001/attempt-10.png`

### Hypothesis

Explicit semantic 44pt circles will balance repeated-use clarity with accessibility.

### Changes

Used equal 44×44 gray decrement and blue increment actions.

### Judge scores

Three independent overall scores: `8.3`, `8.0`, `8.6`.

### Judge feedback

One judge accepted. Shared remaining concern: faint supporting text. One pixel-only judge still perceived targets as small, contradicted by 44×44 hierarchy measurements.

### Decision

ITERATE

---

## Attempt 11

Screenshot: `../screenshots/HOME-001/attempt-11.png`

### Hypothesis

Higher semantic contrast for supporting labels will improve readability without flattening hierarchy.

### Changes

Changed important secondary labels from system secondary gray to 65%-opacity semantic primary.

### Judge feedback

Device review: labels legible and distinct; no clipping, overlap, or layout defect. Water controls measured 44×44. Snack row ends 32pt above tab bar. Calorie arithmetic and water mutations verified. Hostless 45-test gate passed.

### Own visual assessment

Calm, compact, and immediately legible. Remaining plainness is intentional native restraint, not missing hierarchy. More visual treatment would add decoration without solving a user problem.

### Decision

ACCEPTED

### Reason

All identified critical issues resolved: budget first, meal grouping, explicit logging, reachable secondary tools, valid deterministic state, measured touch targets, stronger contrast, and zero tab collision. Additional score-driven changes would be cosmetic or fight native iOS controls.
