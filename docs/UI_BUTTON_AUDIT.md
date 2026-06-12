# UI Button Audit

Date: 2026-06-12

Evidence levels:

- `UI`: clicked in the built macOS app and observed the result.
- `Live`: exercised a real local service, model, file, clipboard, or system pane.
- `Test`: covered by an automated test.
- `Pending`: requires the unlocked macOS graphical session.

## Home

| Control | Evidence | Result |
| --- | --- | --- |
| Select history row | UI | Detail panel shows the selected record. |
| Copy | UI, Live, Test | Clipboard receives final text and success feedback appears. |
| Reprocess | UI, Live, Test | Global LLM processes raw text and the history record updates. |
| Close detail | UI | Detail panel closes. |
| Search | UI, Test | Query filters raw/final transcript text. |
| Delete history row | Test, Pending | Soft delete and reload are tested; destructive UI click remains. |

## Glossary

| Control | Evidence | Result |
| --- | --- | --- |
| Terms/rules tabs | UI | Both workspaces switch correctly. |
| Add term | UI, Test | Valid term saves; empty term shows a visible error. |
| Delete term | Test, Pending | Repository deletion is tested; destructive UI click remains. |
| Add replacement rule | UI, Test | Source, replacement, mode, and stage persist. |
| Delete replacement rule | Test, Pending | Repository deletion is tested; destructive UI click remains. |
| Search | UI, Test | Terms and imported aliases are searchable. |
| JSON export/import | UI, Test | Round trip preserves terms and replacement rules. |
| CSV export/import | UI, Test | Quoting and merge behavior work. |
| Line import | UI, Test | Imported terms are merged and deduplicated. |

## Styles

| Control | Evidence | Result |
| --- | --- | --- |
| Six built-in style cards | UI, Test | Each style opens and displays its complete built-in prompt. |
| Set default | UI, Test | Default style changes globally and can be restored. |
| Save prompt | UI, Test | Trimmed prompt persists; empty prompt is rejected. |
| Reset prompt | UI, Test | Built-in prompt is restored with visible feedback. |
| Add application rule | UI, Test | Bundle ID/name and style mapping persist. |
| Edit application rule | UI, Test | Existing application identity can be updated. |
| Cancel rule editor | UI | Sheet closes without creating a rule. |
| Delete application rule | Test, Pending | Settings-backed deletion is tested; destructive UI click remains. |

## File Transcription

| Control | Evidence | Result |
| --- | --- | --- |
| Choose file | UI, Live, Test | Supported WAV loads; unsupported AIFF shows an error. |
| Start | UI, Live, Test | Local Qwen3-ASR completed a real transcription. |
| Cancel | UI, Test | Cancellation path executes without corrupting the job. |
| Retry | UI, Test | Failed/cancelled job can run again. |
| Export TXT | UI, Test | Plain text export is generated. |
| Export Markdown | UI, Test | Markdown export is generated. |
| Export SRT | UI, Test | Subtitle export is generated. |
| Save as note | UI, Test | A note is created from the transcription. |

## Notes

| Control | Evidence | Result |
| --- | --- | --- |
| New note | UI, Test | Creates and selects an editable draft. |
| Save | UI, Test | Title, tags, and body persist. |
| Search | UI, Test | Repository search matches title, body, and tags. |
| Export Markdown | UI, Test | Markdown output is generated. |
| Delete | Test, Pending | Soft delete is tested; destructive UI click remains. |

## Settings: General

| Control | Evidence | Result |
| --- | --- | --- |
| Input device picker | UI, Test | Device selection persists. |
| Shortcut key code Apply/Return | UI, Test | Valid value applies with feedback; invalid input is rejected. |
| Short-press picker | UI, Test | Behavior changes and persists. |
| Long-press slider | UI, Test | Threshold changes and persists. |
| Sound toggle | UI, Test | State changes and persists. |
| Voice enhancement toggle | UI, Test | State changes and persists. |

## Settings: Models

| Control | Evidence | Result |
| --- | --- | --- |
| Add LLM Provider | UI, Test | Provider and Keychain credential reference persist. |
| Edit/cancel Provider | UI, Test | Existing credential reference survives a blank key edit. |
| Show/hide API key | UI | Secure/plain field toggles. |
| Test connection | UI, Live, Test | Real configured provider succeeds; invalid endpoint shows error. |
| Refresh models and measure | UI, Live, Test | Model request and latency result are surfaced. |
| Select global model | Test, Pending | Repository selection is tested; menu click remains. |
| Delete Provider | Test, Pending | Credential deletion and default-provider promotion are tested. |
| Model size picker | UI, Test | 0.6B/1.7B selection persists. |
| Provider tag filters | UI, Test | Visible provider cards filter by tag. |
| Set default ASR | UI, Test | Available provider becomes the global transcription model. |
| Download local model | Test, Pending | Downloader behavior is tested; live UI click remains. |
| Delete local model | Test, Pending | Path cleanup and Apple fallback are tested; destructive UI click remains. |

## Settings: System and Data

| Control | Evidence | Result |
| --- | --- | --- |
| Microphone settings link | UI, Live | Opens the matching System Settings pane. |
| Speech settings link | UI, Live | Opens the matching System Settings pane. |
| Accessibility settings link | UI, Live | Opens the matching System Settings pane. |
| Mute while recording toggle | UI, Test | State changes and persists. |
| Performance optimization toggle | UI, Test | State changes and persists. |
| Analytics toggle | Test, Pending | Persistence is tested; UI click remains. |
| Export data | Test, Pending | JSON snapshot generation is tested; UI click remains. |
| Import settings | Test, Pending | Settings JSON import is tested; UI click remains. |
| Clear history | Test, Pending | Soft-delete behavior is tested; destructive UI click remains. |
| Clear cache | Test, Pending | Model cache recreation is tested; destructive UI click remains. |
| Reset settings | Test, Pending | Repository/default reset is tested; destructive UI click remains. |

## Help, Menu, and Window

| Control | Evidence | Result |
| --- | --- | --- |
| Project/release/issues/privacy links | Pending | Requires unlocked UI and browser handoff. |
| Language menu items | Test, Pending | Language state is tested; menu clicks remain. |
| ASR engine menu items | Test, Pending | Selection/fallback is tested; menu clicks remain. |
| Open workbench/settings | UI | Both menu entries open the unified main window. |
| LLM correction toggle | Live, Pending | Runtime setting was used by real refinement; menu click remains. |
| Permission check | Pending | Modal and both actions remain. |
| Quit | Pending | Must be the final UI action. |
| Close/minimize/zoom window | Pending | Requires unlocked UI. |
| White status icon | Test, Pending | Template image plus explicit white tint is implemented; visual check remains. |

## Automated Baseline

- `swift test`: 191 tests passed, 2 environment-gated tests skipped before the
  final two regression cases were added.
- `swift build -c debug -Xswiftc -warnings-as-errors`: passed.
- A restorable backup of Application Support, preferences, and the local model
  is stored at `/tmp/voiceinput-ui-audit-backup` for destructive UI checks.
