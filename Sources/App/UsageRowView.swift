import AppKit

/// A single usage window: title, percentage, progress bar and reset countdown.
final class UsageRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let resetLabel = NSTextField(labelWithString: "")
    private let bar = ProgressBarView()

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = title

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        percentLabel.textColor = .labelColor
        resetLabel.font = .systemFont(ofSize: 11)
        resetLabel.textColor = .secondaryLabelColor

        for label in [titleLabel, percentLabel, resetLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
        }

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topRow = NSStackView(views: [titleLabel, spacer, percentLabel])
        topRow.orientation = .horizontal
        topRow.alignment = .firstBaseline
        topRow.spacing = 8
        topRow.translatesAutoresizingMaskIntoConstraints = false

        bar.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [topRow, bar, resetLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            topRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bar.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(percent: Double?, resetsAt: Date?, now: Date = Date()) {
        guard let percent else {
            percentLabel.stringValue = "—"
            resetLabel.stringValue = "Not available"
            bar.progress = 0
            bar.barColor = .tertiaryLabelColor
            return
        }

        percentLabel.stringValue = Formatting.percent(percent)
        bar.progress = percent / 100
        bar.barColor = ColorScale.color(for: percent)

        if let resetsAt {
            resetLabel.stringValue = "Resets in \(Formatting.countdown(until: resetsAt, now: now))"
        } else {
            resetLabel.stringValue = ""
        }
    }
}
