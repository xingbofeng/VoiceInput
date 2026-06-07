import AVFoundation
import XCTest
@testable import VoiceInputApp

@MainActor
final class DictationOrchestratorTests: XCTestCase {
    func testFinalTranscriptIsProcessedInjectedAndSavedToHistory() async throws {
        let engine = FakeASREngine()
        let audioRecorder = FakeAudioRecorder()
        let pipeline = FakeTextPipeline(result: TextProcessingResult(rawText: "raw", finalText: "final"))
        let injector = FakeTextInjector()
        let history = CapturingHistoryRepository()
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1_800_000_000))
        let orchestrator = makeOrchestrator(
            engine: engine,
            audioRecorder: audioRecorder,
            pipeline: pipeline,
            injector: injector,
            history: history,
            clock: clock
        )
        var historySavedCount = 0
        orchestrator.onHistorySaved = {
            historySavedCount += 1
        }

        try orchestrator.start(configuration: .appleChinese)
        clock.now = Date(timeIntervalSince1970: 1_800_000_003)
        orchestrator.release()
        engine.emit(text: "raw", isFinal: true)
        await drainMainActorTasks()

        XCTAssertEqual(injector.injectedTexts, ["final"])
        XCTAssertEqual(history.savedEntries.count, 1)
        XCTAssertEqual(history.savedEntries.first?.rawText, "raw")
        XCTAssertEqual(history.savedEntries.first?.finalText, "final")
        XCTAssertEqual(history.savedEntries.first?.language, "zh-CN")
        XCTAssertEqual(history.savedEntries.first?.asrProviderID, "apple_speech")
        XCTAssertEqual(history.savedEntries.first?.durationMS, 3000)
        XCTAssertEqual(historySavedCount, 1)
        XCTAssertEqual(orchestrator.state, .idle)
        XCTAssertFalse(audioRecorder.isRecording)
        XCTAssertTrue(engine.didStop)
    }

    func testFinalTimeoutUsesLatestPartialResult() async throws {
        let engine = FakeASREngine()
        let audioRecorder = FakeAudioRecorder()
        let pipeline = FakeTextPipeline(result: TextProcessingResult(rawText: "partial", finalText: "partial"))
        let injector = FakeTextInjector()
        let history = CapturingHistoryRepository()
        let clock = MutableClock(
            now: Date(timeIntervalSince1970: 1_800_000_000),
            returnsFromSleepImmediately: true
        )
        let orchestrator = makeOrchestrator(
            engine: engine,
            audioRecorder: audioRecorder,
            pipeline: pipeline,
            injector: injector,
            history: history,
            clock: clock,
            finalTimeoutNanoseconds: 1
        )

        try orchestrator.start(configuration: .appleChinese)
        engine.emit(text: "partial", isFinal: false)
        orchestrator.release()
        await drainMainActorTasks()

        XCTAssertEqual(injector.injectedTexts, ["partial"])
        XCTAssertEqual(history.savedEntries.first?.rawText, "partial")
        XCTAssertEqual(orchestrator.state, .idle)
    }

    func testRecognitionErrorFallsBackToLatestPartialResultAfterRelease() async throws {
        let engine = FakeASREngine()
        let audioRecorder = FakeAudioRecorder()
        let pipeline = FakeTextPipeline(result: TextProcessingResult(rawText: "partial", finalText: "partial"))
        let injector = FakeTextInjector()
        let history = CapturingHistoryRepository()
        let orchestrator = makeOrchestrator(
            engine: engine,
            audioRecorder: audioRecorder,
            pipeline: pipeline,
            injector: injector,
            history: history
        )

        try orchestrator.start(configuration: .appleChinese)
        engine.emit(text: "partial", isFinal: false)
        orchestrator.release()
        engine.fail(TestError.expected)
        await drainMainActorTasks()

        XCTAssertEqual(injector.injectedTexts, ["partial"])
        XCTAssertEqual(history.savedEntries.first?.rawText, "partial")
        XCTAssertEqual(orchestrator.state, .idle)
    }

    func testCancelStopsAudioAndEngineWithoutInjection() throws {
        let engine = FakeASREngine()
        let audioRecorder = FakeAudioRecorder()
        let injector = FakeTextInjector()
        let history = CapturingHistoryRepository()
        let orchestrator = makeOrchestrator(
            engine: engine,
            audioRecorder: audioRecorder,
            injector: injector,
            history: history
        )

        try orchestrator.start(configuration: .appleChinese)
        orchestrator.cancel()

        XCTAssertFalse(audioRecorder.isRecording)
        XCTAssertTrue(engine.didCancel)
        XCTAssertEqual(injector.injectedTexts, [])
        XCTAssertEqual(history.savedEntries, [])
        XCTAssertEqual(orchestrator.state, .idle)
    }

    func testTargetApplicationIsCapturedWhenDictationStarts() async throws {
        let engine = FakeASREngine()
        let pipeline = FakeTextPipeline(
            result: TextProcessingResult(rawText: "raw", finalText: "final")
        )
        let targetProvider = MutableTargetProvider(
            target: DictationTarget(bundleID: "com.apple.dt.Xcode", appName: "Xcode")
        )
        let orchestrator = DictationOrchestrator(
            asrEngineFactory: FakeASREngineFactory(engine: engine),
            audioRecorder: FakeAudioRecorder(),
            textPipeline: pipeline,
            textInjector: FakeTextInjector(),
            historyRepository: CapturingHistoryRepository(),
            targetProvider: targetProvider
        )

        try orchestrator.start(configuration: .appleChinese)
        targetProvider.target = DictationTarget(bundleID: "com.voiceinput.app", appName: "VoiceInput")
        orchestrator.release()
        engine.emit(text: "raw", isFinal: true)
        await drainMainActorTasks()

        XCTAssertEqual(pipeline.targets, [
            DictationTarget(bundleID: "com.apple.dt.Xcode", appName: "Xcode")
        ])
    }

    private func makeOrchestrator(
        engine: FakeASREngine = FakeASREngine(),
        audioRecorder: FakeAudioRecorder = FakeAudioRecorder(),
        pipeline: FakeTextPipeline = FakeTextPipeline(result: TextProcessingResult(rawText: "", finalText: "")),
        injector: FakeTextInjector = FakeTextInjector(),
        history: CapturingHistoryRepository = CapturingHistoryRepository(),
        clock: MutableClock = MutableClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
        finalTimeoutNanoseconds: UInt64 = 15_000_000_000
    ) -> DictationOrchestrator {
        DictationOrchestrator(
            asrEngineFactory: FakeASREngineFactory(engine: engine),
            audioRecorder: audioRecorder,
            textPipeline: pipeline,
            textInjector: injector,
            historyRepository: history,
            clock: clock,
            targetProvider: StaticDictationTargetProvider(
                target: DictationTarget(bundleID: "com.example.editor", appName: "Editor")
            ),
            finalTimeoutNanoseconds: finalTimeoutNanoseconds
        )
    }

    private func drainMainActorTasks() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    private enum TestError: Error {
        case expected
    }
}

