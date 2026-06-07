import Foundation

/// Supported speech recognition languages.
enum RecognitionLanguage: String, CaseIterable {
    case english = "en-US"
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"
    case japanese = "ja-JP"
    case korean = "ko-KR"

    var displayName: String {
        switch self {
        case .english:             return "English"
        case .simplifiedChinese:   return "简体中文"
        case .traditionalChinese:  return "繁體中文"
        case .japanese:            return "日本語"
        case .korean:              return "한국어"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static var `default`: RecognitionLanguage { .simplifiedChinese }
}

/// Manages language preferences stored in UserDefaults.
@MainActor
final class LanguageManager: NSObject {
    static let shared = LanguageManager()

    private let defaultsKey = "VoiceInput_SelectedLanguage"

    private(set) var currentLanguage: RecognitionLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: defaultsKey)
        }
    }

    override private init() {
        if let saved = UserDefaults.standard.string(forKey: defaultsKey),
           let lang = RecognitionLanguage(rawValue: saved) {
            currentLanguage = lang
        } else {
            currentLanguage = .default
        }
        super.init()
    }

    func setLanguage(_ language: RecognitionLanguage) {
        currentLanguage = language
    }

    var allLanguages: [RecognitionLanguage] { RecognitionLanguage.allCases }
}
