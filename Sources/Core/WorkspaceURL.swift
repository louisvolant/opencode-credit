import Foundation

/// Extracts an OpenCode workspace id from a console URL or link.
///
/// Examples: `https://opencode.ai/console/wrk_abc123/go`,
/// `https://opencode.ai/workspace/wrk_abc123/billing` or `/workspace/abc123def`.
enum WorkspaceURL {
    private static let patterns = [
        "/console/(wrk_[A-Za-z0-9]+)",
        "/workspace/(wrk_[A-Za-z0-9]+)",
        "/console/([A-Za-z0-9_]{6,})",
        "/workspace/([A-Za-z0-9_]{6,})",
    ]

    private static let reserved: Set<String> = [
        "billing", "usage", "members", "settings", "keys", "auth", "workspace", "console",
    ]

    static func id(from string: String?) -> String? {
        guard let string, !string.isEmpty else { return nil }

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(string.startIndex..., in: string)
            guard
                let match = regex.firstMatch(in: string, range: range),
                match.numberOfRanges > 1,
                let captured = Range(match.range(at: 1), in: string)
            else {
                continue
            }
            let value = String(string[captured])
            if !reserved.contains(value) { return value }
        }
        return nil
    }
}
