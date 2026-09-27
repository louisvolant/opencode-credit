import AppKit

/// Content of the menu bar popover.
final class PopoverViewController: NSViewController {
    var onRefresh: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let headerLabel = NSTextField(labelWithString: "OpenCode Go")
    private let rollingRow = UsageRowView(title: "Rolling usage")
    private let weeklyRow = UsageRowView(title: "Weekly usage")
    private let monthlyRow = UsageRowView(title: "Monthly usage")
    private let zenTitleLabel = NSTextField(labelWithString: "OpenCode Zen")
    private let balanceLabel = NSTextField(labelWithString: "Not connected")
    private let balanceDetailLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let updatedLabel = NSTextField(labelWithString: "Never updated")
    private let versionLabel = NSTextField(labelWithString: "")

    private let contentWidth: CGFloat = 300

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 260))
        view = root
        build()
    }

    // MARK: - Layout

    private func build() {
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = .labelColor

        zenTitleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        zenTitleLabel.textColor = .labelColor

        balanceLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        balanceLabel.textColor = .labelColor

        balanceDetailLabel.font = .systemFont(ofSize: 11)
        balanceDetailLabel.textColor = .secondaryLabelColor
        balanceDetailLabel.maximumNumberOfLines = 3
        balanceDetailLabel.lineBreakMode = .byWordWrapping

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 4
        statusLabel.lineBreakMode = .byWordWrapping

        updatedLabel.font = .systemFont(ofSize: 11)
        updatedLabel.textColor = .tertiaryLabelColor

        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor
        if let version = AppInfo.version {
            versionLabel.stringValue = "v\(version)"
        } else {
            versionLabel.isHidden = true
        }

        let footer = NSStackView(views: [
            updatedLabel,
            flexibleSpacer(),
            versionLabel,
            iconButton(symbol: "arrow.clockwise", tooltip: "Refresh now", action: #selector(refreshTapped)),
            iconButton(symbol: "gearshape", tooltip: "Settings", action: #selector(settingsTapped)),
            iconButton(symbol: "power", tooltip: "Quit", action: #selector(quitTapped)),
        ])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 6
        footer.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            headerLabel,
            rollingRow,
            weeklyRow,
            monthlyRow,
            separator(),
            zenTitleLabel,
            balanceLabel,
            balanceDetailLabel,
            statusLabel,
            separator(),
            footer,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            view.widthAnchor.constraint(equalToConstant: contentWidth),
            rollingRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            weeklyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            monthlyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    // MARK: - Rendering

    func render(
        snapshot: UsageSnapshot?,
        status: RefreshService.Status,
        balance: ZenBalance?,
        balanceError: String?,
        isConnected: Bool
    ) {
        let now = Date()

        rollingRow.update(percent: snapshot?.rolling?.percent, resetsAt: snapshot?.rolling?.resetsAt, now: now)
        weeklyRow.update(percent: snapshot?.weekly?.percent, resetsAt: snapshot?.weekly?.resetsAt, now: now)
        monthlyRow.update(percent: snapshot?.monthly?.percent, resetsAt: snapshot?.monthly?.resetsAt, now: now)

        if let fetchedAt = snapshot?.fetchedAt, fetchedAt != .distantPast {
            updatedLabel.stringValue = "Updated \(Formatting.relative(fetchedAt, now: now))"
        } else {
            updatedLabel.stringValue = "Never updated"
        }

        switch status {
        case .needsSetup:
            statusLabel.stringValue = "No API key configured. Open Settings to add one."
            statusLabel.isHidden = false
        case .failed(let message):
            statusLabel.stringValue = message
            statusLabel.isHidden = false
        case .loading:
            statusLabel.stringValue = snapshot == nil ? "Refreshing…" : ""
            statusLabel.isHidden = statusLabel.stringValue.isEmpty
        case .idle, .ok:
            statusLabel.stringValue = ""
            statusLabel.isHidden = true
        }

        renderBalance(balance, error: balanceError, isConnected: isConnected)

        view.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(width: contentWidth, height: view.fittingSize.height)
    }

    private func renderBalance(_ balance: ZenBalance?, error: String?, isConnected: Bool) {
        if let balance {
            balanceLabel.stringValue = Formatting.currency(balance.balanceUSD)
            balanceLabel.textColor = .labelColor

            if let usage = balance.monthlyUsageUSD, let limit = balance.monthlyLimitUSD {
                balanceDetailLabel.stringValue =
                    "Used \(Formatting.currency(usage)) of \(Formatting.currency(limit)) this month"
            } else if let usage = balance.monthlyUsageUSD {
                balanceDetailLabel.stringValue = "Used \(Formatting.currency(usage)) this month"
            } else {
                balanceDetailLabel.stringValue = ""
            }
        } else if isConnected {
            balanceLabel.stringValue = "—"
            balanceLabel.textColor = .secondaryLabelColor
            balanceDetailLabel.stringValue = error ?? "Reading the billing page…"
        } else {
            balanceLabel.stringValue = "Not connected"
            balanceLabel.textColor = .secondaryLabelColor
            balanceDetailLabel.stringValue = "Sign in from Settings to show your credit."
        }

        balanceDetailLabel.isHidden = balanceDetailLabel.stringValue.isEmpty
    }

    // MARK: - Actions

    @objc private func refreshTapped() { onRefresh?() }
    @objc private func settingsTapped() { onOpenSettings?() }
    @objc private func quitTapped() { onQuit?() }

    // MARK: - Helpers

    private func flexibleSpacer() -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    private func iconButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) ?? NSImage()
        let button = NSButton(image: image, target: self, action: action)
        button.isBordered = false
        button.bezelStyle = .inline
        button.toolTip = tooltip
        button.contentTintColor = .secondaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        button.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return button
    }
}
