@preconcurrency import Cocoa
import CoreGraphics

fileprivate let _kAXPrompt: String = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

enum HotKeyTransition: Equatable {
    case pressed
    case released
    case shortPress
}

struct RightCommandKeyState {
    private(set) var isPressed = false
    private var pressTimestamp: Date?

    mutating func transition(threshold: TimeInterval) -> HotKeyTransition {
        let now = Date()
        isPressed.toggle()

        if isPressed {
            pressTimestamp = now
            return .pressed
        } else {
            let duration = pressTimestamp.map { now.timeIntervalSince($0) } ?? 0
            pressTimestamp = nil
            return duration < threshold ? .shortPress : .released
        }
    }

    mutating func reset() {
        isPressed = false
        pressTimestamp = nil
    }
}

enum ShortcutEventRouting {
    /// Only pass the shortcut through when VoiceInput has a visible key
    /// window that needs keyboard input (e.g., the Settings window).
    /// When no window is key — even if the app is technically active —
    /// the shortcut must be intercepted so recording can start.
    static func shouldPassThrough(appIsActive: Bool) -> Bool {
        guard appIsActive else { return false }
        // NSApp is nil in unit-test contexts; treat that as "no key window".
        if Thread.isMainThread {
            return MainActor.assumeIsolated { NSApp?.keyWindow != nil }
        }
        return false
    }
}

/// Globally monitors and suppresses the right Command key via a CGEvent tap.
final class KeyMonitor: @unchecked Sendable {
    // MARK: - State

    private var rightCommandState: RightCommandKeyState!
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onHotKeyPress: (() -> Void)?
    var onHotKeyRelease: (() -> Void)?
    var onShortPress: (() -> Void)?

    // MARK: - Lifecycle

    @MainActor
    func start() -> Bool {
        guard eventTap == nil else { return true }

        rightCommandState = RightCommandKeyState()

        let options = [_kAXPrompt: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            return false
        }

        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        rightCommandState.reset()
    }

    // MARK: - Event Handling

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }
        return handleFlagsChanged(event: event)
    }

    private func handleFlagsChanged(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let shortcutManager = ShortcutManager.shared

        guard keyCode == shortcutManager.shortcutKeyCode else {
            return Unmanaged.passUnretained(event)
        }

        let passThrough = MainActor.assumeIsolated {
            ShortcutEventRouting.shouldPassThrough(appIsActive: NSApp.isActive)
        }
        if passThrough {
            rightCommandState.reset()
            return Unmanaged.passUnretained(event)
        }

        switch rightCommandState.transition(threshold: shortcutManager.longPressThreshold) {
        case .pressed:
            let handler = onHotKeyPress
            DispatchQueue.main.async {
                handler?()
            }
        case .released:
            let handler = onHotKeyRelease
            DispatchQueue.main.async {
                handler?()
            }
        case .shortPress:
            let handler = onShortPress
            DispatchQueue.main.async {
                handler?()
            }
        }

        // Suppress the shortcut key event to prevent system-side effects.
        return nil
    }
}
