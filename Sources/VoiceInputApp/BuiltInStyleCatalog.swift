import Foundation

enum BuiltInStyleCatalog {
    static let legacyPrompts: [String: String] = [
        "builtin.original": "不改写用户内容。仅在明显识别错误时做最小修正，不能扩写、总结或改变语气。",
        "builtin.formal": "在不添加事实的前提下，把明显口语化但不改变含义的表达调整为正式书面语。",
        "builtin.casual": "保持轻松自然的口吻，只修正明显识别错误和不顺的标点。",
        "builtin.energetic": "在不添加新信息的前提下，让语气更积极简洁。不要夸张，不要替用户发挥。",
        "builtin.coding": "优先修正技术术语、大小写、代码相关英文和中英混排识别错误。不要解释代码。",
        "builtin.email": "把口述内容整理为清晰、礼貌、简短的邮件或工作消息。不得添加用户没有说的信息。",
    ]

    static func profile(id: String, now: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> StyleProfileRecord? {
        profiles(now: now).first { $0.id == id }
    }

    static func profiles(now: Date) -> [StyleProfileRecord] {
        [
            profile(
                id: "builtin.original",
                name: "原文",
                category: "基础",
                subtitle: "只保留原始表达",
                mode: "raw",
                prompt: """
                你正在处理语音识别得到的原文。保持用户原有措辞、语气、句序和信息密度，只修正能够从上下文明确判断的同音字、技术名词、断句与标点错误。不要润色，不要改写，不要补充用户没有表达的事实，不要删除犹豫词或重复内容。无法确定时保留原样。输出只能包含修正后的正文，不要解释修改过程，不要添加标题、引号或前后说明。
                """,
                sampleInput: "今天同步一下项目进展",
                sampleOutput: "今天同步一下项目进展",
                temperature: 0.0,
                isDefault: true,
                now: now
            ),
            profile(
                id: "builtin.formal",
                name: "正式",
                category: "写作",
                subtitle: "更适合汇报和文档",
                mode: "formal",
                prompt: """
                将口述内容整理成清晰、克制、专业的正式书面语，适合汇报、方案和文档。允许修正明显识别错误、补全必要标点、合并无意义的口头停顿，并在不改变含义的前提下调整语序。必须保留全部事实、数字、专有名词和结论。不要添加新观点，不要夸大语气，不要替用户作判断，也不要生成未要求的标题或列表。输出仅包含整理后的正文，不要解释。
                """,
                sampleInput: "这个方案大概能跑",
                sampleOutput: "这个方案基本可行",
                temperature: 0.1,
                isDefault: false,
                now: now
            ),
            profile(
                id: "builtin.casual",
                name: "日常",
                category: "写作",
                subtitle: "自然聊天语气",
                mode: "casual",
                prompt: """
                将语音内容整理成自然、友好、像真人聊天的日常表达。保留用户原本的态度和信息，只修正明显的识别错误、断句和不自然的标点；可以去掉完全无意义的口头停顿，但不要把句子改成正式公文。不要擅自增加表情、称呼、承诺或事实，不要过度热情，不要改变用户的立场。输出只包含可直接发送的正文，不要附加解释、标题或引号。
                """,
                sampleInput: "等会儿我把链接发你",
                sampleOutput: "等会儿我把链接发你",
                temperature: 0.1,
                isDefault: false,
                now: now
            ),
            profile(
                id: "builtin.energetic",
                name: "元气",
                category: "写作",
                subtitle: "更有活力但不过度发挥",
                mode: "energetic",
                prompt: """
                在完整保留原意和事实的前提下，让表达更积极、明快、有行动感。修正语音识别错误和标点，适度压缩拖沓口头语，让重点更直接；可以使用少量自然的感叹语气，但不得影响专业性。不要添加用户未说出的计划、承诺、数据或评价，不要使用夸张口号，不要连续使用感叹号，也不要替用户发挥。输出仅为可直接使用的正文，不要解释。
                """,
                sampleInput: "我们今天继续推进",
                sampleOutput: "我们今天继续推进！",
                temperature: 0.2,
                isDefault: false,
                now: now
            ),
            profile(
                id: "builtin.coding",
                name: "编程",
                category: "工作",
                subtitle: "技术名词优先",
                mode: "coding",
                prompt: """
                按技术沟通场景处理语音识别文本。优先修正编程语言、框架、命令、API、文件名、变量名和中英混排中的同音误识别，并保留正确的大小写、连字符、路径和代码符号。除非上下文明确，不要猜测具体实现，不要生成代码，不要回答技术问题，不要改变原有需求或结论。保留用户的段落结构。输出只能是修正后的原文，不要解释术语，也不要使用 Markdown 代码围栏。
                """,
                sampleInput: "配森",
                sampleOutput: "Python",
                temperature: 0.0,
                isDefault: false,
                now: now
            ),
            profile(
                id: "builtin.email",
                name: "邮件",
                category: "工作",
                subtitle: "适合邮件和消息",
                mode: "email",
                prompt: """
                将口述内容整理成清晰、礼貌、简洁的邮件或工作消息正文。修正识别错误、口头停顿和标点，并按自然顺序组织背景、请求与时间要求。保持用户原有称呼、事实、日期、数字和承诺；未口述称呼或落款时不要自行添加。不要虚构礼貌套话，不要扩大请求范围，不要替用户作决定。输出只包含可直接发送的正文，不要添加主题、解释、引号或 Markdown 标记。
                """,
                sampleInput: "麻烦你明天之前给我反馈",
                sampleOutput: "麻烦你明天之前给我反馈。",
                temperature: 0.1,
                isDefault: false,
                now: now
            ),
        ]
    }

    private static func profile(
        id: String,
        name: String,
        category: String,
        subtitle: String,
        mode: String,
        prompt: String,
        sampleInput: String,
        sampleOutput: String,
        temperature: Double,
        isDefault: Bool,
        now: Date
    ) -> StyleProfileRecord {
        StyleProfileRecord(
            id: id,
            name: name,
            category: category,
            subtitle: subtitle,
            mode: mode,
            prompt: prompt,
            sampleInput: sampleInput,
            sampleOutput: sampleOutput,
            llmProviderID: nil,
            model: nil,
            temperature: temperature,
            enabled: true,
            builtIn: true,
            isDefault: isDefault,
            createdAt: now,
            updatedAt: now
        )
    }
}

enum BuiltInStyleSeeder {
    static func seed(styleRepository: any StyleRepository, clock: any AppClock) throws {
        let now = clock.now
        let currentDefault = try styleRepository.defaultProfile()

        for profile in BuiltInStyleCatalog.profiles(now: now) {
            guard try styleRepository.profile(id: profile.id) == nil else {
                continue
            }
            var seeded = profile
            if currentDefault != nil && profile.isDefault {
                seeded = profile.withDefault(false)
            }
            try styleRepository.save(seeded)
        }
    }
}

private extension StyleProfileRecord {
    func withDefault(_ value: Bool) -> StyleProfileRecord {
        StyleProfileRecord(
            id: id,
            name: name,
            category: category,
            subtitle: subtitle,
            mode: mode,
            prompt: prompt,
            sampleInput: sampleInput,
            sampleOutput: sampleOutput,
            llmProviderID: llmProviderID,
            model: model,
            temperature: temperature,
            enabled: enabled,
            builtIn: builtIn,
            isDefault: value,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
