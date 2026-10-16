import Foundation

/// User preferences, backed by UserDefaults (domain com.pavlohuk.InstantSpaces).
final class Settings {
    static let shared = Settings()

    private enum Key {
        static let enabled = "enabled"
        static let invert = "invertDirection"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.invert: false,
        ])
    }

    /// When off, the system swipe passes through untouched (normal animated switching).
    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var invertDirection: Bool {
        get { defaults.bool(forKey: Key.invert) }
        set { defaults.set(newValue, forKey: Key.invert) }
    }
}
