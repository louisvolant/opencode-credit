import AppKit
import WebKit

/// Reads the Zen credit and the "Extra Usage" switch by loading the console Go
/// page in a hidden web view and reading the rendered DOM.
///
/// The OpenCode console is a client-side app: its server HTML is an empty
/// shell, so the data only exists after the SPA has run. The hidden web view
/// shares the default website data store, which already holds the session
/// captured by the login window.
final class ConsoleReader: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<ZenBalance, Error>?
    private var attempts = 0

    private static let maxAttempts = 40            // 40 * 0.5s = 20s
    private static let pollInterval: TimeInterval = 0.5

    /// Loads the Go console page and returns once the credit has rendered.
    func read(workspaceID: String) async throws -> ZenBalance {
        try await withCheckedThrowingContinuation { continuation in
            // WebKit must be driven from the main thread.
            DispatchQueue.main.async {
                self.continuation = continuation
                self.start(workspaceID: workspaceID)
            }
        }
    }

    private func start(workspaceID: String) {
        guard let url = URL(string: "https://opencode.ai/console/\(workspaceID)/go") else {
            finish(.failure(OpenCodeAPIError.balanceUnavailable))
            return
        }

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1280, height: 900),
            configuration: WKWebViewConfiguration()
        )
        webView.navigationDelegate = self
        self.webView = webView

        Diagnostics.log("console reader: loading \(Diagnostics.describe(url))")
        webView.load(URLRequest(url: url))
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if Self.isSignIn(webView.url) {
            Diagnostics.log("console reader: redirected to sign-in")
            finish(.failure(OpenCodeAPIError.sessionExpired))
            return
        }
        poll()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(OpenCodeAPIError.network(error.localizedDescription)))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(OpenCodeAPIError.network(error.localizedDescription)))
    }

    // MARK: - Polling

    private func poll() {
        guard let webView else { return }

        webView.evaluateJavaScript(Self.script) { [weak self] result, _ in
            guard let self else { return }

            if let json = result as? String,
               let data = json.data(using: .utf8),
               let extracted = try? JSONDecoder().decode(Extracted.self, from: data),
               let credit = extracted.credit {
                Diagnostics.log("console reader: extracted \(json)")
                self.finish(
                    .success(
                        ZenBalance(
                            balanceUSD: credit,
                            useCredit: extracted.use,
                            fetchedAt: Date()
                        )
                    )
                )
                return
            }

            self.attempts += 1
            if self.attempts >= Self.maxAttempts {
                Diagnostics.log("console reader: timed out waiting for the credit")
                self.finish(.failure(OpenCodeAPIError.balanceUnavailable))
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.pollInterval) { self.poll() }
        }
    }

    private func finish(_ result: Result<ZenBalance, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        continuation.resume(with: result)
    }

    private static func isSignIn(_ url: URL?) -> Bool {
        guard let url else { return false }
        if url.host == "auth.opencode.ai" { return true }
        let path = url.path.lowercased()
        return path.hasPrefix("/auth") || path.hasPrefix("/signin") || path.hasPrefix("/login")
    }

    private struct Extracted: Decodable {
        let credit: Double?
        let use: Bool?
    }

    /// Returns `{ "credit": 18.85, "use": false }`, or `null` until the page
    /// has rendered. Reads the visible dollar amount and the "Use credit"
    /// switch state.
    private static let script = #"""
    (function() {
      var text = document.body ? document.body.innerText : "";
      var m = text.match(/\$([0-9][0-9,]*\.[0-9]{2})\s*available credit/);
      var credit = m ? Number(m[1].replace(/,/g, "")) : null;

      var use = null;
      var labels = Array.prototype.slice.call(document.querySelectorAll("label"));
      for (var i = 0; i < labels.length; i++) {
        if ((labels[i].textContent || "").trim() === "Use credit") {
          var input = labels[i].htmlFor ? document.getElementById(labels[i].htmlFor) : null;
          if (!input && labels[i].parentElement) {
            input = labels[i].parentElement.querySelector("input");
          }
          if (input) { use = input.getAttribute("aria-checked") === "true"; }
          break;
        }
      }

      if (credit === null && use === null) { return null; }
      return JSON.stringify({ credit: credit, use: use });
    })();
    """#
}
