import AppKit

/// Owns the menu bar item. The first version exposes the logo and a Quit
/// action; the usage popover is added in a later change.
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.imagePosition = .imageOnly
            button.toolTip = "OpenCode Credit"
        }

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit OpenCode Credit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }
}
