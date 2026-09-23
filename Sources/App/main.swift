import AppKit

// OpenCode Credit is a menu bar only application: it lives in the status bar
// and has no Dock icon (see LSUIElement in Info.plist).
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
