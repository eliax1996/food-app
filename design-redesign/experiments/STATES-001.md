# STATES-001 — Empty, loading, error, offline, and permission states

**Status:** ACCEPTED — ATTEMPT 04 / COMPLETE
**Started:** 2026-08-09
**Accepted:** 2026-08-09

## Purpose

Keep useful local tracking available when remote services, permissions, or persistence fail. Every state should explain what happened, preserve unaffected work, and expose one clear native recovery action.

Notification authorization and reminder-save semantics moved into deferred `REFINE-001`, where they can be designed with the requested reminder-window and Settings hierarchy instead of patched twice.

## Baseline

Existing behavior before this milestone:

- Remote food search preserved local/cached rows but delayed its loading indicator until after cache/debounce work.
- Remote errors exposed raw `localizedDescription` in red and showed both Retry and a second generic Search action.
- A terminal empty remote response returned to generic invitation copy instead of confirming no match.
- Barcode scanner unsupported/start failures dismissed into a generic alert with no permission-specific recovery.
- Barcode lookup dismissed Food Tools before its result and surfaced generic alerts, hiding custom-food recovery.
- Scanner cancellation from Meal editor could discard draft context.

Baseline audit references: `../01-baseline-audit.md`, `../02-design-log.md`, and prior FOOD-REMOTE-SEARCH-001 evidence.

## Research and independent critique

Verified Apple sources accessed 2026-08-09:

