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

        runSuite("Billing parser: Go console page") {
            let html = """
            <span class="text-[1.3125rem] font-[610]">$18.85</span><span class="text-muted">available credit</span>
            <div role="group" data-component="switch">
              <input type="checkbox" role="switch" aria-checked="false" data-slot="switch-input">
              <label data-slot="switch-label">Use credit</label>
            </div>
            """
            let balance = BillingParser.parse(html: html)
            checkEqual(balance?.balanceUSD, 18.85, "reads the available credit")
            checkEqual(balance?.useCredit, false, "reads the rendered Use credit switch")
        }

        runSuite("Billing parser: useBalance SSR flag") {
            let html = #"<html><script>$R[16]($R[22],$R[25]={balance:425000000,monthlyLimit:20,monthlyUsage:12500000,lite:$R[27]={useBalance:!0}});</script></html>"#
            let balance = BillingParser.parse(html: html)
            checkEqual(balance?.useCredit, true, "reads useBalance:!0")
            checkEqual(balance?.balanceUSD, 4.25, "still reads the balance")
        }

        runSuite("Billing parser: missing credit yields no balance") {
            checkEqual(
                BillingParser.parse(html: "<html><body>Nothing here</body></html>"),
                nil,
                "returns nil when there is neither a balance nor an available credit"
            )
        }

        runSuite("Workspace id extraction") {
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/workspace/wrk_abc123/billing"),
                "wrk_abc123",
                "reads the wrk_ prefixed id"
            )
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/console/wrk_01KZS0V8FH6MY0X3CBHXCTZ8C/go"),
                "wrk_01KZS0V8FH6MY0X3CBHXCTZ8C",
                "reads the console wrk_ id"
            )
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/console/favicon.ico"),
                nil,
                "does not mistake a path segment like 'favicon' for a workspace"
            )
            checkEqual(
                WorkspaceURL.id(from: "/console/settings/billing"),
                nil,
                "ignores a reserved console segment"
            )
            checkEqual(
                WorkspaceURL.id(from: "/workspace/abc123def"),
                nil,
                "ignores an id without the wrk_ prefix"
            )
            checkEqual(
                WorkspaceURL.id(from: "https://opencode.ai/auth"),
                nil,
                "returns nil when there is no workspace"
            )
        }
    }
}
