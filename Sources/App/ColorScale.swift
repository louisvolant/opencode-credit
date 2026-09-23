import AppKit

/// Maps a usage percentage to a colour used by the progress bars and the menu
/// bar title.
enum ColorScale {
    static func color(for percent: Double) -> NSColor {
        switch percent {
        case ..<60:
            return .systemGreen
        case ..<85:
            return .systemOrange
        default:
            return .systemRed
        }
    }
}
