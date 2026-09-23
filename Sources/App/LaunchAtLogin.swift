import Foundation
import ServiceManagement

/// Wraps `SMAppService` so the settings UI can toggle "launch at login".
///
/// Registration is most reliable when the app lives in `/Applications`; a
/// failure is reported back to the caller so the UI can revert the toggle.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                guard service.status != .enabled else { return true }
                try service.register()
            } else {
                guard service.status == .enabled else { return true }
                try service.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
