import AVFoundation

/// Manages audio capture from the default microphone with real-time RMS level metering.
final class AudioRecorder: NSObject {
    // MARK: - Types

    @MainActor protocol Delegate: AnyObject {
        func audioRecorder(_ recorder: AudioRecorder, didReceiveBuffer buffer: AVAudioPCMBuffer)
        func audioRecorder(_ recorder: AudioRecorder, didUpdateRMS rms: Float)
    }

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
    }

    // MARK: - Properties

    private let engine = AVAudioEngine()
    private(set) var isRecording = false
    weak var delegate: Delegate?

    // MARK: - Permission

    static func checkPermission() -> PermissionStatus {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            case .undetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        }
        return .granted
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            #if os(macOS)
            if #available(macOS 14.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                continuation.resume(returning: true)
            }
            #endif
        }
    }

    // MARK: - Lifecycle

    func start() throws {
        guard !isRecording else { return }
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            let rms = Self.calculateRMS(from: buffer)
            DispatchQueue.main.async {
                self.delegate?.audioRecorder(self, didReceiveBuffer: buffer)
                self.delegate?.audioRecorder(self, didUpdateRMS: rms)
            }
        }

        do {
            engine.prepare()
            try engine.start()
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            engine.stop()
            throw error
        }
    }

    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        isRecording = false
    }

    // MARK: - RMS Calculation

    static func calculateRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0.0 }

        let samples = channelData[0]
        var sum: Float = 0.0

        // Process in chunks for better cache utilization
        let strideCount = frameLength / 4
        for i in 0..<strideCount {
            let idx = i * 4
            sum += samples[idx] * samples[idx]
            sum += samples[idx + 1] * samples[idx + 1]
            sum += samples[idx + 2] * samples[idx + 2]
            sum += samples[idx + 3] * samples[idx + 3]
        }

        // Handle remainder
        let remainder = frameLength - (strideCount * 4)
        for i in 0..<remainder {
            let sample = samples[strideCount * 4 + i]
            sum += sample * sample
        }

        let mean = sum / Float(frameLength)
        let rms = sqrt(mean)

        // Convert to dB and normalize to 0...1 range
        // RMS floor is around -60 dB for silence
        let db = 20.0 * log10(max(rms, 1e-6))
        let normalized = max(0.0, min(1.0, (db + 50.0) / 50.0))
        return normalized
    }
}
