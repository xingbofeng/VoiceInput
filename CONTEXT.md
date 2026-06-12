# VoiceInput Project Context

## Domain Language

- **VoiceInput**: The menu-bar application and shipped `.app` bundle.
- **Right Command session**: One press-hold-release interaction that owns a single transcription.
- **Partial result**: A non-final text update emitted by Apple Speech while recording.
- **Final result**: Apple's final transcription after `endAudio()`.
- **Bounded timeout**: The 15 second fallback after right Command release that accepts the latest partial result if no final result arrives.
- **Refinement**: Optional conservative correction through an OpenAI-compatible API.
- **Text processing pipeline**: The post-ASR path that applies conservative refinement and future glossary/style rules while preserving fallback to raw text.
- **PromptBuilder**: The pure builder that combines conservative correction rules, selected style guidance, and enabled glossary terms into an LLM system prompt.
- **App style rule**: A Settings-backed mapping from target app bundle/name to a style profile used during post-ASR refinement.
- **ASR Provider**: A descriptor and runtime entry for a speech recognition backend, including capabilities, privacy summary, availability, and fallback behavior.
- **Capability tag**: A user-facing and filterable ASR Provider label such as local, streaming, cloud, multilingual, or punctuation.
- **Injection**: Temporarily placing text on the pasteboard and posting Command-V to the focused application.
- **HUD**: The bottom-centered non-activating capsule shown during recording and refinement.

## Module Boundaries

| Module | Owns | Must not own |
| --- | --- | --- |
| `AppDelegate` | Menu construction, permissions prompts, hotkey entry, HUD callback wiring | Audio math, URL parsing, pasteboard serialization, dictation state machine |
| `KeyMonitor` | CGEvent tap and right Command transitions | Recording lifecycle |
| `AudioRecorder` | AVAudioEngine and RMS extraction | Speech requests |
| `SpeechRecognizer` | Speech request/task and callbacks | Audio engine |
| `TranscriptionSession` | Final/partial/release/timeout completion semantics | AppKit or asynchronous timers |
| `DictationStateMachine` | Legal dictation state transitions | ASR, audio, UI, persistence |
| `DictationOrchestrator` | Recording lifecycle, ASR engine callbacks, timeout fallback, text pipeline, injection, history save | Menu construction, permission prompts, view layout |
| `TextProcessingPipeline` | Replacement stages, optional LLM refinement, prompt context collection, and fallback warnings | ASR, audio capture, text injection |
| `PromptBuilder` | Pure prompt assembly from conservative rules, default style, and enabled glossary terms | Repository access, network requests, history persistence |
| `AppStyleRuleStore` / `SettingsBackedStyleSelector` | Persisted app-to-style mappings and runtime style resolution for a dictation target | Prompt construction, LLM network requests, SwiftUI layout |
| `ASRProviderRegistry` | ASR provider descriptors, capability filtering, default provider selection, fallback chain, engine creation | Download UI, AppKit window ownership |
| `ASRProviderViewModel` | Dictation model page state, provider records, tag filtering, local model path/download/delete operations | ASR engine implementation details |
| `CloudASRProviderClient` | Basic cloud ASR connection/file transcription protocol shape | Concrete third-party API behavior |
| `SettingsViewModel` | SwiftUI settings state, persisted app settings, shortcut preferences, device/permission snapshots, data actions | Hotkey event capture, real permission requests |
| `FileTranscriptionViewModel` | File import validation, transcription job queue state, progress/cancel/retry, export, save-as-note | Concrete ASR provider internals, note editing UI |
| `FileTranscriptionWorking` | File-to-text worker contract for mock and real ASR implementations | Job persistence or SwiftUI state |
| `NotesViewModel` | Note CRUD, Markdown draft state, search, history/file-transcription import, tag normalization, Markdown export | File transcription queue execution |
| `OverlayWindowController` | NSPanel visibility, sizing, animation | Recognition state |
| `WaveformModel` | Envelope and bar heights | Drawing |
| `TextInjector` | Input source switching, paste, clipboard restoration | Recognition or LLM calls |
| `LLMRefiner` | Configuration, endpoint normalization, API request/response | UI |
| `LanguageManager` | Supported locales and persisted selection | Speech task lifetime |
| `CredentialStore` / `KeychainCredentialStore` | API key persistence and migration target | Non-sensitive preferences, logging |
| `AppLogger` | OSLog output and sensitive-token redaction | Secrets, user content transformation |
| `ApplicationSupportPaths` | VoiceInput Application Support paths for database, exports, and models | File transfer, network downloads |
| `AppClock` | Testable wall-clock and sleep abstraction | Business state transitions by itself |
| `HistoryRepository` | Persisted dictation history records and search/delete queries | ASR lifecycle, text injection |

## Architecture Decisions

### ADR-001: Paste Instead Of Accessibility Value Mutation

Text is injected with the clipboard and Command-V because it works across more native, Electron, browser, and custom text controls than direct Accessibility value mutation.

### ADR-002: Switch CJK Input Sources Before Paste

CJK input methods can intercept or transform synthetic keyboard events. VoiceInput temporarily selects ABC/US for paste, then restores the exact prior input source.

### ADR-003: Final Result With Timeout Fallback

Apple Speech and local ASR final-result latency is not fixed. VoiceInput completes immediately on a final result and otherwise waits up to 15 seconds before accepting the latest partial result. If ASR errors after partial text has arrived, the latest partial is used instead of dropping the dictation.

### ADR-004: LLM Is Conservative And Optional

Refinement is off unless configured and enabled. API failure falls back to raw text. The prompt forbids rewriting and asks for byte-for-byte preservation when no obvious error exists.

### ADR-005: Host-Native SwiftPM Build

The default Make target builds for the current host architecture. A signed bundle is always produced and verified; ad-hoc signing is the default for local development.

### ADR-006: AppDelegate Delegates Dictation Lifecycle

`AppDelegate` keeps menu-bar, permission, and hotkey entry responsibilities, but `DictationOrchestrator` owns the recording lifecycle after start. This keeps right Command behavior stable while allowing timeout, LLM fallback, history persistence, and future glossary/style processing to be tested without AppKit windows or real devices.

### ADR-007: ASR Providers Are Runtime Descriptors

ASR provider availability and labels are computed in `ASRProviderRegistry` from the current `ASRManager` state, then mirrored into SQLite for workbench summaries. This avoids duplicating Apple/Qwen selection logic while still giving the SwiftUI model page a repository-backed view of providers, health, tags, and default/fallback behavior.
