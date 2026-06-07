import XCTest
@testable import VoiceInputApp

final class ASRManagerTests: XCTestCase {
    var manager: ASRManager!
    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.ASRManager")!
        defaults.removePersistentDomain(forName: "test.ASRManager")
        manager = ASRManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "test.ASRManager")
        super.tearDown()
    }

    func testDefaultEngineIsApple() {
        XCTAssertEqual(manager.selectedEngineType, .apple)
    }

    func testSetAndGetSelectedEngine() {
        manager.selectedEngineType = .qwen3
        XCTAssertEqual(manager.selectedEngineType, .qwen3)
    }

    func testEffectiveSelectedEngineFallsBackToAppleWhenQwen3ModelIsMissing() {
        manager.selectedEngineType = .qwen3
        XCTAssertEqual(manager.effectiveSelectedEngineType, .apple)
    }

    func testDefaultModelSizeIs0_6B() {
        XCTAssertEqual(manager.qwen3ModelSize, .size0_6B)
    }

    func testSetAndGetModelSize() {
        manager.qwen3ModelSize = .size1_7B
        XCTAssertEqual(manager.qwen3ModelSize, .size1_7B)
    }

    func testDefaultModelPathIsNil() {
        XCTAssertNil(manager.qwen3ModelPath)
    }

    func testSetAndGetModelPath() {
        let path = "/path/to/model"
        manager.qwen3ModelPath = path
        XCTAssertEqual(manager.qwen3ModelPath, path)
    }

    func testQwen3ModelIsUnavailableWithoutExistingPath() {
        manager.qwen3ModelPath = "/path/to/missing/model.mlmodelc"
        XCTAssertFalse(manager.isQwen3ModelAvailable)
        XCTAssertFalse(manager.canSelectEngine(.qwen3))
        XCTAssertTrue(manager.canSelectEngine(.apple))
    }

    func testQwen3ModelIsAvailableWhenPathExists() throws {
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceInputTests-\(UUID().uuidString)")
        try createLoadableQwen3ModelDirectory(at: modelURL)
        defer { try? FileManager.default.removeItem(at: modelURL) }

        manager.qwen3ModelPath = modelURL.path

        XCTAssertTrue(manager.isQwen3ModelAvailable)
        XCTAssertTrue(manager.canSelectEngine(.qwen3))
        XCTAssertTrue(manager.selectEngine(.qwen3))
        XCTAssertEqual(manager.effectiveSelectedEngineType, .qwen3)
    }

    func testSelectingQwen3WithoutModelFallsBackToApple() {
        XCTAssertFalse(manager.selectEngine(.qwen3))
        XCTAssertEqual(manager.selectedEngineType, .apple)
    }

    func testQwen3DownloadURLsUseOfficialHuggingFaceModels() {
        XCTAssertEqual(
            ASRManager.downloadURL(for: .size0_6B).absoluteString,
            "https://huggingface.co/Qwen/Qwen3-ASR-0.6B"
        )
        XCTAssertEqual(
            ASRManager.downloadURL(for: .size1_7B).absoluteString,
            "https://huggingface.co/Qwen/Qwen3-ASR-1.7B"
        )
    }

    func testQwen3CoreMLManifestUsesDirectDownloadURLs() {
        let manifest = Qwen3ModelManifest.manifest(for: .size0_6B)

        XCTAssertEqual(manifest.repository, "FluidInference/qwen3-asr-0.6b-coreml")
        let embeddingsFile = Qwen3ModelManifest.File(
            remotePath: "int8/qwen3_asr_embeddings.bin",
            localPath: "qwen3_asr_embeddings.bin"
        )
        XCTAssertTrue(manifest.files.contains(embeddingsFile))
        XCTAssertEqual(
            manifest.remoteURL(for: embeddingsFile).absoluteString,
            "https://huggingface.co/FluidInference/qwen3-asr-0.6b-coreml/resolve/main/int8/qwen3_asr_embeddings.bin"
        )
    }

    func testQwen3SupportedModelExistsRejectsOnePointSevenLayoutWithoutVocabulary() throws {
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceInputTests-\(UUID().uuidString)")
        let onePointSevenPathsWithoutVocabulary = [
            "qwen3_asr_audio_encoder_v2.mlpackage/Manifest.json",
            "qwen3_asr_decoder_stateful.mlpackage/Manifest.json",
            "qwen3_asr_embeddings.bin",
        ]
        for relativePath in onePointSevenPathsWithoutVocabulary {
            let fileURL = modelURL.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            XCTAssertTrue(FileManager.default.createFile(atPath: fileURL.path, contents: Data()))
        }
        defer { try? FileManager.default.removeItem(at: modelURL) }

        XCTAssertFalse(Qwen3ModelManifest.supportedModelExists(at: modelURL))

        manager.qwen3ModelSize = .size1_7B
        manager.qwen3ModelPath = modelURL.path
        XCTAssertFalse(manager.isQwen3ModelAvailable)
    }

    func testMakeAppleEngineReturnsSpeechRecognizer() {
        let engine = manager.makeEngine(type: .apple)
        XCTAssertTrue(engine is SpeechRecognizer)
    }

    func testMakeQwen3EngineReturnsQwen3Engine() throws {
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceInputTests-\(UUID().uuidString)")
        try createLoadableQwen3ModelDirectory(at: modelURL)
        defer { try? FileManager.default.removeItem(at: modelURL) }

        manager.qwen3ModelPath = modelURL.path
        let engine = manager.makeEngine(type: .qwen3)
        XCTAssertTrue(engine is Qwen3ASREngine, "Expected Qwen3ASREngine but got \(type(of: engine))")
        XCTAssertTrue(engine.isAvailable)
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
