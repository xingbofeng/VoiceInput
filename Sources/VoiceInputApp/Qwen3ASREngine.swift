import AVFoundation
import FluidAudio
import Foundation

private final class ManagerBox: @unchecked Sendable {
    let value: Any
    init(_ value: Any) { self.value = value }
}

/// Qwen3-ASR CoreML-based speech recognition engine.
final class Qwen3ASREngine: NSObject, @unchecked Sendable, ASREngine {
    // MARK: - ASREngine

    var onTranscription: ((String, Bool) -> Void)?
    var onError: ((Error) -> Void)?
    private(set) var isAvailable: Bool

    // MARK: - Properties

    /// Path to the FluidAudio-compatible Qwen3-ASR model directory.
    private let modelPath: String?
    private var languageHint: String?

    /// Accumulated 16kHz mono audio samples during recording.
    private var audioBuffer: [Float] = []

    /// Pre-loaded Qwen3AsrManager task — created in `start()` so model loading
    /// happens during recording, not during `endAudio()`.
    /// Stored as `Any` to avoid `@available(macOS 15, *)` on the stored property.
    private var managerTask: Task<ManagerBox, Error>?

    // MARK: - Initialization

    /// Creates a Qwen3-ASR engine.
    /// - Parameter modelPath: Path to the compiled .mlmodelc directory,
    ///   or nil if no model is available.
    init(modelPath: String?) {
        self.modelPath = modelPath
        if let modelPath {
            self.isAvailable = Qwen3ModelManifest.supportedModelExists(
                at: URL(fileURLWithPath: modelPath, isDirectory: true)
            )
        } else {
            self.isAvailable = false
        }
        super.init()
    }

    // MARK: - ASREngine Methods

    func configure(locale: Locale) {
        languageHint = Self.qwen3LanguageHint(for: locale)
    }

    func start() throws {
        audioBuffer = []

        guard isAvailable else {
            throw Qwen3ASREngineError.modelNotAvailable
        }
        guard #available(macOS 15, *) else {
            throw Qwen3ASREngineError.unsupportedOS
        }

        // Pre-load CoreML models in background during recording.
        // This avoids the 2-5s model-load penalty in endAudio().
        if managerTask == nil, let path = modelPath {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            managerTask = Task<ManagerBox, Error> {
                let manager = Qwen3AsrManager()
                try await manager.loadModels(from: url)
                return ManagerBox(manager)
            }
        }
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isAvailable else { return }

        if let resampled = AudioPreprocessor.resampleTo16kHz(buffer) {
            audioBuffer.append(contentsOf: resampled)
        }
    }

    func endAudio() {
        guard let modelPath else {
            onError?(Qwen3ASREngineError.modelNotAvailable)
            return
        }

        let samples = audioBuffer
        let languageHint = languageHint

        guard !samples.isEmpty else {
            onTranscription?("", true)
            return
        }

        // Capture the pre-load task (start() already kicked it off).
        let task = managerTask

        Task {
            do {
                guard #available(macOS 15, *) else {
                    throw Qwen3ASREngineError.unsupportedOS
                }

                let manager: Qwen3AsrManager
                if let task {
                    // Reuse pre-loaded model — no disk I/O here.
                    manager = try await task.value.value as! Qwen3AsrManager
                } else {
                    // Fallback: load now (shouldn't normally happen).
                    manager = Qwen3AsrManager()
                    let url = URL(fileURLWithPath: modelPath, isDirectory: true)
                    try await manager.loadModels(from: url)
                }

                let text = try await manager.transcribe(
                    audioSamples: samples,
                    language: languageHint
                )
                let capturedOnTranscription = onTranscription
                await MainActor.run {
                    capturedOnTranscription?(text, true)
                }
            } catch {
                let capturedOnError = onError
                await MainActor.run {
                    capturedOnError?(error)
                }
            }
        }
    }

    func stop() {
        audioBuffer = []
        // Keep managerTask alive — model stays loaded for next recording.
    }

    func cancel() {
        audioBuffer = []
        managerTask?.cancel()
        managerTask = nil
    }

    private static func qwen3LanguageHint(for locale: Locale) -> String? {
        let identifier = locale.identifier.lowercased()
        if identifier.hasPrefix("zh") { return "zh" }
        if identifier.hasPrefix("en") { return "en" }
        if identifier.hasPrefix("ja") { return "ja" }
        if identifier.hasPrefix("ko") { return "ko" }
        return nil
    }
}

// MARK: - Errors

enum Qwen3ASREngineError: Error, LocalizedError {
    case modelNotAvailable
    case modelLoadFailed(String)
    case unsupportedOS

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Qwen3-ASR 模型未配置。请在设置中指定模型路径。"
        case .modelLoadFailed(let reason):
            return "Qwen3-ASR 模型加载失败：\(reason)"
        case .unsupportedOS:
            return "Qwen3-ASR 需要 macOS 15 或更新版本。"
        }
    }
}
