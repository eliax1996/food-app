# Bulk AI food logging — competitor and Apple-framework assessment

**Work item:** BULK-AI-FOOD-001
**Research date:** 2026-08-12
**State:** research complete; decisions feed `bulk-ai-food-logging-specification.md`

## Question

How should Count Calories let someone type or dictate a meal such as “200 g chicken breast, 150 g rice, broccoli, and a glass of oat milk,” turn it into several inspectable food rows, match those rows to nutrition records, and commit them quickly without treating language-model guesses as logged nutrition facts?

## Existing product constraints

- Today already has direct **Log food**, barcode scan, custom-food creation, recent foods, saved foods, and Open Food Facts search. Bulk entry must complement these paths, not replace or bury them.
- `FoodNutrition` normalizes a selected product to g or ml and preserves unknown nutrients as unknown.
- `RemoteFoodSearchService` already supplies persistent query/page caching, 30-day positive freshness, 90-day terminal freshness, request coalescing, cancellation, and a process-wide 10-start/minute budget.
- `PlanEvidenceMutationCoordinator` is the sole writer for food evidence. Single-item insert/update/delete stale a completed food day and bump adaptive evidence. Bulk confirmation therefore needs one coordinator transaction, one save, and one evidence invalidation—not a loop of independently committed rows.
- App deployment target remains iOS 17. AI parsing and modern on-device transcription need availability-gated iOS 26 APIs. Direct logging and a manual bulk-review fallback must remain usable on older or ineligible devices.

## Competitor evidence

Only public first-party material inspected below is treated as evidence. Marketing pages show direction, not implementation guarantees beyond their explicit text.

### MyFitnessPal Voice Logging

