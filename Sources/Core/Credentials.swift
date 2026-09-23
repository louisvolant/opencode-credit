import Foundation

/// Central place that decides which API key the app should use.
///
/// Resolution order:
///   1. a key explicitly saved in the app (macOS Keychain),
///   2. the supported environment variables,
///   3. the user's OpenCode configuration files.
final class CredentialStore {
    static let shared = CredentialStore()

    private let apiKeyAccount = "api-key"

    struct ResolvedKey: Equatable {
        enum Source: Equatable {
            case app
            case environment(name: String)
            case configFile(path: String)
            case authFile(path: String)
        }

        let key: String
        let source: Source

        var sourceDescription: String {
            switch source {
            case .app:
                return "Saved in the app"
            case .environment(let name):
                return "Environment variable \(name)"
            case .configFile(let path):
                return "OpenCode config (\(path))"
            case .authFile(let path):
                return "OpenCode credentials (\(path))"
            }
        }
    }

    /// Key explicitly configured in the app, if any.
    var appKey: String? {
        Keychain.get(apiKeyAccount)
    }

    func setAppKey(_ key: String?) {
        guard let key, !key.isEmpty else {
            Keychain.delete(apiKeyAccount)
            return
        }
        Keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: apiKeyAccount)
    }

    /// Returns the key to use, or `nil` when nothing is configured.
    func resolve(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ResolvedKey? {
        if let key = appKey, !key.isEmpty {
            return ResolvedKey(key: key, source: .app)
        }
        if let resolved = OpenCodeConfig.keyFromEnvironment(environment) {
            return ResolvedKey(key: resolved.key, source: map(resolved.source))
        }
        if let resolved = OpenCodeConfig.keyFromConfigFile(homeDirectory: homeDirectory, environment: environment) {
            return ResolvedKey(key: resolved.key, source: map(resolved.source))
        }
        if let resolved = OpenCodeConfig.keyFromAuthFile(homeDirectory: homeDirectory, environment: environment) {
            return ResolvedKey(key: resolved.key, source: map(resolved.source))
        }
        return nil
    }

    private func map(_ source: OpenCodeConfig.ResolvedKey.Source) -> ResolvedKey.Source {
        switch source {
        case .environment(let name):
            return .environment(name: name)
        case .configFile(let path):
            return .configFile(path: path)
        case .authFile(let path):
            return .authFile(path: path)
        }
    }
}
