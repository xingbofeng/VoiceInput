# VoiceInput Codex Goal

Build VoiceInput into a complete macOS voice input workbench while preserving the existing menu bar dictation experience.

## Absolute Constraints

- Product name remains VoiceInput.
- Do not reference third-party product names in code, UI, tests, resources, docs, or commit messages.
- Keep right Command hold-to-dictate, release-to-insert behavior working.
- Preserve input source switching, pasteboard snapshot, paste, clipboard restore, and input source restore.
- HUD remains non-activating.
- Main window opens only by explicit user action.
- LLM is disabled by default and conservative when enabled.
- API keys live only in Keychain.
- ASR and LLM failures fall back without losing current dictation.

## Implementation Scope

- App environment and dependency container.
- SQLite migrations and repositories.
- Keychain credential storage.
- Dictation orchestration and text pipeline.
- Workbench window and navigation.
- Home, glossary, styles, file transcription, notes, dictation models, settings, and help pages.
- Import/export and privacy controls.
- Tests and documentation.

