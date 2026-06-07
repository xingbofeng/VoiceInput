import AVFoundation
import Foundation

protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    func start() throws
    func stop()
}

extension AudioRecorder: AudioRecording {}

@MainActor
protocol TextInjecting: AnyObject {
    func inject(_ text: String) async
}

extension TextInjector: TextInjecting {}

struct DictationConfiguration: Equatable {
    let engineType: ASREngineType
    let locale: Locale
    let languageIdentifier: String
    let asrProviderID: String

    init(
        engineType: ASREngineType,
        locale: Locale,
        languageIdentifier: String,
        asrProviderID: String? = nil
    ) {
        self.engineType = engineType
        self.locale = locale
        self.languageIdentifier = languageIdentifier
        self.asrProviderID = asrProviderID ?? engineType.providerID
    }
}

@MainActor
final class DictationOrchestrator {
    var onStateChange: (DictationState) -> Void = { _ in }
    var onTranscriptionUpdate: (String, Bool) -> Void = { _, _ in }
    var onProcessingStarted: (String) -> Void = { _ in }
    var onHistorySaved: () -> Void = {}
    var onError: (Error) -> Void = { _ in }

    private let asrEngineFactory: any ASREngineFactory
    private let audioRecorder: any AudioRecording
    private let textPipeline: any TextProcessing
    private let textInjector: any TextInjecting
    private let historyRepository: any HistoryRepository
    private let clock: any AppClock
    private let targetProvider: any DictationTargetProviding
    private let finalTimeoutNanoseconds: UInt64
    private var stateMachine = DictationStateMachine()
    private var transcriptionSession = TranscriptionSession()
    private var currentEngine: ASREngine?
    private var currentConfiguration: DictationConfiguration?
    private var currentTarget: DictationTarget?
    private var startedAt: Date?
    private var finalTimeoutTask: Task<Void, Never>?

    var state: DictationState {
        stateMachine.state
    }

    init(
        asrEngineFactory: any ASREngineFactory,
        audioRecorder: any AudioRecording,
        textPipeline: any TextProcessing,
        textInjector: any TextInjecting,
        historyRepository: any HistoryRepository,
        clock: any AppClock = SystemClock(),
        targetProvider: any DictationTargetProviding = WorkspaceDictationTargetProvider(),
        finalTimeoutNanoseconds: UInt64 = 15_000_000_000
    ) {
        self.asrEngineFactory = asrEngineFactory
        self.audioRecorder = audioRecorder
        self.textPipeline = textPipeline
        self.textInjector = textInjector
        self.historyRepository = historyRepository
        self.clock = clock
        self.targetProvider = targetProvider
        self.finalTimeoutNanoseconds = finalTimeoutNanoseconds
    }

