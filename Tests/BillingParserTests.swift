import Foundation

enum BillingParserTests {
    static func run() {
        runSuite("Billing parser: legacy console payload") {
            let html = #"<html><script>$R[42]={billing:{monthlyUsage:12500000,balance:425000000,monthlyLimit:20}}</script></html>"#
            let data = BillingParser.parseBillingData(html: html)
            checkEqual(data?.balanceUSD, 4.25, "balance converted from billing units")
            checkEqual(data?.monthlyLimitUSD, 20.0, "monthly limit stays in dollars")
            checkEqual(data?.monthlyUsageUSD, 0.125, "monthly usage converted from billing units")
        }

        runSuite("Billing parser: missing and negative balances") {
            checkEqual(
                BillingParser.parseBillingData(html: #"$R[1]={billing:{balance:0}}"#)?.balanceUSD,
                0.0,
                "a zero balance is accepted"
            )
            checkEqual(
                BillingParser.parseBillingData(html: #"$R[1]={billing:{monthlyLimit:20}}"#),
                nil,
                "a missing balance returns nil"
            )
            checkEqual(
                BillingParser.parseBillingData(html: #"$R[1]={billing:{balance:-1}}"#)?.balanceUSD,
                0.0,
                "a negative balance is clamped to zero"
            )
        }

        runSuite("Billing parser: current console payload") {
            let html = #"<html><script>_$HY.r["billing.get[\"wrk_X\"]"]=$R[21]=$R[2]($R[22]={p:0,s:0,f:0});$R[16]($R[22],$R[25]={customerID:"cus_1",balance:425000000,monthlyLimit:20,monthlyUsage:12500000,timeMonthlyUsageUpdated:$R[26]=new Date("2026-08-11T07:05:05.000Z"),lite:$R[27]={useBalance:!0}});</script></html>"#
            let data = BillingParser.parseBillingData(html: html)
            checkEqual(data?.balanceUSD, 4.25, "balance in dollars")
            checkEqual(data?.monthlyUsageUSD, 0.125, "monthly usage in dollars")
        }

        runSuite("Billing parser: data-slot fallback") {
            let html = """
            <div data-slot="billing-item">
              <span data-slot="billing-label">Balance</span>
              <span data-slot="billing-value">$42.50</span>
            </div>
            <div data-slot="billing-item">
              <span data-slot="billing-label">Monthly Limit</span>
              <span data-slot="billing-value">$100.00</span>
            </div>
            <div data-slot="billing-item">
              <span data-slot="billing-label">Monthly Usage</span>
              <span data-slot="billing-value">$12.50</span>
            </div>
            """
            let data = BillingParser.parseBillingData(html: html)
            checkEqual(data?.balanceUSD, 42.5, "balance")
            checkEqual(data?.monthlyLimitUSD, 100.0, "monthly limit")
            checkEqual(data?.monthlyUsageUSD, 12.5, "monthly usage")
        }

        runSuite("Workspace id extraction") {
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/workspace/wrk_abc123/billing"),
                "wrk_abc123",
                "reads the wrk_ prefixed id"
            )
            checkEqual(
                WorkspaceURL.id(from: "/workspace/abc123def"),
                "abc123def",
                "reads a plain id"
            )
            checkEqual(
                WorkspaceURL.id(from: "/workspace/billing"),
                nil,
                "ignores a reserved segment"
            )
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/auth"),
                nil,
                "returns nil when there is no workspace"
            )
        }
    }
}
