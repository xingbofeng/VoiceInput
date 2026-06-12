# Global Model And Style Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Settings the authoritative home for global LLM/ASR models, simplify and repair style routing, and verify every reachable app control.

**Architecture:** A repository-backed refiner resolves the enabled default LLM provider for every request. An async style selector applies explicit application rules first, then an LLM classifier, then the default style. SwiftUI exposes these global controls only in Settings and represents application rules as editable logo tiles.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SQLite, XCTest, Swift Package Manager, macOS Accessibility/Computer Use.

---

### Task 1: Runtime Global LLM Provider

**Files:**
- Create: `Sources/VoiceInputApp/RepositoryBackedLLMRefiner.swift`
- Modify: `Sources/VoiceInputApp/TextProcessingPipeline.swift`
- Modify: `Sources/VoiceInputApp/PromptBuilder.swift`
- Test: `Tests/VoiceInputAppTests/RepositoryBackedLLMRefinerTests.swift`
- Test: `Tests/VoiceInputAppTests/TextProcessingPipelineTests.swift`

- [ ] Add tests proving the enabled default provider supplies model, URL, key, timeout, and temperature.
- [ ] Run focused tests and confirm they fail because the repository-backed refiner does not exist.
- [ ] Implement provider resolution and OpenAI-compatible completion requests.
- [ ] Remove style provider/model metadata from prompt requests and results.
- [ ] Run focused tests and confirm they pass.

### Task 2: Application Style Routing

**Files:**
- Modify: `Sources/VoiceInputApp/AppStyleRule.swift`
- Create: `Sources/VoiceInputApp/ApplicationStyleClassifier.swift`
- Modify: `Sources/VoiceInputApp/DictationOrchestrator.swift`
- Test: `Tests/VoiceInputAppTests/TextProcessingPipelineTests.swift`
- Test: `Tests/VoiceInputAppTests/DictationOrchestratorTests.swift`

- [ ] Add tests for rule priority, classifier selection, classifier fallback, and start-time target capture.
- [ ] Run focused tests and confirm the new expectations fail.
- [ ] Make style selection async, add LLM classification, and retain default fallback.
- [ ] Capture the target when dictation starts and reuse it for processing/history.
- [ ] Run focused tests and confirm they pass.

### Task 3: Style Content And Editing

**Files:**
- Modify: `Sources/VoiceInputApp/BuiltInStyleCatalog.swift`
- Modify: `Sources/VoiceInputApp/StyleViewModel.swift`
- Modify: `Sources/VoiceInputApp/StyleView.swift`
- Modify: `Sources/VoiceInputApp/StyleWorkspaceView.swift`
- Test: `Tests/VoiceInputAppTests/StyleViewModelTests.swift`
- Test: `Tests/VoiceInputAppTests/PromptBuilderTests.swift`

- [ ] Add tests that built-in prompts are complete and profile edits preserve legacy provider fields without exposing them.
- [ ] Confirm focused tests fail.
- [ ] Expand built-in prompts, change `Prompt` to `提示词`, and remove provider/model/temperature plus preview UI.
- [ ] Add application-logo tile CRUD with an editor sheet.
- [ ] Confirm focused tests pass.

### Task 4: Unified Settings And Status Item

**Files:**
- Modify: `Sources/VoiceInputApp/SettingsRootView.swift`
- Modify: `Sources/VoiceInputApp/SettingsViewModel.swift`
- Modify: `Sources/VoiceInputApp/MainShellView.swift`
- Modify: `Sources/VoiceInputApp/MainWindowController.swift`
- Modify: `Sources/VoiceInputApp/NavigationRoute.swift`
- Modify: `Sources/VoiceInputApp/AppDelegate.swift`
- Test: `Tests/VoiceInputAppTests/WorkbenchViewModelTests.swift`
- Test: `Tests/VoiceInputAppTests/SettingsViewModelTests.swift`

- [ ] Add tests for the Models settings section and reduced sidebar routes.
- [ ] Confirm tests fail with the current navigation.
- [ ] Embed LLM and ASR configuration in Settings and remove duplicate routes/tabs.
- [ ] Wire all runtime pipelines to the repository-backed refiner and set the status icon tint to white.
- [ ] Confirm focused tests pass.

### Task 5: Full Verification And Delivery

**Files:**
- Modify: `implementation-notes.md`
- Create: `docs/BUTTON_VERIFICATION.md`

- [ ] Run all unit tests and warnings-as-errors build.
- [ ] Build and launch the release app.
- [ ] Use Computer Use to verify all sidebar, page, sheet, menu, picker, toggle, link, and safe destructive controls, recording evidence in the audit.
- [ ] Run `make dmg` and all CI verification commands.
- [ ] Review the full diff and check for secrets or generated artifacts.
- [ ] Commit with a Chinese Conventional Commit message and Codex co-author trailer.
- [ ] Push to the remote branch, monitor GitHub Actions, and repair any failure until required checks pass.
