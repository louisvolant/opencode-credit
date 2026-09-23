import Foundation

/// Decides which usage windows have just crossed a notification threshold.
///
/// Kept pure so it can be unit tested without touching the notification
/// system.
enum ThresholdEvaluator {
    struct Alert: Equatable {
        let name: String
        let percent: Double
        /// Stable identity for the current window (name + reset time).
        let key: String
    }

    static func alerts(
        snapshot: UsageSnapshot,
        threshold: Int,
        alreadyNotified: Set<String>
    ) -> [Alert] {
        let windows: [(String, UsageWindow?)] = [
            ("Rolling", snapshot.rolling),
            ("Weekly", snapshot.weekly),
            ("Monthly", snapshot.monthly),
        ]

        var alerts: [Alert] = []
        for (name, window) in windows {
            guard let window, window.percent >= Double(threshold) else { continue }
            let key = "\(name)-\(window.resetsAt?.timeIntervalSince1970 ?? 0)"
            guard !alreadyNotified.contains(key) else { continue }
            alerts.append(Alert(name: name, percent: window.percent, key: key))
        }
        return alerts
    }
}
