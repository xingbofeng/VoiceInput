# Global Model And Style Routing Design

## Goal

Unify LLM and ASR configuration under Settings, make the selected defaults authoritative at runtime, simplify styles to prompts plus application routing, and verify every reachable control in the macOS app.

## Runtime Model Configuration

- The enabled default `LLMProviderRecord` is the only source for Base URL, API key reference, model, temperature, and timeout.
- Runtime refinement resolves that provider for every request so edits take effect without restarting.
- Style records keep legacy provider/model fields for database compatibility, but prompt building and refinement ignore them.
- The menu-bar LLM toggle remains global and gates all LLM work.
- The selected ASR provider remains backed by `ASRManager` and is edited from the Models section in Settings.

## Style Routing

- A target application is captured when dictation starts, before VoiceInput becomes frontmost.
- Explicit user rules have priority and map Bundle ID or application name to a style.
- Without a rule, an application classifier asks the global LLM to return one existing style ID.
- Invalid responses, missing configuration, and request failures fall back to the default style without blocking dictation.
- Built-in styles contain complete Chinese instructions with scope, output constraints, and examples.

## User Interface

- Settings gains a Models section containing LLM Provider and transcription model configuration.
- The separate transcription-model sidebar route and the Provider tab under Styles are removed.
- Styles expose only the Chinese label `提示词`, default selection, reset/save, and application routing.
- The former preview area is removed from production UI.
- Application rules appear as application-logo tiles. Add and edit use a sheet; delete remains available from the tile.
- The status-item microphone uses a white tint.
- Action buttons surface success or error feedback.

## Verification

- Unit tests cover global provider resolution, style-independent model selection, target capture timing, style routing, built-in prompts, and view-model CRUD.
- CI-equivalent local checks run `swift test`, warnings-as-errors debug build, release DMG packaging, codesign, universal architecture, and checksum verification.
- Computer Use verifies every reachable non-destructive control. Destructive controls are verified against disposable test records or temporary files, restoring user data where needed.
- After push, GitHub Actions runs are monitored and failures are fixed until all required checks pass.
