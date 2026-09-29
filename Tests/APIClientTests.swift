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

    }

    private static func ok(_ url: URL?, status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: url ?? URL(string: "https://opencode.ai")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