    func start(configuration: DictationConfiguration) throws {
        guard stateMachine.startRecording() else {
            throw DictationOrchestratorError.alreadyRunning
        }

        transcriptionSession = TranscriptionSession()
        currentConfiguration = configuration
        currentTarget = targetProvider.currentTarget()
        startedAt = clock.now
        finalTimeoutTask?.cancel()
        finalTimeoutTask = nil

        let engine = asrEngineFactory.makeEngine(type: configuration.engineType)
        currentEngine = engine
        engine.configure(locale: configuration.locale)
        engine.onTranscription = { [weak self] text, isFinal in
            Task { @MainActor [weak self] in
                self?.handleTranscription(text: text, isFinal: isFinal)
            }
        }
        engine.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                await self?.handleRecognitionError(error)
            }
        }

        do {
            try engine.start()
            try audioRecorder.start()
            notifyStateChanged()
        } catch {
            audioRecorder.stop()
            engine.cancel()
            currentEngine = nil
            stateMachine.reset()
            notifyStateChanged()
            throw error
        }
    }

    func release() {
        guard state == .recording else {
            return
        }

        audioRecorder.stop()
        currentEngine?.endAudio()

        if let completedText = transcriptionSession.release() {
            Task { @MainActor [weak self] in
                await self?.finishRecognizedText(completedText)
            }
            return
        }

        guard stateMachine.waitForFinalResult() else {
            return
        }
        notifyStateChanged()
        scheduleFinalTimeout()
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        currentEngine?.appendAudioBuffer(buffer)
    }

    func cancel() {
        guard state.isRecordingActive else {
            return
        }
        finalTimeoutTask?.cancel()
        finalTimeoutTask = nil
        audioRecorder.stop()
        currentEngine?.cancel()
        currentEngine = nil
        transcriptionSession = TranscriptionSession()
        currentTarget = nil
        stateMachine.finish()
        notifyStateChanged()
    }

    private func handleTranscription(text: String, isFinal: Bool) {
        guard state.isRecordingActive else {
            return
        }
        onTranscriptionUpdate(text, false)
        if let completedText = transcriptionSession.update(text: text, isFinal: isFinal) {
            Task { @MainActor [weak self] in
                await self?.finishRecognizedText(completedText)
            }
        }
    }

    private func scheduleFinalTimeout() {
        finalTimeoutTask?.cancel()
        finalTimeoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await clock.sleep(nanoseconds: finalTimeoutNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await handleFinalTimeout()
        }
    }

    private func handleFinalTimeout() async {
        guard state.isRecordingActive else {
            return
        }

        if let partialText = transcriptionSession.timeout(),
           !partialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await finishRecognizedText(partialText)
            return
        }

        fail(DictationOrchestratorError.finalResultTimedOut)
    }

    private func handleRecognitionError(_ error: Error) async {
        guard state.isRecordingActive else {
            return
        }

        if let partialText = transcriptionSession.fallbackToLatestText(),
           !partialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await finishRecognizedText(partialText)
            return
        }

        fail(error)
    }

    private func finishRecognizedText(_ recognizedText: String) async {
        guard state.isRecordingActive else {
            return
        }

        finalTimeoutTask?.cancel()
        finalTimeoutTask = nil
        audioRecorder.stop()
        currentEngine?.stop()

        let rawText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            currentEngine = nil
            stateMachine.finish()
            notifyStateChanged()
            return
        }

        guard stateMachine.startProcessing() else {
            return
        }
        notifyStateChanged()
        onProcessingStarted(rawText)

        let target = currentTarget
        let processingResult = await textPipeline.process(rawText, target: target)
        let finalText = normalizedFinalText(from: processingResult, fallback: rawText)

        guard stateMachine.startInjecting() else {
            return
        }
        notifyStateChanged()
        await textInjector.inject(finalText)

        saveHistory(rawText: rawText, finalText: finalText, target: target, processingResult: processingResult)

        currentEngine = nil
        currentTarget = nil
        stateMachine.finish()
        notifyStateChanged()
    }

    private func normalizedFinalText(from result: TextProcessingResult, fallback: String) -> String {
        let trimmed = result.finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func saveHistory(
        rawText: String,
        finalText: String,
        target: DictationTarget?,
        processingResult: TextProcessingResult
    ) {
        guard let configuration = currentConfiguration else {
            return
        }

        let finishedAt = clock.now
        let startedAt = startedAt ?? finishedAt
        let durationMS = max(0, Int(finishedAt.timeIntervalSince(startedAt) * 1000))
        let charCount = finalText.count
        let durationMinutes = max(Double(durationMS) / 60_000.0, 1.0 / 60_000.0)

        let entry = DictationHistoryEntry(
            id: UUID().uuidString,
            rawText: rawText,
            finalText: finalText,
            language: configuration.languageIdentifier,
            asrProviderID: configuration.asrProviderID,
            llmProviderID: processingResult.llmProviderID,
            styleID: processingResult.styleID,
            durationMS: durationMS,
            charCount: charCount,
            cpm: Double(charCount) / durationMinutes,
            targetAppBundleID: target?.bundleID,
            targetAppName: target?.appName,
            processingWarningsJSON: warningsJSON(processingResult.warnings),
            processingTraceJSON: traceJSON(processingResult.trace),
            createdAt: finishedAt,
            updatedAt: finishedAt,
            deletedAt: nil
        )

        do {
            try historyRepository.save(entry)
            onHistorySaved()
        } catch {
            AppLogger.general.error("Failed to save dictation history: \(error.localizedDescription)")
        }
    }

    private func warningsJSON(_ warnings: [String]) -> String? {
        guard !warnings.isEmpty,
              let data = try? JSONEncoder().encode(warnings) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func traceJSON(_ trace: TextProcessingTrace?) -> String? {
        guard let trace,
              let data = try? JSONEncoder().encode(trace) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func fail(_ error: Error) {
        finalTimeoutTask?.cancel()
        finalTimeoutTask = nil
        audioRecorder.stop()
        currentEngine?.cancel()
        currentEngine = nil
        currentTarget = nil
        stateMachine.fail(message: error.localizedDescription)
        notifyStateChanged()
        onError(error)
        stateMachine.finish()
        notifyStateChanged()
    }

    private func notifyStateChanged() {
        onStateChange(state)
    }
}

enum DictationOrchestratorError: LocalizedError, Equatable {
    case alreadyRunning
    case finalResultTimedOut

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "听写正在进行中。"
        case .finalResultTimedOut:
            return "语音识别超时，请重试。"
        }
    }
}

extension ASREngineType {
    var providerID: String {
        switch self {
        case .apple:
            return "apple_speech"
        case .qwen3:
            return "qwen3_asr"
        }
    }
}
