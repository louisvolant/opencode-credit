import AppKit

/// Renders the OpenCode logo mark as a template image.
///
/// A template image is drawn by macOS using a single tint colour derived from
/// the alpha channel, so the same asset looks right on light and dark menu
/// bars without shipping two files.
///
/// Geometry is taken from the official logo (`opencode.ai/favicon-v3.svg`),
/// which is authored on a 512x512 view box:
///   - an outer frame from (128, 96) to (384, 416) with a rectangular hole,
///   - an inner block from (192, 224) to (320, 352).
enum MenuBarIcon {
    /// Logical size in points. The mark is 256 wide by 320 tall, so it is
    /// slightly taller than it is wide.
    static let pointSize = NSSize(width: 14.5, height: 18)

    static func make() -> NSImage {
        // Render at 2x for crisp Retina output.
        let backingScale: CGFloat = 2
        let pixelWidth = Int(pointSize.width * backingScale)
        let pixelHeight = Int(pointSize.height * backingScale)

        let image = NSImage(size: pointSize)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return image
        }
        rep.size = pointSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(origin: .zero, size: pointSize))
        NSGraphicsContext.restoreGraphicsState()

        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }

    private static func draw(in bounds: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // The logo's bounding box inside the 512x512 view box.
        let sourceX: CGFloat = 128
        let sourceY: CGFloat = 96
        let sourceWidth: CGFloat = 256
        let sourceHeight: CGFloat = 320

        let scale = min(bounds.width / sourceWidth, bounds.height / sourceHeight)
        let markWidth = sourceWidth * scale
        let markHeight = sourceHeight * scale
        let originX = (bounds.width - markWidth) / 2
        let originY = (bounds.height - markHeight) / 2

        // Convert a rectangle expressed in the SVG coordinate space (top-left
        // origin) into the Core Graphics coordinate space (bottom-left origin).
        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            let px = originX + (x - sourceX) * scale
            let py = originY + markHeight - (y - sourceY) * scale - height * scale
            return CGRect(x: px, y: py, width: width * scale, height: height * scale)
        }

        // Frame: outer rectangle minus the inner hole, filled with the
        // even-odd rule.
        context.setFillColor(NSColor.black.cgColor)
        context.addPath(CGPath(rect: rect(128, 96, 256, 320), transform: nil))
        context.addPath(CGPath(rect: rect(192, 160, 128, 192), transform: nil))
        context.fillPath(using: .evenOdd)

        // Inner block, dimmed so the mark keeps its two-tone appearance.
        context.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        context.fill(rect(192, 224, 128, 128))
    }
}
