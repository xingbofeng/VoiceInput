import Foundation

enum RecordingPermissionPolicy {
    static func hasRequiredPermissions(
        engineType: ASREngineType,
        microphonePermission: AudioRecorder.PermissionStatus,
        speechPermission: AudioRecorder.PermissionStatus
    ) -> Bool {
        guard microphonePermission == .granted else {
            return false
        }

        switch engineType {
        case .apple:
            return speechPermission == .granted
        case .qwen3:
            return true
        }
    }
}
