import AppKit
import WebKit

/// Embedded browser used to sign in to OpenCode and capture the workspace
/// session needed for the credit balance.
///
/// Google blocks OAuth inside embedded web views, so the user is expected to
/// continue with GitHub.
final class LoginWindowController: NSWindowController, WKNavigationDelegate {
    /// Called on the main thread once a session has been captured.
    var onSuccess: (() -> Void)?

    private let session = ZenSession.shared
    private let instructionsLabel = NSTextField(labelWithString: "")
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
            "Continue with GitHub, then open your workspace console (Go or Billing page). "
            + "This window closes automatically once your workspace is detected."
        instructionsLabel.font = .systemFont(ofSize: 11)
        instructionsLabel.textColor = .secondaryLabelColor
        instructionsLabel.maximumNumberOfLines = 2
        instructionsLabel.lineBreakMode = .byWordWrapping
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = NSButton(title: "Done", target: self, action: #selector(doneTapped))
        doneButton.bezelStyle = .rounded
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        let topBar = NSStackView(views: [instructionsLabel, doneButton])
        topBar.orientation = .horizontal
        topBar.alignment = .centerY
        topBar.spacing = 12
        topBar.translatesAutoresizingMaskIntoConstraints = false

        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
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
        guard !didFinish else { return }
        detectWorkspace { [weak self] workspaceID in
            guard let self, let workspaceID else { return }
            self.finish(with: workspaceID)
        }
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

    private func detectWorkspace(completion: @escaping (String?) -> Void) {
        if let id = WorkspaceURL.id(from: webView.url?.absoluteString) {
            completion(id)
            return
        }

        let script = """
        (function() {
          var links = document.querySelectorAll('a[href*="/console/"], a[href*="/workspace/"]');
          for (var i = 0; i < links.length; i++) {
            var href = links[i].getAttribute('href') || '';
            if (href.indexOf('/console/') !== -1 || href.indexOf('/workspace/') !== -1) {
              return href;
            }
          }
          return null;
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            completion(WorkspaceURL.id(from: result as? String))
        }
    }

    private func finish(with workspaceID: String) {
        guard !didFinish else { return }
        didFinish = true

        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let relevant = cookies.filter { $0.domain.contains("opencode.ai") }

            guard !relevant.isEmpty else {
                DispatchQueue.main.async {
                    self.didFinish = false
                    self.showDetectionFailure()
                }
                return
            }

            let header = relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            DispatchQueue.main.async {
                self.session.save(cookie: header, workspaceID: workspaceID)
                self.onSuccess?()
                self.close()
            }
        }
    }

    private func showDetectionFailure() {
        let alert = NSAlert()
        alert.messageText = "Workspace not detected"
        alert.informativeText = "Open your workspace billing page in the window, then click Done again."
        alert.alertStyle = .warning
        alert.runModal()
    }
}
