import Foundation
import UserNotifications

/// Posts a local notification the first time a usage window crosses the
/// configured threshold within its reset period.
final class NotificationManager {
    static let shared = NotificationManager()

    /// Keys of windows already notified, scoped by reset timestamp so a new
    /// window can notify again.
    private var notified: Set<String> = []

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Evaluates a fresh snapshot and posts at most one notification per window
    /// per reset period.
    func evaluate(snapshot: UsageSnapshot, enabled: Bool, threshold: Int) {
        guard enabled else { return }

        let alerts = ThresholdEvaluator.alerts(
            snapshot: snapshot,
            threshold: threshold,
            alreadyNotified: notified
        )

        for alert in alerts {
            notified.insert(alert.key)
            post(name: alert.name, percent: alert.percent)
        }
    }

    private func post(name: String, percent: Double) {
        let content = UNMutableNotificationContent()
        content.title = "OpenCode Go \(name.lowercased()) usage"
        content.body = "You have used \(Formatting.percent(percent)) of your \(name.lowercased()) limit."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
