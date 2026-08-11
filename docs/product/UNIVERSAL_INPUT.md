# Universal Input and Speech

**Classification:** Canonical product and engineering contract
**Audience:** Users, support, product, design, engineering, and QA
**Capability status:** Current workspace; model and speech availability vary
**Source authority:** Universal Input adapters, capture router, and LifeBoardTranscription
**Last verified:** 2026-08-11
**Surfaces:** Persistent Life Thread composer and Eva structured composer
**Related:** [Adaptive Home](./HOME.md), [Insights and Eva](./INSIGHTS_AND_EVA.md), [Product UI/UX Guide](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md)

## Product promise

The composer is a universal input, not a chat-only field. A person can type or dictate what they need in ordinary language; LifeBoard interprets it, shows its understanding when useful, and opens the existing native iOS activity. It does not create a second task, note, journal, calendar, or rescue system.

The required first-class outcomes are:

| Input intent | Native outcome |
|---|---|
| Start journaling | Open the Journal text writer |
| Add a note | Open a new Note |
| Capture a task | Open Task capture with correctable parsed proposals |
| Check meetings | Select Home, return to today, and reveal the calendar schedule |
| Start planning | Open Day Plan |
| Plan the week | Open Weekly Planner |
| Day rescue | Open today’s rescue deck |
| Overdue rescue | Open the overdue rescue deck |
| Conversation or unsupported intent | Hand the preserved text to Eva |

No capture is saved merely because the system classified it. Editors remain the review and commit boundary. Consequential mutations continue through preview, Apply/Edit/Not Now, receipt, and Undo.

## Native iOS interaction contract

- The field is a SwiftUI multi-line `TextField` in the persistent app chrome. It uses semantic system typography and the existing warm clay/glass tokens.
- All icon-only controls have a minimum 44-by-44-point hit target and an explicit VoiceOver label.
- The primary button reads as “Interpret input” when text exists and “Start dictation” when empty.
- Deterministic interpretations may appear while typing. They are review rows, not automatic navigation.
- Semantic model inference starts only after explicit submission. Typing pauses must not repeatedly start Foundation Models or MLX work.
- Ambiguous or medium-confidence results present concrete choices. Low-confidence results fall through to Eva rather than forcing an action.
- The draft and attachments survive clarification, navigation, permission failure, and recoverable presentation changes.
- Reduce Motion removes repeating recording animation while preserving status text.

## Intent-resolution pipeline

Resolution is ordered and allow-listed:

1. Exact commands and slash aliases.
2. Explicit task language parsed by `TaskCaptureParser`.
3. Note, journal, and known ambiguity patterns.
4. Apple Foundation Models structured classification on supported devices.
5. The installed on-device MLX model with bounded JSON output.
6. Eva conversation fallback.

The semantic stages receive only the current input and small state facts such as active root, calendar availability, and rescue eligibility. They do not receive journal contents, note contents, calendar titles, task titles, or repository access. Model output cannot name arbitrary routes or execute code; it maps through `UniversalInputSemanticIntent`.

Confidence behavior:

- below `0.55`: do not claim an action;
- `0.55..<0.78`: ask for confirmation before the predicted action;
- `0.78...1.0`: return the allow-listed action;
- explicit `clarify`: show two or three concrete choices;
- `conversation`: route to Eva.

## SpeechAnalyzer architecture

Both saved Journal audio transcription and live composer dictation use Apple’s iOS 26 SpeechAnalyzer stack through the local `LifeBoardTranscription` package.

- Saved files route through `SpeechAnalyzerEngine`, preferring `SpeechTranscriber` and using `DictationTranscriber` only as a locale-coverage fallback. Both run as modules inside `SpeechAnalyzer`.
- Live microphone input uses `LiveTranscriptionSession`, `AVAudioEngine`, `SpeechAnalyzer.bestAvailableAudioFormat`, and `SpeechAnalyzer` streaming.
- `SpeechTranscriber` is preferred for live input. `DictationTranscriber` is the analyzer-based fallback for supported locales.
- Required model assets are installed through the shared asset manager. Unsupported locale, denied microphone, asset-install failure, and transient analyzer failure are distinct recovery states.
- Audio and inference remain on device. Dictation stops when its surface disappears or the app leaves the foreground.

`LifeBoardTranscription` publishes a cumulative transcript string rather than the analyzer’s finalized range. LifeBoard therefore treats the whole live transcript as provisional and commits the latest cumulative value on stop. This is intentionally loss-safe: a revised partial may change while listening, but stopping cannot erase the visible transcript. Exposing finalized/volatile ranges from the package remains a quality improvement, not a correctness dependency.

## Rollout and fallback

| Flag | Enabled behavior | Disabled behavior |
|---|---|---|
| `universalInputRoutingEnabled` | Structured universal routing | Preserve prior Eva conversation submission |
| `universalInputSemanticClassifierEnabled` | Foundation Models then installed MLX fallback | Deterministic adapters then Eva |
| `universalInputDictationEnabled` | Live SpeechAnalyzer dictation | Preserve the existing Journal audio-capture path in the shell |

The feature must remain useful with no installed MLX model, unavailable Foundation Models, unavailable calendar permission, and an unsupported speech locale.

## Verification and release gates

Automated contracts cover command routing, bare-command editor prefills, task-question false positives, deterministic-only live previews, semantic-adapter inclusion on submit, and cumulative transcript preservation. Simulator build and focused tests are necessary but not sufficient.

Before production promotion, verify on supported physical iPhone and iPad hardware:

- microphone permission grant, denial, Settings recovery, interruption, backgrounding, and route dismissal;
- asset download progress/failure and supported-locale fallback;
- long dictation, punctuation, revised partials, cancel restoration, thermal behavior, and memory;
- VoiceOver, Voice Control, Switch Control, Dynamic Type, Reduce Motion, and Increase Contrast;
- intent accuracy with a versioned corpus of typed and spoken utterances, including false-action rate and clarification rate;
- Foundation Models unavailable, no MLX model installed, and feature-flag rollback.

Promotion requires accuracy measurements against the app’s real task/note/journal/planning vocabulary. Third-party benchmark results can motivate the architecture but do not replace LifeBoard’s own corpus or signed-device evidence.

## External references

- [Apple SpeechAnalyzer documentation](https://developer.apple.com/documentation/speech/speechanalyzer)
- [Inscribe SpeechAnalyzer benchmark](https://get-inscribe.com/blog/apple-speech-api-benchmark.html) — useful directional evidence for English read speech; its own limitations include one corpus, one machine, and no accented, far-field, or multi-speaker evaluation.
