import SwiftUI

struct StyleView: View {
    @ObservedObject var viewModel: StyleViewModel
    @State private var prompt = ""

    var body: some View {
        HStack(spacing: 0) {
            styleList
                .frame(width: 300)
                .background(AppTheme.ColorToken.sidebarBackground)
            Divider()
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(AppTheme.ColorToken.pageBackground)
        .tint(AppTheme.ColorToken.accent)
        .actionFeedbackOverlay(
            message: viewModel.lastActionMessage,
            error: viewModel.lastError,
            onDismiss: viewModel.clearFeedback
        )
        .onAppear {
            viewModel.load()
            prompt = viewModel.selectedProfile?.prompt ?? ""
        }
    }

    private var styleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("风格", systemImage: "slider.horizontal.3")
                .font(.system(size: 24, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.top, 22)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.profiles, id: \.id) { profile in
                        Button {
                            select(profile)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: profile.iconName)
                                    .foregroundStyle(AppTheme.ColorToken.accent)
                                    .frame(width: 24, height: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    if let subtitle = profile.subtitle {
                                        Text(subtitle)
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                            .background(viewModel.selectedProfile?.id == profile.id ? AppTheme.ColorToken.selectionBackground : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                                    .stroke(
                                        viewModel.selectedProfile?.id == profile.id
                                            ? AppTheme.ColorToken.selectionBorder
                                            : Color.clear,
                                        lineWidth: AppTheme.Border.selectedLineWidth
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 18)
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedProfile?.name ?? "风格")
                        .font(.system(size: 26, weight: .semibold))
                    Text("编辑 Markdown 提示词，并在右侧实时预览。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer()
                Button("确认") {
                    savePrompt()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedProfile == nil)
            }
            HSplitView {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Markdown", systemImage: "text.alignleft")
                        .font(.system(size: 13, weight: .semibold))
                    TextEditor(text: $prompt)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(AppTheme.ColorToken.panelBackground)
                        .overlay(editorBorder)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                        .shadow(color: AppTheme.ColorToken.accent.opacity(0.03), radius: 6, y: 2)
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Label("预览", systemImage: "eye")
                        .font(.system(size: 13, weight: .semibold))
                    ScrollView {
                        MarkdownPromptPreview(markdown: prompt)
                            .padding(14)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.ColorToken.panelBackground)
                    .overlay(editorBorder)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                    .shadow(color: AppTheme.ColorToken.accent.opacity(0.03), radius: 6, y: 2)
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(AppTheme.Spacing.page)
    }

    private var editorBorder: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
            .stroke(AppTheme.ColorToken.panelStroke, lineWidth: AppTheme.Border.panelLineWidth)
    }

    private func select(_ profile: StyleProfileRecord) {
        do {
            try viewModel.selectProfile(id: profile.id)
            prompt = viewModel.selectedProfile?.prompt ?? profile.prompt
        } catch {
            viewModel.report(error: error)
        }
    }

    private func savePrompt() {
        guard let profile = viewModel.selectedProfile else { return }
        do {
            try viewModel.updateProfile(id: profile.id, prompt: prompt)
            prompt = viewModel.selectedProfile?.prompt ?? prompt
        } catch {
            viewModel.report(error: error)
        }
    }
}

private struct MarkdownPromptPreview: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Self.blocks(from: markdown)) { block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownPreviewBlock) -> some View {
        switch block.kind {
        case .heading:
            Text(block.text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, block.index == 0 ? 0 : 4)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                inlineText(block.text)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .paragraph:
            inlineText(block.text)
                .font(.system(size: 13))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inlineText(_ text: String) -> Text {
        var remaining = text[...]
        var output = Text("")
        while let start = remaining.range(of: "**"),
              let end = remaining[start.upperBound...].range(of: "**") {
            let prefix = String(remaining[..<start.lowerBound])
            let emphasized = String(remaining[start.upperBound..<end.lowerBound])
            output = output + Text(prefix) + Text(emphasized).bold()
            remaining = remaining[end.upperBound...]
        }
        return output + Text(String(remaining))
    }

    private static func blocks(from markdown: String) -> [MarkdownPreviewBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownPreviewBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                paragraph.removeAll()
                return
            }
            blocks.append(MarkdownPreviewBlock(index: blocks.count, kind: .paragraph, text: text))
            paragraph.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
            } else if trimmed.hasPrefix("## ") {
                flushParagraph()
                blocks.append(MarkdownPreviewBlock(index: blocks.count, kind: .heading, text: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("– ") {
                flushParagraph()
                blocks.append(MarkdownPreviewBlock(index: blocks.count, kind: .bullet, text: String(trimmed.dropFirst(2))))
            } else {
                paragraph.append(trimmed)
            }
        }
        flushParagraph()
        return blocks
    }
}

private struct MarkdownPreviewBlock: Identifiable {
    enum Kind {
        case heading
        case paragraph
        case bullet
    }

    let index: Int
    let kind: Kind
    let text: String

    var id: Int { index }
}

private extension StyleProfileRecord {
    var iconName: String {
        switch id {
        case "builtin.original": return "text.alignleft"
        case "builtin.formal": return "doc.text"
        case "builtin.casual": return "bubble.left.and.bubble.right"
        case "builtin.energetic": return "sparkles"
        case "builtin.coding": return "chevron.left.forwardslash.chevron.right"
        case "builtin.email": return "envelope"
        default: return "slider.horizontal.3"
        }
    }
}
