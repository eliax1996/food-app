# Competitive design research

Captured from current US App Store metadata/screenshots: 2026-08-08. Selected source assets and raw search metadata are retained under `research/competitors/`.

## Sources

- MyFitnessPal: https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718
- YAZIO: https://apps.apple.com/us/app/ai-calorie-tracker-by-yazio/id946099227
- Lifesum: https://apps.apple.com/us/app/lifesum-ai-calorie-counter/id286906691
- Cronometer: https://apps.apple.com/us/app/cronometer-calorie-counter/id1145935738
- MacroFactor: https://apps.apple.com/us/app/macrofactor-macro-tracker/id1553503471
- Lose It!: https://apps.apple.com/us/app/lose-it-calorie-counter/id297368629
- Foodnoms: https://apps.apple.com/us/app/nutrition-tracker-foodnoms/id1479461686
- Apple layout guidance: https://developer.apple.com/design/human-interface-guidelines/layout
- Apple navigation and search guidance: https://developer.apple.com/design/human-interface-guidelines/navigation-and-search
- Apple accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility

## Actual visual material inspected

- `foodnoms-1.jpg`: compact Food Log with date strip, goals, calorie/macro rings, and Breakfast entries.
- `foodnoms-3.jpg`: two-column Insights cards for streak, weight, macros, calories, balance, carbs, and fat.
- `lose-it-calorie-counter-2.jpg`: calorie budget ring plus meal-grouped log and meal subtotals.
- `macrofactor-2.jpg`: dense search, recent-food strip, result metadata, and direct plus actions.
- `lifesum-3.jpg`: breakfast-context search with often-tracked food chips and immediate text/voice entry.
- `cronometer-3.jpg`: target-aware macro/micronutrient progress rows.
- `myfitnesspal-2.jpg`: scan result review organized as breakfast items with explicit Log Breakfast action.
- `yazio-calorie-counter-3.jpg`: image-led recipes/meal-plan browse, useful as secondary discovery—not daily-log hierarchy.

App Store assets mix real product pixels with marketing frames. Findings below use only visible product patterns, not promotional claims as product evidence.

## Category conventions

1. **Budget first.** Remaining/under-budget calories dominate dashboard hierarchy.
2. **Meals organize logs.** Breakfast, lunch, dinner, and snacks carry subtotals and local add actions.
3. **Macros support calories.** Protein/carbs/fat appear as compact progress, not equal dashboard destinations.
4. **Fast repeated entry.** Recent/often-tracked foods and direct add affordances reduce search cost.
5. **Target context in history.** Strong products show goals, averages, balance, adherence, or trends—not raw bars alone.
6. **Scanner is part of logging.** Barcode/camera sits near food search, not as permanent dashboard form.
7. **Calm hierarchy beats equal cards.** Better screens choose one primary status, then progressively disclose detail.

## Product-specific style not to copy

- Foodnoms' orange brand field and dense multi-card Insights mosaic.
- MacroFactor's dark, high-density power-user visual identity.
- Cronometer's clinical nutrient depth on every surface.
- Lose It's green/orange ring and mascot-like brand language.
- YAZIO's decorative marketing colors and image-led recipe emphasis.
- MyFitnessPal's broad coaching/AI navigation scope.
- Promotional gradients, floating device mockups, ratings, and award badges.

## Opportunities for this app

1. Reframe Counter as **Today**, with remaining calories as dominant answer.
2. Group entries by meal and show each meal subtotal.
3. Replace persistent New Food/barcode forms with Food Tools adjacent to logging.
4. Make meal search primary inside a large native sheet; show recent choices when empty.
5. Add target rule and summary to calorie history.
6. Use line marks for weight trend instead of calorie-style histogram.
7. Add macros only after honest local persistence and incomplete-data handling exist.

## Independent review evidence

Bounded visual reviewers independently identified:

- core Add Meal action is buried;
- `1%` competes with more useful remaining-calorie number;
- floating tab bar appears to cover lower content;
- meal picker row is ambiguous;
- controls/secondary strings risk Dynamic Type and touch compression;
- category leaders communicate one primary outcome and faster repeated logging.

Large multi-image reviewer runs exceeded bounded time; smaller independent image reviews completed. This limitation is tracked in `STATUS.md` rather than represented as consensus.