private extension DictationConfiguration {
    static let appleChinese = DictationConfiguration(
        engineType: .apple,
        locale: Locale(identifier: "zh-CN"),
        languageIdentifier: "zh-CN"
    )
}

private final class FakeASREngineFactory: ASREngineFactory {
    let engine: FakeASREngine

    init(engine: FakeASREngine) {
        self.engine = engine
    }

    func makeEngine(type: ASREngineType) -> ASREngine {
        engine
    }
}

private final class FakeASREngine: ASREngine {
    var onTranscription: ((String, Bool) -> Void)?
    var onError: ((Error) -> Void)?
    private(set) var isAvailable = true
    private(set) var didStart = false
    private(set) var didStop = false
    private(set) var didCancel = false
    private(set) var didEndAudio = false

    func configure(locale: Locale) {}

    func start() throws {
        didStart = true
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {}

    func endAudio() {
        didEndAudio = true
    }

    func stop() {
        didStop = true
    }

    func cancel() {
        didCancel = true
    }

    func emit(text: String, isFinal: Bool) {
        onTranscription?(text, isFinal)
    }

    func fail(_ error: Error) {
        onError?(error)
    }
}

private final class FakeAudioRecorder: AudioRecording {
    private(set) var isRecording = false
    var startError: Error?

    func start() throws {
        if let startError {
            throw startError
        }
        isRecording = true
    }

    func stop() {
        isRecording = false
    }
}

@MainActor
private final class FakeTextPipeline: TextProcessing {
    let result: TextProcessingResult
    private(set) var targets: [DictationTarget?] = []

    init(result: TextProcessingResult) {
        self.result = result
    }

    func process(_ rawText: String) async -> TextProcessingResult {
        TextProcessingResult(
            rawText: rawText,
            finalText: result.finalText,
            llmProviderID: result.llmProviderID,
            styleID: result.styleID,
            warnings: result.warnings
        )
    }

    func process(_ rawText: String, target: DictationTarget?) async -> TextProcessingResult {
        targets.append(target)
        return await process(rawText)
    }
}

@MainActor
private final class MutableTargetProvider: DictationTargetProviding {
    var target: DictationTarget?

    init(target: DictationTarget?) {
        self.target = target
    }

    func currentTarget() -> DictationTarget? {
        target
    }
}

@MainActor
private final class FakeTextInjector: TextInjecting {
    private(set) var injectedTexts: [String] = []

    func inject(_ text: String) async {
        injectedTexts.append(text)
    }
}

private final class CapturingHistoryRepository: HistoryRepository {
    private(set) var savedEntries: [DictationHistoryEntry] = []

    func save(_ entry: DictationHistoryEntry) throws {
        savedEntries.append(entry)
    }

    func entry(id: String) throws -> DictationHistoryEntry? {
        savedEntries.first { $0.id == id }
    }

    func listRecent(limit: Int) throws -> [DictationHistoryEntry] {
        Array(savedEntries.prefix(limit))
    }

    func search(_ query: String, limit: Int) throws -> [DictationHistoryEntry] {
        Array(savedEntries.filter { $0.finalText.contains(query) }.prefix(limit))
    }

    func softDelete(id: String, deletedAt: Date) throws {}
}

private final class MutableClock: AppClock, @unchecked Sendable {
    var now: Date
    private let returnsFromSleepImmediately: Bool

    init(now: Date, returnsFromSleepImmediately: Bool = false) {
        self.now = now
        self.returnsFromSleepImmediately = returnsFromSleepImmediately
    }

    func sleep(nanoseconds: UInt64) async throws {
        guard !returnsFromSleepImmediately else {
            return
        }
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
