import CoreGraphics
import Foundation

/// Modifier used by the space hotkeys (modifier+1…9 and modifier+←/→).
enum HotkeyModifier: String, CaseIterable {
    case command
    case control
    case option
    case controlOption

    var flags: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .controlOption: return [.maskControl, .maskAlternate]
        }
    }

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .control: return "⌃"
        case .option: return "⌥"
        case .controlOption: return "⌃⌥"
        }
    }

    var title: String {
        switch self {
        case .command: return "⌘ Command"
        case .control: return "⌃ Control"
        case .option: return "⌥ Option"
        case .controlOption: return "⌃⌥ Control + Option"
        }
    }
}

/// User preferences, backed by UserDefaults (domain com.pavlohuk.InstantSpaces).
final class Settings {
    static let shared = Settings()

    private enum Key {
        static let enabled = "enabled"
        static let invert = "invertDirection"
        static let hotkeyDigits = "hotkeyDigits"
        static let hotkeyArrows = "hotkeyArrows"
        static let hotkeyModifier = "hotkeyModifier"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.invert: false,
            Key.hotkeyDigits: true,
            Key.hotkeyArrows: true,
            Key.hotkeyModifier: HotkeyModifier.command.rawValue,
        ])
    }

    /// Master switch. When off, swipes pass through untouched (normal animated switching) and
    /// the hotkeys do nothing.
    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// Reverses the direction of the trackpad swipe only.
    var invertDirection: Bool {
        get { defaults.bool(forKey: Key.invert) }
        set { defaults.set(newValue, forKey: Key.invert) }
    }

    /// modifier+1…9 jumps straight to desktop N.
    var hotkeyDigits: Bool {
        get { defaults.bool(forKey: Key.hotkeyDigits) }
        set { defaults.set(newValue, forKey: Key.hotkeyDigits) }
    }

    /// modifier+←/→ switches to the neighbouring space.
    var hotkeyArrows: Bool {
        get { defaults.bool(forKey: Key.hotkeyArrows) }
        set { defaults.set(newValue, forKey: Key.hotkeyArrows) }
    }

    var hotkeyModifier: HotkeyModifier {
        get { HotkeyModifier(rawValue: defaults.string(forKey: Key.hotkeyModifier) ?? "") ?? .command }
        set { defaults.set(newValue.rawValue, forKey: Key.hotkeyModifier) }
    }
}
