import Foundation

struct Qwen3ModelManifest: Equatable {
    struct File: Equatable {
        let remotePath: String
        let localPath: String
    }

    let repository: String
    let localDirectoryName: String
    let files: [File]
    let requiredLocalPaths: [String]

    var fileCount: Int { files.count }

    static func manifest(for size: ASRManager.ModelSize) -> Qwen3ModelManifest {
        switch size {
        case .size0_6B:
            return Qwen3ModelManifest(
                repository: "FluidInference/qwen3-asr-0.6b-coreml",
                localDirectoryName: "qwen3-asr-0.6b-coreml-int8",
                files: [
                    File(remotePath: "int8/metadata.json", localPath: "metadata.json"),
                    File(remotePath: "int8/vocab.json", localPath: "vocab.json"),
                    File(remotePath: "int8/qwen3_asr_embeddings.bin", localPath: "qwen3_asr_embeddings.bin"),
                    File(remotePath: "int8/qwen3_asr_audio_encoder_v2.mlmodelc/analytics/coremldata.bin", localPath: "qwen3_asr_audio_encoder_v2.mlmodelc/analytics/coremldata.bin"),
                    File(remotePath: "int8/qwen3_asr_audio_encoder_v2.mlmodelc/coremldata.bin", localPath: "qwen3_asr_audio_encoder_v2.mlmodelc/coremldata.bin"),
                    File(remotePath: "int8/qwen3_asr_audio_encoder_v2.mlmodelc/metadata.json", localPath: "qwen3_asr_audio_encoder_v2.mlmodelc/metadata.json"),
                    File(remotePath: "int8/qwen3_asr_audio_encoder_v2.mlmodelc/model.mil", localPath: "qwen3_asr_audio_encoder_v2.mlmodelc/model.mil"),
                    File(remotePath: "int8/qwen3_asr_audio_encoder_v2.mlmodelc/weights/weight.bin", localPath: "qwen3_asr_audio_encoder_v2.mlmodelc/weights/weight.bin"),
                    File(remotePath: "int8/qwen3_asr_decoder_stateful.mlmodelc/analytics/coremldata.bin", localPath: "qwen3_asr_decoder_stateful.mlmodelc/analytics/coremldata.bin"),
                    File(remotePath: "int8/qwen3_asr_decoder_stateful.mlmodelc/coremldata.bin", localPath: "qwen3_asr_decoder_stateful.mlmodelc/coremldata.bin"),
                    File(remotePath: "int8/qwen3_asr_decoder_stateful.mlmodelc/metadata.json", localPath: "qwen3_asr_decoder_stateful.mlmodelc/metadata.json"),
                    File(remotePath: "int8/qwen3_asr_decoder_stateful.mlmodelc/model.mil", localPath: "qwen3_asr_decoder_stateful.mlmodelc/model.mil"),
                    File(remotePath: "int8/qwen3_asr_decoder_stateful.mlmodelc/weights/weight.bin", localPath: "qwen3_asr_decoder_stateful.mlmodelc/weights/weight.bin"),
                ],
                requiredLocalPaths: Self.requiredLoadablePaths
            )
        case .size1_7B:
            return Qwen3ModelManifest(
                repository: "aoiandroid/Qwen3-ASR-1.7B-CoreML",
                localDirectoryName: "qwen3-asr-1.7b-coreml",
                files: [
                    File(remotePath: "qwen3_asr_embeddings.bin", localPath: "qwen3_asr_embeddings.bin"),
                    File(remotePath: "qwen3_asr_encoder_int8.mlpackage/Manifest.json", localPath: "qwen3_asr_audio_encoder_v2.mlpackage/Manifest.json"),
                    File(remotePath: "qwen3_asr_encoder_int8.mlpackage/Data/com.apple.CoreML/model.mlmodel", localPath: "qwen3_asr_audio_encoder_v2.mlpackage/Data/com.apple.CoreML/model.mlmodel"),
                    File(remotePath: "qwen3_asr_encoder_int8.mlpackage/Data/com.apple.CoreML/weights/weight.bin", localPath: "qwen3_asr_audio_encoder_v2.mlpackage/Data/com.apple.CoreML/weights/weight.bin"),
                    File(remotePath: "qwen3_asr_decoder_f32_anemll_int8-mixed.mlpackage/Manifest.json", localPath: "qwen3_asr_decoder_stateful.mlpackage/Manifest.json"),
                    File(remotePath: "qwen3_asr_decoder_f32_anemll_int8-mixed.mlpackage/Data/com.apple.CoreML/model.mlmodel", localPath: "qwen3_asr_decoder_stateful.mlpackage/Data/com.apple.CoreML/model.mlmodel"),
                    File(remotePath: "qwen3_asr_decoder_f32_anemll_int8-mixed.mlpackage/Data/com.apple.CoreML/weights/weight.bin", localPath: "qwen3_asr_decoder_stateful.mlpackage/Data/com.apple.CoreML/weights/weight.bin"),
                ],
                requiredLocalPaths: [
                    "qwen3_asr_audio_encoder_v2.mlpackage/Manifest.json",
                    "qwen3_asr_decoder_stateful.mlpackage/Manifest.json",
                    "qwen3_asr_embeddings.bin",
                ]
            )
        }
    }

