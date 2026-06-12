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

    var body: some View {
        if let error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .feedbackStyle(color: .red)
        } else if let message {
            Label(message, systemImage: iconName)
                .feedbackStyle(color: color)
        }
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                    .stroke(color.opacity(0.28))
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}
