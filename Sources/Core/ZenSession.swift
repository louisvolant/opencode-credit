import Foundation

/// Stores the OpenCode Zen browser session (cookie + workspace id) needed to
/// read the credit balance, which is not available through the API key.
///
/// The Keychain is the primary store. Some managed Macs (MDM) restrict it, so
/// the session falls back to `UserDefaults` when a Keychain write fails.
final class ZenSession {
    static let shared = ZenSession()

    private let cookieAccount = "zen-cookie"
    private let workspaceAccount = "zen-workspace"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    struct Credentials: Equatable {
        let cookie: String
        let workspaceID: String
    }

    /// Keys used only when the Keychain is unavailable.
    private enum FallbackKey {
        static let cookie = "zenCookieFallback"
        static let workspace = "zenWorkspaceFallback"
    }

    var credentials: Credentials? {
        guard
            let cookie = read(account: cookieAccount, fallbackKey: FallbackKey.cookie), !cookie.isEmpty,
            let workspaceID = read(account: workspaceAccount, fallbackKey: FallbackKey.workspace),
            !workspaceID.isEmpty
        else {
            return nil
        }
        return Credentials(cookie: cookie, workspaceID: workspaceID)
    }

    var isConnected: Bool {
        credentials != nil
    }

    func save(cookie: String, workspaceID: String) {
        Diagnostics.log("zen session save: workspace=\(workspaceID) cookieLength=\(cookie.count)")
        write(cookie, account: cookieAccount, fallbackKey: FallbackKey.cookie)
        write(workspaceID, account: workspaceAccount, fallbackKey: FallbackKey.workspace)
    }

    func clear() {
        Keychain.delete(cookieAccount)
        Keychain.delete(workspaceAccount)
        defaults.removeObject(forKey: FallbackKey.cookie)
        defaults.removeObject(forKey: FallbackKey.workspace)
    }

    // MARK: - Helpers

    private func write(_ value: String, account: String, fallbackKey: String) {
        let status = Keychain.set(value, for: account)
        if status == errSecSuccess {
            // The Keychain works: never keep a stale plaintext fallback around.
            defaults.removeObject(forKey: fallbackKey)
        } else {
            Diagnostics.log("zen session: keychain failed (\(status)), using UserDefaults fallback")
            defaults.set(value, forKey: fallbackKey)
        }
    }

    private func read(account: String, fallbackKey: String) -> String? {
        if let value = Keychain.get(account), !value.isEmpty {
            return value
        }
        return defaults.string(forKey: fallbackKey)
    }
}
