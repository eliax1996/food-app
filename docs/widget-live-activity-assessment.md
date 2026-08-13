# Widget and Live Activity assessment

**Work item:** AUXILIARY-001
**Research date:** 2026-08-13

## Scope

Audit existing WidgetKit summary widget and ActivityKit Live Activity against accepted Today hierarchy, truthful persistence, accessibility, and native interaction behavior. This slice does not add lock-screen accessory widgets, watchOS, remote push updates, or historical charts.

## Current implementation

- Widget extension supports `.systemSmall` and `.systemMedium`.
- Both sizes show consumed calories, water glasses, **Add food**, and water decrement/increment controls.
- Live Activity starts implicitly from normal Today synchronization, then remains active without a visible app control or explicit end path.
- Live Activity attributes already contain calorie and water goals, but UI ignores both.
- Widget water intent updates App Group summary; app imports it when active and persists SwiftData.
- Live Activity water intent updates only displayed ActivityKit state and logs a stale TODO claiming App Groups are unavailable, even though both targets already possess matching App Group entitlements.

## Evidence and findings

Preview evidence on iPhone 17 Pro, iOS 27:

1. Small widget at normal text clips both metric values and **Add food**. Three actions cannot fit its width.
2. Small widget at AX3 clips almost every label and action. This is unusable.
3. Medium widget remains readable at normal and AX3, but reports `kcal today` rather than accepted primary answer, remaining/over goal.
4. Lock Screen Live Activity duplicates widget layout. It remains readable at AX3, but lacks goal context and lifecycle clarity.
5. Dynamic Island compact values have icons but no goal context; expanded layout has excess empty space and no status wording.
6. Implicitly starting an all-day Live Activity from ordinary app synchronization spends a persistent system surface without explicit user intent. There is no stop action or Settings control.
7. Widget and Live Activity water buttons have different truth semantics: widget changes shared durable summary, Live Activity changes display only. Identical controls must not imply identical persistence when behavior differs.

## Native/category constraints retained

- Widget views must be glanceable and family-specific; shrinking medium composition into `.systemSmall` is not acceptable.
- Interactive widget actions should complete quickly and write shared durable state when represented as completed actions.
- Live Activities should represent an active, bounded activity. User needs visible start/stop control when tracking does not have an inherent event boundary.
- Dynamic Island regions need compact semantic status, not full dashboard duplication.
- Deep links remain explicit app handoffs; **Log food** opens reviewed meal entry and never auto-inserts.

## Decision

### Widget

Keep only `.systemMedium` for this milestone. Small composition cannot truthfully fit remaining/over goal, water progress, and three actions at supported text sizes. Medium layout will:

- lead with remaining/over-goal calories;
- show eaten/goal context;
- show water as `x of y`;
- keep **Log food** plus bounded water controls;
- expose complete accessibility labels and disabled states;
- persist calorie goal and water goal in backward-compatible shared summary data.

### Live Activity

Make it explicitly user-controlled from Today:

- default state: no Live Activity;
- toolbar menu action **Start Live Activity**;
- when active: **Stop Live Activity**;
- start/update only while an activity exists—routine Today synchronization must not silently create one;
- end immediately on explicit stop;
- use remaining/over-goal status and water goal across Lock Screen and Dynamic Island;
- remove display-only water buttons from Live Activity. Keep **Log food** deep link only, avoiding false persistence.

## Acceptance criteria

1. Medium widget renders readable normal light, dark, and AX3 evidence with no clipping.
2. Widget displays remaining/over status, eaten/goal, and water progress from shared data.
3. Legacy shared summaries without goal fields decode with safe defaults.
4. Widget water controls remain bounded and durable through App Group summary.
5. App no longer starts a Live Activity implicitly.
6. Today exposes explicit start/stop action and truthful success/failure state.
7. Lock Screen, compact, minimal, and expanded Live Activity layouts show meaningful goal-aware status.
8. Live Activity contains no display-only mutation controls.
9. Build, deterministic model tests, app-hosted tests, functional UI, and source review remain green.
