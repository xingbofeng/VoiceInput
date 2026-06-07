import Foundation

struct TextRefinementRequest: Equatable {
    let text: String
    let systemPrompt: String
    let model: String?
    let temperature: Double?
}

struct PromptBuildResult: Equatable {
    let systemPrompt: String
    let llmProviderID: String?
    let styleID: String?
    let model: String?
    let temperature: Double?
}

struct PromptBuilder {
    static let conservativeSystemPrompt = """
        You are a conservative speech recognition error corrector. Your ONLY job is to fix \
        OBVIOUS speech recognition errors. Follow these rules strictly:

        1. ONLY correct clear speech-to-text mistakes, especially:
           - Chinese homophone errors (e.g., 「配森」→「Python」, 「杰森」→「JSON」, 「扣顶」→「coding」)
           - English technical terms incorrectly transcribed as Chinese characters
           - Chinese characters that are obviously the wrong character due to homophones
        2. Do NOT rewrite, polish, rephrase, or improve the text in any way unless a selected style explicitly asks for light formatting.
        3. Do NOT add facts, answer questions, summarize, or invent content.
        4. Do NOT add, remove, or alter punctuation unless it's clearly wrong.
        5. If the input text appears correct or you're unsure, return it EXACTLY as-is.
        6. Preserve ALL original formatting, spacing, and line breaks unless the selected style requires minimal formatting.
        7. Output ONLY the corrected text — no explanations, no notes, no quotation marks.

        The user spoke in Chinese and/or English. The speech recognizer may have made mistakes \
        converting between the two languages. Your task is to fix only those conversion errors.
        """

    private let glossaryLimit: Int

    init(glossaryLimit: Int = 40) {
        self.glossaryLimit = glossaryLimit
    }

    func build(
        style: StyleProfileRecord?,
        glossaryTerms: [GlossaryTerm]
    ) -> PromptBuildResult {
        var sections = [Self.conservativeSystemPrompt]
        let enabledStyle = style?.enabled == true ? style : nil

        if let enabledStyle {
            sections.append(
                """
                Selected style:
                \(enabledStyle.prompt)
                """
            )
        }

        let enabledTerms = glossaryTerms
            .filter(\.enabled)
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
                }
                return lhs.priority < rhs.priority
            }
            .prefix(glossaryLimit)

        if !enabledTerms.isEmpty {
            let lines = enabledTerms.map { term in
                if term.aliases.isEmpty {
                    return "- \(term.term)"
                }
                return "- \(term.term): \(term.aliases.joined(separator: ", "))"
            }
            sections.append(
                """
                User glossary:
                Prefer these spellings when the spoken text clearly matches an alias or common ASR mistake. Do not force a glossary term when context is uncertain.
                \(lines.joined(separator: "\n"))
                """
            )
        }

        return PromptBuildResult(
            systemPrompt: sections.joined(separator: "\n\n"),
            llmProviderID: nil,
            styleID: enabledStyle?.id,
            model: nil,
            temperature: nil
        )
    }
}

protocol PromptAwareTextRefining: TextRefining {
    func refine(_ request: TextRefinementRequest) async throws -> String
}
