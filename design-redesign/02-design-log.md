# Component design log

## [HOME-001] Today dashboard

### Purpose

Answer three repeated daily questions quickly: calories remaining, what has been logged, and how to log next food/water.

### Current implementation

Grouped `List` containing daily calorie/water summary, separate water Stepper, flat meal rows, custom-food form, and barcode controls. Add/edit meal uses a medium/large sheet.

### Current strengths

- Calm native structure.
- Calories and water visible without navigation.
- Core add/edit/delete and scanner behaviors exist.
- Semantic orange/blue/red status colors.

### Problems

- Remaining calories is secondary to percentage.
- Low-frequency food administration crowds dashboard.
- Flat meal list hides meal organization and totals.
- Core log action has weak prominence.
- Lower fields appear beneath floating tab bar.
- Summary and meal strings are fragile at large text sizes.

### Competitive comparison

Foodnoms and Lose It foreground remaining budget, macro/goal status, and meal-grouped logs. MacroFactor and Lifesum expose immediate search plus recent/often-logged foods. Repeated category convention: status first, meal structure second, one-tap logging near each meal or persistent primary action.

### Native iOS comparison

Current use of `List`, semantic colors, `TabView`, and sheets is strong. Native review flags bottom safe-area overlap, compact stepper hit targets, weak VoiceOver grouping, and probable large-type crowding. Remedy should preserve native containers instead of introducing decorative cards.

### Missing opportunities

- Per-meal totals and add actions.
- Recent/frequent shortcuts.
- Goal-aware status language for near/exceeded states.
- Compact target-aware progress summary.

### Proposed direction

Make remaining calories dominant; expose consumed and goal as clear supporting values; keep water as compact quick action; organize entries by meal; move custom-food/barcode controls to secondary Food Tools sheet; rename primary action to `Log food`.

### Success criteria

- Remaining calories understood in under two seconds.
- Log Food visible without scrolling.
- Breakfast/lunch/dinner/snack organization and totals visible.
- All existing add/edit/delete/water/barcode/custom-food behavior preserved.
- No content appears trapped under floating tab bar.
- 44-point controls, useful VoiceOver values, no color-only status.
- Normal, empty, near-target, exceeded, and long-name states remain coherent.

### Hypothesis

Stronger status hierarchy plus meal-grouped rows will reduce parsing and repeated logging cost while removing administrative clutter from daily flow.

### Attempts

Eleven preserved attempts. Early section-based versions improved hierarchy but remained too tall. Two safe-area/material experiments had no effect and were rejected. Compact meal summaries plus navigable meal details solved density without removing edit/delete behavior. Water action variants were tested at 84×74, sub-44, then accepted at measured 44×44.

Accepted: `screenshots/HOME-001/attempt-11.png`.

Result: calorie answer, water actions, Log Food, and all four meal summaries fit without scrolling or tab collision. Secondary food tools remain available through native toolbar menu. Full evidence: `experiments/HOME-001.md`.

## [MEAL-001] Log food

### Purpose

Select meal and food, enter consumed amount/servings accurately, understand calculated calories, and commit with minimal friction.

### Current implementation

Large native Form sheet with segmented meal type, dedicated food navigation, scanner, exact numeric fields, serving presets, live total, and explicit Add/Save action.

### Current strengths

- Task sequence reads top to bottom.
- Exact inputs and presets support both accuracy and speed.
- Scanner remains adjacent to food choice.
- Calculated total is clear before commit.

### Problems

Original selector was hidden and slider-first. Attempt 01 had a narrow row hit region. Accessibility3 exposed sheet environment propagation and malformed Picker rendering.

### Competitive comparison

Lifesum and MacroFactor prioritize search, often-logged foods, and quick quantity controls. Current direction adopts category speed conventions without copying promotional color/AI styling.

### Native iOS comparison

Uses NavigationStack, Form, searchable list, segmented controls at normal sizes, and Menu rows at accessibility sizes. Cancel/Add semantics replace vague OK.

### Missing opportunities

Favorites and meal templates could further reduce repeated work, but recents solve immediate local repetition without new persistence.

### Proposed direction

Accepted normal design is attempt 03. Keep semantic typography and allow Accessibility sizes to become vertically scrollable rather than shrinking text.

### Success criteria

- Food selection within two taps for recent items.
- Exact amount fields visibly editable.
- Serving preset updates total immediately.
- Add/Save outcome explicit.
- Search selection and cancel/save behavior reliable.
- Accessibility text never clips; compact segmented controls become Menu rows.

### Hypothesis

Search-first selection plus exact inputs and live feedback will reduce logging errors and repeated interaction cost.

