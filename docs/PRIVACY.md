# VoiceInput Privacy

## Local Data

VoiceInput stores local workbench data in SQLite under:

```text
~/Library/Application Support/VoiceInput/voiceinput.sqlite
```

This includes dictation history, glossary terms, replacement rules, style profiles, provider metadata, transcription jobs, notes, and non-sensitive settings.

## Secrets

API keys are stored in macOS Keychain through `KeychainCredentialStore`.

VoiceInput must not store API keys in:

- UserDefaults
- SQLite
- Logs
- Test snapshots
- Export archives

Older plaintext LLM keys written to UserDefaults are migrated to Keychain and removed.

## Network Use

Network behavior is opt-in:

- LLM refinement is disabled by default.
- LLM requests send recognized text only when the user enables refinement or a style that requires it.
- Local/system ASR can be used without uploading audio to an LLM provider.
- Cloud ASR providers must clearly disclose that audio may leave the machine before they are enabled.

## Logging

`AppLogger` redacts bearer tokens and API key-shaped values before sending text to OSLog.

## Manual Controls

Future settings must include:

- Clear history.
- Clear cache/model downloads.
- Export local data without secrets.
- Import local data without overwriting Keychain secrets unless explicitly configured.

