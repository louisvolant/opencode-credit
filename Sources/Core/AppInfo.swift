import Foundation

/// Identity of the running app bundle.
enum AppInfo {
    /// Short marketing version, e.g. `1.0.2`. `nil` outside an app bundle.
    static var version: String? {
        guard
            let value = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            !value.isEmpty
        else {
            return nil
        }
        return value
    }
}
