import AppKit

enum AppPresentationPolicy {
    static let activationPolicy: NSApplication.ActivationPolicy = .regular
    static let opensWorkbenchOnLaunch = true
    static let restoresWorkbenchOnReopen = true
}
