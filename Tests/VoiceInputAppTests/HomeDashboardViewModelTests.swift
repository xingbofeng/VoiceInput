import XCTest
@testable import VoiceInputApp

@MainActor
final class HomeDashboardViewModelTests: XCTestCase {
    func testLoadComputesStatisticsGoalAndGroupedHistory() throws {
        let now = makeDate(year: 2026, month: 6, day: 9, hour: 12)
        let clock = MutableHomeClock(now: now)
        let container = try DependencyContainer.inMemory(clock: clock)
        let environment = AppEnvironment(container: container)
        try environment.settingsRepository.set("home.dailyCharacterGoal", jsonValue: "100")
        try environment.historyRepository.save(
            historyEntry(
                id: "today",
                finalText: "今天输入文本",
                charCount: 50,
                durationMS: 30_000,
                createdAt: makeDate(year: 2026, month: 6, day: 9, hour: 9)
            )
        )
        try environment.historyRepository.save(
            historyEntry(
                id: "yesterday",
                finalText: "昨天输入",
                charCount: 30,
                durationMS: 30_000,
                createdAt: makeDate(year: 2026, month: 6, day: 8, hour: 9)
            )
        )

        let viewModel = HomeDashboardViewModel(environment: environment, calendar: testCalendar)
        viewModel.load()

        XCTAssertEqual(viewModel.stats.totalCharacters, 80)
        XCTAssertEqual(viewModel.stats.todayCharacters, 50)
        XCTAssertEqual(viewModel.stats.averageCPM, 80)
        XCTAssertEqual(viewModel.stats.streakDays, 2)
        XCTAssertEqual(viewModel.stats.dailyGoal, 100)
        XCTAssertEqual(viewModel.stats.dailyGoalProgress, 0.5)
        XCTAssertEqual(viewModel.historyGroups.map(\.title), ["今天", "昨天"])
        XCTAssertEqual(viewModel.historyGroups.first?.items.map(\.id), ["today"])
    }

    func testSearchFiltersHistoryThroughRepository() throws {
        let container = try DependencyContainer.inMemory()
        let environment = AppEnvironment(container: container)
        try environment.historyRepository.save(historyEntry(id: "match", finalText: "搜索目标"))
        try environment.historyRepository.save(historyEntry(id: "miss", finalText: "其他文本"))

        let viewModel = HomeDashboardViewModel(environment: environment, calendar: testCalendar)
        viewModel.updateSearch("目标")

        XCTAssertEqual(viewModel.historyGroups.flatMap(\.items).map(\.id), ["match"])
    }

    func testCopyWritesFinalTextToClipboardWriter() throws {
        let container = try DependencyContainer.inMemory()
        let environment = AppEnvironment(container: container)
        try environment.historyRepository.save(historyEntry(id: "entry", finalText: "可复制文本"))
        let clipboard = CapturingClipboardWriter()
        let viewModel = HomeDashboardViewModel(
            environment: environment,
            clipboardWriter: clipboard,
            calendar: testCalendar
        )
        viewModel.load()

        viewModel.copyHistoryItem(id: "entry")

        XCTAssertEqual(clipboard.copiedTexts, ["可复制文本"])
        XCTAssertEqual(viewModel.lastActionMessage, "已复制历史文本")
        XCTAssertEqual(viewModel.lastActionTone, .informational)
    }

    func testDeleteSoftDeletesAndReloadsHistory() throws {
        let container = try DependencyContainer.inMemory()
        let environment = AppEnvironment(container: container)
        try environment.historyRepository.save(historyEntry(id: "entry", finalText: "删除文本"))
        let viewModel = HomeDashboardViewModel(environment: environment, calendar: testCalendar)
        viewModel.load()

        viewModel.deleteHistoryItem(id: "entry")

        XCTAssertEqual(viewModel.historyGroups, [])
        XCTAssertNotNil(try environment.historyRepository.entry(id: "entry")?.deletedAt)
        XCTAssertEqual(viewModel.lastActionMessage, "已删除历史记录")
        XCTAssertEqual(viewModel.lastActionTone, .destructive)
    }

