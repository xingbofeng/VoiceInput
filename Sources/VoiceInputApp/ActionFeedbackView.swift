import SwiftUI

enum ActionFeedbackTone: Equatable {
    case success
    case informational
    case destructive
}

enum ActionFeedbackLayout {
    static let maxWidth: CGFloat = 340
    static let topPadding: CGFloat = 18
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 10
    static let shadowRadius: CGFloat = 10
    static let shadowYOffset: CGFloat = 4
}

struct ActionFeedbackView: View {
    let message: String?
    let error: String?
    var tone: ActionFeedbackTone = .success
    var autoDismissAfter: TimeInterval? = 2.6
    var onDismiss: (() -> Void)?

    @State private var isVisible = false

    var body: some View {
        Group {
            if isVisible, let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .feedbackStyle(color: .red)
            } else if isVisible, let message {
                Label(message, systemImage: iconName)
                    .feedbackStyle(color: color)
            }
        }
        .task(id: feedbackKey) {
            guard let activeKey = feedbackKey else {
                isVisible = false
                return
            }
            isVisible = true
            guard let autoDismissAfter else { return }
            try? await Task.sleep(nanoseconds: UInt64(autoDismissAfter * 1_000_000_000))
            if feedbackKey == activeKey {
                isVisible = false
                onDismiss?()
            }
        }
    }

    private var feedbackKey: String? {
        error ?? message
    }

    private var iconName: String {
        switch tone {
        case .success:
            return "checkmark.circle.fill"
        case .informational:
            return "checkmark.circle.fill"
        case .destructive:
            return "trash.circle.fill"
        }
    }

    private var color: Color {
        switch tone {
        case .success:
            return AppTheme.ColorToken.accent
        case .informational:
            return AppTheme.ColorToken.accent
        case .destructive:
            return .red
        }
    }
}

private extension View {
    func feedbackStyle(color: Color) -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: ActionFeedbackLayout.maxWidth, alignment: .leading)
            .padding(.horizontal, ActionFeedbackLayout.horizontalPadding)
            .padding(.vertical, ActionFeedbackLayout.verticalPadding)
            .background(AppTheme.ColorToken.panelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: ActionFeedbackLayout.cornerRadius, style: .continuous)
                    .stroke(color.opacity(0.28))
            )
            .clipShape(RoundedRectangle(cornerRadius: ActionFeedbackLayout.cornerRadius, style: .continuous))
            .shadow(
                color: .black.opacity(0.08),
                radius: ActionFeedbackLayout.shadowRadius,
                y: ActionFeedbackLayout.shadowYOffset
            )
    }
}

extension View {
    func actionFeedbackOverlay(
        message: String?,
        error: String?,
        tone: ActionFeedbackTone = .success,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        overlay(alignment: .top) {
            ActionFeedbackView(
                message: message,
                error: error,
                tone: tone,
                onDismiss: onDismiss
            )
            .padding(.top, ActionFeedbackLayout.topPadding)
            .frame(maxWidth: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }
}
