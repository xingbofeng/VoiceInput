import AppKit

enum OverlayLayout {
    static let horizontalPadding: CGFloat = 16
    static let waveformWidth: CGFloat = 44
    static let waveformHeight: CGFloat = 32
    static let interSpacing: CGFloat = 12
    static let minimumTextWidth: CGFloat = 160
    static let maximumTextWidth: CGFloat = 560
    static let capsuleHeight: CGFloat = 56
    static let cornerRadius: CGFloat = 28

    static func clampedTextWidth(_ width: CGFloat) -> CGFloat {
        max(minimumTextWidth, min(maximumTextWidth, width))
    }

    static func windowWidth(textWidth: CGFloat) -> CGFloat {
        horizontalPadding
            + waveformWidth
            + interSpacing
            + clampedTextWidth(textWidth)
            + horizontalPadding
    }
}
