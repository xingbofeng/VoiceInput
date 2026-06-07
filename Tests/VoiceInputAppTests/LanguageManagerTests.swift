import XCTest
@testable import VoiceInputApp

final class LanguageManagerTests: XCTestCase {
    func testDefaultLanguageIsSimplifiedChinese() {
        XCTAssertEqual(RecognitionLanguage.default, .simplifiedChinese)
        XCTAssertEqual(RecognitionLanguage.default.rawValue, "zh-CN")
    }

    func testRequiredLanguagesAreAvailable() {
        XCTAssertEqual(
            Set(RecognitionLanguage.allCases.map(\.rawValue)),
            Set(["en-US", "zh-CN", "zh-TW", "ja-JP", "ko-KR"])
        )
    }
}