- [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators)
- [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)
- [ContentUnavailableView](https://developer.apple.com/documentation/swiftui/contentunavailableview)
- [AVCaptureDevice authorization status](https://developer.apple.com/documentation/avfoundation/avcapturedevice/authorizationstatus(for:))
- [Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications)

Narrow independent reviews identified these actionable gaps:

- remote loading did not cover cache/debounce wait;
- raw and duplicated remote recovery was weak;
- scanner denial was conflated with unsupported hardware and temporary startup failure;
- Food Tools had no local lookup failure/retry state;
- Meal editor draft state needed protection across scanner detours.

Category guidance retained from `../04-competitive-research.md`: local search and repeated logging remain primary; remote/scanner tools are progressive disclosure; service failure must not hide saved foods or custom-food creation.

## Hypothesis

Truthful progress plus compact typed recovery will reduce uncertainty and prevent users from mistaking remote failure for loss of saved/local food access.

## Acceptance criteria

- Loading covers complete cache/debounce/network work and stale requests cannot replace newer state.
- Terminal empty is distinct from initial/loading state.
- Offline, rate-limit, timeout/unavailable, and generic failures use calm actionable copy without HTTP/date/debug jargon.
- Saved and cached foods remain visible during remote failure.
- Exactly one remote retry action appears and measures at least 44 points high.
- Camera denial, unsupported hardware, and temporary scanner failure remain distinct.
- Permission denial offers Open Settings and manual barcode entry; scanner cancellation preserves Meal editor draft.
- Barcode lookup keeps Food Tools and custom-food work available until success.
- Invalid, not-found, incomplete, offline, unavailable, save, and generic barcode failures are typed and recoverable.
- DEBUG-only deterministic fixtures support screenshots and bounded UI automation without production behavior changes.

---

## Attempt 01 — Remote search states

Screenshots:

- ![Remote loading](../screenshots/STATES-001/attempt-01-remote-loading.png)
- ![Remote no matches](../screenshots/STATES-001/attempt-01-remote-no-matches.png)
- ![Rejected small Retry target](../screenshots/STATES-001/attempt-01-remote-offline-small-retry.png)

### Changes

- Coordinator sets loading synchronously for qualifying automatic and explicit work, then clears it through revision-safe success, cancellation, and failure paths.
- Added typed offline, rate-limited, unavailable, and generic presentation failures.
- Added terminal-complete state.
- Remote section shows one compact loading, no-match, or failure block while retaining saved/cached rows and attribution.
- Added DEBUG-only `zzslow`, `zzoffline`, and `zzunavailable` fixtures.

### Decision

**ITERATE**

State hierarchy and copy were accepted, but direct hierarchy inspection measured initial Retry control at about 20 points high. Code expanded it to a minimum 44-point target.

---

## Attempt 02 — Scanner permission and availability recovery

Screenshots:

- ![Scanner permission recovery](../screenshots/STATES-001/attempt-02-scanner-permission.png)
- ![Scanner permission recovery at Accessibility 3 in dark appearance](../screenshots/STATES-001/attempt-02-scanner-permission-ax3-dark.png)

### Changes

- Replaced scanner-owned generic alerts with a native SwiftUI recovery sheet around `DataScannerRepresentable`.
- Added typed `.cameraPermissionDenied`, `.unsupported`, and `.temporarilyUnavailable` states.
- Camera authorization now maps `.notDetermined`, `.authorized`, `.denied`, and `.restricted` explicitly.
- Permission denial offers Open Settings and manual barcode entry; temporary failure offers Retry; all states retain native Cancel.
- Scene-active refresh recognizes authorization changes after returning from Settings.
- Deterministic launch arguments cover each scanner state.
- Scanner cancellation from Meal editor now restores the same selected food and amount draft.

### Assessment

Normal light and Accessibility 3 dark evidence remain legible, unclipped, and task-focused. Actions preserve native hierarchy and adapt without fixed-height layout assumptions.

### Decision

**ACCEPT**

---

## Attempt 03 — Barcode lookup recovery inside Food Tools

Screenshots:

- ![Barcode lookup loading](../screenshots/STATES-001/attempt-03-barcode-loading.png)
- ![Barcode lookup offline recovery](../screenshots/STATES-001/attempt-03-barcode-offline.png)

### Changes

- Added typed invalid, not-found, incomplete, offline, unavailable, save-failure, and generic barcode failures.
- Loading and failure remain in Food Tools; only a successful product lookup dismisses into Log food.
- Offline copy explicitly preserves custom-food creation below the lookup state.
- Added deterministic barcode fixtures for delayed loading, not found, offline, and successful Fixture Granola handoff.
- Lookup tasks are cancellation- and generation-safe; dismissal cannot navigate later from stale completion.
- Failure state is associated with the submitted barcode, so delayed text callbacks cannot erase an immediate result.
- Barcode input disables during active lookup, preventing unsupported mid-request edits while Done still safely dismisses.
- Added a delayed DEBUG lookup fixture and explicit SwiftUI loading preview for deterministic screenshot evidence; functional not-found, offline, and success transitions remain exercised separately.
- Added stable title/message/input/action identifiers and preserved at least 44-point retry targets.

### Assessment

Food Tools remains a native Form. Loading is calm and truthful. Offline state keeps barcode, retry, and custom-food fields in one clear sequence without an alert or dead end.

Three independent final screenshot judges returned two `APPROVE` results. One reviewer objected to the apparent Done pill; it is the unmodified iOS 27 system confirmation toolbar control, so no custom replacement was made.

### Decision

**ACCEPT**

---

## Attempt 04 — Post-fix remote offline acceptance

Screenshot:

- ![Accepted remote offline recovery](../screenshots/STATES-001/attempt-04-remote-offline.png)

### Direct inspection

Rendered iPhone 17 Pro hierarchy proves:

- `No connection` and stable recovery copy are fully visible;
- Saved foods and Open Food Facts attribution remain present;
- exactly one `Try again` action appears;
- Retry measures `69.7 × 44.0` points;
- keyboard does not overlap or hide recovery content;
- no raw transport/debug output appears.

Three independent final screenshot judges returned two `APPROVE` results. One reviewer perceived Retry as text-sized and secondary text as weak. Measured hierarchy disproves the target-size concern; semantic system secondary styling remains consistent with native Form/List hierarchy and the other two reviewers accepted it.

### Decision

**ACCEPT — STATES-001 COMPLETE**

## Deterministic coverage

Focused and full UI coverage now protects:

- truthful remote slow loading followed by terminal no-match;
- direct remote offline recovery, one Retry, local Saved foods, and attribution;
- scanner permission denial to manual entry;
- scanner cancellation preserving Meal editor draft;
- barcode not-found, offline custom-food recovery, and successful Fixture Granola handoff.

Barcode loading remains deterministic preview/screenshot evidence rather than a transient XCTest assertion. The full functional target uses diagnostic phases and keeps every method below the 60-second per-test ceiling.

## Final validation

- `just iterate 240`: **passed** — 130 hostless tests, 2 opt-in live skips, simulator compile passed.
- `just validate 300`: **passed** — exact-tree hostless tests, simulator build, install, and launch passed.
- Focused changed UI tests: **passed**.
- `just test-ui 420`: **passed — 11/11 functional tests**; launch performance remains intentionally excluded.
- `just simulator-run 180`: **passed** before final live screenshot capture.
- Xcode MCP live capture: functional and visual pass; its session vanished after evidence return, so cleanup reported the known external invalid-session error. Retained screenshot and hierarchy were already complete.

## Deferred work

Notification denial, scheduling failure, reminder customization, and Settings save semantics remain required under `REFINE-001`. This is intentional sequencing, not silent acceptance of current reminder behavior.
