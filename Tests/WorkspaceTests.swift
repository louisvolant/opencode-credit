import Foundation

enum WorkspaceTests {
    static func run() {
        runSuite("Workspace id extraction") {
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/workspace/wrk_abc123/billing"),
                "wrk_abc123",
                "reads the wrk_ prefixed id"
            )
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/console/wrk_01KZS0V8FH6MY0X3CBHXCTZ8C/go"),
                "wrk_01KZS0V8FH6MY0X3CBHXCTZ8C",
                "reads the console wrk_ id"
            )
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/console/favicon.ico"),
                nil,
                "does not mistake a path segment like 'favicon' for a workspace"
            )
            checkEqual(
                WorkspaceURL.id(from: "/console/settings/billing"),
                nil,
                "ignores a reserved console segment"
            )
            checkEqual(
                WorkspaceURL.id(from: "/workspace/abc123def"),
                nil,
                "ignores an id without the wrk_ prefix"
            )
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/auth"),
                nil,
                "returns nil when there is no workspace"
            )
        }
    }
}