Official support article: [Voice Logging](https://support.myfitnesspal.com/hc/en-us/articles/30332897072269-Voice-Logging) and its public [Zendesk JSON](https://support.myfitnesspal.com/api/v2/help_center/en-us/articles/30332897072269.json), accessed 2026-08-12.

Verified behavior:

- Entry is a named **Voice Log** action under the dashboard `+` control.
- Microphone and speech-recognition permissions are requested when the voice feature is used.
- User speaks, then explicitly advances to results; speech does not immediately mutate diary.
- Recommended phrase includes food, serving size, and meal. First-party example contains several foods: “For Breakfast, I had one cup of plain Greek Yogurt, Honey, and some Blueberries.”
- Result screen permits tapping a food to edit serving size, serving count, or destination meal.
- **Log** confirms; **Try again** recovers from an unsatisfactory result.
- It searches same food database as manual entry. Custom My Foods, recipes, meals, quick-add calories, weight, exercise, and water are excluded.
- It requires connectivity and, at publication, Premium plus English.

Implication: natural speech can reduce entry effort, but separate capture, result review, edit, retry, and commit states remain essential. Count Calories should keep this state separation while avoiding cloud dependence for language parsing.

### MacroFactor AI food logging

Official article: [AI-Powered Food Logging Comes to MacroFactor](https://macrofactorapp.com/ai-food-logging/), accessed 2026-08-12.

Verified behavior and stated principles:

- Current beta centers on photo capture; **Photo & Text** can add meal-description context. This is not evidence of a text-only or voice flow.
- Analysis breaks a meal into individual ingredients or logically grouped recipes, queries a food database, and streams results into a plate.
- MacroFactor states it prioritizes real, lab-analyzed food records rather than asking an LLM to generate every nutrition entry.
- Every result is inspectable and editable in context before logging. User can adjust quantities, split grouped recipes, search, scan, or invoke AI again.
- Article explicitly recommends reviewing AI results before logging and frames AI as a collaborator rather than primary decision maker.
- Barcode remains faster for one packaged product; AI is positioned for multi-item and complex meals.

Implication: strongest trustworthy pattern is **AI automates decomposition and bulk search; database records own nutrition; unified editable rows own review**. Count Calories should not build chat UI, opaque one-row meal estimates, or LLM-derived calories.

### Foodnoms

Official pages: [Foodnoms](https://www.foodnoms.com/) and [Privacy Policy](https://www.foodnoms.com/privacy), accessed 2026-08-12.

Verified public claims:

- Home page advertises AI logging from a photo or short typed summary, alongside barcode/nutrition-label scanning.
- Product emphasizes native Apple-platform design, optional accounts, and a privacy-first positioning.
- Privacy policy states Foodnoms AI can process text, links, or images for suggested nutrition analysis and relays those inputs to OpenAI. It says inputs are not used to train OpenAI models, while Foodnoms may use anonymous inputs to improve its database and customer experience.

Implication: typed summaries are an established low-friction entry mode. Privacy copy must describe actual transport, not rely on a generic “AI” label. Count Calories can differentiate: meal text and correction examples stay on device; only derived food-search queries may go to Open Food Facts.

### Products not used as evidence

Current first-party public documentation proving equivalent typed or dictated multi-food review behavior was not found for Cronometer, Lose It!, or YAZIO during this bounded pass. Search snippets, old feature names, third-party reviews, and inaccessible/404 pages are insufficient. No claim about their current flow informs the design.

## Competitive synthesis

| Product evidence | Fast input | Intermediate result | Item-level editing | Nutrition source | Privacy/availability lesson |
|---|---|---|---|---|---|
| MyFitnessPal Voice Logging | Voice phrase, including multiple foods | Yes; user advances to results | Serving size/count and meal | Same database as manual search | Permission just in context; cloud/network dependency is explicit |
| MacroFactor AI | Photo, optionally text context | Streaming plate | Full inspect/edit; add/search/scan; confirm later | Prioritizes real food records | AI is fallible collaborator; complex meals benefit most |
| Foodnoms | Photo or short typed summary | Public page does not specify exact review controls | Not established by inspected source | Suggested nutrition analysis | Text/image relayed to OpenAI; explicit privacy policy matters |
| Count Calories decision | Typed paragraph or optional on-device dictation | Editable provisional rows | Query, g/ml amount, selected record, add/remove/retry | Saved food or Open Food Facts record only | Description/extraction/corrections stay local; derived search query may use network |

### Patterns to adopt

1. Keep direct **Log food** prominent; add a distinct **Describe meal** action for multi-item intent.
2. Treat capture, extraction, matching, review, and commit as separate visible states.
3. Decompose into inspectable food rows; never collapse an entire meal into opaque generated calories.
4. Search existing nutrition records and show selected record beneath each provisional query/amount.
5. Permit correction before commit and retry/remove on partial failure.
6. Require one explicit final confirmation.
7. Explain microphone, on-device model, and food-query network behavior at point of use.

### Patterns to reject

- Chat transcript as primary UI.
- Auto-logging when speech stops or model output arrives.
- LLM-generated calories, macros, barcodes, or “verified” product identity.
- Hiding failed rows or silently dropping unmatched foods.
- One blanket confidence percentage. Model confidence is not calibrated nutrition certainty.
- Uploading full meal descriptions merely to search a food API.
- Claiming the feature “learns you” without retained-record details and deletion controls.

## Apple Foundation Models research

### Verified API and platform facts

Official sources:

- [Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
- [Improving the safety of generative model output](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output)
- [`SystemLanguageModel`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- Xcode 27 beta SDK Swift interface at `FoundationModels.framework`, inspected 2026-08-12.

Findings:

- `SystemLanguageModel` is an **on-device** Apple Foundation Model introduced on iOS 26. Apple says Foundation Models features can work offline and carry no per-request charge.
- Runtime availability is not equivalent to OS availability. `SystemLanguageModel.default.availability` is `.available` or unavailable because device is not eligible, Apple Intelligence is not enabled, or model is not ready.
- Locale must also be checked with `supportsLocale(_:)`.
- Apple explicitly requires a fallback experience when model is unavailable.
- `LanguageModelSession` supports asynchronous `respond`, `streamResponse`, cancellation through task cancellation, prewarming, a 4,096-token context on iOS 26-era system models, and one active response per session.
- Apple recommends a fresh session for a single-turn interaction. Bulk meal extraction is single-turn; no raw session transcript needs retention.
- `@Generable` plus `@Guide` uses constrained sampling to return a typed structure. Guides can bound arrays, strings, and numeric ranges. This prevents malformed output but does **not** make semantic guesses true.
- `GenerationOptions` supports greedy sampling and maximum response tokens. Deterministic extraction should prefer greedy sampling and a bounded response.
- Guided generation throws explicit guardrail/refusal, context-size, and generation errors. UI must offer edit/retry/manual recovery.
- Apple safety guidance says untrusted user input belongs in a prompt, never trusted instructions, and recommends output bounds plus app-specific validation. The meal description therefore stays in a delimited prompt; fixed app instructions define only the task.

### Approved Foundation Models role

Use model only to produce provisional, bounded structure:

```text
[(search query, positive amount, g|ml, amount explicitly stated?)]
```

Model may normalize wording and estimate a missing amount. Estimated amounts are visibly labeled. Model must not output calories, macros, barcode, database identity, confidence, meal history, or a final log operation.

A model response is accepted into review only after deterministic validation:

- input: 1...1,200 graphemes;
- output: 1...12 rows;
- query: trimmed, 1...80 graphemes, no control characters;
- amount: finite, 0.01...5,000 g/ml;
- duplicate exact queries may be merged only when units match and sum remains valid;
- every row starts provisional and must acquire a selected nutrition record before confirmation.

Relevant retained corrections can be applied deterministically after extraction. They may also be shown to the model as bounded examples inside the untrusted prompt payload, never inserted into trusted instructions.

## Apple Speech research

Official sources:

- [Bringing advanced speech-to-text capabilities to your app](https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app)
- [`SpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer)
- Apple sample package **BringingAdvancedSpeechToTextCapabilitiesToYourApp**, downloaded from linked documentation and inspected 2026-08-12.
- Xcode 27 beta SDK Swift interface at `Speech.framework`.

Findings:

- `SpeechAnalyzer` and `SpeechTranscriber` arrive on iOS 26 and expose asynchronous input and result sequences.
- Locale support and installed assets are separate concerns. `supportedLocale(equivalentTo:)`, `AssetInventory.status`, and `assetInstallationRequest` must be handled. Initial asset download can need connectivity.
- Volatile results support live editable transcript display; finalization is explicit.
- Analyzer input, result consumption, and session control run in separate tasks. One analyzer handles one input sequence at a time.
- Apple sample requests microphone access with `AVCaptureDevice.requestAccess(for: .audio)` at moment of recording and includes `NSMicrophoneUsageDescription`. It does not request legacy `SFSpeechRecognizer` authorization for this `SpeechAnalyzer` path.
- Apple sample uses `AVAudioEngine`, converts buffers to analyzer format, finishes input, then calls `finalizeAndFinishThroughEndOfInput()`.

### Approved dictation role

- Dictation is optional input assistance into same editable text field; it never bypasses review.
- Request microphone permission only after microphone tap.
- Use current supported locale; show unsupported/download/preparing/listening/finishing/denied/failure states truthfully.
- Keep typed editing available before, during, and after dictation where safe.
- Do not persist audio. Append finalized transcript to existing text; volatile text is visibly transient.
- On iOS <26, unsupported locale, denied microphone, or speech failure, typed input and manual row entry remain available.

## Availability matrix

| Condition | Typed natural-language parse | Dictation | Manual/direct recovery |
|---|---|---|---|
| iOS 26+, eligible device, Apple Intelligence enabled/ready, supported locale | Available on device | Available when Speech locale/assets and microphone allow | Always |
| Foundation model downloading | Disabled with “model not ready”; retry later | Independent | Manual rows + direct Log food |
| Apple Intelligence off | Disabled with Settings guidance, no false promise | May remain available | Manual rows + direct Log food |
| Device ineligible or iOS 17–25 | Disabled | SpeechAnalyzer unavailable | Manual rows + direct Log food |
| Foundation locale unsupported | Disabled for current input locale | Dictation may also be unsupported independently | Manual rows + direct Log food |
| Offline after model/speech assets installed | Parse works; saved/cache matches work | Works | Unmatched remote rows show offline recovery |
| Offline before speech asset installed | Parse may work | Preparation/download fails truthfully | Type instead |
| Open Food Facts unavailable | Parse still works | Independent | Saved/history matches remain; failed rows retry/change/remove |

## Privacy and data-flow conclusion

1. Raw typed/dictated description is sent only to Apple’s on-device `SystemLanguageModel` and held in local draft storage if user chooses **Keep Draft**.
2. Microphone audio is streamed to on-device Speech analysis and not written to disk by Count Calories.
3. Model output and retained corrections stay in app-local Application Support, excluded from backup where supported, and use complete file protection on iOS.
4. Only per-row derived food query strings can be sent to Open Food Facts. Privacy copy must not say “everything stays on device.”
5. Open Food Facts result/cache behavior and attribution remain unchanged.
6. Learning records are bounded, inspectable by count, and deletable from Settings. “Learning” means deterministic reuse of saved corrections and selected matches—not model training or upload.
7. Logs enter SwiftData only after one atomic confirmation. Cancel or partial lookup writes no `PlateEntry`.

## Decision

Proceed with a native staged sheet and no chat UI:

```text
Describe (type/dictate)
  → Structure on device
  → Match rows concurrently from retained preference, saved foods, cache, then Open Food Facts
  → Review/edit every query, amount, and selected record
  → Confirm one atomic batch
```

Detailed contract: `bulk-ai-food-logging-specification.md`.
