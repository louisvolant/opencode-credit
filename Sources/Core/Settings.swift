import Foundation

/// User defaults backed preferences.
final class Settings {
    static let shared = Settings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let showPercentInMenuBar = "showPercentInMenuBar"
        static let cachedUsage = "cachedUsage"
    }

    /// How often the app refreshes, in minutes. Defaults to 5.
    var refreshIntervalMinutes: Int {
        get {
            let value = defaults.integer(forKey: Key.refreshIntervalMinutes)
            return value > 0 ? value : 5
        }
        set {
            defaults.set(newValue, forKey: Key.refreshIntervalMinutes)
        }
    }

    /// Whether the rolling percentage is shown next to the logo. Defaults to true.
    var showPercentInMenuBar: Bool {
        get {
            if defaults.object(forKey: Key.showPercentInMenuBar) == nil { return true }
            return defaults.bool(forKey: Key.showPercentInMenuBar)
        }
        set {
            defaults.set(newValue, forKey: Key.showPercentInMenuBar)
        }
    }

    /// Last successful snapshot, cached so the app can render offline.
    var cachedUsage: UsageSnapshot? {
        get {
            guard let data = defaults.data(forKey: Key.cachedUsage) else { return nil }
            return try? JSONDecoder().decode(UsageSnapshot.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.cachedUsage)
            } else {
                defaults.removeObject(forKey: Key.cachedUsage)
            }
        }
    }
}
