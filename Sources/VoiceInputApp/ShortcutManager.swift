import Foundation

enum ShortPressBehavior: String, CaseIterable, Codable, Equatable {
    case toggleListening
    case none
}

/// Manages keyboard shortcut preferences stored in UserDefaults.
final class ShortcutManager: @unchecked Sendable {
    static let shared = ShortcutManager()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Keys {
        static let shortcutKeyCode = "ShortcutKeyCode"
        static let longPressThreshold = "LongPressThreshold"
        static let shortPressBehavior = "ShortPressBehavior"
    }

    // MARK: - Shortcut Key Code

    /// The keyboard key code for the hotkey. Default is 54 (Right Command).
    var shortcutKeyCode: Int64 {
        get {
            guard defaults.object(forKey: Keys.shortcutKeyCode) != nil else {
                return 54
            }
            return Int64(defaults.integer(forKey: Keys.shortcutKeyCode))
        }
        set {
            defaults.set(newValue, forKey: Keys.shortcutKeyCode)
        }
    }

    // MARK: - Long Press Threshold

    /// Duration in seconds that distinguishes a long press from a short press. Default is 0.5.
    var longPressThreshold: TimeInterval {
        get {
            guard defaults.object(forKey: Keys.longPressThreshold) != nil else {
                return 0.5
            }
            return defaults.double(forKey: Keys.longPressThreshold)
        }
        set {
            defaults.set(newValue, forKey: Keys.longPressThreshold)
        }
    }

    // MARK: - Short Press Behavior

    /// Action to perform on a short press. Default is `.toggleListening`.
    var shortPressBehavior: ShortPressBehavior {
        get {
            guard let raw = defaults.string(forKey: Keys.shortPressBehavior) else {
                return .toggleListening
            }
            return ShortPressBehavior(rawValue: raw) ?? .toggleListening
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.shortPressBehavior)
        }
    }
}
