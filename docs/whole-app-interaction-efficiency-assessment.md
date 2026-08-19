# Whole-app interaction-efficiency assessment

**Evidence access:** retained sources accessed **2026-08-08, 2026-08-10, 2026-08-11, and 2026-08-12**, matching source assessments. **Implementation read:** final SwiftUI feature files and UI-test names. **Scope:** accepted implementation and closed decision archive. **Coverage:** whole product plus BACKLOG-CLOSURE-001 follow-ups.

## Audit convention

- **Action count** = deliberate user activations after arrival at named starting point. Text entry, typing, system permission choice, scrolling, and confirmation each count when required. Back/Cancel omitted unless task needs recovery.
- **Before** = pre-current efficiency iteration documented in retained experiment/assessment; `—` means no comparable measured baseline, not no prior UI.
- **Floor / target** = safety minimum / preferred repeat-use path. Safety confirmations intentionally add actions.
- **Competitor evidence** describes only cited first-party material. `Unknown / not established` means retained first-party evidence does not establish behavior; it does **not** claim feature absence.

## Competitive guardrails

| Product | Retained first-party evidence | Interaction lesson admitted by evidence | Boundary for Count Calories |
|---|---|---|---|
| MacroFactor | [Dashboard](https://help.macrofactorapp.com/en/articles/22-get-to-know-your-dashboard), [weight logging](https://help.macrofactorapp.com/en/articles/15-log-your-weight), [AI food logging](https://macrofactorapp.com/ai-food-logging/), accessed 2026-08-08/12 | Broad daily log/analytics; inspectable database-grounded AI result; barcode faster for one packaged item; approved weekly coaching evidence. | Keep direct food/barcode primary; bulk stays review-first. Do not claim equivalent algorithm or copy power-user styling. |
| MyFitnessPal | [Today](https://support.myfitnesspal.com/hc/en-us/articles/39985611667341-Your-Today-tab), [add food](https://support.myfitnesspal.com/hc/en-us/articles/360032274592-How-do-I-add-a-food-to-my-food-diary), [Voice Logging](https://support.myfitnesspal.com/hc/en-us/articles/30332897072269-Voice-Logging), [meal reminders](https://support.myfitnesspal.com/hc/en-us/articles/360032622391-Can-you-send-me-a-reminder-if-I-forget-to-log-a-meal), accessed 2026-08-08/10/12 | Today/Progress separation; voice advances to editable results then explicit Log; exact meal times. | Keep one explicit save/log and focused reminder timing. No claim about its keypad or bulk typed flow. |
| Lose It! | [calorie budget](https://loseit.zendesk.com/hc/en-us/articles/47497714327060-How-the-Calorie-Budget-is-Calculated), [start plan](https://loseit.zendesk.com/hc/en-us/articles/47649627723540-How-to-Start-a-New-Weight-Loss-Plan), [projection dates](https://loseit.zendesk.com/hc/en-us/articles/51382148864532-Understanding-Goal-and-Streak-Projection-Dates), accessed 2026-08-10 | Sequenced plan inputs; distinguish projection contexts; hide unsupported extreme projection. | Setup remains staged; unsafe date produces recovery, not forced calories. Food/bulk/reminder mechanics: Unknown / not established. |
| YAZIO | [calorie calculation](https://help.yazio.com/hc/en-us/articles/4410156873233-How-does-Yazio-calculate-my-calorie-goal), [activity examples](https://help.yazio.com/hc/en-us/articles/360005363638-Which-activity-level-should-I-choose), [reminders](https://help.yazio.com/hc/en-us/articles/4406890595601-Set-Up-Reminders-in-Yazio), accessed 2026-08-10 | Explain equation/routine; exact reminder times; manual control remains. | Concrete routine choices, explicit times, manual override. Bulk behavior: Unknown / not established. |
| Lifesum | [change goal](https://help.lifesum.com/en/article/how-do-i-change-my-goal-1ow4ip1/), [maintain mode](https://help.lifesum.com/en/article/can-i-use-lifesum-to-maintain-my-weight-z6naxb/), [iOS notifications](https://help.lifesum.com/en/article/how-can-i-manage-push-notifications-on-my-phone-ios-33fnrk/), accessed 2026-08-10 | Focused goal flow; maintain mode; app preferences separate from iOS notification delivery. | Focused Plan transaction; show selected-vs-deliverable truthfully. Food/bulk/weight flow: Unknown / not established. |
| Cronometer | [Mobile Diary](https://support.cronometer.com/hc/en-us/articles/360018593112-Mobile-Diary-Overview), [Mobile Charts](https://support.cronometer.com/hc/en-us/articles/360019864311-Mobile-Charts), [Weight Goal](https://support.cronometer.com/hc/en-us/articles/32978027080980-Mobile-Weight-Goal), [Notifications](https://support.cronometer.com/hc/en-us/articles/360051718511-Mobile-Notifications), accessed 2026-08-08/10 | Diary/chart separation; review-before-save goal flow; exact/conditional reminders; dense nutrient report. | Use native progressive disclosure, not dense branded card copy. Typed/dictated multi-food review: Unknown / not established. |
| Foodnoms | [track weight](https://foodnoms.com/help/track-weight), [Calibrated Energy](https://foodnoms.com/help/calibrated-energy), [automatic calorie goal](https://foodnoms.com/help/automatic-calorie-goal), [privacy](https://www.foodnoms.com/privacy), accessed 2026-08-08/10/12 | Calories first; weight/energy evidence can be proposal-only; public privacy page distinguishes AI transport. | Preserve on-device/raw-data truth and explicit proposal. Do not imply identical evidence model or AI transport. |

### Weight-specific comparison

| Evidence | Established pattern | Count Calories decision |
|---|---|---|
| [Apple Health](https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/ios), [Happy Scale](https://happyscale.com/support), [Withings measurements](https://support.withings.com/hc/en-us/articles/39334195353233-Withings-App-Viewing-my-measurements), [Weight Diary Lite](https://www.curlybrace.co.uk/weightdiaryfree), [Weigh In](https://weighin.app/), accessed 2026-08-08 | Metric context can separate record, chronological history, and progress/reporting; retained evidence supports dated records and dedicated weight surfaces. | Root Weight owns raw record/edit/delete; Progress owns read-only fuller chart. Preserve same-day raw readings. No claim that any named product uses Count Calories’ exact seven/fourteen-reading limits, undo stack, or chart gesture. |

## Before → current summary

| Change | Before | Current final | Decision |
|---|---:|---:|---|
| Today scan | 2 | **1** toolbar tap | Implemented; scanner is direct primary shortcut. |
| Recent/frequent food selection | 4 | **3** | Implemented; direct editor shows recent buttons and empty search adds derived frequently logged foods without another index. |
| Custom food, create-to-review | 6 | **4** | Implemented; toolbar menu → Custom Food → Save → Log food review. Keep explicit save. |
| Normal scanner manual fallback | unavailable / detour | **1** action from scanner state | Implemented; `Enter barcode manually` opens Food tools. |
| Meal delete | 1 | **2** | Intentional safety cost: swipe Delete → confirmation. |
| Goal check-ins entry | 2 | **1** from Settings root | Implemented direct Settings row; Plan retains related route. |
| Meal reminder controls | tapping a meal opened an editor and implied one-meal scope | passive time + Enabled/Disabled rows; one **Customize Meal Reminders** menu splits enablement from timing | Implemented after usability review; no meal row pretends to be an action. |
| Manual goal | repeated 50-kcal Stepper taps | direct keyboard entry + Done | Implemented; bounds still clamp 1,000–5,000. |
| Setup progress | misleading fixed progress | branch-aware step count | Implemented truth correction: Maintain skips Pace; review count updates. |
| Progress exact point | unsupported | **1** tap or drag gesture | Implemented nearest recorded point; VoiceOver adjustable action cycles points. |
| Adaptive revert | 1 | **2** | Intentional safety: Revert → exact-value confirmation. |
| Bulk | N/A | review + explicit estimate acceptance + atomic `Log N Foods` | Implemented and accepted; per-row acceptance remains intentionally required before Log. |

## Screen-by-screen audit

### Today, meals, food discovery, tools

| Surface/state | Primary task; start | Before → final current actions | Floor / target | Implemented decision; competitor boundary |
|---|---|---|---|---|
| **Today** | See remaining calories; Today tab / launch | Dashboard had inline administrative forms and weaker add hierarchy → scan **1**, Log food **1**, Describe **1**, water ± **1**, meal detail **1** | Floor: calorie status, water, food-log state visible; target: one action to chosen entry path | Implemented budget-first List, four meal summaries, toolbar scanner, secondary tools menu. Native rows/buttons; no competitor dashboard copied. |
| **Today food-log states: In progress / Complete / Needs review** | Attest today after logging; Today status | No explicit evidence state → nonempty mark/reconfirm **1**; empty needs Mark + `I ate nothing today` **2** | Floor: missing never equals zero; target: one nonempty attestation | Implemented stale-on-food edit, genuine-zero confirmation, no auto-complete. MacroFactor/Foodnoms evidence supports careful partial-day handling, not these exact controls. |
| **Meal detail — empty** | Add food to selected meal; Today → meal row | Flat meal sections → row **1**, Add Food **1** | Floor: empty names meal and gives recovery; target: two actions to editor | Implemented native empty state; no invented meal. |
| **Meal detail — populated** | Inspect/edit/delete meal row; Today → meal row | Flat list → detail **1**, tap edit **1** or swipe Delete + confirm **2** | Floor: deletion cannot full-swipe; target: one tap to edit | Implemented detail and destructive confirmation. MyFitnessPal/Cronometer retain diary editing evidence; exact row mechanics Unknown / not established. |
| **Log food** | Add/edit one food; Today/meal Add | `OK`, inline limited search, keyboard-first correction → Add **1**, choose **1**, amount nudge **1**, Add/Save **1** | Floor: explicit Save, valid positive amount/servings; target: default food **2** total | Implemented full-height native Form, contextual scanner, exact fields, `−10/−1/+1/+10`, keyboard Done. Do not claim competitor +/- controls. |
| **Choose food — local** | Pick saved/recent/frequent food; Log food → Choose | Inline five-result filter → Choose **1**, result **1** | Floor: full-row 44pt selection and selected checkmark; target: recent pick **1** from editor | Implemented dedicated native search/List; empty search orders recent then count/recency-ranked frequent then catalog. MacroFactor/MyFitnessPal evidence establishes direct food/serving context, not this exact path. |
| **Choose food — remote** | Discover un-saved food; type ≥3 graphemes | No discovery → query, debounce, one remote selection **1** after result | Floor: local/cache remains; attribution; no duplicate search; target: select result once | Implemented cached Search-a-licious path, 750 ms debounce, explicit Load more. Retained Open Food Facts evidence, not nutrition-competitor behavior. |
| **Choose food — loading / empty / offline / unavailable** | Recover without losing local path; Choose food search | Late/raw/duplicated failure → one visible loading state; one Retry or alternate query | Floor: one 44pt retry, saved foods stay visible, no raw transport text | Implemented typed state blocks. Rejected oversized empty `ContentUnavailableView`: keyboard cost. |
| **Scanner — normal** | Scan one packaged item; Today toolbar or Log food | Today scan 2 → **1** | Floor: request camera only in context; manual fallback always present | Implemented VisionKit scan sheet. MacroFactor first-party AI article says barcode faster for one packaged product; no copied scanner UI. |
| **Scanner — denied** | Recover camera denial; scanner sheet | Generic dismissal → Open Settings **1** or manual **1** | Floor: permission-specific copy, Cancel; draft preserved from Log food | Implemented; permission never requested at launch. |
| **Scanner — unsupported / temporarily unavailable** | Recover hardware/start failure; scanner sheet | Generic alert → manual **1**; temporary state Retry **1** | Floor: distinguish unsupported from temporary failure | Implemented typed states. |
| **Food tools — barcode** | Manual barcode lookup; toolbar More → Enter barcode | Inline Today form / dismissal on error → menu **1**, manual entry, lookup **1** | Floor: 8–14 digits, inline typed recovery, custom food survives failure | Implemented large Form; only success enters Log food. |
| **Food tools — custom food** | Define food; toolbar More → Create | Create-to-review 6 → **4** | Floor: name, nonnegative kcal, positive serving; explicit save before selection | Implemented Custom Food in Food tools; menu progressive disclosure. Rejected medium sheet clipping and blue-looking disabled lookup. |
| **Nutrient editor** | Add optional custom-food facts; Food tools → Nutrients | No nutrient input → link **1**, fields, Done **1**, Food-tools Save **1** | Floor: blank = unknown, not zero; target: no required nutrient fields | Implemented local draft and explicit Done. Cronometer dense-report precedent does not establish custom-editor behavior. |

### Bulk describe/dictate flow

| Surface/state | Primary task; start | Before → final current actions | Floor / target | Implemented decision; competitor boundary |
|---|---|---|---|---|
| **Describe meal** | Type multi-food description; Today → Describe | Repeated single-food flow → Describe **1**, type, Find Foods **1** | Floor: direct Log food remains first; description editable; no microphone permission for typing | Implemented staged large sheet and local-processing disclosure. Foodnoms supports typed-summary claim; exact controls Unknown / not established. |
| **Dictation: idle / permission / preparing / listening / finishing / failed** | Fill same text field; Describe → Dictate | No path → mic tap **1**, Stop **1** | Floor: contextual microphone request, no saved audio, typed fallback persists | Implemented stateful label/status and local transcript insertion. MyFitnessPal evidence supports permission-at-use and explicit result advance; Apple availability is source basis. |
| **Extracting** | Wait/cancel structuring; Find Foods | N/A → Find **1**, Cancel **1** if needed | Floor: no logging while extracting; cancellation retains text | Implemented explicit on-device progress. |
| **Review** | Resolve every row, choose meal, commit batch; extraction/manual rows | N/A → edit/query/match as needed; estimated amount requires **Use Estimated Amount 1**; `Log N Foods` **1** | Floor: each selected record visible; unresolved/loading/estimate blocks readiness; Log is atomic | Implemented rows, candidate dialog, retry/remove, disabled total button. MacroFactor/MFP evidence supports inspect/edit then explicit log; no chat UI. |
| **Draft restored / cancel** | Resume, keep, discard unlogged work; Describe open / Cancel | N/A → Resume automatic presentation; Cancel → Keep Draft or Discard **1** | Floor: Cancel inserts zero foods; background review saves one bounded draft | Implemented 7-day local draft and explicit destructive choice. |
| **Model unavailable** | Continue without Apple model; Describe | N/A → Add Rows Manually **1** | Floor: iOS/device/locale/model state named; direct Log never blocked | Implemented manual review fallback. Foundation-model availability—not competitors—sets behavior. |

### Nutrition, weight, progress

| Surface/state | Primary task; start | Before → final current actions | Floor / target | Implemented decision; competitor boundary |
|---|---|---|---|---|
| **Nutrition balance — empty** | Learn why no balance yet; Today | No nutrition view → detail **1** | Floor: no invented facts/score; target: compact invitation | Implemented calories-first row with empty explanation. |
| **Nutrition balance — complete** | Inspect measured macros/fiber/guidance; Today → row | No persisted nutrients → detail **1** | Floor: coverage gates; food-label calories authoritative; max two neutral suggestions | Implemented macro-only split separate from AMDR denominator, source links, nonmedical copy. Foodnoms/Cronometer establish broad hierarchy only. |
| **Nutrition balance — partial** | See known values without false comparison; Today → row | Unknown treated absent → detail **1** | Floor: exact coverage, guidance paused, missing never zero | Implemented partial grams plus explicit pause. |
| **Weight Log — empty** | Record first weight; Weight tab | Weight was nested/combined in Progress → Weight **1**, Record **1**, Save **1** | Floor: useful prompt, no dead chart; target: two actions from Weight to saved default | Implemented root Weight and first-reading prompt. Apple/Happy Scale/Withings/Weight Diary Lite/Weigh In support separation, not exact count. |
| **Weight Log — populated** | Review raw dated readings / open trends; Weight | Mixed Progress record → Weight **1**, row edit **1**, View full trends **1** | Floor: newest-first local-date groups; preserve same-day readings; target: one tap to edit or trends | Implemented seven-reading context, raw list, handoff. |
| **Weight editor** | Record/correct value/date/time; Record or row | Profile default + keyboard only → open **1**, optional ± **1**, Save **1** | Floor: latest valid reading default, valid nonfuture timestamp, Save separate from keyboard Done | Implemented `−1/−0.1/+0.1/+1`, direct decimal entry, 2×2 AX layout. |
| **Weight delete / undo** | Safely remove one raw reading; row swipe | Unspecified → Delete **1**, confirm **1**, Undo **1** optional | Floor: no full swipe; confirm before mutation; restore exact snapshot | Implemented intentional transaction cost and stacked undo. |
| **Progress — Calories** | Read seven recorded-day trend; Progress tab | Raw bars/no target context → Progress **1**, exact point tap/drag **1** | Floor: historical goal unavailable stated, not fabricated; target: one gesture reveals exact day | Implemented nearest-point selection. VoiceOver adjustable action cycles dates. |
| **Historical Food Diary** | Explain or correct selected recorded day; Progress point → View Day | Totals only → View Day **1**, item **1**, then explicit edit/copy/delete or Log Food **1** | Floor: legacy provenance remains limited; future/stale/duplicate writes fail closed; destructive delete confirms and offers undo | Implemented date-first known-snapshot add/edit/copy/delete/undo under atomic coordinator; generic mixed history rejected. |
| **Progress — Weight** | Read fourteen raw readings; Progress → Weight segment | No exact inspection → segment **1**, exact point tap/drag **1** | Floor: analytics cannot mutate log; target: one gesture reveals raw time/value | Implemented nearest-point detail and VoiceOver adjustable action. |

### Settings, plan, adaptation, profile, reminders, data controls

| Surface/state | Primary task; start | Before → final current actions | Floor / target | Implemented decision; competitor boundary |
|---|---|---|---|---|
| **Settings root** | Route to Plan, Goal check-ins, Profile, Reminders, local data; Settings tab | Flat mixed form → tab **1**, row **1** | Floor: summaries do not mutate; target: one row to focused task | Implemented native hierarchy. MacroFactor/MFP/Cronometer broad hierarchy supports separation; no copy. |
| **Plan** | Inspect goal/source/basis/reference/optional personal targets; Settings → Plan | Flat settings → Settings **1**, Plan **1** | Floor: Manual/Calculated/Adapted/Unknown truthful; general references never become silent prescription | Implemented current plan, check-ins, calculated basis, references, measured coverage, and explicit Set/Edit/Use General References target flow. |
| **Edit Plan** | Change manual goal/context; Plan → Edit | repeated 50-step taps → Edit **1**, keyboard direct entry, Save **1** | Floor: 1,000–5,000 validation, Save/Cancel transaction, no retroactive food edits | Implemented direct keyboard, Stepper remains bounded alternate. YAZIO/Lifesum support manual control, not exact entry. |
| **Goal check-ins — off** | Enable evidence collection; Settings root → Goal check-ins | 2 → **1** root route | Floor: calculated/adapted source and explicit scope confirmation required | Implemented off explanation + Enable; Manual/Unknown route to setup instead. |
| **Goal check-ins — collecting** | Learn exact missing evidence; check-ins | Opaque/no adaptation → enter **1**, optional yesterday mark **1** | Floor: 42 complete days, distributed weights, dates/counts visible; no estimate | Implemented exact requirements, earliest date, method disclosure. MacroFactor/Foodnoms establish evidence/proposal category only. |
| **Goal check-ins — Check data / Up to date** | Understand no proposal; check-ins | N/A → enter **1** | Floor: disagreement/limits displayed; no automatic change | Implemented neutral evidence state and limitations. |
| **Goal check-ins — proposal** | Inspect then apply/decline/close; check-ins | N/A → Use **1** + confirm **1**, Decline **1** + confirm **1**, or Close **1** | Floor: close/decline preserve goal; explicit application only | Implemented persisted proposal, evidence rows, cadence. |
| **Goal check-ins — applied / revert** | See Adapted goal, restore exact prior value; check-ins | revert 1 → **2** intentionally | Floor: raw food/weight unchanged; revert only current revision | Implemented Revert + named confirmation. |
| **Goal check-ins — corrupt/unknown/unavailable** | Preserve goal and recover; check-ins | N/A → Review calculated setup **1** | Floor: unknown never becomes Manual; proposal unavailable; fail closed | Implemented Unknown source / missing-basis pause. |
| **Profile** | Inspect age/calculated context/privacy; Settings → Profile | Flat form → Settings **1**, Profile **1** | Floor: no inferred identity; no recalculation on inspection | Implemented read-only context and explicit Edit. |
| **Edit Profile** | Change age; Profile → Edit | Flat save → Edit **1**, adjust, Save **1** | Floor: Save/Cancel; context change does not silently alter current goal | Implemented one-field editor through coordinator. |
| **Reminders root** | Inspect schedules/delivery/next reminder; Settings → Reminders | Flat switches with mixed persistence → Settings **1**, Reminders **1** | Floor: selected preference distinct from iOS permission/delivery | Implemented summary, denied recovery, next planned item. |
| **Meal reminder summary + customization** | Understand all four schedules, then change enablement or timing; Settings → Reminders | Misleading meal-row editor → passive rows show exact time + Enabled/Disabled; **Customize Meal Reminders** **1**, choose enablement or timing **1**, Save **1** | Floor: summary rows never mutate or imply singular scope; enablement and times remain independent; permission only after enabled Save | Implemented mode-specific sheets: four switches with no time controls, or four time controls with no switches. MFP/YAZIO/Cronometer establish exact-times category, not this exact layout. |
| **Focused Weight reminder editor** | Set off/daily/weekly/time; Reminders → Weight row | All controls shown → **1** from Reminders / **2** root | Floor: weekly waits seven days after latest weight; Save/Cancel | Implemented focused Weight-only controls. |
| **Focused Water reminder editor** | Enable fixed-window water schedule; Reminders → Water row | All controls shown → **1** from Reminders / **2** root | Floor: independent schedule; no sensitive lock-screen values | Implemented Water-only toggle and clear fixed-window copy. |
| **Cross-category reminder editing** | Change meals, weight, or water; Reminders | One broad editor mixed unrelated controls → category summary then focused meal mode, Weight row, or Water row | Floor: each sheet is one draft transaction; permission only after enabled Save | Broad editor removed after usability review. Category-specific routes preserve context and reduce accidental cross-category edits. |
| **Meal Description & Draft Data** | Inspect/clear local learned choices or draft; Settings → row | No controls → Settings **1**, row **1**, destructive confirmation **1** | Floor: clear never deletes logs/saved foods; local transport disclosure | Implemented counts, separate confirmations, on-device explanation. |

### Calculated setup

| Setup page/state | Primary task; start | Before → final current actions | Floor / target | Implemented decision |
|---|---|---|---|---|
| **Welcome** | Decide supported setup vs manual; automatic/new setup or Plan | No explainable calculator → scope toggle **1**, Continue **1**, or Keep manual **1** | Floor: no default inferred body/equation; skip preserves manual goal | Implemented skippable/resumable entry. |
| **Goal** | Choose Lose/Maintain/Gain; Continue from Welcome | N/A → choice **1**, Continue **1** | Floor: mode changes no goal until final confirmation | Implemented full first-class modes. |
| **Body Details** | Enter units, current/target weight, age, height | N/A → required values then Continue **1** | Floor: metric/US preserve canonical values; relation/BMI/domain validation inline | Implemented direct numeric fields and keyboard Done. |
| **Equation** | Choose published constant | N/A → choice **1**, Continue **1** | Floor: label equation, not gender identity; manual route remains | Implemented female −161 / male +5 explanation. |
| **Daily Routine** | Select non-workout routine | N/A → choice **1**, Continue **1** | Floor: no tracker/workout double count | Implemented four concrete routine choices. |
| **Pace** | Select rate or date | N/A → rate/date choice **1**, Continue **1** | Floor: reject unsupported date/rate; no clamp to unsafe goal | Implemented 0.25/0.50 kg/week or future date. |
| **Review Plan** | Inspect formula and accept/keep current goal | N/A → Use calculated **1** or Keep current/manual **1** | Floor: explicit one-save acceptance; breakdown/limitations visible | Implemented source and retained basis. |
| **Unsupported / infeasible** | Recover from out-of-scope/body/date/calorie issue | N/A → Back **1** or Close **1** | Floor: current manual goal unchanged, actionable reason, no recommendation | Implemented typed recovery. |

## Preserved safety, permission, privacy, accessibility

- **Confirmations retained:** genuine-zero food completion; meal delete; weight delete; adaptive apply, decline, disable, revert; clear learned choices; discard draft. These are intentional action costs.
- **Permissions:** camera only after Scan; microphone only after Dictate; notification request only after saving enabled reminder. Denial leaves manual/typed paths usable and exposes Settings recovery where applicable.
- **Privacy:** profile, plan, evidence, meal text, dictation, draft, and learned corrections stay on device; audio is not saved. Only individual derived food queries/barcodes may go to Open Food Facts. No claim that all bulk data stays local.
- **Accessibility/native floor:** `NavigationStack`, `List`/`Form`, native sheets, pickers, DatePickers, alerts, system keyboard toolbar, Dynamic Type reflow, non-color status text, 44pt app-owned actions. Charts expose point detail by tap/drag plus VoiceOver adjustable actions. Native controls may retain platform hit slop and appearance.

## Native iOS, not competitor copy

Use competitor evidence for problem framing only: calorie-first daily action, inspect-before-log, exact reminder timing, focused plan flow, record/history/analytics separation, and proposal-only adaptation. Count Calories uses native SwiftUI hierarchy, labels, data rules, thresholds, charts, and confirmations. Do not reproduce competitor chrome, branded scores/rings, chat transcripts, undocumented action counts, or claimed algorithm quality.

## Closed opportunity dispositions

| Opportunity | Final status | Rationale |
|---|---|---|
| Historical known-item mutations | Implemented | Separate date-first provenance/attestation/goal/duplicate/undo contract preserves semantics; generic mixed journal stays rejected. |
| Personal macro/fiber targets | Implemented | Values are user-entered, local, complete-set validated, distinct from retained general references, and coverage-gated. |
| Reminder windows | Permanently rejected from current scope | Retained MFP/YAZIO/Cronometer evidence supports exact times; no retained first-party evidence establishes windows as better. |
| Scanner as replacement for manual entry | Permanently rejected | Permission, hardware, and temporary failures require manual path. |
| Bulk auto-log, chat UI, LLM nutrition | Permanently rejected | Nutrition must come from selected records; estimate acceptance and atomic final Log remain explicit. |
| Cloud model fallback / upload full description | Permanently rejected | Current contract is on-device extraction; only derived search queries may travel. |
| Remote search large empty panel | Rejected design | Accepted experiment found 234pt panel hid remote controls under keyboard. |
| Inline amount compact sheet / hold-repeat | Permanently rejected from current scope | Current four-button native inline pattern meets repeat correction; retained competitor evidence does not establish alternatives. |
| HealthKit, accounts, cross-device plan evidence | Permanently rejected from current scope | No permission, identity, backend, conflict, or provenance contract; local/offline privacy remains product boundary. |
| Streak/coaching, exercise credits, duplicate per-meal shortcuts, photo recognition | Permanently rejected from current scope | No evidence/trusted activity source, conflicts with calm hierarchy, or introduces accuracy/privacy cost without validated value. |

No opportunity in this table is deferred. A new explicit user request may create a new contract; repository currently promises none.

## Evidence and implementation notes

- Research, safety rules, API behavior, and source URLs retained in: `amount-entry-pattern-assessment.md`, `bulk-ai-food-logging-assessment.md`, `bulk-ai-food-logging-specification.md`, `nutrition-balance-assessment.md`, `refine-plan-reminder-assessment.md`, `calculated-plan-specification.md`, `adaptive-calorie-plan-specification.md`, `tracking-navigation-assessment.md`, `open-food-facts-api-assessment.md`, and `open-food-facts-search-assessment.md`.
- Design decision history retained in `design-redesign/STATUS.md`, `design-redesign/PRODUCT-BACKLOG.md`, and all `design-redesign/experiments/*.md` read for this audit.
- UI-test coverage names confirm current paths: default meal, bulk atomic/partial failure, amount controls, recent/frequent local and remote search, scanner recovery, barcode/custom nutrients, nutrition/personal targets, Weight lifecycle, chart point inspection, historical diary mutations, calculated setup, focused reminders, root settings, food-log completion, and adaptive collecting/proposal/apply/decline/revert/unknown/manual states.
