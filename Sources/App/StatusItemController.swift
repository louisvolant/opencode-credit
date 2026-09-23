import AppKit

/// Owns the menu bar item, the popover and the settings window.
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let popoverController = PopoverViewController()
    private let refreshService = RefreshService()
    private let settings = Settings.shared

    private lazy var settingsWindowController: SettingsWindowController = {
        let controller = SettingsWindowController()
        controller.onSave = { [weak self] in
            guard let self else { return }
            self.refreshService.rescheduleTimer()
            self.refreshService.refresh()
            self.render()
        }
        controller.onClose = { [weak self] in self?.render() }
        return controller
    }()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.contentViewController = popoverController
        popover.behavior = .transient
        popover.delegate = self

        popoverController.onRefresh = { [weak self] in self?.refreshService.refresh() }
        popoverController.onOpenSettings = { [weak self] in self?.settingsWindowController.show() }
        popoverController.onQuit = { NSApp.terminate(nil) }

        refreshService.onUpdate = { [weak self] in self?.render() }

        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "OpenCode Credit"
        }

        refreshService.start()
        render()
    }

    // MARK: - Rendering

    private func render() {
        updateButton()
        popoverController.render(snapshot: refreshService.snapshot, status: refreshService.status)
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }

        guard
            settings.showPercentInMenuBar,
            let snapshot = refreshService.snapshot,
            let rolling = snapshot.rolling
        else {
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        let text = " " + Formatting.percent(rolling.percent)
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: ColorScale.color(for: rolling.percent),
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            ]
        )
    }

    // MARK: - Interaction

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        render()
        refreshIfStale()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshIfStale() {
        guard let fetchedAt = refreshService.snapshot?.fetchedAt else {
            refreshService.refresh()
            return
        }
        if Date().timeIntervalSince(fetchedAt) > 30 {
            refreshService.refresh()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(contextRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(contextSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit OpenCode Credit", action: #selector(contextQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Temporarily attach the menu so a click opens it as a context menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func contextRefresh() { refreshService.refresh() }
    @objc private func contextSettings() { settingsWindowController.show() }
    @objc private func contextQuit() { NSApp.terminate(nil) }
}
