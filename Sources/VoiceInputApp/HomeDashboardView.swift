import SwiftUI

struct HomeDashboardView: View {
    @ObservedObject var viewModel: HomeDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                HStack {
                    Label("首页", systemImage: "house.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                    Spacer()
                }

                HomeStatsGrid(stats: viewModel.stats, focusedCharactersTitle: viewModel.focusedCharactersTitle)
                GoalProgressCard(stats: viewModel.stats, title: viewModel.goalTitle)
                HomeActivityCard(
                    activity: viewModel.activity,
                    selectedDate: viewModel.selectedActivityDate,
                    selectAction: viewModel.selectActivityDay,
                    clearAction: viewModel.clearActivityDaySelection
                )
                HomeHistorySection(viewModel: viewModel)
            }
            .padding(AppTheme.Spacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.ColorToken.pageBackground)
        .tint(AppTheme.ColorToken.accent)
        .actionFeedbackOverlay(
            message: viewModel.lastActionMessage,
            error: viewModel.lastError,
            tone: viewModel.lastActionTone,
            onDismiss: viewModel.clearFeedback
        )
        .onAppear {
            viewModel.load()
        }
        .sheet(
            item: Binding(
                get: { viewModel.selectedDetail },
                set: { newValue in
                    if newValue == nil {
                        viewModel.clearSelectedDetail()
                    }
                }
            )
        ) { detail in
            HomeHistoryDetailModal(viewModel: viewModel, detail: detail)
        }
    }
}

private struct HomeActivityCard: View {
    let activity: HomeActivitySummary
    let selectedDate: Date?
    let selectAction: (Date) -> Void
    let clearAction: () -> Void

    private let maxSquareSize: CGFloat = 14
    private let minSquareSize: CGFloat = 8
    private let squareGap: CGFloat = 3
    private let weekdayLabelWidth: CGFloat = 18
    private let gridHeight: CGFloat = 116

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.grid) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("输入活跃度", systemImage: "square.grid.3x3.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("过去 52 周 · 每格代表一天")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(summaryText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    if selectedDate != nil {
                        Button("清除") {
                            clearAction()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.ColorToken.accent)
                    }
                }
            }

            GeometryReader { proxy in
                let columns = max(weeks.count, 1)
                let availableGridWidth = max(0, proxy.size.width - weekdayLabelWidth - 8)
                let squareSize = min(
                    maxSquareSize,
                    max(minSquareSize, (availableGridWidth - CGFloat(columns - 1) * squareGap) / CGFloat(columns))
                )

                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            clearAction()
                        }

                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: squareGap) {
                            ForEach(0..<7, id: \.self) { row in
                                Text(weekdayLabel(for: row))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.ColorToken.secondaryText.opacity(0.85))
                                    .frame(width: weekdayLabelWidth, height: squareSize, alignment: .trailing)
                            }
                        }

                        HStack(alignment: .top, spacing: squareGap) {
                            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                                VStack(spacing: squareGap) {
                                    ForEach(week) { day in
                                        Button {
                                            selectAction(day.date)
                                        } label: {
                                            RoundedRectangle(cornerRadius: min(4, squareSize * 0.28), style: .continuous)
                                                .fill(color(for: day.level))
                                                .frame(width: squareSize, height: squareSize)
                                                .overlay {
                                                    if isSelected(day) {
                                                        RoundedRectangle(cornerRadius: min(4, squareSize * 0.28), style: .continuous)
                                                            .stroke(AppTheme.ColorToken.accent, lineWidth: 2)
                                                    }
                                                }
                                        }
                                        .buttonStyle(.plain)
                                        .help("\(Self.dateFormatter.string(from: day.date)) · \(day.characters) 字")
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: gridHeight)

            HStack(spacing: 5) {
                Spacer()
                Text("少")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color(for: level))
                        .frame(width: 10, height: 10)
                }
                Text("多")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
        }
        .padding(AppTheme.Spacing.card)
        .appPanel()
    }

    private var summaryText: String {
        guard let selectedDate,
              let selectedDay = activity.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) else {
            return "本周 \(activity.thisWeekCharacters) 字"
        }
        return "\(Self.dateFormatter.string(from: selectedDate)) \(selectedDay.characters) 字"
    }

    private var weeks: [[HomeActivityDay]] {
        stride(from: 0, to: activity.days.count, by: 7).map { startIndex in
            Array(activity.days[startIndex..<min(startIndex + 7, activity.days.count)])
        }
    }

    private func isSelected(_ day: HomeActivityDay) -> Bool {
        guard let selectedDate else {
            return false
        }
        return Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
    }

    private func weekdayLabel(for row: Int) -> String {
        switch row {
        case 0:
            return "一"
        case 1:
            return "二"
        case 2:
            return "三"
        case 3:
            return "四"
        case 4:
            return "五"
        case 5:
            return "六"
        case 6:
            return "日"
        default:
            return ""
        }
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 1:
            return Color(red: 0.718, green: 0.847, blue: 0.812)
        case 2:
            return Color(red: 0.408, green: 0.718, blue: 0.639)
        case 3:
            return AppTheme.ColorToken.accentDark
        case 4:
            return AppTheme.ColorToken.accent
        default:
            return Color(red: 0.910, green: 0.938, blue: 0.925)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}