### Attempts

Three normal attempts. Attempt 03 received two independent ACCEPT verdicts (`8.7`, `8.6`) and one ITERATE (`8.1`). Luna `max` then verified Accessibility3 Menu rows and reachability without clipping. Accepted: `screenshots/MEAL-001/attempt-03.png`. Full evidence: `experiments/MEAL-001.md`.

## [FOOD-SEARCH-001] Choose food

### Purpose

Find a repeated or catalog food quickly and return its serving to Log Food.

### Current implementation

Dedicated native searchable list with Recently Logged and All Foods sections, live filtering, full-row buttons, and selected-food checkmark.

### Current strengths

- Recent choices appear before catalog.
- Search remains visible at top.
- Metadata consistently shows calories and serving.
- One-tap result selection updates editor amount and total.

### Problems

Original inline expansion clipped and limited results. First dedicated attempt had incomplete hit shape and bottom search overlap.

### Competitive comparison

Matches MacroFactor/Lifesum category convention of recents plus immediate search while retaining calmer native density.

### Native iOS comparison

Uses List, Section, searchable navigation drawer, semantic checkmark, and ContentUnavailableView for no results.

### Missing opportunities

Favorites and frequency ranking remain optional; current recency derivation needs no new model.

### Proposed direction

Keep current accepted native list. Do not add images or extra cards without evidence.

### Success criteria

- Recent food visible before typing.
- Search filters immediately.
- Entire result row is tappable.
- Long names and metadata remain readable.
- Selection returns with correct default serving.

### Hypothesis

Recents plus full catalog search will make repeated foods faster without hiding breadth.

### Attempts

Attempt 02 accepted after Banana search/select functional pass. Full evidence: `experiments/FOOD-SEARCH-001.md`.

## [HISTORY-001] Progress and weight

### Purpose

Explain calorie adherence and weight direction over time, then support quick weight recording.

### Current implementation

Segmented Calories/Weight List with one generic histogram component and a Current Weight button row.

### Current strengths

Native Charts, simple metric switcher, orange/blue semantic distinction, explicit empty state.

### Problems

Calories lack goal/average context; annotations become noisy; weight incorrectly shares zero-based bar language; Record Weight affordance is weak.

### Competitive comparison

Foodnoms and Cronometer interpret values against targets. Strong category products expose trend/balance rather than raw history alone.

### Native iOS comparison

Chart is appropriate, but semantic mark type should match data: bars for daily intake, line/points for weight. Standard RuleMark can show profile target without custom chart chrome.

### Missing opportunities

Seven-day average, goal rule, days near target, period weight change, and explicit empty-state recording action.

### Proposed direction

Rename destination Progress; add concise summary above target-aware chart; use a weight line chart; keep recording native and prominent.

### Success criteria

Trend and goal relationship understood in under three seconds; readable axes; no zero-based weight distortion; empty state leads directly to recording; Dynamic Type remains usable.

### Hypothesis

Target-aware summaries and data-appropriate charts will convert stored history into actionable feedback.

### Attempts

Baseline documented in `experiments/HISTORY-001.md`; implementation follows higher-priority search/amount backlog.

## [FOOD-TOOLS-001] Barcode and custom food tools

### Purpose

Preserve manual barcode lookup and custom-food creation without crowding repeated daily logging.

### Current implementation

Secondary toolbar menu opens large native Form with Barcode and Custom Food sections.

### Current strengths

Clear separation, exact units, keyboard-safe sheet, valid zero-calorie custom foods, and direct handoff into food selection.

### Problems

Original inline forms overwhelmed Today. Medium sheet clipped Save. Empty barcode action initially looked enabled despite semantic disablement.

### Competitive comparison

Category products place scanner/search adjacent to logging and move food-database administration out of dashboard hierarchy.

### Native iOS comparison

Large Form sheet, semantic disabled color, grouped fields, Done toolbar action, and explanatory footers follow native conventions.

### Missing opportunities

Deterministic UI fixture for successful barcode lookup would remove live-network dependence if this integration needs repeated end-to-end proof.

### Proposed direction

Keep current large sheet. Do not shorten merely to fill space; keyboard and Accessibility sizes need room.

### Success criteria

Tools remain discoverable; invalid barcode action looks disabled; custom food round trip works; no Today clutter; keyboard and large text remain reachable.

### Hypothesis

Progressive disclosure will improve daily hierarchy without removing advanced entry paths.

### Attempts

Attempt 04 accepted after custom-food create/search/select/cancel proof plus visible disabled-state correction. Full evidence: `experiments/FOOD-TOOLS-001.md`.
