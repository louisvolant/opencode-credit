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
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationThreshold = "notificationThreshold"
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

    /// Whether to post a local notification when a window crosses the
    /// threshold. Defaults to false.
    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Key.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Key.notificationsEnabled) }
    }

    /// Percentage at which a notification is posted. Defaults to 80.
    var notificationThreshold: Int {
        get {
            let value = defaults.integer(forKey: Key.notificationThreshold)
            return value > 0 ? value : 80
        }
        set {
            defaults.set(newValue, forKey: Key.notificationThreshold)
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
