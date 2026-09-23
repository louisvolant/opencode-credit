import Foundation

enum SettingsTests {
    static func run() {
        runSuite("Settings defaults and persistence") {
            let suiteName = "opencode-credit-tests-\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                check(false, "could not create an isolated defaults suite")
                return
            }
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let settings = Settings(defaults: defaults)

            checkEqual(settings.refreshIntervalMinutes, 5, "default interval is 5 minutes")
            checkEqual(settings.showPercentInMenuBar, true, "the percentage is shown by default")
            checkEqual(settings.cachedUsage, nil, "there is no cached usage initially")

            settings.refreshIntervalMinutes = 15
            settings.showPercentInMenuBar = false
            checkEqual(settings.refreshIntervalMinutes, 15, "the interval persists")
            checkEqual(settings.showPercentInMenuBar, false, "the menu bar option persists")

            let snapshot = UsageSnapshot(
                rolling: UsageWindow(status: .ok, percent: 42, resetsAt: Date(timeIntervalSince1970: 1_700_000_000)),
                weekly: nil,
                monthly: nil,
                fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
            settings.cachedUsage = snapshot
            checkEqual(settings.cachedUsage, snapshot, "the cached usage round-trips")

            settings.cachedUsage = nil
            checkEqual(settings.cachedUsage, nil, "the cache can be cleared")
        }

        runSuite("Settings ignores an invalid interval") {
            let suiteName = "opencode-credit-tests-\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                check(false, "could not create an isolated defaults suite")
                return
            }
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let settings = Settings(defaults: defaults)
            settings.refreshIntervalMinutes = 0
            checkEqual(settings.refreshIntervalMinutes, 5, "a zero interval falls back to the default")
        }
    }
}
