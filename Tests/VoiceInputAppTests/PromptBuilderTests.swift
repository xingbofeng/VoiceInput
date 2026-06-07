import XCTest
@testable import VoiceInputApp

final class PromptBuilderTests: XCTestCase {
    func testBuildIncludesStylePromptAndEnabledGlossaryTerms() throws {
        let style = try XCTUnwrap(BuiltInStyleCatalog.profile(id: "builtin.coding"))
        let prompt = PromptBuilder().build(
            style: style,
            glossaryTerms: [
                glossaryTerm(term: "Python", aliases: ["配森", "派森"], enabled: true, priority: 1),
                glossaryTerm(term: "Go", aliases: ["够"], enabled: false, priority: 2),
            ]
        )

        XCTAssertEqual(prompt.styleID, "builtin.coding")
        XCTAssertNil(prompt.model)
        XCTAssertNil(prompt.temperature)
        XCTAssertNil(prompt.llmProviderID)
        XCTAssertTrue(prompt.systemPrompt.contains(style.prompt))
        XCTAssertTrue(prompt.systemPrompt.contains("Python"))
        XCTAssertTrue(prompt.systemPrompt.contains("配森"))
        XCTAssertFalse(prompt.systemPrompt.contains("Go"))
    }

    func testBuiltInPromptsContainCompleteOutputConstraints() throws {
        for style in BuiltInStyleCatalog.profiles(now: Date()) {
            XCTAssertGreaterThan(style.prompt.count, 100, style.id)
            XCTAssertTrue(style.prompt.contains("输出"), style.id)
            XCTAssertTrue(style.prompt.contains("不要"), style.id)
        }
    }

    private func glossaryTerm(
        term: String,
        aliases: [String],
        enabled: Bool,
        priority: Int
    ) -> GlossaryTerm {
        GlossaryTerm(
            id: UUID().uuidString,
            term: term,
            aliases: aliases,
            category: "coding",
            enabled: enabled,
            priority: priority,
            notes: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
