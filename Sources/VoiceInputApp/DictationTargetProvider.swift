import AppKit
import Foundation

struct DictationTarget: Equatable {
    let bundleID: String?
    let appName: String?
}

@MainActor
protocol DictationTargetProviding {
    func currentTarget() -> DictationTarget?
}

struct WorkspaceDictationTargetProvider: DictationTargetProviding {
    func currentTarget() -> DictationTarget? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return DictationTarget(
            bundleID: application.bundleIdentifier,
            appName: application.localizedName
        )
    }
}

struct StaticDictationTargetProvider: DictationTargetProviding {
    let target: DictationTarget?

    func currentTarget() -> DictationTarget? {
        target
    }
}
