import AppKit
import Combine
import Foundation

struct HomeDashboardStats: Equatable {
    var totalCharacters = 0
    var todayCharacters = 0
    var averageCPM = 0
    var streakDays = 0
    var dailyGoal = 180000
    var dailyGoalProgress = 0.0
}

struct HomeHistoryItem: Equatable, Identifiable {
    let id: String
    let finalText: String
    let rawText: String
    let appName: String?
    let charCount: Int
    let cpm: Double
    let createdAt: Date
}

struct HomeHistoryGroup: Equatable, Identifiable {
    let id: String
    let title: String
    let date: Date
    let items: [HomeHistoryItem]
}

struct HomeHistoryDetail: Equatable, Identifiable {
    let id: String
    let rawText: String
    let finalText: String
    let language: String
    let asrProviderID: String?
    let llmProviderID: String?
    let styleID: String?
    let appName: String?
    let durationMS: Int
    let charCount: Int
    let cpm: Double
    let warnings: [String]
    let createdAt: Date
    let updatedAt: Date
}

protocol ClipboardWriting: AnyObject {
    func copy(_ text: String)
}

final class GeneralPasteboardWriter: ClipboardWriting {
    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

@MainActor
final class HomeDashboardViewModel: ObservableObject {
    @Published private(set) var stats = HomeDashboardStats()
    @Published private(set) var historyGroups: [HomeHistoryGroup] = []
    @Published private(set) var selectedDetail: HomeHistoryDetail?
    @Published private(set) var isReprocessing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastActionMessage: String?
    @Published private(set) var lastActionTone = ActionFeedbackTone.success
    @Published var searchText = ""

    private enum SettingsKey {
        static let dailyCharacterGoal = "home.dailyCharacterGoal"
    }

    private let environment: AppEnvironment
    private let clipboardWriter: ClipboardWriting
    private let textPipeline: (any TextProcessing)?
    private let calendar: Calendar
    private let historyLimit: Int

    init(
        environment: AppEnvironment,
        clipboardWriter: ClipboardWriting = GeneralPasteboardWriter(),
        textPipeline: (any TextProcessing)? = nil,
        calendar: Calendar = .current,
        historyLimit: Int = 1_000
    ) {
        self.environment = environment
        self.clipboardWriter = clipboardWriter
        self.textPipeline = textPipeline
        self.calendar = calendar
        self.historyLimit = historyLimit
    }

