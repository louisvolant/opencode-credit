import Foundation

enum FormattingTests {
    static func run() {
        runSuite("Countdown formatting") {
            let now = Date(timeIntervalSince1970: 1_000_000)
            checkEqual(
                Formatting.countdown(until: now.addingTimeInterval(3 * 3600 + 2 * 60), now: now),
                "3h 2m",
                "hours and minutes"
            )
            checkEqual(
                Formatting.countdown(until: now.addingTimeInterval(4 * 86_400 + 4 * 3600), now: now),
                "4d 4h",
                "days and hours"
            )
            checkEqual(
                Formatting.countdown(until: now.addingTimeInterval(26 * 86_400 + 16 * 3600), now: now),
                "26d 16h",
                "many days"
            )
            checkEqual(
                Formatting.countdown(until: now.addingTimeInterval(45 * 60), now: now),
                "45m",
                "minutes only"
            )
            checkEqual(
                Formatting.countdown(until: now.addingTimeInterval(-10), now: now),
                "0m",
                "a past date clamps to 0m"
            )
        }

        runSuite("Percent and currency formatting") {
            checkEqual(Formatting.percent(55.4), "55%", "rounds down")
            checkEqual(Formatting.percent(55.6), "56%", "rounds up")
            checkEqual(Formatting.currency(22), "$22.00", "whole dollars keep two decimals")
            checkEqual(Formatting.currency(4.25), "$4.25", "cents")
        }

        runSuite("Relative time formatting") {
            let now = Date(timeIntervalSince1970: 1_000_000)
            checkEqual(Formatting.relative(now.addingTimeInterval(-2), now: now), "just now", "just now")
            checkEqual(Formatting.relative(now.addingTimeInterval(-300), now: now), "5m ago", "minutes")
            checkEqual(Formatting.relative(now.addingTimeInterval(-7200), now: now), "2h ago", "hours")
        }
    }
}
