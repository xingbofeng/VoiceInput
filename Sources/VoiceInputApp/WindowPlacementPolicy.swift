import AppKit

enum WindowPlacementPolicy {
    static func centeredFrame(
        windowSize: NSSize,
        visibleFrame: NSRect
    ) -> NSRect {
        NSRect(
            x: visibleFrame.midX - windowSize.width / 2,
            y: visibleFrame.midY - windowSize.height / 2,
            width: min(windowSize.width, visibleFrame.width),
            height: min(windowSize.height, visibleFrame.height)
        )
    }

    static func isVisible(_ frame: NSRect, on screens: [NSScreen]) -> Bool {
        screens.contains { screen in
            frame.intersects(screen.visibleFrame)
        }
    }

    @MainActor
    static func placeOnVisibleScreenIfNeeded(_ window: NSWindow) {
        let screens = NSScreen.screens
        guard !isVisible(window.frame, on: screens) else { return }
        let visibleFrame = NSScreen.main?.visibleFrame ?? screens.first?.visibleFrame
        guard let visibleFrame else { return }
        window.setFrame(
            centeredFrame(windowSize: window.frame.size, visibleFrame: visibleFrame),
            display: true,
            animate: false
        )
    }
}