    static let requiredLoadablePaths = [
        "qwen3_asr_audio_encoder_v2.mlmodelc/coremldata.bin",
        "qwen3_asr_decoder_stateful.mlmodelc/coremldata.bin",
        "qwen3_asr_embeddings.bin",
        "vocab.json",
    ]

    static let supportedLoadablePathSets = [
        requiredLoadablePaths,
        [
            "qwen3_asr_audio_encoder_v2.mlpackage/Manifest.json",
            "qwen3_asr_decoder_stateful.mlpackage/Manifest.json",
            "qwen3_asr_embeddings.bin",
        ],
    ]

    func remoteURL(for file: File) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/\(repository)/resolve/main/\(file.remotePath)"
        return components.url!
    }

    func modelsExist(at directory: URL, fileManager: FileManager = .default) -> Bool {
        requiredLocalPaths.allSatisfy { path in
            fileManager.fileExists(atPath: directory.appendingPathComponent(path).path)
        }
    }

    static func supportedModelExists(at directory: URL, fileManager: FileManager = .default) -> Bool {
        supportedLoadablePathSets.contains { paths in
            paths.allSatisfy { path in
                fileManager.fileExists(atPath: directory.appendingPathComponent(path).path)
            }
        }
    }
}

struct Qwen3ModelDownloadProgress: Equatable {
    let fileIndex: Int
    let fileCount: Int
    let fileName: String
    let fileProgress: Double

    var overallProgress: Double {
        guard fileCount > 0 else { return 0 }
        return (Double(fileIndex) + fileProgress) / Double(fileCount)
    }
}

final class Qwen3ModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    typealias ProgressHandler = @MainActor (Qwen3ModelDownloadProgress) -> Void

    private let fileManager: FileManager
    private var session: URLSession!
    private var activeContinuation: CheckedContinuation<Void, Error>?
    private var activeDestinationURL: URL?
    private var activeProgress: Qwen3ModelDownloadProgress?
    private var activeProgressHandler: ProgressHandler?
    private var activeMoveResult: Result<Void, Error>?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        super.init()
        self.session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: nil
        )
    }

    func download(
        manifest: Qwen3ModelManifest,
        progress: @escaping ProgressHandler
    ) async throws -> URL {
        let rootURL = try modelRootURL()
            .appendingPathComponent(manifest.localDirectoryName, isDirectory: true)
        let partialURL = rootURL.appendingPathExtension("partial")

        if fileManager.fileExists(atPath: partialURL.path) {
            try fileManager.removeItem(at: partialURL)
        }
        try fileManager.createDirectory(
            at: partialURL,
            withIntermediateDirectories: true
        )

        for (index, file) in manifest.files.enumerated() {
            let destinationURL = partialURL.appendingPathComponent(file.localPath)
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try await downloadFile(
                from: manifest.remoteURL(for: file),
                to: destinationURL,
                progress: Qwen3ModelDownloadProgress(
                    fileIndex: index,
                    fileCount: manifest.fileCount,
                    fileName: file.localPath,
                    fileProgress: 0
                ),
                progressHandler: progress
            )
        }

        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.removeItem(at: rootURL)
        }
        try fileManager.moveItem(at: partialURL, to: rootURL)
        return rootURL
    }

    private func modelRootURL() throws -> URL {
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw Qwen3ModelDownloadError.applicationSupportUnavailable
        }

        let rootURL = applicationSupportURL
            .appendingPathComponent("VoiceInput", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        try fileManager.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        return rootURL
    }

    private func downloadFile(
        from sourceURL: URL,
        to destinationURL: URL,
        progress: Qwen3ModelDownloadProgress,
        progressHandler: @escaping ProgressHandler
    ) async throws {
        activeDestinationURL = destinationURL
        activeProgress = progress
        activeProgressHandler = progressHandler
        activeMoveResult = nil
        await progressHandler(progress)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                activeContinuation = continuation
                session.downloadTask(with: sourceURL).resume()
            }
        } onCancel: {
            session.invalidateAndCancel()
        }

        activeContinuation = nil
        activeDestinationURL = nil
        activeProgress = nil
        activeProgressHandler = nil
        activeMoveResult = nil
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let activeProgress, totalBytesExpectedToWrite > 0 else { return }
        let progress = Qwen3ModelDownloadProgress(
            fileIndex: activeProgress.fileIndex,
            fileCount: activeProgress.fileCount,
            fileName: activeProgress.fileName,
            fileProgress: min(
                1,
                Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            )
        )
        Task { @MainActor [activeProgressHandler] in
            activeProgressHandler?(progress)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let destinationURL = activeDestinationURL else {
            activeMoveResult = .failure(Qwen3ModelDownloadError.downloadedFileUnavailable)
            return
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            activeMoveResult = .success(())
        } catch {
            activeMoveResult = .failure(error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            activeContinuation?.resume(throwing: error)
            return
        }

        guard let activeMoveResult else {
            activeContinuation?.resume(
                throwing: Qwen3ModelDownloadError.downloadedFileUnavailable
            )
            return
        }

        switch activeMoveResult {
        case .success:
            activeContinuation?.resume()
        case .failure(let error):
            activeContinuation?.resume(throwing: error)
        }
    }
}

enum Qwen3ModelDownloadError: LocalizedError {
    case applicationSupportUnavailable
    case downloadedFileUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "无法定位 Application Support 目录。"
        case .downloadedFileUnavailable:
            return "模型文件下载完成但临时文件不可用。"
        }
    }
}
