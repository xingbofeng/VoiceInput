import SwiftUI

enum ActionFeedbackTone: Equatable {
    case success
    case informational
    case destructive
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
            return "doc.on.doc.fill"
        case .destructive:
            return "trash.circle.fill"
        }
    }

    private var color: Color {
        switch tone {
        case .success:
            return AppTheme.ColorToken.accent
        case .informational:
            return .blue
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
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 360, maxHeight: 96, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.ColorToken.panelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                    .stroke(color.opacity(0.28))
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}
