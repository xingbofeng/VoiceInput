import AVFoundation
import XCTest
@testable import VoiceInputApp

final class Qwen3LiveSmokeTests: XCTestCase {
    func testDownloadedQwen3EngineProcessesSyntheticAudio() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["VOICEINPUT_TEST_QWEN3_LIVE"] == "1",
            "Set VOICEINPUT_TEST_QWEN3_LIVE=1 to run the local Qwen3 model smoke test."
        )

        let modelPath = ProcessInfo.processInfo.environment["VOICEINPUT_TEST_QWEN3_MODEL_PATH"]
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/VoiceInput/Models/qwen3-asr-0.6b-coreml-int8")
                .path
        let engine = Qwen3ASREngine(modelPath: modelPath)
        XCTAssertTrue(engine.isAvailable, "Qwen3 model is not available at \(modelPath)")

        let completed = expectation(description: "Qwen3 completes synthetic audio transcription")
        var receivedText: String?
        var receivedError: Error?
        engine.onTranscription = { text, isFinal in
            if isFinal {
                receivedText = text
                completed.fulfill()
            }
        }
        engine.onError = { error in
            receivedError = error
            completed.fulfill()
        }

        do {
            try engine.start()
        } catch Qwen3ASREngineError.unsupportedOS {
            throw XCTSkip("Qwen3-ASR requires macOS 15 or newer.")
        }

        engine.appendAudioBuffer(Self.makeSilentBuffer(seconds: 2))
        engine.endAudio()

        wait(for: [completed], timeout: 120)
        XCTAssertNil(receivedError)
        XCTAssertNotNil(receivedText)
    }

    private static func makeSilentBuffer(seconds: Double) -> AVAudioPCMBuffer {
        let sampleRate = 16_000.0
        let frameCount = AVAudioFrameCount(sampleRate * seconds)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        return buffer
    }
}
