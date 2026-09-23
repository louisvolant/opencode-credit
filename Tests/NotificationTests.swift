import Foundation

enum NotificationTests {
    static func run() {
        runSuite("ThresholdEvaluator alerts on the windows above the threshold") {
            let now = Date(timeIntervalSince1970: 1_700_000_000)
            let snapshot = UsageSnapshot(
                rolling: UsageWindow(status: .ok, percent: 85, resetsAt: now.addingTimeInterval(3600)),
                weekly: UsageWindow(status: .ok, percent: 40, resetsAt: now.addingTimeInterval(86_400)),
                monthly: nil,
                fetchedAt: now
            )

            let alerts = ThresholdEvaluator.alerts(snapshot: snapshot, threshold: 80, alreadyNotified: [])
            checkEqual(alerts.count, 1, "only the window above the threshold alerts")
            checkEqual(alerts.first?.name, "Rolling", "the alert names the window")
            checkEqual(alerts.first?.percent, 85, "the alert carries the percent")

            guard let key = alerts.first?.key else {
                check(false, "expected an alert key")
                return
            }
            let second = ThresholdEvaluator.alerts(
                snapshot: snapshot,
                threshold: 80,
                alreadyNotified: [key]
            )
            checkEqual(second.count, 0, "an already notified window does not alert again")
        }

        runSuite("ThresholdEvaluator respects the threshold") {
            let now = Date(timeIntervalSince1970: 1_700_000_000)
            let snapshot = UsageSnapshot(
                rolling: UsageWindow(status: .ok, percent: 79, resetsAt: now),
                weekly: nil,
                monthly: nil,
                fetchedAt: now
            )
            checkEqual(
                ThresholdEvaluator.alerts(snapshot: snapshot, threshold: 80, alreadyNotified: []).count,
                0,
                "below the threshold does not alert"
            )
            checkEqual(
                ThresholdEvaluator.alerts(snapshot: snapshot, threshold: 70, alreadyNotified: []).count,
                1,
                "above a lower threshold alerts"
            )
        }
    }
}
