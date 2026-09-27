import Foundation

enum ConfigTests {
    static func run() {
        runSuite("Environment key resolution") {
            checkEqual(
                OpenCodeConfig.keyFromEnvironment(["OPENCODE_API_KEY": "sk-env"])?.key,
                "sk-env",
                "reads OPENCODE_API_KEY"
            )
            checkEqual(
                OpenCodeConfig.keyFromEnvironment(["ZEN_API_KEY": "sk-zen"])?.key,
                "sk-zen",
                "reads the ZEN_API_KEY alias"
            )
            checkEqual(
                OpenCodeConfig.keyFromEnvironment(["OPENCODE_API_KEY": ""]),
                nil,
                "ignores empty values"
            )
            checkEqual(
                OpenCodeConfig.keyFromEnvironment([:]),
                nil,
                "returns nil when nothing is set"
            )
        }

        runSuite("opencode.json key resolution") {
            let home = makeTempHome()
            defer { cleanup(home) }

            let configURL = home.appendingPathComponent(".config/opencode/opencode.json")
            write(#"{"provider":{"zen":{"options":{"apiKey":"sk-config"}}}}"#, to: configURL)

            let resolved = OpenCodeConfig.keyFromConfigFile(homeDirectory: home, environment: [:])
            checkEqual(resolved?.key, "sk-config", "reads provider.zen.options.apiKey")
            checkEqual(
                resolved?.source,
                .configFile(path: configURL.path),
                "reports the config file path"
            )
        }

        runSuite("opencode.json respects XDG_CONFIG_HOME") {
            let home = makeTempHome()
            defer { cleanup(home) }

            let xdg = home.appendingPathComponent("xdg-config")
            let configURL = xdg.appendingPathComponent("opencode/opencode.json")
            write(#"{"provider":{"opencode-go":{"options":{"apiKey":"sk-go"}}}}"#, to: configURL)

            let resolved = OpenCodeConfig.keyFromConfigFile(
                homeDirectory: home,
                environment: ["XDG_CONFIG_HOME": xdg.path]
            )
            checkEqual(resolved?.key, "sk-go", "reads the opencode-go provider entry")
        }

        runSuite("auth.json key resolution") {
            let home = makeTempHome()
            defer { cleanup(home) }

            let authURL = home.appendingPathComponent(".local/share/opencode/auth.json")
            write(#"{"opencode":{"type":"api","key":"sk-auth"}}"#, to: authURL)

            let resolved = OpenCodeConfig.keyFromAuthFile(homeDirectory: home, environment: [:])
            checkEqual(resolved?.key, "sk-auth", "reads an api key entry")
            checkEqual(
                resolved?.source,
                .authFile(path: authURL.path),
                "reports the credentials file path"
            )
        }

        runSuite("v2 opencode.json key resolution") {
            let home = makeTempHome()
            defer { cleanup(home) }

            let configURL = home.appendingPathComponent(".config/opencode/opencode.json")
            write(
                #"{"providers":{"opencode-go":{"type":"opencode-go","apiKey":"oc_sk_v2"}}}"#,
                to: configURL
            )

            let resolved = OpenCodeConfig.keyFromConfigFile(homeDirectory: home, environment: [:])
            checkEqual(resolved?.key, "oc_sk_v2", "reads providers.opencode-go.apiKey")
            checkEqual(resolved?.source, .configFile(path: configURL.path), "reports the config file path")
        }

        runSuite("v2 config matched by provider type") {
            let home = makeTempHome()
            defer { cleanup(home) }

            write(
                #"{"providers":{"custom":{"type":"opencode-go","apiKey":"oc_sk_type"}}}"#,
                to: home.appendingPathComponent(".config/opencode/opencode.json")
            )

            let resolved = OpenCodeConfig.keyFromConfigFile(homeDirectory: home, environment: [:])
            checkEqual(resolved?.key, "oc_sk_type", "matches an entry by its type field")
        }

        runSuite("config value substitution") {
            let home = makeTempHome()
            defer { cleanup(home) }

            let configURL = home.appendingPathComponent(".config/opencode/opencode.json")
            write(
                #"{"providers":{"opencode-go":{"apiKey":"{env:OPENCODE_GO}"}}}"#,
                to: configURL
            )

            let resolved = OpenCodeConfig.keyFromConfigFile(
                homeDirectory: home,
                environment: ["OPENCODE_GO": "oc_sk_env"]
            )
            checkEqual(resolved?.key, "oc_sk_env", "resolves {env:NAME}")

            let unresolved = OpenCodeConfig.keyFromConfigFile(homeDirectory: home, environment: [:])
            checkEqual(unresolved, nil, "an unset {env:NAME} yields no key")

            // {file:path} is resolved relative to the config directory.
            write("oc_sk_file\n", to: home.appendingPathComponent(".config/opencode/.opencode-key"))
            write(
                #"{"providers":{"opencode-go":{"apiKey":"{file:.opencode-key}"}}}"#,
                to: configURL
            )
            let fromFile = OpenCodeConfig.keyFromConfigFile(homeDirectory: home, environment: [:])
            checkEqual(fromFile?.key, "oc_sk_file", "resolves {file:path} and trims whitespace")
        }

        runSuite("CredentialStore priority") {
            let home = makeTempHome()
            defer { cleanup(home) }

            write(
                #"{"provider":{"zen":{"options":{"apiKey":"sk-config"}}}}"#,
                to: home.appendingPathComponent(".config/opencode/opencode.json")
            )

            // The environment wins over the config file when no app key is set.
            let resolved = CredentialStore.shared.resolve(
                homeDirectory: home,
                environment: ["OPENCODE_API_KEY": "sk-env"]
            )
            checkEqual(resolved?.key, "sk-env", "environment beats config file")
            checkEqual(
                resolved?.source,
                .environment(name: "OPENCODE_API_KEY"),
                "reports the environment source"
            )

            // With no environment, the config file is used.
            let fallback = CredentialStore.shared.resolve(homeDirectory: home, environment: [:])
            checkEqual(fallback?.key, "sk-config", "falls back to the config file")
        }
    }

    // MARK: - Helpers

    private static func makeTempHome() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("opencode-credit-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func write(_ contents: String, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