private struct HomeStatsGrid: View {
    let stats: HomeDashboardStats
    let focusedCharactersTitle: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: AppTheme.Spacing.grid)], spacing: AppTheme.Spacing.grid) {
            HomeStatCard(title: "累计字符", value: "\(stats.totalCharacters)", systemImage: "textformat.size")
            HomeStatCard(title: focusedCharactersTitle, value: "\(stats.todayCharacters)", systemImage: "calendar")
            HomeStatCard(title: "平均字/分钟", value: "\(stats.averageCPM)", systemImage: "speedometer")
            HomeStatCard(title: "连续使用", value: "\(stats.streakDays) 天", systemImage: "flame")
        }
    }
}

private struct HomeStatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.ColorToken.accent)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                Spacer()
            }
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(AppTheme.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel()
    }
}

private struct GoalProgressCard: View {
    let stats: HomeDashboardStats
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "target")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(stats.todayCharacters) / \(stats.dailyGoal)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.ColorToken.progressTrack)
                    Capsule()
                        .fill(AppTheme.ColorToken.accent)
                        .frame(width: max(6, proxy.size.width * stats.dailyGoalProgress))
                }
            }
            .frame(height: 8)
        }
        .padding(AppTheme.Spacing.card)
        .appPanel()
    }
}

private struct HomeHistorySection: View {
    @ObservedObject var viewModel: HomeDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("历史", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                TextField(
                    "搜索历史",
                    text: Binding(
                        get: { viewModel.searchText },
                        set: { viewModel.updateSearch($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            }

            if viewModel.historyGroups.isEmpty {
                Text("暂无记录")
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .appPanel()
            } else {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.grid) {
                    ForEach(viewModel.historyGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            ForEach(group.items) { item in
                                HomeHistoryRow(
                                    item: item,
                                    isSelected: viewModel.selectedDetail?.id == item.id,
                                    selectAction: { viewModel.selectHistoryItem(id: item.id) },
                                    copyAction: { viewModel.copyHistoryItem(id: item.id) },
                                    deleteAction: { viewModel.deleteHistoryItem(id: item.id) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HomeHistoryRow: View {
    let item: HomeHistoryItem
    let isSelected: Bool
    let selectAction: () -> Void
    let copyAction: () -> Void
    let deleteAction: () -> Void
    @State private var textVariant: HomeHistoryTextVariant = .final

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: selectAction) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text(for: textVariant))
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .lineLimit(2)
                        .truncationMode(.head)
                    HStack(spacing: 8) {
                        if let appName = item.appName {
                            Text(appName)
                        }
                        Text("\(item.charCount) 字")
                        Text("\(Int(item.cpm.rounded())) 字/分钟")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                textVariant = textVariant == .final ? .raw : .final
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!item.hasTextVariants)
            .help(textVariant == .final ? "显示转换前" : "显示转换后")
            Button(action: copyAction) {
                Image(systemName: "doc.on.doc")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("复制")
            Button(action: deleteAction) {
                Image(systemName: "trash")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("删除")
        }
        .padding(12)
        .background(isSelected ? AppTheme.ColorToken.selectionBackground : AppTheme.ColorToken.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .stroke(
                    isSelected ? AppTheme.ColorToken.selectionBorder : AppTheme.ColorToken.panelStroke,
                    lineWidth: AppTheme.Border.panelLineWidth
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(
            color: AppTheme.ColorToken.accent.opacity(isSelected ? 0.05 : 0.025),
            radius: isSelected ? 8 : 4,
            y: 2
        )
    }
}

private struct HomeHistoryDetailModal: View {
    @ObservedObject var viewModel: HomeDashboardViewModel
    let detail: HomeHistoryDetail

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                textComparison
                traceSection
                metadataSection
                warningsSection
            }
            .padding(24)
        }
        .frame(width: 980, height: 720)
        .background(AppTheme.ColorToken.pageBackground)
        .tint(AppTheme.ColorToken.accent)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 46, height: 46)
                .background(AppTheme.ColorToken.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.icon, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("转写详情")
                    .font(.system(size: 24, weight: .semibold))
                Text(traceSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            Spacer()
            Button {
                Task {
                    await viewModel.reprocessSelectedHistoryItem()
                }
            } label: {
                Label(viewModel.isReprocessing ? "处理中" : "重新处理", systemImage: viewModel.isReprocessing ? "hourglass" : "arrow.triangle.2.circlepath")
                    .frame(height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isReprocessing)
            Button {
                viewModel.clearSelectedDetail()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .appControlSurface(cornerRadius: 8)
        }
    }

    private var textComparison: some View {
        HStack(alignment: .top, spacing: 12) {
            DetailTextBlock(title: "处理后", subtitle: "最终注入到当前应用的文本", text: detail.finalText, highlighted: true)
            DetailTextBlock(title: "原文", subtitle: "ASR 识别返回的原始文本", text: detail.rawText, highlighted: false)
        }
    }

    @ViewBuilder
    private var traceSection: some View {
        if let llmTrace = detail.trace?.llm {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("模型纠错追踪", systemImage: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(llmTrace.succeeded ? "已调用" : "调用失败")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(llmTrace.succeeded ? AppTheme.ColorToken.accent : Color.orange)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background((llmTrace.succeeded ? AppTheme.ColorToken.accent : Color.orange).opacity(0.10))
                        .clipShape(Capsule())
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    DetailMetaItem(title: "Provider", value: llmTrace.providerName)
                    DetailMetaItem(title: "模型", value: llmTrace.model)
                    DetailMetaItem(title: "耗时", value: llmTrace.durationMS.map { "\($0) ms" } ?? "-")
                    DetailMetaItem(title: "状态", value: llmTrace.statusCode.map(String.init) ?? "-")
                    DetailMetaItem(title: "温度", value: String(format: "%.2f", llmTrace.temperature))
                    DetailMetaItem(title: "接口", value: llmTrace.endpoint)
                }
                HStack(alignment: .top, spacing: 12) {
                    TraceCodeBlock(title: "请求体", text: llmTrace.requestBodyJSON)
                    TraceCodeBlock(title: llmTrace.errorMessage == nil ? "模型响应" : "错误", text: llmTrace.errorMessage ?? llmTrace.responseText ?? "-")
                }
            }
            .padding(16)
            .appPanel(cornerRadius: 14)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("模型纠错追踪", systemImage: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text("这条历史没有保存到 LLM 请求体。通常表示当时没有启用或配置 LLM，或这是旧记录。重新处理后会生成可追溯记录。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .padding(16)
            .appPanel(cornerRadius: 14)
        }
    }

    private var metadataSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: AppTheme.Spacing.grid)], spacing: 10) {
            DetailMetaItem(title: "语言", value: detail.language)
            DetailMetaItem(title: "应用", value: detail.appName ?? "-")
            DetailMetaItem(title: "ASR", value: detail.asrProviderID ?? "-")
            DetailMetaItem(title: "LLM", value: detail.llmProviderID ?? "-")
            DetailMetaItem(title: "风格", value: detail.styleID ?? "-")
            DetailMetaItem(title: "字符", value: "\(detail.charCount)")
            DetailMetaItem(title: "速度", value: "\(Int(detail.cpm.rounded())) 字/分钟")
            DetailMetaItem(title: "创建", value: Self.format(detail.createdAt))
            DetailMetaItem(title: "更新", value: Self.format(detail.updatedAt))
        }
        .padding(16)
        .appPanel(cornerRadius: 14)
    }

    @ViewBuilder
    private var warningsSection: some View {
        if !detail.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("处理提示", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .semibold))
                ForEach(detail.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
            }
            .padding(16)
            .appPanel(cornerRadius: 14)
        }
    }

    private var traceSubtitle: String {
        if detail.trace?.llm != nil {
            return "包含原文、处理结果、元数据和本次 LLM 请求体"
        }
        return "包含原文、处理结果和元数据；旧记录可重新处理生成请求追踪"
    }

    private static func format(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}

private struct DetailTextBlock: View {
    let title: String
    let subtitle: String
    let text: String
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(highlighted ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlighted ? AppTheme.ColorToken.accentSoft.opacity(0.5) : AppTheme.ColorToken.controlBackground.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .stroke(highlighted ? AppTheme.ColorToken.selectionBorder : AppTheme.ColorToken.subtleStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

private struct TraceCodeBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            ScrollView {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .frame(minHeight: 160, maxHeight: 220)
            .background(AppTheme.ColorToken.controlBackground.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DetailMetaItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
