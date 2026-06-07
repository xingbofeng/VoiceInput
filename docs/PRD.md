# VoiceInput PRD

## Product Positioning

VoiceInput is a macOS voice input workbench for Chinese users, developers, and knowledge workers. It keeps the core interaction simple: hold the right Command key, speak, release, and insert text at the current cursor position.

## Goals

- Preserve the existing dictation loop: hotkey, recording, ASR, optional conservative LLM refinement, injection, clipboard restore, input source restore.
- Add a full workbench window with Home, Glossary, Styles, File Transcription, Notes, Dictation Models, Settings, and Help.
- Store local data in SQLite and API keys in Keychain.
- Keep all network features optional and explicit.
- Make failures recoverable: ASR and LLM failures must fall back without losing the current dictation.

## User Stories

- As a developer, I can dictate mixed Chinese-English technical text and keep terms accurate through glossary and replacement rules.
- As a knowledge worker, I can review recent dictation history, search it, copy it, delete it, and save useful entries as notes.
- As a privacy-conscious user, I can choose local/system/cloud providers and understand what data leaves the machine.
- As a writer, I can apply conservative styles without the model inventing content.
- As a power user, I can transcribe local audio or video files into text and save the result.

## Acceptance Criteria

- The app builds and launches as VoiceInput.
- The menu bar dictation loop still works without requiring the workbench window.
- Main workbench navigation contains every required page.
- SQLite migrations create the required local tables.
- API keys are stored only in Keychain and never in SQLite or UserDefaults.
- `swift test` and `make build` pass.

