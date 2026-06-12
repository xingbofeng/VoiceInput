import XCTest
@testable import VoiceInputApp

@MainActor
final class FileTranscriptionViewModelTests: XCTestCase {
    func testRejectsUnsupportedFormat() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = FileTranscriptionViewModel(
            environment: environment,
            worker: StubFileTranscriptionWorker()
        )
        let file = URL(fileURLWithPath: "/tmp/readme.txt")

        XCTAssertThrowsError(try viewModel.enqueueFiles([file]))
        XCTAssertEqual(viewModel.jobs, [])
    }

    func testQueueRunsJobAndPersistsProgress() async throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let worker = StubFileTranscriptionWorker(
            result: FileTranscriptionResult(
                text: "转写完成",
                durationMS: 2_000,
                segments: [TranscriptionSegment(startMS: 0, endMS: 2_000, text: "转写完成")]
            )
        )
        let viewModel = FileTranscriptionViewModel(environment: environment, worker: worker)
        let job = try viewModel.enqueueFiles([URL(fileURLWithPath: "/tmp/audio.m4a")]).first!

        await viewModel.run(jobID: job.id)

        let saved = try XCTUnwrap(try environment.transcriptionJobRepository.job(id: job.id))
        XCTAssertEqual(saved.status, TranscriptionJobStatus.completed.rawValue)
        XCTAssertEqual(saved.progress, 1)
        XCTAssertEqual(saved.finalText, "转写完成")
        XCTAssertEqual(viewModel.jobs.first?.status, TranscriptionJobStatus.completed.rawValue)
        XCTAssertEqual(viewModel.statusTitle(for: saved), "已完成")
    }

    func testCancelAndRetryFailedJob() async throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let worker = StubFileTranscriptionWorker(error: CancellationError())
        let viewModel = FileTranscriptionViewModel(environment: environment, worker: worker)
        let job = try viewModel.enqueueFiles([URL(fileURLWithPath: "/tmp/audio.wav")]).first!

        await viewModel.run(jobID: job.id)
        XCTAssertEqual(viewModel.jobs.first?.status, TranscriptionJobStatus.cancelled.rawValue)

        viewModel.worker = StubFileTranscriptionWorker(
            result: FileTranscriptionResult(text: "retry ok", durationMS: 1_000, segments: [])
        )
        await viewModel.retry(jobID: job.id)

        XCTAssertEqual(viewModel.jobs.first?.status, TranscriptionJobStatus.completed.rawValue)
        XCTAssertEqual(viewModel.jobs.first?.finalText, "retry ok")
    }

    func testExportsTxtMarkdownSRTAndSavesNote() async throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let worker = StubFileTranscriptionWorker(
            result: FileTranscriptionResult(
                text: "第一句\n第二句",
                durationMS: 3_000,
                segments: [
                    TranscriptionSegment(startMS: 0, endMS: 1_500, text: "第一句"),
                    TranscriptionSegment(startMS: 1_500, endMS: 3_000, text: "第二句"),
                ]
            )
        )
        let viewModel = FileTranscriptionViewModel(environment: environment, worker: worker)
        let job = try viewModel.enqueueFiles([URL(fileURLWithPath: "/tmp/story.mp3")]).first!
        await viewModel.run(jobID: job.id)

        let txt = try viewModel.export(jobID: job.id, format: .txt)
        let md = try viewModel.export(jobID: job.id, format: .markdown)
        let srt = try viewModel.export(jobID: job.id, format: .srt)
        let note = try viewModel.saveAsNote(jobID: job.id)

        XCTAssertEqual(txt, "第一句\n第二句")
        XCTAssertTrue(md.contains("# story.mp3"))
        XCTAssertTrue(srt.contains("00:00:01,500 --> 00:00:03,000"))
        XCTAssertEqual(note.sourceType, "fileTranscription")
        XCTAssertEqual(try environment.noteRepository.list().first?.sourceID, job.id)
        XCTAssertEqual(viewModel.lastActionMessage, "已保存为笔记")
    }

    func testStatusTitlesAreLocalized() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = FileTranscriptionViewModel(
            environment: environment,
            worker: StubFileTranscriptionWorker()
        )

        XCTAssertEqual(viewModel.statusTitle(for: makeJob(status: .queued)), "等待开始")
        XCTAssertEqual(viewModel.statusTitle(for: makeJob(status: .running)), "转写中")
        XCTAssertEqual(viewModel.statusTitle(for: makeJob(status: .completed)), "已完成")
        XCTAssertEqual(viewModel.statusTitle(for: makeJob(status: .failed)), "失败")
        XCTAssertEqual(viewModel.statusTitle(for: makeJob(status: .cancelled)), "已取消")
    }

    func testCopyResultWritesCompletedTextToClipboard() async throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let clipboard = CapturingFileClipboardWriter()
        let worker = StubFileTranscriptionWorker(
            result: FileTranscriptionResult(text: "直接复制结果", durationMS: 1_000, segments: [])
        )
        let viewModel = FileTranscriptionViewModel(
            environment: environment,
            worker: worker,
            clipboardWriter: clipboard
        )
        let job = try viewModel.enqueueFiles([URL(fileURLWithPath: "/tmp/copy.m4a")]).first!
        await viewModel.run(jobID: job.id)

        try viewModel.copyResult(jobID: job.id)

        XCTAssertEqual(clipboard.copiedTexts, ["直接复制结果"])
        XCTAssertEqual(viewModel.lastActionMessage, "已复制转写结果")
        XCTAssertEqual(viewModel.lastActionTone, .informational)
    }

    private func makeJob(status: TranscriptionJobStatus) -> TranscriptionJobRecord {
        TranscriptionJobRecord(
            id: UUID().uuidString,
            sourceFilePath: "/tmp/audio.m4a",
            sourceFileName: "audio.m4a",
            status: status.rawValue,
            progress: 0,
            rawText: nil,
            finalText: status == .completed ? "完成" : nil,
            asrProviderID: nil,
            styleID: nil,
            errorMessage: nil,
            durationMS: 0,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil
        )
    }
}

private final class CapturingFileClipboardWriter: ClipboardWriting {
    private(set) var copiedTexts: [String] = []

    func copy(_ text: String) {
        copiedTexts.append(text)
    }
}

private struct StubFileTranscriptionWorker: FileTranscriptionWorking {
    var result = FileTranscriptionResult(text: "", durationMS: 0, segments: [])
    var error: Error?

    func transcribe(
        fileURL: URL,
        asrProviderID: String?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> FileTranscriptionResult {
        progress(0.5)
        if let error {
            throw error
        }
        progress(1)
        return result
    }
}
