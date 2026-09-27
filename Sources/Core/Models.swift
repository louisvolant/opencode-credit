import Foundation

/// Helpers around ISO-8601 timestamps, which is the format used by the
/// OpenCode API (`2026-09-23T22:48:39.852Z`).
enum ISO8601 {
    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return withFractionalSeconds.date(from: string) ?? plain.date(from: string)
    }

    static func string(from date: Date) -> String {
        withFractionalSeconds.string(from: date)
    }
}

/// A single quota window returned by the Go usage endpoint.
struct UsageWindow: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case ok
        case limited
        case blocked
        case unknown
    }

    let status: Status
    let percent: Double
    let resetsAt: Date?

    init(status: Status, percent: Double, resetsAt: Date?) {
        self.status = status
        self.percent = percent
        self.resetsAt = resetsAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawStatus = try container.decodeIfPresent(String.self, forKey: .status)
        // Be tolerant: an unknown status must not break decoding.
        status = Status(rawValue: (rawStatus ?? "").lowercased()) ?? .unknown
        percent = try container.decodeIfPresent(Double.self, forKey: .percent) ?? 0
        resetsAt = ISO8601.date(from: try container.decodeIfPresent(String.self, forKey: .resetsAt))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(percent, forKey: .percent)
        try container.encodeIfPresent(resetsAt.map(ISO8601.string(from:)), forKey: .resetsAt)
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case percent
        case resetsAt
    }
}

/// The OpenCode Zen available credit, read from the workspace billing or Go
/// console page.
struct ZenBalance: Codable, Equatable, Sendable {
    let balanceUSD: Double
    let monthlyLimitUSD: Double?
    let monthlyUsageUSD: Double?
    /// Whether "Extra Usage" (use the balance after reaching the Go limits) is
    /// enabled. `nil` when the page did not expose it.
    let useCredit: Bool?
    let fetchedAt: Date

    init(
        balanceUSD: Double,
        monthlyLimitUSD: Double? = nil,
        monthlyUsageUSD: Double? = nil,
        useCredit: Bool? = nil,
        fetchedAt: Date
    ) {
        self.balanceUSD = balanceUSD
        self.monthlyLimitUSD = monthlyLimitUSD
        self.monthlyUsageUSD = monthlyUsageUSD
        self.useCredit = useCredit
        self.fetchedAt = fetchedAt
    }
}

/// The three Go usage windows plus the moment they were fetched.
struct UsageSnapshot: Codable, Equatable, Sendable {
    let rolling: UsageWindow?
    let weekly: UsageWindow?
    let monthly: UsageWindow?
    let fetchedAt: Date

    static let empty = UsageSnapshot(rolling: nil, weekly: nil, monthly: nil, fetchedAt: .distantPast)

    var isReachable: Bool {
        rolling != nil || weekly != nil || monthly != nil
    }

    /// Highest usage across all windows, used for the menu bar tint.
    var maxPercent: Double {
        [rolling, weekly, monthly].compactMap { $0?.percent }.max() ?? 0
    }

    /// Decodes a `/zen/go/v1/usage` payload.
    static func decode(from data: Data, fetchedAt: Date = Date()) throws -> UsageSnapshot {
        let response = try JSONDecoder().decode(UsageResponse.self, from: data)
        return UsageSnapshot(
            rolling: response.usage.rolling,
            weekly: response.usage.weekly,
            monthly: response.usage.monthly,
            fetchedAt: fetchedAt
        )
    }

    private struct UsageResponse: Decodable {
        struct Windows: Decodable {
            let rolling: UsageWindow?
            let weekly: UsageWindow?
            let monthly: UsageWindow?
        }

        let usage: Windows
    }
}
