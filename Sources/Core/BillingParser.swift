import Foundation

/// Parses the OpenCode Zen billing page (server-rendered HTML) to extract the
/// available credit.
///
/// The page has changed shape several times, so three strategies are tried in
/// order. They all produce the same normalised values:
///   - `balanceUnits` and `monthlyUsageUnits` use "billing units", where
///     1 USD = 100_000_000 units;
///   - `monthlyLimitUSD` is already a dollar amount.
enum BillingParser {
    static let unitsPerDollar: Double = 100_000_000

    struct BillingData: Equatable {
        let balanceUnits: Double
        let monthlyLimitUSD: Double?
        let monthlyUsageUnits: Double?

        var balanceUSD: Double { balanceUnits / unitsPerDollar }
        var monthlyUsageUSD: Double? { monthlyUsageUnits.map { $0 / unitsPerDollar } }
    }

    static func parse(html: String, fetchedAt: Date = Date()) -> ZenBalance? {
        guard let data = parseBillingData(html: html) else { return nil }
        return ZenBalance(
            balanceUSD: data.balanceUSD,
            monthlyLimitUSD: data.monthlyLimitUSD,
            monthlyUsageUSD: data.monthlyUsageUSD,
            fetchedAt: fetchedAt
        )
    }

    static func parseBillingData(html: String) -> BillingData? {
        parseScopedSSR(html: html)
            ?? parseGenericSSR(html: html)
            ?? parseDataSlot(html: html)
    }

    // MARK: - Strategies

    /// Looks for the `billing.get` payload and reads the fields from it. This
    /// is the current console shape and the most precise strategy.
    private static func parseScopedSSR(html: String) -> BillingData? {
        guard let marker = html.range(of: "billing.get") else { return nil }
        let scope = String(html[marker.upperBound...].prefix(4_000))
        return parseFields(in: scope)
    }

    /// Older consoles simply inlined `balance:` / `monthlyLimit:` /
    /// `monthlyUsage:` somewhere in the page.
    private static func parseGenericSSR(html: String) -> BillingData? {
        parseFields(in: html)
    }

    private static let fieldRegex = try! NSRegularExpression(
        pattern: "\\b(balance|monthlyLimit|monthlyUsage)\\s*:\\s*(-?\\d+(?:\\.\\d+)?)"
    )

    private static func parseFields(in text: String) -> BillingData? {
        let range = NSRange(text.startIndex..., in: text)
        var values: [String: Double] = [:]

        for match in fieldRegex.matches(in: text, range: range) {
            guard
                match.numberOfRanges == 3,
                let keyRange = Range(match.range(at: 1), in: text),
                let valueRange = Range(match.range(at: 2), in: text),
                let value = Double(text[valueRange])
            else {
                continue
            }
            values[String(text[keyRange])] = value
        }

        guard let balance = values["balance"] else { return nil }
        return BillingData(
            balanceUnits: max(0, balance),
            monthlyLimitUSD: values["monthlyLimit"],
            monthlyUsageUnits: values["monthlyUsage"]
        )
    }

    /// Last resort: read the rendered `data-slot="billing-item"` blocks, which
    /// already contain formatted dollar amounts.
    private static func parseDataSlot(html: String) -> BillingData? {
        let chunks = html.components(separatedBy: "data-slot=\"billing-item\"").dropFirst()
        var balanceDollars: Double?
        var limitDollars: Double?
        var usageDollars: Double?

        for chunk in chunks {
            guard
                let label = firstMatch(in: chunk, pattern: "data-slot=\"billing-label\">([^<]+)<")?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased(),
                let rawValue = firstMatch(
                    in: chunk,
                    pattern: "data-slot=\"billing-value\">[^0-9$]*\\$?([\\d,]+(?:\\.\\d+)?)"
                ),
                let value = Double(rawValue.replacingOccurrences(of: ",", with: ""))
            else {
                continue
            }

            if label.contains("balance") {
                balanceDollars = value
            } else if label.contains("monthly") && label.contains("limit") {
                limitDollars = value
            } else if label.contains("monthly") && label.contains("usage") {
                usageDollars = value
            }
        }

        guard let balanceDollars else { return nil }
        return BillingData(
            balanceUnits: balanceDollars * unitsPerDollar,
            monthlyLimitUSD: limitDollars,
            monthlyUsageUnits: usageDollars.map { $0 * unitsPerDollar }
        )
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges > 1,
            let captured = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captured])
    }
}
