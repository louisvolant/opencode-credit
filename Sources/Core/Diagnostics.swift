import Foundation

/// Lightweight file logger for the fragile console/WebKit flows.
///
/// Writes to `~/Library/Logs/OpenCodeCredit.log`, one line per event. It is
/// deliberately dependency-free and never throws: diagnostics must never break
/// the feature they are meant to observe.
enum Diagnostics {
    static let logURL: URL = {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("OpenCodeCredit.log")
    }()

    static func log(_ message: String) {
        let line = "\(ISO8601.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL)
        }
    }

    /// A short, log-friendly description of a URL (host + path only).
    static func describe(_ url: URL?) -> String {
        guard let url else { return "nil" }
        if let host = url.host {
            return host + url.path
        }
        return url.absoluteString
    }
}
