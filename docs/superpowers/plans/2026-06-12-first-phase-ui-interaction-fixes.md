# VoiceInput First-Phase UI Interaction Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the confirmed first-phase homepage, glossary, style, and file-transcription interaction fixes.

**Architecture:** Preserve existing repositories and ViewModels while narrowing the SwiftUI surfaces to first-phase behavior. Add small presentation models for feedback and status localization, keep file parsing in ViewModels, and use AVKit only for local media playback.

**Tech Stack:** Swift 6, SwiftUI, AppKit, AVFoundation/AVKit, XCTest, Swift Package Manager.

---

### Task 1: Typed Action Feedback

**Files:**
- Modify: `Sources/VoiceInputApp/ActionFeedbackView.swift`
- Modify: `Sources/VoiceInputApp/HomeDashboardViewModel.swift`
- Modify: `Sources/VoiceInputApp/HomeDashboardView.swift`
- Test: `Tests/VoiceInputAppTests/HomeDashboardViewModelTests.swift`

- [ ] Add a failing test proving copy feedback is informational and delete feedback is destructive.
- [ ] Run `swift test --filter HomeDashboardViewModelTests` and confirm the new test fails because feedback has no typed presentation.
- [ ] Introduce an `ActionFeedback` value with message and style, update copy/delete actions, and render a prominent overlay Toast.
- [ ] Ensure row action buttons consume clicks independently from row selection.
- [ ] Run `swift test --filter HomeDashboardViewModelTests` and confirm all tests pass.

### Task 2: Sidebar Collapse Alignment

**Files:**
- Modify: `Sources/VoiceInputApp/MainShellView.swift`
- Modify: `Sources/VoiceInputApp/SidebarView.swift`
- Modify: `Sources/VoiceInputApp/MainWindowController.swift`

- [ ] Inspect the existing toolbar/sidebar toggle ownership and identify the offset source.
- [ ] Center the collapse icon in a fixed-size hit target that does not inherit sidebar label spacing.
- [ ] Build with `swift build` and verify both expanded and collapsed states in the running App.

### Task 3: First-Phase Glossary Behavior

**Files:**
- Modify: `Sources/VoiceInputApp/GlossaryViewModel.swift`
- Replace presentation in: `Sources/VoiceInputApp/GlossaryView.swift`
- Test: `Tests/VoiceInputAppTests/GlossaryViewModelTests.swift`

- [ ] Add failing tests for newline-separated terms, blank-line filtering, duplicate skipping, and simple replacement creation.
- [ ] Run `swift test --filter GlossaryViewModelTests` and confirm failures represent the missing first-phase APIs.
- [ ] Add a batch term API that stores only visible term text with internal defaults.
- [ ] Add TXT file loading with UTF-8 validation and reject non-`.txt` URLs.
- [ ] Replace the page with “易错词” and “文本替换” sections; remove category, priority, alias, JSON, CSV, export, and replacement import controls.
- [ ] Run `swift test --filter GlossaryViewModelTests` and confirm all tests pass.

### Task 4: First-Phase Style Editor

**Files:**
- Modify: `Sources/VoiceInputApp/StyleViewModel.swift`
- Replace presentation in: `Sources/VoiceInputApp/StyleView.swift`
- Test: `Tests/VoiceInputAppTests/StyleViewModelTests.swift`

- [ ] Add a failing test for selecting a profile and making it default in one ViewModel operation.
- [ ] Run `swift test --filter StyleViewModelTests` and confirm the new test fails.
- [ ] Add `selectProfile(id:)` to persist the default profile and expose the selected record.
- [ ] Make each list row use a full rectangular content shape and invoke selection from the whole row.
- [ ] Remove the default check action, reset action, application-style UI, and lower configuration sections.
- [ ] Add side-by-side Markdown source and `AttributedString(markdown:)` preview with one “确认” button.
- [ ] Run `swift test --filter StyleViewModelTests` and confirm all tests pass.

### Task 5: File Transcription Controls

**Files:**
- Modify: `Sources/VoiceInputApp/FileTranscriptionViewModel.swift`
- Modify: `Sources/VoiceInputApp/FileTranscriptionView.swift`
- Test: `Tests/VoiceInputAppTests/FileTranscriptionViewModelTests.swift`

- [ ] Add failing tests for localized status labels and direct result copying.
- [ ] Run `swift test --filter FileTranscriptionViewModelTests` and confirm the tests fail for the missing APIs.
- [ ] Add status presentation and clipboard injection to the ViewModel.
- [ ] Add a local media player controller with play/pause state scoped to the selected job.
- [ ] Replace the share menu with explicit play/pause, start/retry, and copy buttons.
- [ ] Run `swift test --filter FileTranscriptionViewModelTests` and confirm all tests pass.

### Task 6: Documentation and Full Verification

**Files:**
- Modify: `CONTEXT.md`
- Modify: `implementation-notes.md`

- [ ] Update domain and module notes for typed feedback, first-phase glossary/style boundaries, and file playback controls.
- [ ] Archive implementation notes first if the file would exceed roughly 300 lines.
- [ ] Run `swift test`.
- [ ] Run the project build/package command and verify codesigning.
- [ ] Launch `.build/VoiceInputApp.app` and manually exercise every requested interaction.
- [ ] Review the complete diff for unintended changes and request an independent code review.