    func testSelectHistoryItemLoadsDetail() throws {
        let container = try DependencyContainer.inMemory()
        let environment = AppEnvironment(container: container)
        try environment.historyRepository.save(
            historyEntry(
                id: "entry",
                rawText: "原始文本",
                finalText: "最终文本",
                processingWarningsJSON: #"["llm_refinement_failed"]"#
            )
        )
        let viewModel = HomeDashboardViewModel(environment: environment, calendar: testCalendar)

        viewModel.selectHistoryItem(id: "entry")

        XCTAssertEqual(viewModel.selectedDetail?.id, "entry")
        XCTAssertEqual(viewModel.selectedDetail?.rawText, "原始文本")
        XCTAssertEqual(viewModel.selectedDetail?.finalText, "最终文本")
        XCTAssertEqual(viewModel.selectedDetail?.warnings, ["llm_refinement_failed"])
        XCTAssertNil(viewModel.lastError)
    }

    func testReprocessSelectedHistoryItemUsesRawTextAndUpdatesHistory() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_100)
        let clock = MutableHomeClock(now: now)
        let container = try DependencyContainer.inMemory(clock: clock)
        let environment = AppEnvironment(container: container)
        try environment.historyRepository.save(
            historyEntry(
                id: "entry",
                rawText: "原始文本",
                finalText: "旧文本",
                durationMS: 30_000
            )
        )
        let pipeline = CapturingHomeTextPipeline(
            result: TextProcessingResult(
                rawText: "原始文本",
                finalText: "新文本",
                llmProviderID: "llm-provider",
                styleID: "style-formal",
                warnings: ["replacement_rule_invalid_regex:rule"]
            )
        )
        let viewModel = HomeDashboardViewModel(
            environment: environment,
            clipboardWriter: CapturingClipboardWriter(),
            textPipeline: pipeline,
            calendar: testCalendar
        )
        viewModel.load()
        viewModel.selectHistoryItem(id: "entry")

        await viewModel.reprocessSelectedHistoryItem()

        let saved = try XCTUnwrap(environment.historyRepository.entry(id: "entry"))
        XCTAssertEqual(pipeline.receivedTexts, ["原始文本"])
        XCTAssertEqual(saved.rawText, "原始文本")
        XCTAssertEqual(saved.finalText, "新文本")
        XCTAssertEqual(saved.llmProviderID, "llm-provider")
        XCTAssertEqual(saved.styleID, "style-formal")
        XCTAssertEqual(saved.charCount, 3)
        XCTAssertEqual(saved.cpm, 6)
        XCTAssertEqual(saved.updatedAt, now)
        XCTAssertEqual(viewModel.selectedDetail?.finalText, "新文本")
        XCTAssertEqual(viewModel.historyGroups.flatMap(\.items).first?.finalText, "新文本")
        XCTAssertEqual(saved.processingWarningsJSON, #"["replacement_rule_invalid_regex:rule"]"#)
    }

    private func historyEntry(
        id: String,
        rawText: String = "raw",
        finalText: String = "final",
        charCount: Int? = nil,
        durationMS: Int = 1000,
        createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
        processingWarningsJSON: String? = nil
    ) -> DictationHistoryEntry {
        DictationHistoryEntry(
            id: id,
            rawText: rawText,
            finalText: finalText,
            language: "zh-CN",
            asrProviderID: "apple_speech",
            llmProviderID: nil,
            styleID: nil,
            durationMS: durationMS,
            charCount: charCount ?? finalText.count,
            cpm: 120,
            targetAppBundleID: nil,
            targetAppName: "Editor",
            processingWarningsJSON: processingWarningsJSON,
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: nil
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = testCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return testCalendar.date(from: components)!
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

private final class CapturingClipboardWriter: ClipboardWriting {
    private(set) var copiedTexts: [String] = []

    func copy(_ text: String) {
        copiedTexts.append(text)
    }
}

private final class CapturingHomeTextPipeline: TextProcessing {
    private(set) var receivedTexts: [String] = []
    let result: TextProcessingResult

    init(result: TextProcessingResult) {
        self.result = result
    }

    func process(_ rawText: String) async -> TextProcessingResult {
        receivedTexts.append(rawText)
        return result
    }
}

private final class MutableHomeClock: AppClock, @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func sleep(nanoseconds: UInt64) async throws {}
}
