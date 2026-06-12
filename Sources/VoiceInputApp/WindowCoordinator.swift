import AppKit

@MainActor
final class WindowCoordinator {
    private let environment: AppEnvironment
    private var mainWindowController: MainWindowController?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController(environment: environment)
        }
        guard let window = mainWindowController?.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        WindowPlacementPolicy.placeOnVisibleScreenIfNeeded(window)
        window.makeKeyAndOrderFront(nil)
    }

    func showSettings(tab: SettingsTab = .asr) {
        showMainWindow()
    }
}
