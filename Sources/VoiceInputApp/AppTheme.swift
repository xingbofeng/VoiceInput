import SwiftUI

enum AppTheme {
    enum Radius {
        static let card: CGFloat = 8
        static let control: CGFloat = 6
    }

    enum Spacing {
        static let page: CGFloat = 28
        static let section: CGFloat = 18
        static let grid: CGFloat = 12
        static let card: CGFloat = 16
    }

    enum FontToken {
        static let heading = Font.system(size: 24, weight: .semibold)
        static let body = Font.system(size: 14)
        static let caption = Font.system(size: 12)
        static let title = Font.system(size: 18, weight: .semibold)
    }

    enum ColorToken {
        static let pageBackground = Color(nsColor: .windowBackgroundColor)
        static let panelBackground = Color(nsColor: .controlBackgroundColor)
        static let panelStroke = Color(nsColor: .separatorColor).opacity(0.45)
        static let primaryText = Color(nsColor: .labelColor)
        static let secondaryText = Color(nsColor: .secondaryLabelColor)
        static let accent = Color(red: 0.08, green: 0.44, blue: 0.36)
        static let progressTrack = Color(nsColor: .separatorColor).opacity(0.35)
        static var accentDark: Color { Color(red: 0.16, green: 0.56, blue: 0.48) }
        static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
        static let sidebarText = Color(nsColor: .labelColor).opacity(0.82)
        static let selectionBackground = accent.opacity(0.14)
        static let selectionBorder = accent.opacity(0.32)
    }
}
