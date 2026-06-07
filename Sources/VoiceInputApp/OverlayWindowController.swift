import AppKit

/// Manages the compact floating overlay window that displays real-time transcription
/// with an animated waveform during voice recording.
final class OverlayWindowController: NSWindowController {
    // MARK: - UI Components

    private let waveformView = WaveformView(
        frame: NSRect(
            x: 0,
            y: 0,
            width: OverlayLayout.waveformWidth,
            height: OverlayLayout.waveformHeight
        )
    )
    private let indicatorBackgroundView = NSView()
    private let textLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let refiningSpinner = NSProgressIndicator()
    private let visualEffectView = NSVisualEffectView()

    // MARK: - Temporary Message

    private var temporaryMessageTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        let window = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        setupWindow()
        setupContentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Window Setup

    private func setupWindow() {
        guard let window = window as? OverlayPanel else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.alphaValue = 0.0
        window.ignoresMouseEvents = true
    }

    // MARK: - Content View Setup

    private func setupContentView() {
        guard let window = window else { return }

        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = OverlayLayout.cornerRadius
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.backgroundColor = NSColor(
            red: 0.973,
            green: 0.988,
            blue: 0.979,
            alpha: 0.94
        ).cgColor
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor(
            red: 0.790,
            green: 0.835,
            blue: 0.815,
            alpha: 0.55
        ).cgColor
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        window.contentView = visualEffectView

        indicatorBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        indicatorBackgroundView.wantsLayer = true
        indicatorBackgroundView.layer?.cornerRadius = 9
        indicatorBackgroundView.layer?.backgroundColor = NSColor(
            red: 0.055,
            green: 0.420,
            blue: 0.345,
            alpha: 0.11
        ).cgColor
        visualEffectView.addSubview(indicatorBackgroundView)

        // Waveform view
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        indicatorBackgroundView.addSubview(waveformView)

        // Text label — multi-line with word wrapping for long transcription
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.isBezeled = false
        textLabel.isEditable = false
        textLabel.drawsBackground = false
        textLabel.textColor = NSColor(red: 0.114, green: 0.169, blue: 0.149, alpha: 1.0)
        textLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        textLabel.lineBreakMode = .byTruncatingHead
        textLabel.maximumNumberOfLines = OverlayLayout.maxVisibleLines
        textLabel.alignment = .left
        textLabel.cell?.wraps = true
        textLabel.cell?.isScrollable = false
        textLabel.cell?.truncatesLastVisibleLine = true
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        visualEffectView.addSubview(textLabel)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.isBezeled = false
        statusLabel.isEditable = false
        statusLabel.drawsBackground = false
        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        statusLabel.textColor = NSColor(red: 0.055, green: 0.420, blue: 0.345, alpha: 1.0)
        statusLabel.stringValue = "听写中"
        statusLabel.wantsLayer = true
        statusLabel.layer?.cornerRadius = 10
        statusLabel.layer?.backgroundColor = NSColor(
            red: 0.055,
            green: 0.420,
            blue: 0.345,
            alpha: 0.10
        ).cgColor
        visualEffectView.addSubview(statusLabel)

        // Refining spinner (hidden by default)
        refiningSpinner.style = .spinning
        refiningSpinner.controlSize = .mini
        refiningSpinner.translatesAutoresizingMaskIntoConstraints = false
        refiningSpinner.isHidden = true
        indicatorBackgroundView.addSubview(refiningSpinner)

        // Layout — vertical padding and variable-height text
        NSLayoutConstraint.activate([
            indicatorBackgroundView.leadingAnchor.constraint(
                equalTo: visualEffectView.leadingAnchor,
                constant: OverlayLayout.horizontalPadding
            ),
            indicatorBackgroundView.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            indicatorBackgroundView.widthAnchor.constraint(equalToConstant: OverlayLayout.indicatorSize),
            indicatorBackgroundView.heightAnchor.constraint(equalToConstant: OverlayLayout.indicatorSize),

            waveformView.centerXAnchor.constraint(equalTo: indicatorBackgroundView.centerXAnchor),
            waveformView.centerYAnchor.constraint(equalTo: indicatorBackgroundView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: OverlayLayout.waveformWidth),
            waveformView.heightAnchor.constraint(equalToConstant: OverlayLayout.waveformHeight),

            textLabel.leadingAnchor.constraint(
                equalTo: indicatorBackgroundView.trailingAnchor,
                constant: OverlayLayout.interSpacing
            ),
            textLabel.topAnchor.constraint(
                equalTo: visualEffectView.topAnchor,
                constant: OverlayLayout.verticalPadding
            ),
            textLabel.trailingAnchor.constraint(
                equalTo: statusLabel.leadingAnchor,
                constant: -OverlayLayout.interSpacing
            ),
            textLabel.bottomAnchor.constraint(
                lessThanOrEqualTo: visualEffectView.bottomAnchor,
                constant: -OverlayLayout.verticalPadding
            ),

            statusLabel.trailingAnchor.constraint(
                equalTo: visualEffectView.trailingAnchor,
                constant: -OverlayLayout.horizontalPadding
            ),
            statusLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: OverlayLayout.statusChipWidth),
            statusLabel.heightAnchor.constraint(equalToConstant: 26),

            refiningSpinner.centerXAnchor.constraint(equalTo: indicatorBackgroundView.centerXAnchor),
            refiningSpinner.centerYAnchor.constraint(equalTo: indicatorBackgroundView.centerYAnchor),
        ])
    }

    // MARK: - Sizing

    private func updateWindowSize(textWidth: CGFloat, textHeight: CGFloat = 0) {
        guard let window = window else { return }

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let windowWidth = ceil(OverlayLayout.windowWidth(textWidth: textWidth))
        let windowHeight = OverlayLayout.windowHeight(textHeight: textHeight)
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.minY + OverlayLayout.bottomOffset

        let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        window.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Public API

    func show() {
        guard let window = window else { return }
        temporaryMessageTask?.cancel()
        temporaryMessageTask = nil

        // Calculate initial size for empty text
        updateWindowSize(textWidth: OverlayLayout.minimumTextWidth)

        waveformView.isHidden = false
        waveformView.reset()
        waveformView.startAnimation()
        statusLabel.stringValue = "听写中"
        statusLabel.textColor = NSColor(red: 0.055, green: 0.420, blue: 0.345, alpha: 1.0)
        refiningSpinner.isHidden = true
        refiningSpinner.stopAnimation(nil)

        present(window)
    }

    private func present(_ window: NSWindow) {
        window.orderFront(nil)

        if let layer = visualEffectView.layer {
            let spring = CASpringAnimation(keyPath: "transform.scale")
            spring.fromValue = 0.82
            spring.toValue = 1.0
            spring.mass = 1
            spring.stiffness = 320
            spring.damping = 24
            spring.initialVelocity = 0
            spring.duration = 0.35
            layer.add(spring, forKey: "voiceinput.entrance")
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }
    }

    func updateTranscription(_ text: String, isRefining: Bool) {
        let displayText: String
        if isRefining {
            displayText = text.isEmpty ? "正在识别文本" : text
            textLabel.textColor = NSColor(red: 0.220, green: 0.310, blue: 0.280, alpha: 0.92)
            statusLabel.stringValue = "纠错中"
            waveformView.stopAnimation()
            waveformView.isHidden = true
            refiningSpinner.isHidden = false
            refiningSpinner.startAnimation(nil)
        } else {
            displayText = text.isEmpty ? "正在聆听..." : text
            textLabel.textColor = NSColor(red: 0.114, green: 0.169, blue: 0.149, alpha: 1.0)
            statusLabel.stringValue = "听写中"
            waveformView.isHidden = false
            waveformView.startAnimation()
            refiningSpinner.isHidden = true
            refiningSpinner.stopAnimation(nil)
        }
        let visibleText = OverlayLayout.visibleTranscriptionText(displayText)
        textLabel.stringValue = visibleText

        let textSize = (visibleText as NSString).boundingRect(
            with: NSSize(
                width: OverlayLayout.maximumTextWidth,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: textLabel.font as Any]
        )
        let newTextWidth = textSize.width + 8
        let newTextHeight = textSize.height + 8

        guard let window = window else { return }
        let totalWidth = OverlayLayout.windowWidth(textWidth: newTextWidth)
        let totalHeight = OverlayLayout.windowHeight(textHeight: newTextHeight)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let newFrame = NSRect(
            x: screenFrame.midX - totalWidth / 2,
            y: screenFrame.minY + OverlayLayout.bottomOffset,
            width: totalWidth,
            height: totalHeight
        )

        // Smooth width transition (0.25s)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }

    func updateRMS(_ rms: Float) {
        waveformView.updateRMS(rms)
    }

    /// Displays a temporary error/info message in the overlay that auto-dismisses
    /// after `duration` seconds. Used for non-blocking error feedback.
    func showTemporaryMessage(_ text: String, duration: TimeInterval = 3.0) {
        temporaryMessageTask?.cancel()

        waveformView.stopAnimation()
        waveformView.isHidden = true
        statusLabel.stringValue = "提示"
        statusLabel.textColor = NSColor(red: 0.670, green: 0.390, blue: 0.080, alpha: 1.0)
        refiningSpinner.isHidden = true
        refiningSpinner.stopAnimation(nil)

        textLabel.stringValue = text
        textLabel.textColor = NSColor(red: 1.0, green: 0.78, blue: 0.38, alpha: 1.0)  // warm amber

        let textSize = (text as NSString).boundingRect(
            with: NSSize(
                width: OverlayLayout.maximumTextWidth,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: textLabel.font as Any]
        )
        updateWindowSize(textWidth: textSize.width + 8, textHeight: textSize.height + 8)
        guard let window else { return }
        present(window)

        temporaryMessageTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.dismiss()
        }
    }

    func dismiss() {
        guard let window = window else { return }

        waveformView.stopAnimation()
        if let layer = visualEffectView.layer {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1.0
            scale.toValue = 0.86
            scale.duration = 0.22
            scale.timingFunction = CAMediaTimingFunction(name: .easeIn)
            layer.add(scale, forKey: "voiceinput.exit")
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0.0
        } completionHandler: {
            MainActor.assumeIsolated {
                window.orderOut(nil)
                self.visualEffectView.layer?.removeAnimation(forKey: "voiceinput.exit")
            }
        }
    }

    /// Returns the current transcription text shown in the overlay.
    var currentText: String {
        textLabel.stringValue
    }
}

// MARK: - Overlay NSPanel

/// A borderless, non-activating NSPanel that floats above other windows.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
