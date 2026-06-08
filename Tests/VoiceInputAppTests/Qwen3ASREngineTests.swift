import AVFoundation
import XCTest
@testable import VoiceInputApp

final class Qwen3ASREngineTests: XCTestCase {
    func testEngineIsNotAvailableWithoutModel() {
        let engine = Qwen3ASREngine(modelPath: nil)
        XCTAssertFalse(engine.isAvailable)
    }

    func testEngineIsNotAvailableWithEmptyModelDirectory() throws {
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceInputTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: modelURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: modelURL) }

        let engine = Qwen3ASREngine(modelPath: modelURL.path)
        XCTAssertFalse(engine.isAvailable)
    }

    func testEngineIsAvailableWithLoadableModelDirectory() throws {
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceInputTests-\(UUID().uuidString)")
        try createLoadableQwen3ModelDirectory(at: modelURL)
        defer { try? FileManager.default.removeItem(at: modelURL) }

        let engine = Qwen3ASREngine(modelPath: modelURL.path)
        XCTAssertTrue(engine.isAvailable)
    }

    func testEngineIsNotAvailableWithMissingModelPath() {
        let engine = Qwen3ASREngine(modelPath: "/tmp/missing-\(UUID().uuidString).mlmodelc")
        XCTAssertFalse(engine.isAvailable)
        XCTAssertThrowsError(try engine.start())
    }

    func testStartClearsBuffer() {
        let engine = makeEngineWithExistingModelPath()
        XCTAssertNoThrow(try engine.start())

        // Buffer should be empty after start
        var receivedText: String?
        var receivedIsFinal = false
        engine.onTranscription = { text, isFinal in
            receivedText = text
            receivedIsFinal = isFinal
        }
        engine.endAudio()
        XCTAssertEqual(receivedText, "")
        XCTAssertTrue(receivedIsFinal)
    }

    func testCancelClearsBuffer() {
        let engine = makeEngineWithExistingModelPath()
        try! engine.start()

        // Append some audio then cancel
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            XCTFail("Failed to create PCM buffer")
            return
        }
        buffer.frameLength = 1024
        engine.appendAudioBuffer(buffer)
        engine.cancel()

        // After cancel, endAudio should produce empty result
        try! engine.start()
        var receivedText: String?
        engine.onTranscription = { text, isFinal in
            receivedText = text
        }
        engine.endAudio()
        XCTAssertEqual(receivedText, "")
    }

    func testOnTranscriptionCallbackIsCalled() {
        let engine = makeEngineWithExistingModelPath()

        var receivedText: String?
        var receivedIsFinal = false
        engine.onTranscription = { text, isFinal in
            receivedText = text
            receivedIsFinal = isFinal
        }

        try! engine.start()
        engine.endAudio()

        XCTAssertNotNil(receivedText)
        XCTAssertTrue(receivedIsFinal)
    }

    func testOnErrorCallbackIsSet() {
        // onError is nil by default on a new engine
        let engine = makeEngineWithExistingModelPath()
        XCTAssertNil(engine.onError)

        engine.onError = { _ in }
        XCTAssertNotNil(engine.onError)
    }

    func testConfigureIsNoOp() {
        let engine = makeEngineWithExistingModelPath()
        // configure should not crash for any locale
        engine.configure(locale: Locale(identifier: "zh_CN"))
        engine.configure(locale: Locale(identifier: "en_US"))
        engine.configure(locale: Locale(identifier: "ja_JP"))
    }

    func testConformsToASREngineProtocol() {
        let engine: ASREngine = makeEngineWithExistingModelPath()
        XCTAssertNil(engine.onTranscription)
        XCTAssertNil(engine.onError)
        XCTAssertTrue(engine.isAvailable)
    }

    private func makeEngineWithExistingModelPath() -> Qwen3ASREngine {
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceInputTests-\(UUID().uuidString)")
        try! createLoadableQwen3ModelDirectory(at: modelURL)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: modelURL)
        }
        return Qwen3ASREngine(modelPath: modelURL.path)
    }

    private func createLoadableQwen3ModelDirectory(at modelURL: URL) throws {
        for relativePath in Qwen3ModelManifest.requiredLoadablePaths {
            let fileURL = modelURL.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            XCTAssertTrue(FileManager.default.createFile(atPath: fileURL.path, contents: Data()))
        }
    }
}
