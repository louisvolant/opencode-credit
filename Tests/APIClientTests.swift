import Foundation

enum APIClientTests {
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func run() async {
        await runAsyncSuite("OpenCodeAPI.fetchUsage") {
            let api = OpenCodeAPI(session: makeSession())
            MockURLProtocol.handler = { request in
                checkEqual(
                    request.value(forHTTPHeaderField: "Authorization"),
                    "Bearer sk-test",
                    "sends the bearer token"
                )
                checkEqual(request.url?.path, "/zen/go/v1/usage", "calls the usage endpoint")
                let body = #"{"usage":{"rolling":{"status":"ok","percent":55,"resetsAt":"2026-09-23T22:48:39.852Z"},"weekly":{"status":"ok","percent":28,"resetsAt":"2026-09-28T00:00:00.000Z"},"monthly":{"status":"ok","percent":15,"resetsAt":"2026-10-20T12:09:44.000Z"}}}"#
                return (ok(request.url), Data(body.utf8))
            }

            do {
                let snapshot = try await api.fetchUsage(apiKey: "sk-test")
                checkEqual(snapshot.rolling?.percent, 55, "decodes rolling percent")
                checkEqual(snapshot.monthly?.percent, 15, "decodes monthly percent")
            } catch {
                check(false, "unexpected error: \(error)")
            }
        }

        await runAsyncSuite("OpenCodeAPI.fetchUsage maps HTTP errors") {
            let api = OpenCodeAPI(session: makeSession())
            let cases: [(Int, OpenCodeAPIError)] = [
                (401, .unauthorized),
                (403, .unauthorized),
                (404, .noGoSubscription),
                (429, .rateLimited),
                (500, .http(status: 500)),
            ]

            for (status, expected) in cases {
                MockURLProtocol.handler = { request in (ok(request.url, status: status), Data()) }
                do {
                    _ = try await api.fetchUsage(apiKey: "sk-test")
                    check(false, "expected an error for HTTP \(status)")
                } catch let error as OpenCodeAPIError {
                    checkEqual(error, expected, "HTTP \(status) maps to the right error")
                } catch {
                    check(false, "unexpected error type for HTTP \(status): \(error)")
                }
            }
        }

        await runAsyncSuite("OpenCodeAPI.fetchUsage rejects an empty key") {
            let api = OpenCodeAPI(session: makeSession())
            MockURLProtocol.handler = { request in (ok(request.url), Data()) }
            do {
                _ = try await api.fetchUsage(apiKey: "")
                check(false, "expected missingKey")
            } catch let error as OpenCodeAPIError {
                checkEqual(error, .missingKey, "empty key is rejected before any request")
            } catch {
                check(false, "unexpected error: \(error)")
            }
        }

        await runAsyncSuite("OpenCodeAPI.fetchBalance reads the Go console page") {
            let api = OpenCodeAPI(session: makeSession())
            MockURLProtocol.handler = { request in
                checkEqual(request.value(forHTTPHeaderField: "Cookie"), "auth=abc", "sends the session cookie")
                checkEqual(request.url?.path, "/console/wrk_test/go", "calls the Go console page")
                let html = """
                <span class="text-[1.3125rem]">$18.85</span><span class="text-muted">available credit</span>
                <input type="checkbox" role="switch" aria-checked="false" data-slot="switch-input">
                <label data-slot="switch-label">Use credit</label>
                """
                return (ok(request.url), Data(html.utf8))
            }

            do {
                let balance = try await api.fetchBalance(cookie: "auth=abc", workspaceID: "wrk_test")
                checkEqual(balance.balanceUSD, 18.85, "reads $18.85 of credit")
                checkEqual(balance.useCredit, false, "reads the Use credit switch")
            } catch {
                check(false, "unexpected error: \(error)")
            }
        }

        await runAsyncSuite("OpenCodeAPI.fetchBalance falls back to the billing page") {
            let api = OpenCodeAPI(session: makeSession())
            MockURLProtocol.handler = { request in
                let path = request.url?.path ?? ""
                if path == "/console/wrk_test/go" {
                    return (ok(request.url, status: 404), Data())
                }
                checkEqual(path, "/console/wrk_test/settings/billing", "falls back to the billing settings page")
                let html = #"<html><script>_$HY.r["billing.get[\"wrk_test\"]"]=$R[21]=$R[2]($R[22]={p:0,s:0,f:0});$R[16]($R[22],$R[25]={balance:2200000000,monthlyLimit:20,monthlyUsage:12500000});</script></html>"#
                return (ok(request.url), Data(html.utf8))
            }

            do {
                let balance = try await api.fetchBalance(cookie: "auth=abc", workspaceID: "wrk_test")
                checkEqual(balance.balanceUSD, 22.0, "reads $22.00 of credit")
                checkEqual(balance.monthlyUsageUSD, 0.125, "reads monthly usage")
            } catch {
                check(false, "unexpected error: \(error)")
            }
        }

        await runAsyncSuite("OpenCodeAPI.fetchBalance detects an expired session") {
            let api = OpenCodeAPI(session: makeSession())
            MockURLProtocol.handler = { _ in
                // The console redirects to the auth host, served with HTTP 200.
                let auth = URL(string: "https://auth.opencode.ai/authorize")!
                return (ok(auth, status: 200), Data(#"<html><body>Continue with GitHub</body></html>"#.utf8))
            }
            do {
                _ = try await api.fetchBalance(cookie: "auth=abc", workspaceID: "wrk_test")
                check(false, "expected sessionExpired")
            } catch let error as OpenCodeAPIError {
                checkEqual(error, .sessionExpired, "detects a redirect to the auth host")
            } catch {
                check(false, "unexpected error: \(error)")
            }
        }

        await runAsyncSuite("OpenCodeAPI.fetchBalance maps 401 to an expired session") {
            let api = OpenCodeAPI(session: makeSession())
            MockURLProtocol.handler = { request in (ok(request.url, status: 401), Data()) }
            do {
                _ = try await api.fetchBalance(cookie: "auth=abc", workspaceID: "wrk_test")
                check(false, "expected sessionExpired")
            } catch let error as OpenCodeAPIError {
                checkEqual(error, .sessionExpired, "a 401 means the session expired")
            } catch {
                check(false, "unexpected error: \(error)")
            }
        }
    }

    private static func ok(_ url: URL?, status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: url ?? URL(string: "https://opencode.ai")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
