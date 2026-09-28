import AppKit
import WebKit

/// Embedded browser used to sign in to OpenCode and capture the workspace
/// session needed for the credit balance.
///
/// Google blocks OAuth inside embedded web views, so the user is expected to
/// continue with GitHub.
final class LoginWindowController: NSWindowController, WKNavigationDelegate, WKUIDelegate {
    /// Called on the main thread once a session has been captured.
    var onSuccess: (() -> Void)?

    private let session = ZenSession.shared
    private let instructionsLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private var webView: WKWebView!
    private var didFinish = false

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 680),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to OpenCode"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        build()
    }

    func show() {
        didFinish = false
        setStatus("Waiting for sign-in…")
        Diagnostics.log("login window shown")
        load()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func build() {
        guard let window else { return }

        let content = NSView()
        window.contentView = content

        instructionsLabel.stringValue =
            "Sign in with GitHub or Google, then open your workspace console (Go or Billing page). "
            + "This window closes automatically once your workspace is detected."
        instructionsLabel.font = .systemFont(ofSize: 11)
        instructionsLabel.textColor = .secondaryLabelColor
        instructionsLabel.maximumNumberOfLines = 2
        instructionsLabel.lineBreakMode = .byWordWrapping
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = NSButton(title: "Done", target: self, action: #selector(doneTapped))
        doneButton.bezelStyle = .rounded
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        let infoStack = NSStackView(views: [instructionsLabel, statusLabel])
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 2
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        let topBar = NSStackView(views: [infoStack, doneButton])
        topBar.orientation = .horizontal
        topBar.alignment = .centerY
        topBar.spacing = 12
        topBar.translatesAutoresizingMaskIntoConstraints = false

        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        // Google refuses OAuth inside embedded web views ("disallowed_useragent")
        // unless the user agent looks like a full desktop browser. WKWebView's
        // default UA omits the `Safari/...` token, so we impersonate Safari.
        webView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
            + "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(topBar)
        content.addSubview(webView)

        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            topBar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            topBar.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 12),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    private func load() {
        guard let url = URL(string: "https://opencode.ai/auth") else { return }
        webView.load(URLRequest(url: url))
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Diagnostics.log("didFinish \(Diagnostics.describe(webView.url))")
        guard !didFinish else { return }
        detectWorkspace { [weak self] workspaceID in
            guard let self else { return }
            if let workspaceID {
                self.finish(with: workspaceID)
            } else {
                self.setStatus("No workspace id on this page — open your console (Go or Billing) page.")
            }
        }
    }

    /// Some pages (Google OAuth in particular) call `window.close()`. Log it so
    /// we can tell whether that is why the window disappears.
    func webViewDidClose(_ webView: WKWebView) {
        Diagnostics.log("webViewDidClose url=\(Diagnostics.describe(webView.url))")
    }

    @objc private func doneTapped() {
        detectWorkspace { [weak self] workspaceID in
            guard let self else { return }
            if let workspaceID {
                self.finish(with: workspaceID)
            } else {
                self.showDetectionFailure()
            }
        }
    }

    // MARK: - Workspace detection

    /// Tries the current URL first, then scans the rendered HTML: the console is
    /// a single-page app, so the workspace id often only exists in its links.
    private func detectWorkspace(completion: @escaping (String?) -> Void) {
        if let id = WorkspaceURL.id(from: webView.url?.absoluteString) {
            Diagnostics.log("workspace from URL: \(id)")
            completion(id)
            return
        }

        let script = """
        (function() {
          var href = location.href || '';
          var html = document.documentElement ? document.documentElement.outerHTML : '';
          return href + "\\n" + html;
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            let id = WorkspaceURL.id(from: result as? String)
            Diagnostics.log("workspace from HTML: \(id ?? "nil")")
            completion(id)
        }
    }

    private func finish(with workspaceID: String) {
        guard !didFinish else { return }
        didFinish = true
        Diagnostics.log("finish workspace=\(workspaceID)")

        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let relevant = cookies.filter { $0.domain.contains("opencode.ai") }
            Diagnostics.log("cookies total=\(cookies.count) opencode=\(relevant.count)")

            guard !relevant.isEmpty else {
                DispatchQueue.main.async {
                    self.didFinish = false
                    self.setStatus("Workspace \(workspaceID) found, but no opencode.ai cookie yet — reload the page, then Done.")
                    self.showDetectionFailure()
                }
                return
            }

            let header = relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            DispatchQueue.main.async {
                self.session.save(cookie: header, workspaceID: workspaceID)
                Diagnostics.log("session saved, connected=\(self.session.isConnected)")
                self.setStatus("Connected: \(workspaceID) (\(relevant.count) cookies).")
                self.onSuccess?()
                self.close()
            }
        }
    }

    private func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    private func showDetectionFailure() {
        let path = webView.url?.path ?? "?"
        let alert = NSAlert()
        alert.messageText = "Workspace not detected"
        alert.informativeText =
            "Open your workspace console (Go or Billing page) in the window, then click Done again.\n\n"
            + "Current page: \(path)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}
