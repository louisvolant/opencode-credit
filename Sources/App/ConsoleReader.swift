import AppKit
import WebKit

/// Reads the Zen credit and the "Extra Usage" switch — and can toggle that
/// switch — by loading the console Go page in a hidden web view and acting on
/// the rendered DOM.
///
/// The OpenCode console is a client-side app: its server HTML is an empty
/// shell, so the data only exists after the SPA has run, and its internal API
/// is not reachable outside the browser. The hidden web view shares the default
/// website data store (so it is already authenticated) and clicks the real
/// switch, which lets the console perform its own request.
final class ConsoleReader: NSObject, WKNavigationDelegate {
    enum Request {
        case read
        case setExtraUsage(Bool)
    }

    private let request: Request
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<ZenBalance, Error>?
    private var attempts = 0
    private var clicked = false

    private static let maxAttempts = 40            // 40 * 0.5s = 20s
    private static let pollInterval: TimeInterval = 0.5

    init(request: Request = .read) {
        self.request = request
        super.init()
    }

    /// Loads the Go console page and returns once the credit (and, when asked,
    /// the requested switch state) has rendered.
    func run(workspaceID: String) async throws -> ZenBalance {
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

        webView.evaluateJavaScript(Self.extractScript) { [weak self] result, _ in
            guard let self else { return }

            if let extracted = Self.decode(result), let credit = extracted.credit {
                let balance = ZenBalance(
                    balanceUSD: credit,
                    useCredit: extracted.use,
                    fetchedAt: Date()
                )

                switch self.request {
                case .read:
                    Diagnostics.log("console reader: extracted credit=\(credit) use=\(String(describing: extracted.use))")
                    self.finish(.success(balance))
                    return

                case .setExtraUsage(let target):
                    if extracted.use == target {
                        Diagnostics.log("console reader: switch is now \(target)")
                        self.finish(.success(balance))
                        return
                    }
                    if !self.clicked {
                        self.clicked = true
                        Diagnostics.log("console reader: clicking Use credit switch -> \(target)")
                        webView.evaluateJavaScript(Self.clickScript) { _, _ in
                            self.scheduleNextPoll()
                        }
                        return
                    }
                }
            }

            self.scheduleNextPoll()
        }
    }

    private func scheduleNextPoll() {
        attempts += 1
        if attempts >= Self.maxAttempts {
            Diagnostics.log("console reader: timed out")
            finish(.failure(OpenCodeAPIError.balanceUnavailable))
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pollInterval) { self.poll() }
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

    private static func decode(_ result: Any?) -> Extracted? {
        guard let json = result as? String, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Extracted.self, from: data)
    }

    private struct Extracted: Decodable {
        let credit: Double?
        let use: Bool?
    }

    /// Returns `{ "credit": 18.85, "use": false }`, or `null` until the page
    /// has rendered. Reads the visible dollar amount and the "Use credit"
    /// switch state.
    private static let extractScript = #"""
    (function() {
      var text = document.body ? document.body.innerText : "";
      var m = text.match(/\$([0-9][0-9,]*\.[0-9]{2})\s*available credit/);
      var credit = m ? Number(m[1].replace(/,/g, "")) : null;

      var use = null;
      var input = findUseCreditInput();
      if (input) { use = input.getAttribute("aria-checked") === "true"; }

      if (credit === null && use === null) { return null; }
      return JSON.stringify({ credit: credit, use: use });

      function findUseCreditInput() {
        var labels = Array.prototype.slice.call(document.querySelectorAll("label"));
        for (var i = 0; i < labels.length; i++) {
          if ((labels[i].textContent || "").trim() === "Use credit") {
            var el = labels[i].htmlFor ? document.getElementById(labels[i].htmlFor) : null;
            if (!el && labels[i].parentElement) {
              el = labels[i].parentElement.querySelector("input");
            }
            return el;
          }
        }
        return null;
      }
    })();
    """#

    /// Clicks the "Use credit" switch for real, so the console performs its own
    /// (CSRF-protected) request.
    private static let clickScript = #"""
    (function() {
      var labels = Array.prototype.slice.call(document.querySelectorAll("label"));
      for (var i = 0; i < labels.length; i++) {
        if ((labels[i].textContent || "").trim() === "Use credit") {
          var el = labels[i].htmlFor ? document.getElementById(labels[i].htmlFor) : null;
          if (!el && labels[i].parentElement) {
            el = labels[i].parentElement.querySelector("input");
          }
          if (el) { el.click(); return true; }
        }
      }
      return false;
    })();
    """#
}
