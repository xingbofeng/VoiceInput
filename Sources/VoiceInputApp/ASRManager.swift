import Foundation

final class ASRManager: ASREngineFactory {
    enum ModelSize: String, CaseIterable, Equatable {
        case size0_6B = "0.6B"
        case size1_7B = "1.7B"
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let selectedEngineType = "ASRManager.selectedEngineType"
        static let qwen3ModelSize = "ASRManager.qwen3ModelSize"
        static let qwen3ModelPath = "ASRManager.qwen3ModelPath"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Engine Selection

    var selectedEngineType: ASREngineType {
        get {
            guard let raw = defaults.string(forKey: Keys.selectedEngineType),
                  let type = ASREngineType(rawValue: raw) else {
                return .apple
            }
            return type
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.selectedEngineType)
        }
    }

    // MARK: - Qwen3 Configuration

    var qwen3ModelSize: ModelSize {
        get {
            guard let raw = defaults.string(forKey: Keys.qwen3ModelSize),
                  let size = ModelSize(rawValue: raw) else {
                return .size0_6B
            }
            return size
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.qwen3ModelSize)
        }
    }

    var qwen3ModelPath: String? {
        get {
            defaults.string(forKey: Keys.qwen3ModelPath)
        }
        set {
            if let path = newValue {
                defaults.set(path, forKey: Keys.qwen3ModelPath)
            } else {
                defaults.removeObject(forKey: Keys.qwen3ModelPath)
            }
        }
    }

    var isQwen3ModelAvailable: Bool {
        guard let path = qwen3ModelPath, !path.isEmpty else {
            return false
        }
        let modelURL = URL(fileURLWithPath: path, isDirectory: true)
        return Qwen3ModelManifest.manifest(for: qwen3ModelSize).modelsExist(at: modelURL)
    }

    var effectiveSelectedEngineType: ASREngineType {
        if selectedEngineType == .qwen3 && !isQwen3ModelAvailable {
            return .apple
        }
        return selectedEngineType
    }

    func canSelectEngine(_ type: ASREngineType) -> Bool {
        switch type {
        case .apple:
            return true
        case .qwen3:
            return isQwen3ModelAvailable
        }
    }

    @discardableResult
    func selectEngine(_ type: ASREngineType) -> Bool {
        guard canSelectEngine(type) else {
            selectedEngineType = .apple
            return false
        }
        selectedEngineType = type
        return true
    }

    var qwen3DownloadURL: URL {
        Self.downloadURL(for: qwen3ModelSize)
    }

    static func downloadURL(for size: ModelSize) -> URL {
        switch size {
        case .size0_6B:
            return URL(string: "https://huggingface.co/Qwen/Qwen3-ASR-0.6B")!
        case .size1_7B:
            return URL(string: "https://huggingface.co/Qwen/Qwen3-ASR-1.7B")!
        }
    }

    // MARK: - ASREngineFactory

    func makeEngine(type: ASREngineType) -> ASREngine {
        switch type {
        case .apple:
            return SpeechRecognizer()
        case .qwen3:
            return Qwen3ASREngine(modelPath: qwen3ModelPath)
        }
    }
}
