import Foundation

enum PermissionSummary {
    static func statusText(_ granted: Bool) -> String {
        granted ? "已授权" : "未授权"
    }

    static func speechRecognitionStatus(
        engineType: ASREngineType,
        speechPermission: AudioRecorder.PermissionStatus
    ) -> String {
        switch engineType {
        case .apple:
            return statusText(speechPermission == .granted)
        case .qwen3:
            return "不需要（当前使用 Qwen3-ASR）"
        }
    }

    static func recordingPermissionAlertText(engineType: ASREngineType) -> (title: String, body: String) {
        switch engineType {
        case .apple:
            return (
                "需要录音与语音识别权限",
                """
                VoiceInput 需要麦克风和语音识别权限才能使用系统自带模型。

                请在 系统设置 → 隐私与安全性 中启用“麦克风”和“语音识别”权限。
                """
            )
        case .qwen3:
            return (
                "需要麦克风权限",
                """
                VoiceInput 使用 Qwen3-ASR 时只需要麦克风权限，不需要 Apple 语音识别权限。

                请在 系统设置 → 隐私与安全性 → 麦克风 中启用 VoiceInput。
                """
            )
        }
    }
}
