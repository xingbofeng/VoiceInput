import XCTest
@testable import VoiceInputApp

final class PermissionSummaryTests: XCTestCase {
    func testQwen3DoesNotRequireAppleSpeechRecognitionPermission() {
        XCTAssertEqual(
            PermissionSummary.speechRecognitionStatus(
                engineType: .qwen3,
                speechPermission: .denied
            ),
            "不需要（当前使用 Qwen3-ASR）"
        )
    }

    func testAppleSpeechShowsSpeechRecognitionPermissionState() {
        XCTAssertEqual(
            PermissionSummary.speechRecognitionStatus(
                engineType: .apple,
                speechPermission: .denied
            ),
            "未授权"
        )
        XCTAssertEqual(
            PermissionSummary.speechRecognitionStatus(
                engineType: .apple,
                speechPermission: .granted
            ),
            "已授权"
        )
    }

    func testQwen3PermissionAlertOnlyMentionsMicrophoneRequirement() {
        let message = PermissionSummary.recordingPermissionAlertText(engineType: .qwen3)

        XCTAssertEqual(message.title, "需要麦克风权限")
        XCTAssertTrue(message.body.contains("只需要麦克风权限"))
        XCTAssertTrue(message.body.contains("不需要 Apple 语音识别权限"))
    }
}
