# Baseline audit

Captured: 2026-08-08
Device: iPhone 17 Pro, iOS 27.0, portrait, light appearance

## Build and launch evidence

- `just validate`: passed immediately before redesign work.
- Xcode MCP install/run: passed.
- Bundle `ch.elia.count-calories`: launched and remained running.
- Baseline flow: Counter → Add Meal → food selector → save → Counter tools → History calories/weight → Config/reminders.
- Functional failures during capture: none.

## Information architecture

Primary `TabView`:

1. **Counter** — daily calorie/water status, today's meals, custom-food creation, barcode lookup.
2. **History** — calorie and weight charts, current-weight entry.
3. **Config** — profile, target, reminders.

Modal flows:

- Add/edit meal sheet.
- Barcode scanner sheet.
- Weight picker sheet.

## Stable component inventory

| ID | Surface | Baseline evidence |
|---|---|---|
| NAV-001 | Three-tab primary navigation | all baseline screens |
| HOME-001 | Counter/dashboard | `screenshots/baseline/counter-normal.png` |
| CALORIES-001 | Daily calorie status | `screenshots/baseline/counter-normal.png` |
| WATER-001 | Water quick tracker | `screenshots/baseline/counter-empty.png` |
| MEALS-001 | Today's meal list | `screenshots/baseline/counter-normal.png` |
| MEAL-001 | Add/edit meal sheet | `screenshots/baseline/add-meal.png` |
| FOOD-SEARCH-001 | Expandable food selector | `screenshots/baseline/food-selector.png` |
| FOOD-ROW-001 | Food/meal rows | `screenshots/baseline/food-selector.png`, `counter-normal.png` |
| FOOD-CREATE-001 | Custom food form | `screenshots/baseline/counter-entry-tools.png` |
| BARCODE-001 | Manual lookup and scanner entry | `screenshots/baseline/counter-entry-tools.png` |
| HISTORY-001 | History shell/metric switcher | `screenshots/baseline/history-calories.png` |
| PROGRESS-001 | Calorie history chart | `screenshots/baseline/history-calories.png` |
| WEIGHT-001 | Weight history/entry | `screenshots/baseline/history-weight-empty.png` |
| SETTINGS-001 | Body and goal settings | `screenshots/baseline/config-top.png` |
| REMINDERS-001 | Meal/water reminders | `screenshots/baseline/config-reminders.png` |

## Existing visual language

- Native SwiftUI `NavigationStack`, `List`, `Form`, `Section`, `Picker`, `Stepper`, sheets, and system symbols.
- Semantic system background and grouped white list surfaces.
- Orange for calories, blue for water/weight, red only for exceeded goal.
- Large navigation titles and system typography.
- iOS 27 floating tab bar.
- Few custom visual primitives; most rounded surfaces come from native grouped lists.

## Strengths

1. Native controls and semantic colors provide a calm, familiar base.
2. Daily calories and water are both visible immediately.
3. Add/edit/delete behavior is complete; meal rows support swipe actions.
4. Barcode scanning, manual lookup, custom foods, reminders, history, and weight entry already exist.
5. Empty states are explicit rather than silent.
6. Screens remain visually coherent because they share system `List`/`Form` structure.

## High-impact problems

### Information architecture

- HOME-001 combines daily tracking with low-frequency food-database administration. Three custom-food fields and barcode form compete with daily status and push core content under floating tab bar.
- Meals are a flat chronological list. Meal type appears as tiny trailing metadata instead of organizing breakfast, lunch, dinner, and snacks.
- `Counter` and `Config` are implementation-oriented labels. `Today` and `Settings` better describe user destinations.

### Daily status

- `1%` is largest value while actionable number, `1685 kcal remaining`, is secondary gray text.
- Consumed and goal appear in one small caption. Meaning requires parsing.
- Calories and water use two thin progress bars inside calorie card, then water receives another separate section, duplicating hierarchy.
- No meal-level calorie totals or macro visibility.

### Repeated-use logging

- Core `Add meal` action is visually equal to list content.
- Meal editor opens at medium detent; amount controls sit near sheet edge.
- Food selection is hidden behind expandable row, then limited to five matches.
- Search, selection, amount, quantity, and final calories do not form a clear top-to-bottom task sequence.
- Confirmation label `OK` describes no outcome.

### History and progress

- Calorie bars annotate every value and date; dense histories will become noisy.
- No goal rule, average, adherence summary, or period context.
- Weight uses same histogram language as calories despite being continuous trend data.
- Weight entry row appears static until tapped.

### Settings

- `Config` is technical terminology.
- Numeric fields begin with bare values (`70,0`, `68,0`) while meaning exists mainly in section headers/placeholders.
- Reminder changes apply immediately, while profile changes require a bottom `Save configuration` row. Persistence semantics are inconsistent.
- Bottom save row and lower reminder controls sit beneath floating tab bar until scrolled.

## Visual/accessibility risks

- Floating tab bar visibly overlays lower Counter and Config content; reachable by scroll, but hierarchy appears broken.
- Secondary text is compact in meal/chart/reminder rows.
- Meal summary string (`1x, 100 g, 15 kcal`) has weak scanability and poor large-type resilience.
- Several values rely on color/progress alone for status.
- Current native colors should adapt to dark mode, but accepted components still require actual dark-mode evidence.
- VoiceOver grouping and custom value labels are sparse in summary and meal rows.

## Baseline state coverage

Captured:

- empty day;
- normal day after logging one meal;
- meal editor and food-filter expansion;
- populated calorie history;
- empty weight history;
- settings top and long reminder content.

Not yet captured in original app:

- near target;
- exceeded target;
- long meal names/large lists;
- dark mode;
- accessibility Dynamic Type;
- network loading/error and scanner permission states.

These states will use DEBUG-only deterministic review data during iteration.
