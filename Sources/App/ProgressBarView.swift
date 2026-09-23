import AppKit

/// A small rounded progress bar. `NSProgressIndicator` does not allow reliable
/// colour control, so the bar is drawn directly.
final class ProgressBarView: NSView {
    /// Value between 0 and 1.
    var progress: Double = 0 {
        didSet { needsDisplay = true }
    }

    var barColor: NSColor = .systemGreen {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 6)
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2

        let track = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        NSColor.quaternaryLabelColor.setFill()
        track.fill()

        let clamped = max(0, min(1, progress))
        guard clamped > 0, bounds.width > 0 else { return }

        let width = max(bounds.height, bounds.width * clamped)
        let fillRect = NSRect(x: 0, y: 0, width: width, height: bounds.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)
        barColor.setFill()
        fill.fill()
    }
}
