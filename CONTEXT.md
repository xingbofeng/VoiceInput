# VoiceInput Project Context

## Domain Language

- **VoiceInput**: The menu-bar application and shipped `.app` bundle.
- **Right Command session**: One press-hold-release interaction that owns a single transcription.
- **Partial result**: A non-final text update emitted by Apple Speech while recording.
- **Final result**: Apple's final transcription after `endAudio()`.
- **Bounded timeout**: The 1.2 second fallback after right Command release that accepts the latest partial result if no final result arrives.
- **Refinement**: Optional conservative correction through an OpenAI-compatible API.
- **Injection**: Temporarily placing text on the pasteboard and posting Command-V to the focused application.
- **HUD**: The bottom-centered non-activating capsule shown during recording and refinement.

## Module Boundaries

| Module | Owns | Must not own |
| --- | --- | --- |
| `AppDelegate` | Menu construction and cross-module state flow | Audio math, URL parsing, pasteboard serialization |
| `KeyMonitor` | CGEvent tap and right Command transitions | Recording lifecycle |
| `AudioRecorder` | AVAudioEngine and RMS extraction | Speech requests |
| `SpeechRecognizer` | Speech request/task and callbacks | Audio engine |
| `TranscriptionSession` | Final/partial/release/timeout completion semantics | AppKit or asynchronous timers |
| `OverlayWindowController` | NSPanel visibility, sizing, animation | Recognition state |
| `WaveformModel` | Envelope and bar heights | Drawing |
| `TextInjector` | Input source switching, paste, clipboard restoration | Recognition or LLM calls |
| `LLMRefiner` | Configuration, endpoint normalization, API request/response | UI |
| `LanguageManager` | Supported locales and persisted selection | Speech task lifetime |

## Architecture Decisions

### ADR-001: Paste Instead Of Accessibility Value Mutation

Text is injected with the clipboard and Command-V because it works across more native, Electron, browser, and custom text controls than direct Accessibility value mutation.

### ADR-002: Switch CJK Input Sources Before Paste

CJK input methods can intercept or transform synthetic keyboard events. VoiceInput temporarily selects ABC/US for paste, then restores the exact prior input source.

### ADR-003: Final Result With Timeout Fallback

Apple Speech final-result latency is not fixed. VoiceInput completes immediately on a final result and otherwise waits up to 1.2 seconds before accepting the latest partial result.

### ADR-004: LLM Is Conservative And Optional

Refinement is off unless configured and enabled. API failure falls back to raw text. The prompt forbids rewriting and asks for byte-for-byte preservation when no obvious error exists.

### ADR-005: Host-Native SwiftPM Build

The default Make target builds for the current host architecture. A signed bundle is always produced and verified; ad-hoc signing is the default for local development.
