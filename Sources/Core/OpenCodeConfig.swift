import Foundation

/// Finds an OpenCode API key in the user's existing OpenCode installation, so
/// that most people do not have to configure anything.
enum OpenCodeConfig {
    /// Environment variables that may hold a key, in priority order.
    static let environmentVariables = [
        "OPENCODE_API_KEY",
        "OPENCODE_GO_API_KEY",
        "ZEN_API_KEY",
    ]

    /// Provider ids that may hold a key in `opencode.json`, in priority order.
    static let providerIds = ["zen", "opencode-go", "opencode"]

    struct ResolvedKey: Equatable {
        enum Source: Equatable {
            case environment(name: String)
            case configFile(path: String)
            case authFile(path: String)
        }

        let key: String
        let source: Source
    }

    static func keyFromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ResolvedKey? {
        for name in environmentVariables {
            if let value = environment[name], !value.isEmpty {
                return ResolvedKey(key: value, source: .environment(name: name))
            }
        }
        return nil
    }

    static func keyFromConfigFile(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ResolvedKey? {
        let url = configHome(homeDirectory: homeDirectory, environment: environment)
            .appendingPathComponent("opencode/opencode.json")
        guard
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let providers = root["provider"] as? [String: Any]
        else {
            return nil
        }

        for id in providerIds {
            guard let entry = providers[id] as? [String: Any] else { continue }
            // The documented location is provider.<id>.options.apiKey; accept a
            // top level apiKey as well for robustness.
            let key = (entry["options"] as? [String: Any])?["apiKey"] as? String
                ?? entry["apiKey"] as? String
            if let key, !key.isEmpty {
                return ResolvedKey(key: key, source: .configFile(path: url.path))
            }
        }
        return nil
    }

    static func keyFromAuthFile(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ResolvedKey? {
        let url = dataHome(homeDirectory: homeDirectory, environment: environment)
            .appendingPathComponent("opencode/auth.json")
        guard
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        // Preferred providers first, then any API-key entry.
        var candidates: [[String: Any]] = []
        for id in providerIds {
            if let entry = root[id] as? [String: Any] { candidates.append(entry) }
        }
        candidates.append(contentsOf: root.values.compactMap { $0 as? [String: Any] })

        for entry in candidates {
            guard (entry["type"] as? String) == "api", let key = entry["key"] as? String, !key.isEmpty else {
                continue
            }
            return ResolvedKey(key: key, source: .authFile(path: url.path))
        }
        return nil
    }

    private static func configHome(homeDirectory: URL, environment: [String: String]) -> URL {
        if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg)
        }
        return homeDirectory.appendingPathComponent(".config")
    }

    private static func dataHome(homeDirectory: URL, environment: [String: String]) -> URL {
        if let xdg = environment["XDG_DATA_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg)
        }
        return homeDirectory.appendingPathComponent(".local/share")
    }
}
