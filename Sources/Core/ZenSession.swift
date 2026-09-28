import Foundation

/// Stores the OpenCode Zen browser session (cookie + workspace id) needed to
/// read the credit balance, which is not available through the API key.
final class ZenSession {
    static let shared = ZenSession()

    private let cookieAccount = "zen-cookie"
    private let workspaceAccount = "zen-workspace"

    struct Credentials: Equatable {
        let cookie: String
        let workspaceID: String
    }

    var credentials: Credentials? {
        guard
            let cookie = Keychain.get(cookieAccount), !cookie.isEmpty,
            let workspaceID = Keychain.get(workspaceAccount), !workspaceID.isEmpty
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
        Keychain.set(cookie, for: cookieAccount)
        Keychain.set(workspaceID, for: workspaceAccount)
    }

    func clear() {
        Keychain.delete(cookieAccount)
        Keychain.delete(workspaceAccount)
    }
}
