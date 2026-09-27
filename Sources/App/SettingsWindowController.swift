import AppKit

/// Settings window: API key, refresh interval and menu bar options.
final class SettingsWindowController: NSWindowController {
    /// Called whenever a setting that affects the rest of the app changes.
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?

    private let credentials = CredentialStore.shared
    private let settings = Settings.shared

    private let keyField = NSSecureTextField()
    private let sourceLabel = NSTextField(labelWithString: "")
    private let intervalPopup = NSPopUpButton()
    private let showPercentCheckbox = NSButton(
        checkboxWithTitle: "Show rolling percentage in the menu bar",
        target: nil,
        action: nil
    )
    private let launchAtLoginCheckbox = NSButton(
        checkboxWithTitle: "Launch at login",
        target: nil,
        action: nil
    )
    private let notificationsCheckbox = NSButton(
        checkboxWithTitle: "Notify me when a window reaches",
        target: nil,
        action: nil
    )
    private let thresholdPopup = NSPopUpButton()
    private let thresholdOptions = [70, 80, 90, 95]
    private let zenStatusLabel = NSTextField(labelWithString: "")
    private let signInButton = NSButton(title: "Sign in…", target: nil, action: nil)
    private let disconnectButton = NSButton(title: "Disconnect", target: nil, action: nil)

    private let session = ZenSession.shared

    private lazy var loginWindowController: LoginWindowController = {
        let controller = LoginWindowController()
        controller.onSuccess = { [weak self] in
            self?.refreshFromSettings()
            self?.onSave?()
        }
        return controller
    }()

