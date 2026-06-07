import Combine
import Foundation

protocol Qwen3ModelDownloading: Sendable {
    func download(
        manifest: Qwen3ModelManifest,
        progress: @escaping Qwen3ModelDownloader.ProgressHandler
    ) async throws -> URL
}

extension Qwen3ModelDownloader: Qwen3ModelDownloading {}

@MainActor
final class ASRProviderViewModel: ObservableObject {
    @Published private(set) var providers: [ASRProviderDescriptor] = []
    @Published private(set) var selectedTags: Set<String> = []
    @Published private(set) var downloadProgress: Qwen3ModelDownloadProgress?
    @Published private(set) var isDownloading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastActionMessage: String?

    private let environment: AppEnvironment
    private let asrManager: ASRManager
    private let registry: ASRProviderRegistry
    private let downloader: any Qwen3ModelDownloading
    private let fileManager: FileManager

    init(
        environment: AppEnvironment,
        asrManager: ASRManager = ASRManager(),
        registry: ASRProviderRegistry? = nil,
        downloader: any Qwen3ModelDownloading = Qwen3ModelDownloader(),
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.asrManager = asrManager
        self.registry = registry ?? ASRProviderRegistry(asrManager: asrManager)
        self.downloader = downloader
        self.fileManager = fileManager
        load()
    }

    var visibleProviders: [ASRProviderDescriptor] {
        providers.filter { ASRProviderFilter(tags: selectedTags).matches($0) }
    }

    var availableTags: [String] {
        Array(Set(providers.flatMap(\.tags))).sorted()
    }

    var selectedQwenModelSize: ASRManager.ModelSize {
        asrManager.qwen3ModelSize
    }

    var qwenModelPath: String? {
        asrManager.qwen3ModelPath
    }

    func load() {
        do {
            providers = registry.descriptors()
            try persistProviderRecords()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    func selectDefaultProvider(id: String) {
        do {
            try registry.selectDefaultProvider(id: id)
            load()
            lastError = nil
            lastActionMessage = nil
        } catch {
            let message = error.localizedDescription
            load()
            lastError = message
        }
    }

    func selectQwenModelSize(_ size: ASRManager.ModelSize) {
        asrManager.qwen3ModelSize = size
        load()
        lastError = nil
        lastActionMessage = "已选择 \(size.rawValue) 模型"
    }

    func setQwenModelPath(_ path: String) {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard Qwen3ModelManifest.supportedModelExists(at: url, fileManager: fileManager) else {
            lastError = "所选目录不是可用的 Qwen3-ASR 模型。"
            return
        }
        asrManager.qwen3ModelPath = path
        load()
        lastError = nil
        lastActionMessage = "已设置本地模型目录"
    }

    func downloadQwenModel() async {
        isDownloading = true
        downloadProgress = nil
        lastError = nil
        defer { isDownloading = false }

        do {
            let manifest = Qwen3ModelManifest.manifest(for: asrManager.qwen3ModelSize)
            let url = try await downloader.download(manifest: manifest) { [weak self] progress in
                self?.downloadProgress = progress
            }
            asrManager.qwen3ModelPath = url.path
            load()
            lastError = nil
            lastActionMessage = "本地模型下载完成"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteLocalQwenModel() {
        do {
            if let path = asrManager.qwen3ModelPath, fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(at: URL(fileURLWithPath: path, isDirectory: true))
            }
            asrManager.qwen3ModelPath = nil
            if asrManager.selectedEngineType == .qwen3 {
                asrManager.selectedEngineType = .apple
            }
            load()
            lastError = nil
            lastActionMessage = "已删除本地模型"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearFeedback() {
        lastError = nil
        lastActionMessage = nil
    }

    private func persistProviderRecords() throws {
        let existing = try environment.asrProviderRepository.list()
            .reduce(into: [String: ASRProviderRecord]()) { partial, record in
                partial[record.id] = record
            }
        let now = environment.clock.now
        for descriptor in providers {
            let record = ASRProviderRecord(
                id: descriptor.id,
                displayName: descriptor.displayName,
                providerType: descriptor.providerType,
                capabilitiesJSON: jsonString(descriptor.capabilities.identifiers),
                tagsJSON: jsonString(descriptor.tags),
                configJSON: jsonString([
                    "modelSize": descriptor.modelSize?.rawValue ?? "",
                    "privacy": descriptor.privacySummary,
                ]),
                enabled: true,
                isDefault: descriptor.isDefault,
                lastHealthStatus: descriptor.isAvailable ? "ok" : "unavailable",
                lastHealthMessage: descriptor.statusMessage,
                lastCheckedAt: now,
                createdAt: existing[descriptor.id]?.createdAt ?? now,
                updatedAt: now
            )
            try environment.asrProviderRepository.save(record)
        }
    }

    private func jsonString<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
