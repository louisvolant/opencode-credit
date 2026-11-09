import AppKit

/// Settings window: API key, refresh interval and menu bar options.
final class SettingsWindowController: NSWindowController {
    /// Called whenever a setting that affects the rest of the app changes.
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?
    var sessionStatusMessage: String? {
        didSet {
            if isWindowLoaded { refreshFromSettings() }
        }
    }

    private let credentials = CredentialStore.shared
    private let settings = Settings.shared

    private let keyField = NSSecureTextField()
    private let keyFieldVisible = NSTextField()
    private let revealKeyButton = NSButton()
    private var isKeyRevealed = false
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
    private let launchAtLoginStatusLabel = NSTextField(labelWithString: "")
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
            self?.sessionStatusMessage = nil
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

        // Mirror of the secure field, shown in clear text while the eye button
        // is toggled on. Only one of the two is visible at a time.
        keyFieldVisible.placeholderString = "Paste an OpenCode API key"
        keyFieldVisible.translatesAutoresizingMaskIntoConstraints = false
        keyFieldVisible.isHidden = true

        revealKeyButton.target = self
        revealKeyButton.action = #selector(toggleKeyVisibility)
        revealKeyButton.isBordered = false
        revealKeyButton.bezelStyle = .inline
        revealKeyButton.imagePosition = .imageOnly
        revealKeyButton.translatesAutoresizingMaskIntoConstraints = false
        revealKeyButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        updateRevealButton()

        let saveKeyButton = NSButton(title: "Save key", target: self, action: #selector(saveKey))
        let clearKeyButton = NSButton(title: "Clear", target: self, action: #selector(clearKey))
        for button in [saveKeyButton, clearKeyButton] {
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
        }

        let keyRow = NSStackView(views: [keyField, keyFieldVisible, revealKeyButton, saveKeyButton, clearKeyButton])
        keyRow.detachesHiddenViews = true
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

        launchAtLoginStatusLabel.font = .systemFont(ofSize: 11)
        launchAtLoginStatusLabel.textColor = .secondaryLabelColor
        launchAtLoginStatusLabel.maximumNumberOfLines = 2
        launchAtLoginStatusLabel.lineBreakMode = .byWordWrapping
        launchAtLoginStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        launchAtLoginStatusLabel.isHidden = true

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
            launchAtLoginStatusLabel,
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
        keyFieldVisible.stringValue = ""
        isKeyRevealed = false
        keyField.isHidden = false
        keyFieldVisible.isHidden = true
        updateRevealButton()

        if let resolved = credentials.resolve() {
            sourceLabel.stringValue = "Using: \(resolved.sourceDescription)"
        } else {
            sourceLabel.stringValue = "No key configured yet. Paste one above or set OPENCODE_API_KEY."
        }

        if let error = sessionStatusMessage, !error.isEmpty {
            zenStatusLabel.stringValue = "\(error) Sign in to reconnect."
            disconnectButton.isEnabled = session.isConnected
        } else if session.isConnected {
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

        switch LaunchAtLogin.status {
        case .enabled:
            launchAtLoginCheckbox.state = .on
            launchAtLoginStatusLabel.stringValue = ""
            launchAtLoginStatusLabel.isHidden = true
        case .requiresApproval:
            launchAtLoginCheckbox.state = .on
            launchAtLoginStatusLabel.stringValue = "Requires approval in System Settings → General → Login Items."
            launchAtLoginStatusLabel.textColor = .systemOrange
            launchAtLoginStatusLabel.isHidden = false
        case .notRegistered, .notFound:
            launchAtLoginCheckbox.state = settings.launchAtStartupEnabled ? .on : .off
            if settings.launchAtStartupEnabled {
                launchAtLoginStatusLabel.stringValue = "Registration pending or app not located in /Applications."
                launchAtLoginStatusLabel.textColor = .secondaryLabelColor
                launchAtLoginStatusLabel.isHidden = false
            } else {
                launchAtLoginStatusLabel.stringValue = ""
                launchAtLoginStatusLabel.isHidden = true
            }
        }

        notificationsCheckbox.state = settings.notificationsEnabled ? .on : .off
        thresholdPopup.isEnabled = settings.notificationsEnabled
        thresholdPopup.selectItem(at: thresholdOptions.firstIndex(of: settings.notificationThreshold) ?? 1)
    }

    // MARK: - Actions

    @objc private func saveKey() {
        let value = enteredKey
        guard !value.isEmpty else { return }
        credentials.setAppKey(value)
        refreshFromSettings()
        onSave?()
    }

    /// Shows or hides the key in clear text, keeping the same value in both
    /// fields so that revealing it always reflects what was typed.
    @objc private func toggleKeyVisibility() {
        let value = isKeyRevealed ? keyFieldVisible.stringValue : keyField.stringValue
        isKeyRevealed.toggle()
        keyField.stringValue = value
        keyFieldVisible.stringValue = value
        keyField.isHidden = isKeyRevealed
        keyFieldVisible.isHidden = !isKeyRevealed
        updateRevealButton()
        if let window {
            window.makeFirstResponder(isKeyRevealed ? keyFieldVisible : keyField)
        }
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
        let success = LaunchAtLogin.setEnabled(enabled)
        if !success {
            launchAtLoginStatusLabel.stringValue = "Registration failed. Ensure the app is in /Applications."
            launchAtLoginStatusLabel.textColor = .systemRed
            launchAtLoginStatusLabel.isHidden = false
        }
        refreshFromSettings()
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
        sessionStatusMessage = nil
        refreshFromSettings()
        onSave?()
    }

    @objc private func closeTapped() {
        close()
        onClose?()
    }

    // MARK: - Helpers

    /// The key currently entered, from whichever of the two fields is visible.
    private var enteredKey: String {
        (isKeyRevealed ? keyFieldVisible.stringValue : keyField.stringValue)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateRevealButton() {
        let symbol = isKeyRevealed ? "eye.slash" : "eye"
        let label = isKeyRevealed ? "Hide key" : "Show key"
        revealKeyButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        revealKeyButton.toolTip = label
    }

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