    private let intervalOptions = [1, 5, 15, 30, 60]

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenCode Credit Settings"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        build()
    }

    func show() {
        refreshFromSettings()
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

        keyField.placeholderString = "Paste an OpenCode API key"
        keyField.translatesAutoresizingMaskIntoConstraints = false

        let saveKeyButton = NSButton(title: "Save key", target: self, action: #selector(saveKey))
        let clearKeyButton = NSButton(title: "Clear", target: self, action: #selector(clearKey))
        for button in [saveKeyButton, clearKeyButton] {
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
        }

        let keyRow = NSStackView(views: [keyField, saveKeyButton, clearKeyButton])
        keyRow.orientation = .horizontal
        keyRow.spacing = 8
        keyRow.translatesAutoresizingMaskIntoConstraints = false

        sourceLabel.font = .systemFont(ofSize: 11)
        sourceLabel.textColor = .secondaryLabelColor
        sourceLabel.maximumNumberOfLines = 2
        sourceLabel.lineBreakMode = .byWordWrapping
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false

        zenStatusLabel.font = .systemFont(ofSize: 11)
        zenStatusLabel.textColor = .secondaryLabelColor
        zenStatusLabel.maximumNumberOfLines = 2
        zenStatusLabel.lineBreakMode = .byWordWrapping
        zenStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        signInButton.target = self
        signInButton.action = #selector(signIn)
        signInButton.bezelStyle = .rounded
        signInButton.translatesAutoresizingMaskIntoConstraints = false

        disconnectButton.target = self
        disconnectButton.action = #selector(disconnect)
        disconnectButton.bezelStyle = .rounded
        disconnectButton.translatesAutoresizingMaskIntoConstraints = false

        let zenButtons = NSStackView(views: [signInButton, disconnectButton, flexibleSpacer()])
        zenButtons.orientation = .horizontal
        zenButtons.spacing = 8
        zenButtons.translatesAutoresizingMaskIntoConstraints = false

        intervalPopup.removeAllItems()
        for minutes in intervalOptions {
            intervalPopup.addItem(withTitle: "\(minutes) minute\(minutes == 1 ? "" : "s")")
            intervalPopup.lastItem?.representedObject = minutes
        }
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)

        let intervalRow = NSStackView(views: [makeLabel("Refresh every"), intervalPopup, flexibleSpacer()])
        intervalRow.orientation = .horizontal
        intervalRow.spacing = 8
        intervalRow.translatesAutoresizingMaskIntoConstraints = false

        showPercentCheckbox.target = self
        showPercentCheckbox.action = #selector(showPercentChanged)
        showPercentCheckbox.translatesAutoresizingMaskIntoConstraints = false

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginChanged)
        launchAtLoginCheckbox.translatesAutoresizingMaskIntoConstraints = false

        notificationsCheckbox.target = self
        notificationsCheckbox.action = #selector(notificationsChanged)
        notificationsCheckbox.translatesAutoresizingMaskIntoConstraints = false

        thresholdPopup.removeAllItems()
        for value in thresholdOptions {
            thresholdPopup.addItem(withTitle: "\(value)%")
            thresholdPopup.lastItem?.representedObject = value
        }
        thresholdPopup.target = self
        thresholdPopup.action = #selector(thresholdChanged)
        thresholdPopup.translatesAutoresizingMaskIntoConstraints = false

        let notificationsRow = NSStackView(views: [notificationsCheckbox, thresholdPopup, flexibleSpacer()])
        notificationsRow.orientation = .horizontal
        notificationsRow.spacing = 8
        notificationsRow.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = NSButton(title: "Done", target: self, action: #selector(closeTapped))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSStackView(views: [flexibleSpacer(), closeButton])
        footer.orientation = .horizontal
        footer.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            makeSectionLabel("API key"),
            keyRow,
            sourceLabel,
            makeSeparator(),
            makeSectionLabel("OpenCode Zen credit"),
            zenStatusLabel,
            zenButtons,
            makeSeparator(),
            makeSectionLabel("Refresh"),
            intervalRow,
            showPercentCheckbox,
            launchAtLoginCheckbox,
            makeSeparator(),
            makeSectionLabel("Notifications"),
            notificationsRow,
            makeSeparator(),
            footer,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
            keyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            zenButtons.widthAnchor.constraint(equalTo: stack.widthAnchor),
            notificationsRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            intervalRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    // MARK: - State

    private func refreshFromSettings() {
        keyField.stringValue = ""

        if let resolved = credentials.resolve() {
            sourceLabel.stringValue = "Using: \(resolved.sourceDescription)"
        } else {
            sourceLabel.stringValue = "No key configured yet. Paste one above or set OPENCODE_API_KEY."
        }

        if session.isConnected {
            zenStatusLabel.stringValue = "Connected to your OpenCode workspace."
            disconnectButton.isEnabled = true
        } else {
            zenStatusLabel.stringValue =
                "Not connected. Sign in to show your available credit and Extra Usage state "
                + "(not available through the API key)."
            disconnectButton.isEnabled = false
        }

        let index = intervalOptions.firstIndex(of: settings.refreshIntervalMinutes) ?? 1
        intervalPopup.selectItem(at: index)
        showPercentCheckbox.state = settings.showPercentInMenuBar ? .on : .off
        launchAtLoginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        notificationsCheckbox.state = settings.notificationsEnabled ? .on : .off
        thresholdPopup.isEnabled = settings.notificationsEnabled
        thresholdPopup.selectItem(at: thresholdOptions.firstIndex(of: settings.notificationThreshold) ?? 1)
    }

    // MARK: - Actions

    @objc private func saveKey() {
        let value = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        credentials.setAppKey(value)
        refreshFromSettings()
        onSave?()
    }

    @objc private func clearKey() {
        credentials.setAppKey(nil)
        refreshFromSettings()
        onSave?()
    }

    @objc private func intervalChanged() {
        let minutes = intervalPopup.selectedItem?.representedObject as? Int ?? 5
        settings.refreshIntervalMinutes = minutes
        onSave?()
    }

    @objc private func showPercentChanged() {
        settings.showPercentInMenuBar = showPercentCheckbox.state == .on
        onSave?()
    }

    @objc private func launchAtLoginChanged() {
        let enabled = launchAtLoginCheckbox.state == .on
        if !LaunchAtLogin.setEnabled(enabled) {
            // The system refused (for example the app is not in /Applications).
            launchAtLoginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        }
    }

    @objc private func notificationsChanged() {
        let enabled = notificationsCheckbox.state == .on
        settings.notificationsEnabled = enabled
        thresholdPopup.isEnabled = enabled
        if enabled { NotificationManager.shared.requestAuthorization() }
    }

    @objc private func thresholdChanged() {
        settings.notificationThreshold = thresholdPopup.selectedItem?.representedObject as? Int ?? 80
    }

    @objc private func signIn() {
        loginWindowController.show()
    }

    @objc private func disconnect() {
        session.clear()
        refreshFromSettings()
        onSave?()
    }

    @objc private func closeTapped() {
        close()
        onClose?()
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func flexibleSpacer() -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }

    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }
}
