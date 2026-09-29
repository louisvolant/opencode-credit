import Foundation

/// Extracts an OpenCode workspace id from a console URL or link.
///
/// Only ids carrying the `wrk_` prefix are accepted: scanning page HTML for a
/// generic id is far too loose (it matched `/console/favicon…` once).
///
/// Examples: `https://opencode.ai/console/wrk_abc123/go` or
/// `https://opencode.ai/workspace/wrk_abc123/billing`.
enum WorkspaceURL {
    private static let patterns = [
        "/console/(wrk_[A-Za-z0-9]+)",
        "/workspace/(wrk_[A-Za-z0-9]+)",
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
            return String(string[captured])
        }
        return nil
    }
}
