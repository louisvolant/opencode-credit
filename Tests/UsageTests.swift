import Foundation

enum UsageTests {
    static func run() {
        runSuite("UsageSnapshot decoding") {
            let payload = """
            {"usage":{"rolling":{"status":"ok","percent":55,"resetsAt":"2026-09-23T22:48:39.852Z"},\
            "weekly":{"status":"ok","percent":28,"resetsAt":"2026-09-28T00:00:00.000Z"},\
            "monthly":{"status":"ok","percent":15,"resetsAt":"2026-10-20T12:09:44.000Z"}}}
            """.data(using: .utf8)!

            let snapshot = try! UsageSnapshot.decode(from: payload, fetchedAt: Date(timeIntervalSince1970: 0))
            checkEqual(snapshot.rolling?.percent, 55, "rolling percent")
            checkEqual(snapshot.weekly?.percent, 28, "weekly percent")
            checkEqual(snapshot.monthly?.percent, 15, "monthly percent")
            checkEqual(snapshot.rolling?.status, .ok, "rolling status")
            check(snapshot.rolling?.resetsAt != nil, "rolling resetsAt is parsed")
            checkEqual(snapshot.maxPercent, 55, "max percent")
            check(snapshot.isReachable, "snapshot is reachable")
        }

        runSuite("UsageSnapshot tolerates unknown shapes") {
            let payload = """
            {"usage":{"rolling":{"status":"weird","percent":12}}}
            """.data(using: .utf8)!

            let snapshot = try! UsageSnapshot.decode(from: payload)
            checkEqual(snapshot.rolling?.status, .unknown, "unknown status falls back to .unknown")
            checkEqual(snapshot.rolling?.resetsAt, nil, "missing resetsAt is nil")
            checkEqual(snapshot.weekly, nil, "missing window is nil")
        }

        runSuite("UsageSnapshot round-trips through the cache format") {
            let payload = """
            {"usage":{"rolling":{"status":"limited","percent":99,"resetsAt":"2026-09-23T22:48:39.852Z"}}}
            """.data(using: .utf8)!

            let original = try! UsageSnapshot.decode(
                from: payload,
                fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
            let encoded = try! JSONEncoder().encode(original)
            let decoded = try! JSONDecoder().decode(UsageSnapshot.self, from: encoded)
            checkEqual(decoded, original, "snapshot survives encode/decode")
        }
    }
}
