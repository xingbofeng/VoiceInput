import Cocoa
import CoreGraphics

enum HotKeyTransition: Equatable {
    case pressed
    case released
}

struct RightCommandKeyState {
    static let keyCode: Int64 = 54

    private(set) var isPressed = false

    mutating func transition(keyCode: Int64) -> HotKeyTransition? {
        guard keyCode == Self.keyCode else { return nil }

        isPressed.toggle()
        return isPressed ? .pressed : .released
    }

    mutating func reset() {
        isPressed = false
    }
}

/// Globally monitors and suppresses the right Command key via a CGEvent tap.
final class KeyMonitor {
    // MARK: - State

    private var rightCommandState = RightCommandKeyState()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onHotKeyPress: (() -> Void)?
    var onHotKeyRelease: (() -> Void)?

    // MARK: - Lifecycle

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
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
        guard keyCode == RightCommandKeyState.keyCode else {
            return Unmanaged.passUnretained(event)
        }

        switch rightCommandState.transition(keyCode: keyCode) {
        case .pressed:
            DispatchQueue.main.async { [weak self] in
                self?.onHotKeyPress?()
            }
        case .released:
            DispatchQueue.main.async { [weak self] in
                self?.onHotKeyRelease?()
            }
        case nil:
            break
        }

        return nil
    }
}
