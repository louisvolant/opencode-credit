import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusItemController = StatusItemController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Closing a window (settings, login) must never quit the app: it lives
        // in the menu bar.
        false
    }

    /// The app has no visible menu bar, but a main menu is still required so
    /// that the standard editing shortcuts (⌘C/⌘V/⌘A/⌘X…) reach the focused
    /// text field. Without it, only the right-click menu can paste.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "Quit OpenCode Credit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        let undo = editMenu.addItem(
            withTitle: "Undo",
            action: NSSelectorFromString("undo:"),
            keyEquivalent: "z"
        )
        undo.target = nil
        let redo = editMenu.addItem(
            withTitle: "Redo",
            action: NSSelectorFromString("redo:"),
            keyEquivalent: "z"
        )
        redo.keyEquivalentModifierMask = [.command, .shift]
        redo.target = nil
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: NSSelectorFromString("cut:"), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: NSSelectorFromString("copy:"), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: NSSelectorFromString("paste:"), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: NSSelectorFromString("selectAll:"), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }
}
