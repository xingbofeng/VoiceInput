import AVFoundation
import Foundation

enum ASREngineType: String, CaseIterable, Equatable {
    case apple = "Apple Speech"
    case qwen3 = "Qwen3-ASR"
}

protocol ASREngine: AnyObject {
    /// Must be called on the main thread. Implementations must dispatch callbacks to main queue.
    var onTranscription: ((String, Bool) -> Void)? { get set }
    /// Must be called on the main thread. Implementations must dispatch callbacks to main queue.
    var onError: ((Error) -> Void)? { get set }
    var isAvailable: Bool { get }
    func configure(locale: Locale)
    func start() throws
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func endAudio()
    func stop()
    func cancel()
}

enum ASREngineError: LocalizedError {
    case modelNotLoaded
    var errorDescription: String? { "Qwen3-ASR 模型未加载。请在设置中指定模型路径。" }
}

protocol ASREngineFactory {
    func makeEngine(type: ASREngineType) -> ASREngine
}
