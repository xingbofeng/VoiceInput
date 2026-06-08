import AppKit

/// Manages the floating capsule overlay window that displays real-time transcription
/// with an animated waveform during voice recording.
final class OverlayWindowController: NSWindowController {
    // MARK: - UI Components

    private let waveformView = WaveformView(frame: NSRect(x: 0, y: 0, width: 44, height: 32))
    private let textLabel = NSTextField(labelWithString: "")
    private let refiningSpinner = NSProgressIndicator()
    private let visualEffectView = NSVisualEffectView()

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

        // Visual effect view (hudWindow material for dark, frosted look)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = OverlayLayout.cornerRadius
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        window.contentView = visualEffectView

        // Waveform view
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(waveformView)

        // Text label
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.isBezeled = false
        textLabel.isEditable = false
        textLabel.drawsBackground = false
        textLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        textLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 1
        textLabel.alignment = .left
        textLabel.cell?.truncatesLastVisibleLine = true
        visualEffectView.addSubview(textLabel)

        // Refining spinner (hidden by default)
        refiningSpinner.style = .spinning
        refiningSpinner.controlSize = .small
        refiningSpinner.translatesAutoresizingMaskIntoConstraints = false
        refiningSpinner.isHidden = true
        visualEffectView.addSubview(refiningSpinner)

        // Layout
        NSLayoutConstraint.activate([
            // Waveform: left-aligned, vertically centered
            waveformView.leadingAnchor.constraint(
                equalTo: visualEffectView.leadingAnchor,
                constant: OverlayLayout.horizontalPadding
            ),
            waveformView.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: OverlayLayout.waveformWidth),
            waveformView.heightAnchor.constraint(equalToConstant: OverlayLayout.waveformHeight),

            // Text label: right of waveform, vertically centered
            textLabel.leadingAnchor.constraint(
                equalTo: waveformView.trailingAnchor,
                constant: OverlayLayout.interSpacing
            ),
            textLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            textLabel.trailingAnchor.constraint(
                equalTo: visualEffectView.trailingAnchor,
                constant: -OverlayLayout.horizontalPadding
            ),
            textLabel.heightAnchor.constraint(equalToConstant: 24),

            // Refining spinner occupies the waveform slot.
            refiningSpinner.centerXAnchor.constraint(equalTo: waveformView.centerXAnchor),
            refiningSpinner.centerYAnchor.constraint(equalTo: waveformView.centerYAnchor),
        ])
    }

    // MARK: - Sizing

    private func updateWindowSize(textWidth: CGFloat) {
        guard let window = window else { return }

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let windowWidth = ceil(OverlayLayout.windowWidth(textWidth: textWidth))
        let windowHeight = OverlayLayout.capsuleHeight
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.minY + 40  // 40px above bottom edge

        let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        window.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Public API

    func show() {
        guard let window = window else { return }

        // Calculate initial size for empty text
        updateWindowSize(textWidth: OverlayLayout.minimumTextWidth)

        waveformView.isHidden = false
        waveformView.reset()
        waveformView.startAnimation()
        refiningSpinner.isHidden = true
        refiningSpinner.stopAnimation(nil)

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
            displayText = text.isEmpty ? "Refining..." : text
            textLabel.textColor = NSColor.white.withAlphaComponent(0.5)
            waveformView.stopAnimation()
            waveformView.isHidden = true
            refiningSpinner.isHidden = false
            refiningSpinner.startAnimation(nil)
        } else {
            displayText = text.isEmpty ? "正在聆听..." : text
            textLabel.textColor = NSColor.white.withAlphaComponent(0.92)
            waveformView.isHidden = false
            waveformView.startAnimation()
            refiningSpinner.isHidden = true
            refiningSpinner.stopAnimation(nil)
        }
        textLabel.stringValue = displayText

        let textSize = (displayText as NSString).size(withAttributes: [
            .font: textLabel.font as Any
        ])
        let newTextWidth = textSize.width + 8

        guard let window = window else { return }
        let totalWidth = OverlayLayout.windowWidth(textWidth: newTextWidth)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let newFrame = NSRect(
            x: screenFrame.midX - totalWidth / 2,
            y: screenFrame.minY + 40,
            width: totalWidth,
            height: OverlayLayout.capsuleHeight
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
