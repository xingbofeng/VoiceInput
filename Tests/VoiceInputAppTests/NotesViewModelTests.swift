import XCTest
@testable import VoiceInputApp

@MainActor
final class NotesViewModelTests: XCTestCase {
    func testCreateUpdateDeleteAndSearchNotes() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = NotesViewModel(environment: environment)

        let note = try viewModel.createNote(
            title: "会议纪要",
            bodyMarkdown: "今天讨论 VoiceInput",
            tags: ["meeting", "work"]
        )
        try viewModel.updateNote(
            id: note.id,
            title: "会议纪要 updated",
            bodyMarkdown: "更新后的 Markdown",
            tags: ["work"]
        )
        viewModel.search("updated")

        XCTAssertEqual(viewModel.notes.map(\.title), ["会议纪要 updated"])
        XCTAssertEqual(viewModel.notes.first?.tags, ["work"])

        try viewModel.deleteNote(id: note.id)
        XCTAssertEqual(viewModel.notes, [])
    }

    func testSaveFromHistoryAndFileTranscription() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let now = environment.clock.now
        try environment.historyRepository.save(
            DictationHistoryEntry(
                id: "history",
                rawText: "raw",
                finalText: "历史文本",
                language: "zh-CN",
                asrProviderID: nil,
                llmProviderID: nil,
                styleID: nil,
                durationMS: 100,
                charCount: 4,
                cpm: 100,
                targetAppBundleID: nil,
                targetAppName: "Notes",
                processingWarningsJSON: nil,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
        )
        try environment.transcriptionJobRepository.save(
            TranscriptionJobRecord(
                id: "job",
                sourceFilePath: "/tmp/audio.m4a",
                sourceFileName: "audio.m4a",
                status: TranscriptionJobStatus.completed.rawValue,
                progress: 1,
                rawText: "文件 raw",
                finalText: "文件文本",
                asrProviderID: nil,
                styleID: nil,
                errorMessage: nil,
                durationMS: 1_000,
                createdAt: now,
                updatedAt: now,
                completedAt: now
            )
        )
        let viewModel = NotesViewModel(environment: environment)

        let historyNote = try viewModel.saveFromHistoryEntry(id: "history")
        let fileNote = try viewModel.saveFromTranscriptionJob(id: "job")

        XCTAssertEqual(historyNote.sourceType, "history")
        XCTAssertEqual(historyNote.bodyMarkdown, "历史文本")
        XCTAssertEqual(fileNote.sourceType, "fileTranscription")
        XCTAssertTrue(fileNote.bodyMarkdown.contains("文件文本"))
    }

    func testExportMarkdown() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = NotesViewModel(environment: environment)
        let note = try viewModel.createNote(
            title: "Draft",
            bodyMarkdown: "**hello**",
            tags: ["draft"]
        )

        let markdown = try viewModel.exportMarkdown(noteID: note.id)

        XCTAssertEqual(markdown, "# Draft\n\n**hello**")
        XCTAssertEqual(viewModel.lastActionMessage, "已生成 Markdown 导出内容")
    }

    func testRecordingStreamsTextAndSavesFinalNote() async throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let recorder = NotesTranscriberStub()
        let viewModel = NotesViewModel(environment: environment, transcriber: recorder)

        await viewModel.startRecording()
        recorder.emit(text: "正在记录", isFinal: false)

        XCTAssertEqual(viewModel.recordingState, .recording)
        XCTAssertEqual(viewModel.draftBodyMarkdown, "正在记录")
        XCTAssertEqual(viewModel.characterCount, 4)

        viewModel.finishRecording()
        XCTAssertEqual(viewModel.recordingState, .finishing)
        XCTAssertEqual(recorder.finishCallCount, 1)

        recorder.emit(text: "正在记录完成", isFinal: true)

        XCTAssertEqual(viewModel.recordingState, .idle)
        XCTAssertEqual(viewModel.notes.first?.bodyMarkdown, "正在记录完成")
        XCTAssertEqual(viewModel.selectedNoteID, viewModel.notes.first?.id)
    }

    func testRecordingFailureReturnsToIdleAndShowsError() async {
        let environment = try! AppEnvironment(container: DependencyContainer.inMemory())
        let recorder = NotesTranscriberStub()
        recorder.startError = NotesTranscriberStubError.permissionDenied
        let viewModel = NotesViewModel(environment: environment, transcriber: recorder)

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.recordingState, .idle)
        XCTAssertEqual(viewModel.lastError, "没有录音权限")
    }
}

@MainActor
private final class NotesTranscriberStub: NotesTranscribing {
    var onTranscription: ((String, Bool) -> Void)?
    var onError: ((Error) -> Void)?
    var startError: Error?
    private(set) var finishCallCount = 0

    func start() async throws {
        if let startError {
            throw startError
        }
    }

    func finish() {
        finishCallCount += 1
    }

    func cancel() {}

    func emit(text: String, isFinal: Bool) {
        onTranscription?(text, isFinal)
    }
}

private enum NotesTranscriberStubError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "没有录音权限"
    }
}
