import AppKit
import Foundation
import ServiceManagement

/// Wraps `SMAppService` so the settings UI can toggle launch at login/startup,
/// and reconciles registration with the saved user preference across app updates.
enum LaunchAtLogin {
    enum Status: Equatable {
        case enabled
        case requiresApproval
        case notRegistered
        case notFound
    }

    static var status: Status {
        let rawStatus = SMAppService.mainApp.status
        Diagnostics.log("launch at startup: status check -> \(rawStatus.rawValue)")
        switch rawStatus {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .notRegistered
        case .notFound:
            return .notFound
        @unknown default:
            return .notRegistered
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Synchronises SMAppService registration with the user's saved preference in Settings.
    /// If the user intended the app to launch at startup, but SMAppService was
    /// unregistered (e.g. following an app update or file replacement), this re-registers it.
    @discardableResult
    static func syncWithSettings(settings: Settings = .shared) -> Bool {
        let serviceStatus = SMAppService.mainApp.status
        // If the preference was never explicitly stored, adopt current enabled state.
        if !settings.hasConfiguredLaunchAtStartup && serviceStatus == .enabled {
            settings.launchAtStartupEnabled = true
            return true
        }

        let desired = settings.launchAtStartupEnabled
        let current = isEnabled

        if desired && !current {
            Diagnostics.log("launch at startup: auto-reconciling SMAppService registration (expected enabled)")
            return setEnabled(true, settings: settings)
        } else if !desired && current {
            Diagnostics.log("launch at startup: auto-reconciling SMAppService unregistration (expected disabled)")
            return setEnabled(false, settings: settings)
        }
        return true
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool, settings: Settings = .shared) -> Bool {
        settings.launchAtStartupEnabled = enabled
        let service = SMAppService.mainApp
        do {
            if enabled {
                guard service.status != .enabled else { return true }
                try service.register()
                Diagnostics.log("launch at startup: registered SMAppService, status=\(service.status.rawValue)")
            } else {
                guard service.status == .enabled else { return true }
                try service.unregister()
                Diagnostics.log("launch at startup: unregistered SMAppService, status=\(service.status.rawValue)")
            }
            return true
        } catch {
            Diagnostics.log("launch at startup: SMAppService error: \(error.localizedDescription)")
            return false
        }
    }

    /// Opens macOS System Settings to the Login Items pane.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