    func load() {
        do {
            let entries = try environment.historyRepository.listRecent(limit: historyLimit)
            stats = makeStats(from: entries)
            historyGroups = try makeHistoryGroups(query: searchText)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateSearch(_ query: String) {
        searchText = query
        do {
            historyGroups = try makeHistoryGroups(query: query)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func copyHistoryItem(id: String) {
        guard let item = historyGroups.flatMap(\.items).first(where: { $0.id == id }) else {
            return
        }
        clipboardWriter.copy(item.finalText)
        lastError = nil
        lastActionMessage = "已复制历史文本"
        lastActionTone = .informational
    }

    func deleteHistoryItem(id: String) {
        do {
            try environment.historyRepository.softDelete(id: id, deletedAt: environment.clock.now)
            load()
            lastError = nil
            lastActionMessage = "已删除历史记录"
            lastActionTone = .destructive
        } catch {
            lastError = error.localizedDescription
        }
    }

    func selectHistoryItem(id: String) {
        do {
            guard let entry = try environment.historyRepository.entry(id: id), entry.deletedAt == nil else {
                selectedDetail = nil
                lastError = "未找到历史记录。"
                return
            }
            selectedDetail = HomeHistoryDetail(entry: entry)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearSelectedDetail() {
        selectedDetail = nil
    }

    func clearFeedback() {
        lastError = nil
        lastActionMessage = nil
    }

    func reprocessSelectedHistoryItem() async {
        guard let id = selectedDetail?.id else {
            return
        }
        guard let textPipeline else {
            lastError = "文本处理管线不可用。"
            return
        }

        isReprocessing = true
        defer { isReprocessing = false }

        do {
            guard let entry = try environment.historyRepository.entry(id: id), entry.deletedAt == nil else {
                selectedDetail = nil
                lastError = "未找到历史记录。"
                return
            }

            let result = await textPipeline.process(entry.rawText)
            let finalText = normalizedFinalText(from: result, fallback: entry.rawText)
            let updatedEntry = updatedHistoryEntry(from: entry, finalText: finalText, processingResult: result)
            try environment.historyRepository.save(updatedEntry)
            load()
            selectedDetail = HomeHistoryDetail(entry: updatedEntry)
            lastError = nil
            lastActionMessage = "已重新处理历史记录"
            lastActionTone = .success
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func makeStats(from entries: [DictationHistoryEntry]) -> HomeDashboardStats {
        let validEntries = entries.filter { $0.durationMS >= 300 && $0.charCount > 0 }
        let totalCharacters = validEntries.reduce(0) { $0 + $1.charCount }
        let today = calendar.startOfDay(for: environment.clock.now)
        let todayCharacters = entries
            .filter { calendar.isDate($0.createdAt, inSameDayAs: today) }
            .reduce(0) { $0 + $1.charCount }
        let totalDurationMS = validEntries.reduce(0) { $0 + max(0, $1.durationMS) }
        let totalMinutes = max(Double(totalDurationMS) / 60_000.0, 1.0 / 60_000.0)
        let averageCPM = validEntries.isEmpty ? 0 : Int((Double(totalCharacters) / totalMinutes).rounded())
        let dailyGoal = readDailyGoal()

        return HomeDashboardStats(
            totalCharacters: totalCharacters,
            todayCharacters: todayCharacters,
            averageCPM: averageCPM,
            streakDays: streakDays(from: entries),
            dailyGoal: dailyGoal,
            dailyGoalProgress: min(1.0, Double(todayCharacters) / Double(max(1, dailyGoal)))
        )
    }

    private func readDailyGoal() -> Int {
        guard let text = try? environment.settingsRepository.value(forKey: SettingsKey.dailyCharacterGoal),
              let data = text.data(using: .utf8),
              let value = try? JSONDecoder().decode(Int.self, from: data),
              value > 0 else {
            return 1000
        }
        return value
    }

    private func streakDays(from entries: [DictationHistoryEntry]) -> Int {
        let activeDays = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        var cursor = calendar.startOfDay(for: environment.clock.now)
        var streak = 0

        while activeDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    private func makeHistoryGroups(query: String) throws -> [HomeHistoryGroup] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let entries: [DictationHistoryEntry]
        if trimmedQuery.isEmpty {
            entries = try environment.historyRepository.listRecent(limit: historyLimit)
        } else {
            entries = try environment.historyRepository.search(trimmedQuery, limit: historyLimit)
        }

        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }

        return grouped.keys.sorted(by: >).map { day in
            let items = (grouped[day] ?? [])
                .sorted { $0.createdAt > $1.createdAt }
                .map(HomeHistoryItem.init(entry:))
            return HomeHistoryGroup(
                id: ISO8601DateFormatter().string(from: day),
                title: title(for: day),
                date: day,
                items: items
            )
        }
    }

    private func title(for day: Date) -> String {
        let today = calendar.startOfDay(for: environment.clock.now)
        if calendar.isDate(day, inSameDayAs: today) {
            return "今天"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "昨天"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: day)
    }

    private func normalizedFinalText(from result: TextProcessingResult, fallback: String) -> String {
        let trimmed = result.finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func updatedHistoryEntry(
        from entry: DictationHistoryEntry,
        finalText: String,
        processingResult: TextProcessingResult
    ) -> DictationHistoryEntry {
        let charCount = finalText.count
        let durationMinutes = max(Double(entry.durationMS) / 60_000.0, 1.0 / 60_000.0)
        let now = environment.clock.now

        return DictationHistoryEntry(
            id: entry.id,
            rawText: entry.rawText,
            finalText: finalText,
            language: entry.language,
            asrProviderID: entry.asrProviderID,
            llmProviderID: processingResult.llmProviderID,
            styleID: processingResult.styleID,
            durationMS: entry.durationMS,
            charCount: charCount,
            cpm: Double(charCount) / durationMinutes,
            targetAppBundleID: entry.targetAppBundleID,
            targetAppName: entry.targetAppName,
            processingWarningsJSON: warningsJSON(processingResult.warnings),
            createdAt: entry.createdAt,
            updatedAt: now,
            deletedAt: entry.deletedAt
        )
    }

    private func warningsJSON(_ warnings: [String]) -> String? {
        guard !warnings.isEmpty,
              let data = try? JSONEncoder().encode(warnings) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

private extension HomeHistoryItem {
    init(entry: DictationHistoryEntry) {
        self.init(
            id: entry.id,
            finalText: entry.finalText,
            rawText: entry.rawText,
            appName: entry.targetAppName,
            charCount: entry.charCount,
            cpm: entry.cpm,
            createdAt: entry.createdAt
        )
    }
}

private extension HomeHistoryDetail {
    init(entry: DictationHistoryEntry) {
        self.init(
            id: entry.id,
            rawText: entry.rawText,
            finalText: entry.finalText,
            language: entry.language,
            asrProviderID: entry.asrProviderID,
            llmProviderID: entry.llmProviderID,
            styleID: entry.styleID,
            appName: entry.targetAppName,
            durationMS: entry.durationMS,
            charCount: entry.charCount,
            cpm: entry.cpm,
            warnings: Self.decodeWarnings(entry.processingWarningsJSON),
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    private static func decodeWarnings(_ json: String?) -> [String] {
        guard let data = json?.data(using: .utf8),
              let warnings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return warnings
    }
}
