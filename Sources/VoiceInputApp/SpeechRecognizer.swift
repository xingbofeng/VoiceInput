import Speech

/// Streaming speech recognizer using Apple's SFSpeechRecognizer.
/// Provides real-time transcription updates as audio is received.
final class SpeechRecognizer: NSObject {
    // MARK: - Types

    typealias TranscriptionHandler = (String, Bool) -> Void  // (text, isFinal)
    typealias ErrorHandler = (Swift.Error) -> Void

    // MARK: - Properties

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var onTranscription: TranscriptionHandler?
    var onError: ErrorHandler?
    private(set) var isAvailable = false

    // MARK: - Permission

    static func checkPermission() -> AudioRecorder.PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func requestPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Lifecycle

    func configure(locale: Locale) {
        recognizer = nil
        recognizer = SFSpeechRecognizer(locale: locale)
        isAvailable = recognizer?.isAvailable ?? false
    }

    func start() throws {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw Error.authorizationDenied
        }

        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw Error.recognizerUnavailable
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw Error.requestCreationFailed
        }

        request.shouldReportPartialResults = true

        // For macOS, we don't use on-device; always use network
        if #available(macOS 14.0, *) {
            // on-device is not supported on macOS
        }
        request.requiresOnDeviceRecognition = false

        // taskHint based on expected content
        request.taskHint = .dictation

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                let nsError = error as NSError
                let wasCancelled =
                    (nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216)
                    || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
                if wasCancelled {
                    return
                }
                DispatchQueue.main.async {
                    self.onError?(error)
                }
                return
            }

            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                DispatchQueue.main.async {
                    self.onTranscription?(text, isFinal)
                }
            }
        }
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func endAudio() {
        recognitionRequest?.endAudio()
    }

    func stop() {
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
    }

    func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    // MARK: - Errors

    enum Error: Swift.Error, LocalizedError {
        case authorizationDenied
        case recognizerUnavailable
        case requestCreationFailed

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "未获得语音识别权限。"
            case .recognizerUnavailable:
                return "语音识别服务不可用，请检查网络连接。"
            case .requestCreationFailed:
                return "无法创建语音识别请求。"
            }
        }
    }
}
