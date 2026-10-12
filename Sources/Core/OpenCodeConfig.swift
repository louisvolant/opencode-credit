import Foundation

/// Finds an OpenCode API key in the user's existing OpenCode installation, so
/// that most people do not have to configure anything.
///
/// Config shapes are supported across OpenCode versions:
///   - v1: `provider.<id>.options.apiKey`
///   - v2 beta: `providers.<id>.apiKey`
///   - OpenCode 2.0 native: `providers.<id>.settings.apiKey` (provider
///     `options` became `settings`)
///
/// An entry can also be matched by its `type` (v2 beta) or `canonical`
/// (native 2.0) field, so a custom provider that inherits the OpenCode Go
/// catalog is recognised even when its id is not one of the known ones.
///
/// Supporting every shape keeps key discovery working when the user migrates
/// their config to a newer OpenCode format. This is intentionally defensive:
/// the cost is a couple of dictionary lookups, and the alternative is silently
/// losing the key (and showing stale usage) after an upgrade.
///
/// Values may use OpenCode's variable substitution: `{env:NAME}` for an
/// environment variable and `{file:path}` for the contents of a file.
enum OpenCodeConfig {
    /// Environment variables that may hold a key, in priority order.
    static let environmentVariables = [
        "OPENCODE_API_KEY",
        "OPENCODE_GO_API_KEY",
        "ZEN_API_KEY",
    ]

    /// Provider ids (and `type` values) that may hold a key, in priority order.
    static let providerIds = ["opencode-go", "zen", "opencode"]

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
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let directory = url.deletingLastPathComponent()
        let containers = [root["provider"], root["providers"]].compactMap { $0 as? [String: Any] }

        // 1. Preferred provider ids.
        for container in containers {
            for id in providerIds {
                guard let entry = container[id] as? [String: Any] else { continue }
                if let key = key(from: entry, configDirectory: directory, environment: environment) {
                    return ResolvedKey(key: key, source: .configFile(path: url.path))
                }
            }
        }

        // 2. Any entry whose `type` (v2 beta) or `canonical` (native 2.0)
        //    names a known provider.
        for container in containers {
            for value in container.values {
                guard
                    let entry = value as? [String: Any],
                    let marker = (entry["type"] as? String) ?? (entry["canonical"] as? String),
                    providerIds.contains(marker)
                else {
                    continue
                }
                if let key = key(from: entry, configDirectory: directory, environment: environment) {
                    return ResolvedKey(key: key, source: .configFile(path: url.path))
                }
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

    // MARK: - Helpers

    /// Reads the API key from a provider entry, whichever config shape it uses
    /// (`options.apiKey`, `settings.apiKey` or a top-level `apiKey`), and
    /// resolves any variable substitution. Returns nil when the value is
    /// missing or empty.
    private static func key(
        from entry: [String: Any],
        configDirectory: URL,
        environment: [String: String]
    ) -> String? {
        let raw = (entry["options"] as? [String: Any])?["apiKey"] as? String
            ?? (entry["settings"] as? [String: Any])?["apiKey"] as? String
            ?? entry["apiKey"] as? String
        guard let raw else { return nil }
        return resolve(raw, configDirectory: configDirectory, environment: environment)
    }

    /// Resolves `{env:NAME}` and `{file:path}` placeholders, mirroring OpenCode.
    static func resolve(
        _ raw: String,
        configDirectory: URL,
        environment: [String: String]
    ) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("{env:"), trimmed.hasSuffix("}") {
            let name = String(trimmed.dropFirst("{env:".count).dropLast())
            let value = (environment[name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        if trimmed.hasPrefix("{file:"), trimmed.hasSuffix("}") {
            let path = String(trimmed.dropFirst("{file:".count).dropLast())
            guard
                let fileURL = resolvePath(path, relativeTo: configDirectory),
                let data = try? Data(contentsOf: fileURL),
                let contents = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            let value = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        return trimmed.isEmpty ? nil : trimmed
    }

    private static func resolvePath(_ path: String, relativeTo directory: URL) -> URL? {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        return directory.appendingPathComponent(expanded)
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
