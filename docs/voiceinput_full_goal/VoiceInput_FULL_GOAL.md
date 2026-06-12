# VoiceInput 完整产品与技术实现方案（Codex Goal 版）

> 目标：把当前 `VoiceInput` 从「轻量菜单栏语音输入工具」一次性升级为「完整 macOS 语音输入工作台」。本文档不以任何第三方产品命名；交互图片仅作为信息架构、页面布局、控件状态和交互密度参考。  
> 执行对象：Codex / Claude Code / 任意代码 Agent。  
> 交付方式：一次性完成，不按 MVP/二期拆分；文档中的顺序只是实现顺序，不代表允许部分交付。

---

## 0. Codex Goal Prompt（可直接复制给 Codex）

```text
你正在维护 GitHub 仓库：https://github.com/xingbofeng/VoiceInput

请一次性把 VoiceInput 升级为完整 macOS 语音输入工作台。不要改项目名称，不要引用任何第三方产品名称。交互图片位于 docs/interaction-references/，仅作为布局、导航、状态和交互参考。

核心目标：
1. 保留现有右 Command/自定义快捷键听写能力：按住录音、松手识别、自动注入当前光标位置。
2. 保留现有不抢焦点 HUD、输入法临时切换、Command-V 注入、剪贴板完整恢复、LLM 失败回退、ASR 失败回退等核心稳定性原则。
3. 新增完整主窗口：左侧导航 + 首页 + 词汇表 + 风格 + 文件转写 + 笔记 + 听写模型 + 设置 + 帮助。
4. 新增首页统计：连续使用、累计字符、CPM、目标进度、历史记录、搜索、复制、删除、重新处理。
5. 新增词汇表：易错词、专有名词、文本替换、批量导入、分类、启用/禁用、导入导出。
6. 新增风格系统：个人/工作/编程/邮件/默认分类，风格卡片，风格编辑器，Prompt 编辑，LLM 参数，调试预览，默认风格，按应用自动选择。
7. 新增 LLM Provider 管理：OpenAI-compatible provider，Base URL 归一化，API Key 存 Keychain，模型管理，测试，测速，错误展示，每个风格可绑定模型。
8. 新增 ASR Provider 管理：Apple Speech、Qwen3-ASR、本地模型、云 API provider、标签筛选、健康检查、测速、默认模型、回退策略。
9. 新增设置中心：通用、系统、数据与隐私。包括输入设备、快捷键、录音模式、提示音、录音时静音、声音增强、性能优化、权限状态、隐私分析、本地数据清理、导入导出。
10. 新增文件转写：拖拽音频/视频文件，任务队列，进度，取消，重试，导出 txt/md/srt，保存到笔记。
11. 新增笔记：听写历史/文件转写可保存为笔记，支持 Markdown、搜索、标签、导出。
12. 新增本地数据层：SQLite3 + Repository + Migration，不要把 API Key 明文写入 SQLite 或 UserDefaults。
13. 新增完整测试：单元测试、集成测试、UI smoke test、权限/剪贴板/输入法/状态机/Provider/数据迁移测试。
14. 更新 README、CONTEXT、docs/ARCHITECTURE.md、docs/TEST_PLAN.md、docs/PRD.md、docs/CODEX_GOAL.md。

硬性约束：
- macOS 14+。
- Swift 5.9+。
- AppKit 负责菜单栏、全局事件、HUD、窗口生命周期；SwiftUI 负责主窗口和设置表单视图。
- 不能引入会破坏构建稳定性的重型依赖。数据库优先使用系统 SQLite3；网络用 URLSession；Keychain 用 Security.framework。
- 所有网络能力必须可关闭；默认不开启 LLM，不默认上传音频。
- Provider 失败必须回退，不能丢用户本次输入。
- 任何 UI 不得抢当前输入焦点；主窗口只有用户主动打开时才激活。
- Overlay/HUD 必须保持 non-activating。
- 注入流程必须完整恢复剪贴板，包括富文本、图片、多 item、多 UTI 类型。
- 不得把识别文本发送给 LLM，除非用户启用了 LLM/风格处理。
- 不得保存原始音频，除非用户在设置中明确开启“保留失败任务音频用于重试”。

完成标准：
- `make clean && make build` 成功。
- `swift test` 成功。
- 应用可启动，菜单栏可见。
- 首次打开有权限向导。
- 主窗口所有导航均可进入。
- 核心听写闭环可用。
- 首页、词汇表、风格、听写模型、设置、文件转写、笔记均有真实数据流，不是静态假 UI。
- README 与 docs 中的实现说明和实际代码一致。
```

---

## 1. 当前仓库理解与改造边界

### 1.1 当前项目已有能力

从仓库 README 和模块结构看，当前项目已经具备以下基础：

- macOS 原生菜单栏应用。
- 默认右 Command 触发听写。
- CGEvent tap 监听快捷键。
- AVAudioEngine 捕获麦克风音频。
- Apple Speech 实时 partial result。
- Qwen3-ASR 可插拔方向已经存在雏形。
- HUD 使用非激活窗口展示实时文本和波形。
- 注入时临时切换 ABC/US 输入源，避免中文输入法吞粘贴。
- Command-V 注入文字到当前光标所在应用。
- 注入后恢复输入源和剪贴板。
- OpenAI-compatible LLM 纠错能力。
- ASR / LLM / Shortcut 三栏设置页。
- 已有测试基础。

### 1.2 不能破坏的已有体验

| 编号 | 不可破坏项 | 说明 |
|---|---|---|
| KEEP-001 | 右 Command 继续可用 | 默认快捷键仍为右 Command，不影响左 Command |
| KEEP-002 | 不抢焦点 | HUD、录音、注入都不能抢走当前输入框焦点 |
| KEEP-003 | 快速反馈 | 按下快捷键后 HUD 必须快速出现 |
| KEEP-004 | 流式预览 | 支持 partial result 实时展示 |
| KEEP-005 | 最终兜底 | final result 超时后使用 latest partial |
| KEEP-006 | 输入法恢复 | 粘贴前切 ABC/US，粘贴后恢复原输入源 |
| KEEP-007 | 剪贴板恢复 | 恢复所有 pasteboard item 和类型，不只恢复纯文本 |
| KEEP-008 | LLM 可关闭 | 默认不调用 LLM；失败回退原文 |
| KEEP-009 | ASR 可回退 | 本地/云 ASR 不可用时回退 Apple Speech 或可用引擎 |
| KEEP-010 | 菜单栏运行 | 保持轻量菜单栏应用，不强迫打开主窗口 |

### 1.3 本次改造方式

本次不是重写核心，而是把项目拆成更清晰的层：

```text
AppKit Runtime
  ├── 菜单栏生命周期
  ├── 全局快捷键监听
  ├── 非激活 HUD
  ├── 输入法与剪贴板注入
  └── 主窗口承载 SwiftUI

SwiftUI Workbench
  ├── 首页
  ├── 词汇表
  ├── 风格
  ├── 文件转写
  ├── 笔记
  ├── 听写模型
  ├── 设置
  └── 帮助

Domain Services
  ├── DictationOrchestrator
  ├── TextProcessingPipeline
  ├── ASRProviderRegistry
  ├── LLMProviderRegistry
  ├── HistoryService
  ├── GlossaryService
  ├── StyleService
  ├── TranscriptionJobService
  ├── NoteService
  ├── PermissionService
  ├── MetricsService
  └── SecureCredentialStore
```

---

## 2. 产品定义

### 2.1 一句话定位

VoiceInput 是一个面向中文用户、开发者和知识工作者的 macOS 语音输入工作台：按住说话，松手输入；可按词汇表纠错、按场景输出、按模型选择准确度与隐私策略。

### 2.2 产品目标

| 目标 | 描述 |
|---|---|
| 输入更快 | 把口述内容直接注入任意应用 |
| 技术词更准 | 用词汇表和 LLM 纠正常见 ASR 错词 |
| 输出更合场景 | 不同场景可用不同风格规则 |
| 模型可选择 | 支持系统、本地、云 API 多种 ASR/LLM |
| 数据可掌控 | 历史、词库、风格、笔记保存在本地 |
| 隐私可解释 | 明确展示何时本地、何时联网、何时上传文本/音频 |

### 2.3 目标用户

| 用户 | 高频场景 | 核心痛点 | 关键功能 |
|---|---|---|---|
| AI Agent 使用者 | 给 Codex/Claude/Cursor 讲需求 | 长上下文打字慢，技术词容易错 | 编程风格、术语表、快速听写 |
| 开发者 | issue、commit、需求、代码解释 | 中英文混合识别不准 | 词汇表、文本替换、保守纠错 |
| 内容创作者 | 小红书、知乎、B 站文案 | 口述后格式乱 | 风格系统、历史记录、笔记 |
| 办公用户 | IM、邮件、文档 | 不同场景语气不同 | 邮件/正式/日常风格 |
| 隐私用户 | 内部资料、客户沟通 | 不想上传音频 | 本地 ASR、LLM 可关闭、隐私页 |

### 2.4 设计原则

1. **输入优先**：任何功能都不能牺牲“按住说话、松手输入”的主链路。
2. **保守默认**：默认只纠错，不替用户扩写、总结、编造信息。
3. **本地优先**：本地能完成的事情优先本地完成。
4. **失败可回退**：ASR/LLM/数据库/网络失败都不能丢本次输入。
5. **可解释**：用户能清楚知道用了哪个模型、发出了什么数据、保存了什么数据。
6. **可组合**：ASR、词汇表、替换、风格、LLM、注入是流水线，可插拔、可测试。
7. **可迁移**：设置、词库、风格、历史、笔记都支持导入导出。

---

## 3. 交互参考图索引

这些图片只作为 VoiceInput 目标交互参考，不代表项目名称或品牌。

| 图 | 页面/交互 | 文件 |
|---|---|---|
| 01 | 首页：欢迎、统计、激励卡、历史记录 | `images/interaction-reference-01.png` |
| 02 | 词汇表：易错词、文本替换、添加、空状态 | `images/interaction-reference-02.png` |
| 03 | 风格列表：分类、启用、风格卡片 | `images/interaction-reference-03.png` |
| 04 | 风格编辑：Prompt、LLM 参数、调试预览 | `images/interaction-reference-04.png` |
| 05 | LLM 配置弹窗：Provider、Base URL、API Key、模型、测试 | `images/interaction-reference-05.png` |
| 06 | 听写模型：Provider 列表、标签筛选 | `images/interaction-reference-06.png` |
| 07 | 通用设置：输入设备、快捷键、录音模式 | `images/interaction-reference-07.png` |
| 08 | 系统设置：音频反馈、声音增强、性能优化 | `images/interaction-reference-08.png` |
| 09 | 数据与隐私：权限状态、分析开关 | `images/interaction-reference-09.png` |
| 10 | 帮助菜单：官网、GitHub、反馈、社群 | `images/interaction-reference-10.png` |

![首页参考](images/interaction-reference-01.png)

---

## 4. 功能范围总览

### 4.1 必须一次性实现的功能模块

| 模块 | 必须完成 |
|---|---|
| 核心听写 | 快捷键、录音、ASR、HUD、文本处理、注入、历史保存 |
| 主窗口 | 左侧导航、路由、页面状态、窗口生命周期 |
| 首页 | 统计、目标、历史、搜索、复制、删除、重新处理 |
| 词汇表 | 易错词、替换规则、分类、导入导出、参与 Prompt |
| 风格 | 风格分类、卡片、编辑器、Prompt、调试预览、默认/自动选择 |
| LLM Provider | OpenAI-compatible 配置、Keychain、测试、测速、错误展示 |
| ASR Provider | Apple Speech、Qwen3、本地/云 API 抽象、模型筛选、默认、健康检查 |
| 设置中心 | 通用、系统、数据与隐私、权限、快捷键、音效、音频增强 |
| 文件转写 | 拖拽、任务队列、进度、取消、重试、导出、保存笔记 |
| 笔记 | Markdown、标签、搜索、历史/文件转写保存为笔记 |
| 数据层 | SQLite3、迁移、Repository、备份、导入导出 |
| 安全 | Keychain、日志脱敏、隐私开关 |
| 测试 | 单元、集成、UI smoke、手工测试清单 |
| 文档 | README、架构、测试、Codex Goal、隐私说明 |

### 4.2 不做或延后但要留接口

| 项 | 原因 | 留接口 |
|---|---|---|
| 云同步 | 复杂度高，涉及账号体系 | `SyncService` 协议空实现 |
| 团队词库 | 需要后端或文件共享协议 | `GlossarySource` 支持 local/remote 枚举 |
| 会议录音机器人 | 与输入工具主线不同 | 文件转写任务可扩展到会议源 |
| 付费订阅 | 与当前开源工具定位无关 | 不写死商业逻辑 |

---

## 5. 信息架构

### 5.1 主导航

```text
VoiceInput
├── 首页 Home
├── 词汇表 Glossary
├── 风格 Styles
├── 文件转写 File Transcription
├── 笔记 Notes
├── 听写模型 Dictation Models
├── 设置 Settings
└── 帮助 Help
```

### 5.2 设置中心导航

```text
设置 Settings
├── 通用 General
│   ├── 语音识别
│   ├── 输入设备
│   ├── 快捷键
│   └── 录音模式
├── 系统 System
│   ├── 音频反馈
│   ├── 录音时静音
│   ├── 声音增强
│   └── 性能优化
└── 数据与隐私 Data & Privacy
    ├── 权限状态
    ├── 隐私与分析
    ├── 本地数据
    └── 导入导出
```

### 5.3 页面状态规范

每个页面必须有以下状态：

| 状态 | UI 要求 |
|---|---|
| loading | 骨架屏或局部 loading，不阻塞整个窗口 |
| ready | 正常内容 |
| empty | 明确空状态和下一步行动 |
| error | 错误说明 + 重试按钮 + 复制错误详情 |
| disabled | 功能未启用时说明原因和入口 |
| permission_required | 权限缺失时展示去授权按钮 |

---

## 6. 用户故事与验收标准

## 6.1 核心听写

### 用户故事

- 作为用户，我希望按住快捷键说话，松开后文字直接落到当前光标位置，这样我不用离开当前编辑环境。
- 作为中文输入法用户，我希望粘贴不会被拼音输入法吞掉，也不会破坏我的当前输入法。
- 作为重度用户，我希望识别失败、LLM 超时或网络失败时至少能得到原始文本，而不是丢失本次输入。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| DIC-001 | 默认右 Command 触发 | P0 |
| DIC-002 | 支持自定义快捷键 | P0 |
| DIC-003 | 支持长按模式 | P0 |
| DIC-004 | 支持短按切换模式 | P0 |
| DIC-005 | HUD 不抢焦点 | P0 |
| DIC-006 | 录音时展示实时文本和波形 | P0 |
| DIC-007 | 松手后 final result 有上限等待时间 | P0 |
| DIC-008 | final 超时使用 latest partial | P0 |
| DIC-009 | 空文本不注入、不入库 | P0 |
| DIC-010 | 注入前执行文本处理流水线 | P0 |
| DIC-011 | 注入时切换安全输入源 | P0 |
| DIC-012 | 注入后恢复输入源 | P0 |
| DIC-013 | 注入后恢复完整剪贴板 | P0 |
| DIC-014 | 失败提示不打断用户 | P0 |
| DIC-015 | 记录听写历史和指标 | P0 |

### 验收标准

| Given | When | Then |
|---|---|---|
| 光标在任意输入框 | 按住右 Command 说话并松开 | 文本被注入当前输入框 |
| 当前输入法是中文 | 听写完成 | 文本正确粘贴，输入法恢复中文 |
| 剪贴板有图片+富文本 | 听写完成 | 剪贴板内容完全恢复 |
| LLM 超时 | 听写完成 | 使用 ASR 原文注入，历史标记 refinement failed |
| ASR 没有 final | 松手超过等待上限 | 使用 latest partial |
| 录音无语音 | 松手 | HUD 关闭，不注入，不保存历史 |

---

## 6.2 首页

### 用户故事

- 作为用户，我想看到今天和近期的语音输入成果，知道自己节省了多少打字时间。
- 作为用户，我想快速找回之前说过的内容并复制或重新处理。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| HOME-001 | 展示欢迎语 | P0 |
| HOME-002 | 展示连续使用天数/周数 | P0 |
| HOME-003 | 展示累计字符数 | P0 |
| HOME-004 | 展示平均 CPM | P0 |
| HOME-005 | 展示目标进度卡片 | P1 |
| HOME-006 | 按日期分组展示历史 | P0 |
| HOME-007 | 历史搜索 | P0 |
| HOME-008 | 复制历史最终文本 | P0 |
| HOME-009 | 删除历史 | P0 |
| HOME-010 | 查看原文/最终文本 diff | P1 |
| HOME-011 | 使用当前风格重新处理历史 | P1 |
| HOME-012 | 空状态引导用户开始听写 | P0 |

### 统计规则

| 指标 | 计算方式 |
|---|---|
| 累计字符数 | `sum(dictation_history.char_count where deleted_at is null)` |
| 今日字符数 | 当天本地时间范围内字符数 |
| CPM | `char_count / duration_minutes`，过滤 duration < 300ms 或 char_count = 0 |
| 连续使用 | 每天至少一条成功历史视为使用 |
| 目标进度 | 默认目标 180000 字，可在设置中调整 |

### 验收标准

| Given | When | Then |
|---|---|---|
| 新用户 | 打开首页 | 显示 0 统计和空历史 |
| 完成一次 100 字听写 | 回到首页 | 累计字符 +100，历史出现一条 |
| 历史包含 “Qwen3-ASR” | 搜索 “Qwen3” | 只显示匹配记录 |
| 删除一条历史 | 确认删除 | 记录隐藏，统计刷新 |

---

## 6.3 词汇表

### 用户故事

- 作为开发者，我希望把项目名、框架名、人名、缩写加入词汇表，让语音识别和纠错更准。
- 作为用户，我希望配置“错词 -> 正确词”，让常见误识别自动修正。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| GLO-001 | 易错词列表 | P0 |
| GLO-002 | 添加单个词 | P0 |
| GLO-003 | 每行一个批量添加 | P0 |
| GLO-004 | 删除词 | P0 |
| GLO-005 | 启用/禁用词 | P0 |
| GLO-006 | 分类：个人/工作/编程/人名/项目/自定义 | P1 |
| GLO-007 | 文本替换规则 | P0 |
| GLO-008 | 替换匹配模式：exact/contains/regex | P1 |
| GLO-009 | 替换阶段：LLM 前/LLM 后/注入前 | P0 |
| GLO-010 | 搜索 | P0 |
| GLO-011 | 清空全部 | P1 |
| GLO-012 | 导入 JSON/CSV | P1 |
| GLO-013 | 导出 JSON/CSV | P1 |
| GLO-014 | 词汇表进入 PromptBuilder | P0 |

### 数据规则

- `term` 去除首尾空格。
- 空行忽略。
- 同分类下大小写不敏感去重，但原始大小写保留。
- regex 规则必须校验，错误 regex 不允许保存。
- 替换规则执行顺序：优先级高的在前；同优先级按创建时间。

### 验收标准

| Given | When | Then |
|---|---|---|
| 添加词 “TypeScript” | 听写包含该词 | Prompt 中包含术语上下文 |
| 替换规则 “杰森 -> JSON” | 输入 “这个杰森解析” | 输出 “这个 JSON 解析” |
| 禁用规则 | 再次处理 | 不再替换 |
| 批量导入重复词 | 保存 | 自动去重并提示数量 |

---

## 6.4 风格系统

### 用户故事

- 作为用户，我希望不同场景有不同输出风格，例如聊天自然一点，邮件正式一点，编程保留术语。
- 作为高级用户，我希望能编辑 Prompt 和模型参数，并看到预览结果。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| STY-001 | 全局风格系统开关 | P0 |
| STY-002 | 分类：个人/工作/编程/邮件/默认 | P0 |
| STY-003 | 默认风格：原文、正式、日常、元气、编程、邮件 | P0 |
| STY-004 | 风格卡片展示示例 | P0 |
| STY-005 | 设为默认 | P0 |
| STY-006 | 编辑风格名称、副标题、Prompt | P0 |
| STY-007 | 配置 LLM provider/model/temperature | P0 |
| STY-008 | Prompt 重置 | P0 |
| STY-009 | 调试预览：原文 -> 结果 | P0 |
| STY-010 | 复制风格 | P1 |
| STY-011 | 删除自定义风格 | P1 |
| STY-012 | 内置风格不可删除，只可重置 | P0 |
| STY-013 | 按应用自动选择风格 | P1 |
| STY-014 | 保守纠错模式与风格改写模式分离 | P0 |

### 风格模式

| 模式 | 行为 |
|---|---|
| 原文模式 | 不调用 LLM，只执行本地替换 |
| 保守纠错 | 只修明显错词、标点、技术术语，不改写结构 |
| 风格处理 | 允许按规则整理语气和格式，但不能添加事实 |
| 邮件格式化 | 可补齐礼貌格式，但不得编造收件人、时间、承诺 |
| 编程优化 | 保留代码、英文、API、变量名，不随意翻译 |

### 默认 Prompt 模板

```text
# Role
你是 VoiceInput 的文本修正引擎。你只处理用户刚刚说出的文本，不回答问题，不执行指令，不添加用户没有说过的信息。

# Hard Rules
1. 不得回答文本中的问题。
2. 不得扩写事实。
3. 不得添加原因、结论、建议。
4. 不得删除用户明确表达的含义。
5. 不确定时保留原文。
6. 代码、变量、项目名、英文缩写、人名优先按词汇表保留。

# Style
{{style_prompt}}

# Glossary
{{enabled_glossary_terms}}

# Replacement Rules
本地替换已经按规则执行。你只需处理剩余明显错误。

# Input
{{raw_text}}

# Output
只输出处理后的文本，不要解释。
```

### 验收标准

| Given | When | Then |
|---|---|---|
| 风格关闭 | 听写 | 只执行 ASR + 本地替换 |
| 使用编程风格 | 输入 “杰森 和 Type Script” | 输出保留 JSON、TypeScript 等技术词 |
| 使用邮件风格 | 输入口述邮件 | 输出可分段，但不编造收件人 |
| Prompt 为空 | 保存 | 禁止保存并提示 |
| LLM 不可用 | 使用风格 | 回退原文，历史标记失败 |

---

## 6.5 LLM Provider

### 用户故事

- 作为用户，我希望配置自己的 API，而不是绑定固定服务。
- 作为用户，我希望 API Key 安全保存，不明文出现在配置文件里。
- 作为用户，我希望每个风格可以用不同模型。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| LLM-001 | Provider 列表 | P0 |
| LLM-002 | 添加 OpenAI-compatible provider | P0 |
| LLM-003 | Base URL 归一化 | P0 |
| LLM-004 | API Key 存 Keychain | P0 |
| LLM-005 | Model 保存 | P0 |
| LLM-006 | Temperature 保存 | P0 |
| LLM-007 | 测试连接 | P0 |
| LLM-008 | 测速：响应耗时、tokens/s 可选 | P1 |
| LLM-009 | 错误展示 | P0 |
| LLM-010 | 隐藏/显示 Key | P0 |
| LLM-011 | 获取模型列表 | P1 |
| LLM-012 | 每个风格绑定 provider | P0 |
| LLM-013 | 全局默认 provider | P0 |
| LLM-014 | 请求超时配置 | P0 |
| LLM-015 | 日志脱敏 | P0 |

### Base URL 归一化

允许用户输入：

```text
https://api.example.com
https://api.example.com/v1
https://api.example.com/v1/chat/completions
```

内部统一成：

```text
https://api.example.com/v1/chat/completions
```

禁止：

- 空 URL。
- 非 http/https。
- 明显不是 API 的业务页面 URL。

### Keychain 规则

```text
service: com.xingbofeng.VoiceInput.llm
account: provider_id
value: api_key
```

SQLite 只保存：

```text
api_key_ref = provider_id
```

### 验收标准

| Given | When | Then |
|---|---|---|
| API Key 保存 | 重启应用 | Key 可用但数据库无明文 |
| Base URL 是 `/v1` | 测试 | 请求正确发到 `/v1/chat/completions` |
| API 401 | 测试 | 显示认证失败，不崩溃 |
| LLM 超时 | 听写 | 回退 ASR 文本 |

---

## 6.6 ASR Provider

### 用户故事

- 作为用户，我希望选择系统内置、本地模型或云 API。
- 作为隐私用户，我希望完全本地处理。
- 作为追求准确率的用户，我希望使用更准的模型。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| ASR-001 | Provider 列表页 | P0 |
| ASR-002 | 标签筛选：全部/在线/本地/API/快速/准确/实时 | P0 |
| ASR-003 | Apple Speech provider | P0 |
| ASR-004 | Qwen3-ASR provider | P0 |
| ASR-005 | 本地模型下载/校验/删除 | P0 |
| ASR-006 | 云 API provider 协议 | P1 |
| ASR-007 | Provider 配置弹窗 | P0 |
| ASR-008 | Provider 健康检查 | P0 |
| ASR-009 | 默认听写模型选择 | P0 |
| ASR-010 | 失败回退策略 | P0 |
| ASR-011 | 实时 partial capability | P0 |
| ASR-012 | 文件转写 capability | P1 |
| ASR-013 | 模型测速 | P1 |
| ASR-014 | 展示隐私说明 | P0 |

### Provider 能力标签

```swift
struct ASRProviderCapabilities: OptionSet {
    let rawValue: Int
    static let streaming        = ASRProviderCapabilities(rawValue: 1 << 0)
    static let fileTranscription = ASRProviderCapabilities(rawValue: 1 << 1)
    static let local            = ASRProviderCapabilities(rawValue: 1 << 2)
    static let cloud            = ASRProviderCapabilities(rawValue: 1 << 3)
    static let fast             = ASRProviderCapabilities(rawValue: 1 << 4)
    static let accurate         = ASRProviderCapabilities(rawValue: 1 << 5)
    static let multilingual     = ASRProviderCapabilities(rawValue: 1 << 6)
    static let punctuation      = ASRProviderCapabilities(rawValue: 1 << 7)
}
```

### 回退顺序

```text
当前选择 provider
  -> 当前 provider 的备用模型
  -> Apple Speech（如果权限可用）
  -> latest partial
  -> 空结果并提示用户
```

### 验收标准

| Given | When | Then |
|---|---|---|
| 未配置任何模型 | 打开听写模型页 | Apple Speech 显示为可用默认 |
| Qwen3 模型缺失 | 选择 Qwen3 | 提示下载模型，不允许启用 |
| 云 API 失败 | 听写 | 自动回退并提示 |
| Provider 不支持 streaming | 录音中 | HUD 展示录音状态，不展示实时文本 |

---

## 6.7 设置中心

### 用户故事

- 作为用户，我希望在一个地方配置麦克风、快捷键、声音反馈、权限和隐私。
- 作为首次用户，我希望知道为什么需要权限，以及如何授权。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| SET-001 | 输入设备选择 | P0 |
| SET-002 | 快捷键录制 | P0 |
| SET-003 | 长按阈值 | P0 |
| SET-004 | 短按行为 | P0 |
| SET-005 | 录音模式说明 | P0 |
| SET-006 | 录音时静音其他音频 | P1 |
| SET-007 | 提示音开关 | P0 |
| SET-008 | 声音增强开关 | P0 |
| SET-009 | 声音增强参数 | P1 |
| SET-010 | 性能优化开关 | P1 |
| SET-011 | 麦克风权限状态 | P0 |
| SET-012 | 辅助功能权限状态 | P0 |
| SET-013 | 语音识别权限状态 | P0 |
| SET-014 | 跳转系统设置 | P0 |
| SET-015 | 刷新权限状态 | P0 |
| SET-016 | 使用分析开关 | P0 |
| SET-017 | 清空历史 | P0 |
| SET-018 | 清空缓存 | P0 |
| SET-019 | 导出全部数据 | P0 |
| SET-020 | 导入数据 | P1 |
| SET-021 | 重置所有设置 | P1 |

### 权限解释

| 权限 | 用途 | 缺失影响 |
|---|---|---|
| 麦克风 | 录制语音 | 无法听写 |
| 辅助功能 | 全局快捷键、模拟粘贴 | 快捷键无响应或无法注入 |
| 语音识别 | Apple Speech 转录 | Apple Speech 不可用，本地 ASR 可不需要 |

### 验收标准

| Given | When | Then |
|---|---|---|
| 无麦克风权限 | 打开设置 | 显示未授权和跳转按钮 |
| 修改快捷键 | 保存 | 即时生效，不重启 |
| 关闭提示音 | 录音 | 不播放提示音 |
| 关闭分析 | 使用应用 | 不记录匿名分析事件 |

---

## 6.8 文件转写

### 用户故事

- 作为用户，我希望把音频/视频文件拖进来转文字。
- 作为内容创作者，我希望导出 Markdown 或字幕。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| FILE-001 | 拖拽文件导入 | P0 |
| FILE-002 | 选择文件按钮 | P0 |
| FILE-003 | 支持 m4a/mp3/wav/aac/mp4/mov | P0 |
| FILE-004 | 文件格式校验 | P0 |
| FILE-005 | 任务队列 | P0 |
| FILE-006 | 进度展示 | P0 |
| FILE-007 | 取消任务 | P0 |
| FILE-008 | 失败重试 | P0 |
| FILE-009 | 选择 ASR provider | P0 |
| FILE-010 | 长文件分段 | P1 |
| FILE-011 | 导出 txt | P0 |
| FILE-012 | 导出 md | P0 |
| FILE-013 | 导出 srt | P1 |
| FILE-014 | 保存为笔记 | P0 |
| FILE-015 | 任务历史 | P0 |

### 转写状态机

```text
queued -> preparing -> transcribing -> post_processing -> completed
                         ├── cancelled
                         └── failed -> retrying -> transcribing
```

### 验收标准

| Given | When | Then |
|---|---|---|
| 拖入 mp3 | 选择模型并开始 | 任务进入队列并展示进度 |
| API 失败 | 点击重试 | 使用同配置重新执行 |
| 完成任务 | 点击导出 md | 生成 markdown 文件 |
| 完成任务 | 点击保存为笔记 | 笔记页出现该内容 |

---

## 6.9 笔记

### 用户故事

- 作为用户，我希望把有价值的听写内容保存为笔记，后续搜索和导出。

### 需求

| ID | 需求 | 优先级 |
|---|---|---|
| NOTE-001 | 新建笔记 | P0 |
| NOTE-002 | 从历史保存为笔记 | P0 |
| NOTE-003 | 从文件转写保存为笔记 | P0 |
| NOTE-004 | Markdown 编辑 | P0 |
| NOTE-005 | 标签 | P1 |
| NOTE-006 | 搜索标题和正文 | P0 |
| NOTE-007 | 删除笔记 | P0 |
| NOTE-008 | 导出 Markdown | P0 |
| NOTE-009 | 自动保存 | P1 |

### 验收标准

| Given | When | Then |
|---|---|---|
| 有历史记录 | 点击保存为笔记 | 生成笔记 |
| 搜索关键词 | 输入关键词 | 匹配标题和正文 |
| 编辑笔记 | 离开页面 | 内容自动保存或提示保存 |

---

## 7. 非功能需求

| 类型 | 要求 |
|---|---|
| 启动性能 | 冷启动到菜单栏图标 < 1.5s |
| HUD 响应 | 快捷键按下到 HUD 出现 < 100ms |
| 注入耗时 | 短句松手到注入：无 LLM < 1.2s；有 LLM 按超时配置回退 |
| 内存 | 常驻空闲 < 150MB；本地模型除外 |
| CPU | 空闲时接近 0；录音时可接受短时升高 |
| 稳定性 | 任一 provider 崩溃/失败不得导致 App 崩溃 |
| 隐私 | 默认不上传音频；默认不开 LLM；分析默认关闭或首次询问 |
| 安全 | API Key 只存 Keychain；日志脱敏 |
| 可测试性 | 核心服务均可单测；系统能力用 adapter mock |
| 可维护性 | UI、业务服务、数据、系统能力分层隔离 |
| 兼容性 | macOS 14+，Apple Silicon + Intel |
| 可恢复 | 输入法、剪贴板、录音会话、provider 状态均可恢复 |

---

## 8. 技术架构

## 8.1 总体架构

```text
┌──────────────────────────────────────────────────────────────┐
│ App Runtime                                                   │
│ AppDelegate / MenuBarController / WindowCoordinator           │
└──────────────────────────────────────────────────────────────┘
             │
┌──────────────────────────────────────────────────────────────┐
│ Presentation Layer                                            │
│ SwiftUI Views + ViewModels / AppKit HUD / Sheets / Alerts      │
└──────────────────────────────────────────────────────────────┘
             │
┌──────────────────────────────────────────────────────────────┐
│ Application Services                                          │
│ DictationOrchestrator / TextPipeline / History / Settings      │
│ ProviderRegistry / Permission / Metrics / ImportExport         │
└──────────────────────────────────────────────────────────────┘
             │
┌──────────────────────────────────────────────────────────────┐
│ Domain Layer                                                  │
│ Models / Value Objects / State Machines / Provider Protocols   │
└──────────────────────────────────────────────────────────────┘
             │
┌──────────────────────────────────────────────────────────────┐
│ Infrastructure                                                │
│ AVAudioEngine / Speech / CGEventTap / TIS / Pasteboard         │
│ SQLite3 / Keychain / URLSession / FileManager / OSLog          │
└──────────────────────────────────────────────────────────────┘
```

## 8.2 进程与线程模型

| 任务 | 线程/队列 | 说明 |
|---|---|---|
| UI 更新 | MainActor | SwiftUI 和 AppKit UI |
| 快捷键事件 | CGEvent tap callback queue | 尽量轻，只派发状态 |
| 音频采集 | AVAudioEngine audio thread | 不做阻塞操作 |
| ASR streaming | async task | 消费 audio buffer |
| LLM 请求 | async URLSession | 可取消，可超时 |
| SQLite 写入 | serial database queue | 避免并发写冲突 |
| Keychain | background task | 保存/读取时不阻塞 UI |
| 文件转写 | task queue | 支持取消和重试 |

## 8.3 依赖策略

| 类型 | 选择 | 原因 |
|---|---|---|
| UI | AppKit + SwiftUI | AppKit 控系统能力，SwiftUI 提升页面开发效率 |
| 数据库 | SQLite3 系统库 | 稳定、无额外依赖、便于迁移 |
| 网络 | URLSession | 原生、可测试 |
| Keychain | Security.framework | 原生安全存储 |
| 日志 | OSLog | 原生、支持隐私脱敏 |
| 音频 | AVFoundation | 现有基础可复用 |
| ASR | Speech + 可插拔本地/云 provider | 兼容现有能力 |
| 测试 | XCTest | 现有 SwiftPM 测试体系 |

## 8.4 依赖注入

```swift
@MainActor
final class AppEnvironment: ObservableObject {
    let preferences: AppPreferences
    let database: AppDatabase
    let keychain: SecureCredentialStore
    let permissionService: PermissionService
    let settingsService: SettingsService
    let historyService: HistoryService
    let glossaryService: GlossaryService
    let styleService: StyleService
    let asrRegistry: ASRProviderRegistry
    let llmRegistry: LLMProviderRegistry
    let textPipeline: TextProcessingPipeline
    let dictationOrchestrator: DictationOrchestrator
    let metricsService: MetricsService
    let transcriptionJobService: TranscriptionJobService
    let noteService: NoteService
    let importExportService: ImportExportService
}
```

原则：

- View 只依赖 ViewModel。
- ViewModel 只依赖 Service 协议。
- Service 只依赖 Repository/Adapter 协议。
- Infrastructure 实现协议。
- 测试用 InMemoryRepository 和 MockProvider。

---

## 9. 核心流程设计

## 9.1 听写主流程

```text
User presses hotkey
  -> HotkeyService emits .pressed
  -> DictationOrchestrator.start()
  -> PermissionService verifies microphone/accessibility/asr permission
  -> AudioCaptureService starts AVAudioEngine
  -> ASRSession starts selected ASR engine
  -> OverlayService shows non-activating HUD
  -> ASR partial updates HUD
  -> User releases hotkey
  -> DictationOrchestrator.stop()
  -> ASR final with bounded timeout
  -> TextProcessingPipeline.process(rawText)
       -> local replacement before LLM
       -> glossary prompt context
       -> style prompt
       -> LLM refinement if enabled
       -> local replacement after LLM
       -> final cleanup
  -> TextInjectionService.inject(finalText)
       -> snapshot pasteboard
       -> switch input source
       -> paste via Command-V
       -> restore input source
       -> restore pasteboard
  -> HistoryService.save()
  -> MetricsService.recalculateIncrementally()
  -> OverlayService.dismiss()
```

## 9.2 Dictation 状态机

```swift
enum DictationState: Equatable {
    case idle
    case preparing
    case recording(sessionID: UUID, startedAt: Date)
    case finalizing(sessionID: UUID)
    case processingText(sessionID: UUID, rawText: String)
    case injecting(sessionID: UUID, finalText: String)
    case completed(sessionID: UUID)
    case failed(sessionID: UUID?, error: DictationError)
}
```

合法转移：

```text
idle -> preparing
preparing -> recording
preparing -> failed
recording -> finalizing
recording -> failed
finalizing -> processingText
finalizing -> failed
processingText -> injecting
processingText -> failed_with_fallback -> injecting
injecting -> completed
injecting -> failed
completed -> idle
failed -> idle
```

## 9.3 TextPipeline

```swift
struct TextProcessingInput {
    let rawText: String
    let locale: String
    let targetApp: TargetApplication?
    let selectedStyleID: UUID?
    let asrProviderID: String
    let startedAt: Date
    let endedAt: Date
}

struct TextProcessingOutput {
    let rawText: String
    let finalText: String
    let appliedReplacementIDs: [UUID]
    let appliedGlossaryTermIDs: [UUID]
    let styleID: UUID?
    let llmProviderID: UUID?
    let warnings: [TextProcessingWarning]
}
```

处理顺序：

```text
1. normalize whitespace
2. run enabled replacement rules where stage = beforeLLM
3. detect active style
4. build glossary context
5. call LLM only if mode requires it and provider is available
6. run enabled replacement rules where stage = afterLLM
7. final cleanup: trim, remove duplicated spaces, protect code blocks
8. return output
```

---

## 10. 数据架构

## 10.1 数据库位置

```text
~/Library/Application Support/VoiceInput/voiceinput.sqlite
~/Library/Application Support/VoiceInput/Exports/
~/Library/Application Support/VoiceInput/Models/
~/Library/Caches/VoiceInput/
```

## 10.2 Migration 表

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    applied_at TEXT NOT NULL
);
```

## 10.3 历史表

```sql
CREATE TABLE IF NOT EXISTS dictation_history (
    id TEXT PRIMARY KEY,
    raw_text TEXT NOT NULL,
    final_text TEXT NOT NULL,
    language TEXT NOT NULL,
    asr_provider_id TEXT,
    llm_provider_id TEXT,
    style_id TEXT,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    char_count INTEGER NOT NULL DEFAULT 0,
    cpm REAL NOT NULL DEFAULT 0,
    target_app_bundle_id TEXT,
    target_app_name TEXT,
    processing_warnings_json TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_dictation_history_created_at ON dictation_history(created_at);
CREATE INDEX IF NOT EXISTS idx_dictation_history_deleted_at ON dictation_history(deleted_at);
```

## 10.4 词汇表

```sql
CREATE TABLE IF NOT EXISTS glossary_terms (
    id TEXT PRIMARY KEY,
    term TEXT NOT NULL,
    aliases_json TEXT NOT NULL DEFAULT '[]',
    category TEXT NOT NULL DEFAULT 'general',
    enabled INTEGER NOT NULL DEFAULT 1,
    priority INTEGER NOT NULL DEFAULT 100,
    notes TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_glossary_terms_unique ON glossary_terms(lower(term), category);
```

## 10.5 替换规则

```sql
CREATE TABLE IF NOT EXISTS replacement_rules (
    id TEXT PRIMARY KEY,
    source TEXT NOT NULL,
    target TEXT NOT NULL,
    match_mode TEXT NOT NULL DEFAULT 'contains',
    apply_stage TEXT NOT NULL DEFAULT 'beforeLLM',
    category TEXT NOT NULL DEFAULT 'general',
    enabled INTEGER NOT NULL DEFAULT 1,
    priority INTEGER NOT NULL DEFAULT 100,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

## 10.6 风格

```sql
CREATE TABLE IF NOT EXISTS style_profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    subtitle TEXT,
    mode TEXT NOT NULL DEFAULT 'conservative',
    prompt TEXT NOT NULL,
    sample_input TEXT,
    sample_output TEXT,
    llm_provider_id TEXT,
    model TEXT,
    temperature REAL NOT NULL DEFAULT 0.2,
    enabled INTEGER NOT NULL DEFAULT 1,
    built_in INTEGER NOT NULL DEFAULT 0,
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

## 10.7 Provider

```sql
CREATE TABLE IF NOT EXISTS asr_providers (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    provider_type TEXT NOT NULL,
    capabilities_json TEXT NOT NULL,
    tags_json TEXT NOT NULL,
    config_json TEXT NOT NULL DEFAULT '{}',
    enabled INTEGER NOT NULL DEFAULT 0,
    is_default INTEGER NOT NULL DEFAULT 0,
    last_health_status TEXT,
    last_health_message TEXT,
    last_checked_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS llm_providers (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    provider_type TEXT NOT NULL DEFAULT 'openaiCompatible',
    base_url TEXT NOT NULL,
    default_model TEXT NOT NULL,
    api_key_ref TEXT NOT NULL,
    temperature REAL NOT NULL DEFAULT 0.2,
    timeout_seconds REAL NOT NULL DEFAULT 8,
    enabled INTEGER NOT NULL DEFAULT 0,
    is_default INTEGER NOT NULL DEFAULT 0,
    last_health_status TEXT,
    last_health_message TEXT,
    last_latency_ms INTEGER,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

## 10.8 文件转写任务

```sql
CREATE TABLE IF NOT EXISTS transcription_jobs (
    id TEXT PRIMARY KEY,
    source_file_path TEXT NOT NULL,
    source_file_name TEXT NOT NULL,
    source_file_bookmark BLOB,
    status TEXT NOT NULL,
    progress REAL NOT NULL DEFAULT 0,
    raw_text TEXT,
    final_text TEXT,
    asr_provider_id TEXT,
    style_id TEXT,
    error_message TEXT,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    completed_at TEXT
);
```

## 10.9 笔记

```sql
CREATE TABLE IF NOT EXISTS notes (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    body_markdown TEXT NOT NULL,
    source_type TEXT NOT NULL DEFAULT 'manual',
    source_id TEXT,
    tags_json TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at);
```

## 10.10 设置

```sql
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value_json TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

设置也可部分继续放 UserDefaults，但建议统一：

| 设置类型 | 存储 |
|---|---|
| 非敏感偏好 | SQLite 或 UserDefaults |
| API Key | Keychain |
| 大文件路径授权 | security-scoped bookmark |
| 历史/词库/风格/笔记 | SQLite |

---

## 11. 推荐目录结构

```text
VoiceInput/
├── Package.swift
├── Makefile
├── README.md
├── README_EN.md
├── CONTEXT.md
├── LICENSE
├── Resources/
│   ├── Info.plist
│   ├── Assets.xcassets/
│   └── Sounds/
│       ├── start.caf
│       ├── stop.caf
│       └── done.caf
├── docs/
│   ├── PRD.md
│   ├── TECHNICAL_DESIGN.md
│   ├── ARCHITECTURE.md
│   ├── TEST_PLAN.md
│   ├── CODEX_GOAL.md
│   ├── PRIVACY.md
│   ├── interaction-references/
│   │   ├── interaction-reference-01.png
│   │   ├── interaction-reference-02.png
│   │   ├── interaction-reference-03.png
│   │   ├── interaction-reference-04.png
│   │   ├── interaction-reference-05.png
│   │   ├── interaction-reference-06.png
│   │   ├── interaction-reference-07.png
│   │   ├── interaction-reference-08.png
│   │   ├── interaction-reference-09.png
│   │   └── interaction-reference-10.png
│   └── ADR/
│       ├── 0001-appkit-swiftui-boundary.md
│       ├── 0002-sqlite3-data-layer.md
│       ├── 0003-keychain-credentials.md
│       ├── 0004-provider-registry.md
│       ├── 0005-text-injection-clipboard-restore.md
│       └── 0006-privacy-defaults.md
├── Sources/
│   └── VoiceInputApp/
│       ├── App/
│       │   ├── main.swift
│       │   ├── AppDelegate.swift
│       │   ├── AppEnvironment.swift
│       │   ├── DependencyContainer.swift
│       │   ├── AppConstants.swift
│       │   ├── AppLifecycleService.swift
│       │   └── WindowCoordinator.swift
│       ├── MenuBar/
│       │   ├── MenuBarController.swift
│       │   ├── MenuBarMenuBuilder.swift
│       │   └── MenuBarStatusModel.swift
│       ├── Presentation/
│       │   ├── Shared/
│       │   │   ├── Components/
│       │   │   │   ├── AppCard.swift
│       │   │   │   ├── AppButton.swift
│       │   │   │   ├── AppToggleRow.swift
│       │   │   │   ├── EmptyStateView.swift
│       │   │   │   ├── ErrorStateView.swift
│       │   │   │   ├── LoadingStateView.swift
│       │   │   │   ├── ProviderBadgeView.swift
│       │   │   │   ├── SearchField.swift
│       │   │   │   ├── SectionHeader.swift
│       │   │   │   └── TagPillView.swift
│       │   │   ├── Theme/
│       │   │   │   ├── AppTheme.swift
│       │   │   │   ├── AppSpacing.swift
│       │   │   │   ├── AppTypography.swift
│       │   │   │   └── AppIcons.swift
│       │   │   └── Extensions/
│       │   │       ├── Date+Formatting.swift
│       │   │       ├── String+Trimming.swift
│       │   │       └── View+CardStyle.swift
│       │   ├── Shell/
│       │   │   ├── MainWindowController.swift
│       │   │   ├── MainShellView.swift
│       │   │   ├── SidebarView.swift
│       │   │   ├── NavigationRoute.swift
│       │   │   └── ToolbarActionsView.swift
│       │   ├── Home/
│       │   │   ├── HomeView.swift
│       │   │   ├── HomeViewModel.swift
│       │   │   ├── StatsSummaryView.swift
│       │   │   ├── GoalProgressCardView.swift
│       │   │   ├── HistoryListView.swift
│       │   │   ├── HistoryRowView.swift
│       │   │   └── HistoryDetailSheet.swift
│       │   ├── Glossary/
│       │   │   ├── GlossaryView.swift
│       │   │   ├── GlossaryViewModel.swift
│       │   │   ├── GlossaryTermListView.swift
│       │   │   ├── GlossaryTermEditorSheet.swift
│       │   │   ├── ReplacementRuleListView.swift
│       │   │   ├── ReplacementRuleEditorSheet.swift
│       │   │   └── GlossaryImportExportSheet.swift
│       │   ├── Styles/
│       │   │   ├── StyleListView.swift
│       │   │   ├── StyleListViewModel.swift
│       │   │   ├── StyleCardView.swift
│       │   │   ├── StyleEditorView.swift
│       │   │   ├── StyleEditorViewModel.swift
│       │   │   ├── PromptEditorView.swift
│       │   │   ├── PromptPreviewView.swift
│       │   │   └── StyleProviderConfigView.swift
│       │   ├── Models/
│       │   │   ├── DictationModelsView.swift
│       │   │   ├── DictationModelsViewModel.swift
│       │   │   ├── ASRProviderCardView.swift
│       │   │   ├── ASRProviderConfigSheet.swift
│       │   │   ├── LocalModelDownloadView.swift
│       │   │   ├── LLMProviderConfigSheet.swift
│       │   │   └── ProviderHealthView.swift
│       │   ├── FileTranscription/
│       │   │   ├── FileTranscriptionView.swift
│       │   │   ├── FileTranscriptionViewModel.swift
│       │   │   ├── FileDropZoneView.swift
│       │   │   ├── TranscriptionJobListView.swift
│       │   │   ├── TranscriptionJobRowView.swift
│       │   │   ├── TranscriptionJobDetailView.swift
│       │   │   └── ExportTranscriptionSheet.swift
│       │   ├── Notes/
│       │   │   ├── NotesView.swift
│       │   │   ├── NotesViewModel.swift
│       │   │   ├── NoteListView.swift
│       │   │   ├── NoteEditorView.swift
│       │   │   ├── NoteTagEditorView.swift
│       │   │   └── NoteExportSheet.swift
│       │   ├── Settings/
│       │   │   ├── SettingsWindowController.swift
│       │   │   ├── SettingsRootView.swift
│       │   │   ├── SettingsViewModel.swift
│       │   │   ├── GeneralSettingsView.swift
│       │   │   ├── SystemSettingsView.swift
│       │   │   ├── DataPrivacySettingsView.swift
│       │   │   ├── PermissionStatusView.swift
│       │   │   ├── ShortcutRecorderView.swift
│       │   │   ├── AudioDevicePickerView.swift
│       │   │   └── DataManagementView.swift
│       │   ├── Help/
│       │   │   ├── HelpView.swift
│       │   │   ├── HelpViewModel.swift
│       │   │   └── HelpLinkRowView.swift
│       │   └── Overlay/
│       │       ├── OverlayWindowController.swift
│       │       ├── DictationOverlayView.swift
│       │       ├── WaveformView.swift
│       │       ├── OverlayState.swift
│       │       └── OverlayLayout.swift
│       ├── Domain/
│       │   ├── Common/
│       │   │   ├── EntityID.swift
│       │   │   ├── AppError.swift
│       │   │   ├── ResultState.swift
│       │   │   └── Clock.swift
│       │   ├── Dictation/
│       │   │   ├── DictationState.swift
│       │   │   ├── DictationSession.swift
│       │   │   ├── DictationResult.swift
│       │   │   ├── DictationError.swift
│       │   │   └── TargetApplication.swift
│       │   ├── Audio/
│       │   │   ├── AudioDevice.swift
│       │   │   ├── AudioLevel.swift
│       │   │   └── AudioEnhancementSettings.swift
│       │   ├── ASR/
│       │   │   ├── ASREngine.swift
│       │   │   ├── ASRProvider.swift
│       │   │   ├── ASRProviderCapabilities.swift
│       │   │   ├── ASRConfiguration.swift
│       │   │   ├── ASRResult.swift
│       │   │   └── ASRError.swift
│       │   ├── LLM/
│       │   │   ├── LLMProvider.swift
│       │   │   ├── LLMRequest.swift
│       │   │   ├── LLMResponse.swift
│       │   │   ├── LLMError.swift
│       │   │   └── PromptTemplate.swift
│       │   ├── TextProcessing/
│       │   │   ├── TextProcessingInput.swift
│       │   │   ├── TextProcessingOutput.swift
│       │   │   ├── TextProcessingWarning.swift
│       │   │   ├── ReplacementRule.swift
│       │   │   ├── GlossaryTerm.swift
│       │   │   └── StyleProfile.swift
│       │   ├── History/
│       │   │   └── DictationHistoryItem.swift
│       │   ├── FileTranscription/
│       │   │   ├── TranscriptionJob.swift
│       │   │   ├── TranscriptionJobStatus.swift
│       │   │   └── TranscriptionExportFormat.swift
│       │   ├── Notes/
│       │   │   ├── Note.swift
│       │   │   └── NoteSource.swift
│       │   └── Settings/
│       │       ├── AppSettings.swift
│       │       ├── ShortcutConfiguration.swift
│       │       ├── PrivacySettings.swift
│       │       └── RecordingMode.swift
│       ├── Services/
│       │   ├── Dictation/
│       │   │   ├── DictationOrchestrator.swift
│       │   │   ├── DictationOrchestratorProtocol.swift
│       │   │   └── DictationSessionStore.swift
│       │   ├── Hotkey/
│       │   │   ├── HotkeyService.swift
│       │   │   ├── KeyMonitor.swift
│       │   │   ├── ShortcutManager.swift
│       │   │   └── ShortcutRecorderService.swift
│       │   ├── Audio/
│       │   │   ├── AudioCaptureService.swift
│       │   │   ├── AudioDeviceService.swift
│       │   │   ├── AudioPreprocessor.swift
│       │   │   ├── SoundFeedbackService.swift
│       │   │   └── SystemAudioDuckingService.swift
│       │   ├── ASR/
│       │   │   ├── ASRManager.swift
│       │   │   ├── ASRProviderRegistry.swift
│       │   │   ├── AppleSpeechEngine.swift
│       │   │   ├── Qwen3ASREngine.swift
│       │   │   ├── Qwen3ModelDownloader.swift
│       │   │   ├── CloudASREngine.swift
│       │   │   └── ASRHealthCheckService.swift
│       │   ├── LLM/
│       │   │   ├── LLMProviderRegistry.swift
│       │   │   ├── LLMRefiner.swift
│       │   │   ├── OpenAICompatibleClient.swift
│       │   │   ├── PromptBuilder.swift
│       │   │   └── LLMHealthCheckService.swift
│       │   ├── TextProcessing/
│       │   │   ├── TextProcessingPipeline.swift
│       │   │   ├── ReplacementProcessor.swift
│       │   │   ├── GlossaryContextBuilder.swift
│       │   │   ├── StyleResolver.swift
│       │   │   └── TextNormalizer.swift
│       │   ├── Injection/
│       │   │   ├── TextInjectionService.swift
│       │   │   ├── TextInjector.swift
│       │   │   ├── PasteboardSnapshot.swift
│       │   │   ├── InputSourceGuard.swift
│       │   │   └── TargetApplicationService.swift
│       │   ├── History/
│       │   │   ├── HistoryService.swift
│       │   │   └── HistorySearchService.swift
│       │   ├── Glossary/
│       │   │   ├── GlossaryService.swift
│       │   │   └── GlossaryImportExportService.swift
│       │   ├── Styles/
│       │   │   ├── StyleService.swift
│       │   │   └── BuiltInStyleSeeder.swift
│       │   ├── FileTranscription/
│       │   │   ├── TranscriptionJobService.swift
│       │   │   ├── FileTranscriptionQueue.swift
│       │   │   ├── MediaFileInspector.swift
│       │   │   └── TranscriptionExportService.swift
│       │   ├── Notes/
│       │   │   ├── NoteService.swift
│       │   │   └── NoteExportService.swift
│       │   ├── Permissions/
│       │   │   ├── PermissionService.swift
│       │   │   ├── PermissionStatus.swift
│       │   │   └── SystemSettingsOpener.swift
│       │   ├── Metrics/
│       │   │   ├── MetricsService.swift
│       │   │   └── UsageStreakCalculator.swift
│       │   ├── Settings/
│       │   │   ├── SettingsService.swift
│       │   │   └── SettingsSeeder.swift
│       │   └── ImportExport/
│       │       ├── ImportExportService.swift
│       │       ├── BackupArchiveWriter.swift
│       │       └── BackupArchiveReader.swift
│       ├── Data/
│       │   ├── Database/
│       │   │   ├── AppDatabase.swift
│       │   │   ├── SQLiteConnection.swift
│       │   │   ├── SQLiteStatement.swift
│       │   │   ├── DatabaseMigrator.swift
│       │   │   ├── DatabaseQueue.swift
│       │   │   └── Migrations/
│       │   │       ├── Migration001InitialSchema.swift
│       │   │       ├── Migration002SeedBuiltIns.swift
│       │   │       └── Migration003CredentialMigration.swift
│       │   ├── Repositories/
│       │   │   ├── HistoryRepository.swift
│       │   │   ├── SQLiteHistoryRepository.swift
│       │   │   ├── GlossaryRepository.swift
│       │   │   ├── SQLiteGlossaryRepository.swift
│       │   │   ├── ReplacementRuleRepository.swift
│       │   │   ├── SQLiteReplacementRuleRepository.swift
│       │   │   ├── StyleRepository.swift
│       │   │   ├── SQLiteStyleRepository.swift
│       │   │   ├── ASRProviderRepository.swift
│       │   │   ├── SQLiteASRProviderRepository.swift
│       │   │   ├── LLMProviderRepository.swift
│       │   │   ├── SQLiteLLMProviderRepository.swift
│       │   │   ├── TranscriptionJobRepository.swift
│       │   │   ├── SQLiteTranscriptionJobRepository.swift
│       │   │   ├── NoteRepository.swift
│       │   │   ├── SQLiteNoteRepository.swift
│       │   │   ├── SettingsRepository.swift
│       │   │   └── SQLiteSettingsRepository.swift
│       │   ├── Keychain/
│       │   │   ├── SecureCredentialStore.swift
│       │   │   └── KeychainCredentialStore.swift
│       │   ├── UserDefaults/
│       │   │   └── LegacyPreferencesMigrator.swift
│       │   └── Fixtures/
│       │       ├── BuiltInStyles.json
│       │       ├── BuiltInASRProviders.json
│       │       └── BuiltInSettings.json
│       ├── Infrastructure/
│       │   ├── Network/
│       │   │   ├── HTTPClient.swift
│       │   │   ├── URLSessionHTTPClient.swift
│       │   │   ├── RetryPolicy.swift
│       │   │   └── RedactedRequestLogger.swift
│       │   ├── Logging/
│       │   │   ├── AppLogger.swift
│       │   │   └── LogCategory.swift
│       │   ├── Files/
│       │   │   ├── ApplicationSupportPaths.swift
│       │   │   ├── SecurityScopedBookmarkStore.swift
│       │   │   └── TemporaryFileStore.swift
│       │   └── Updates/
│       │       └── UpdateServicePlaceholder.swift
│       └── Resources/
│           ├── Localizable.strings
│           ├── zh-Hans.lproj/
│           └── en.lproj/
└── Tests/
    └── VoiceInputAppTests/
        ├── TestSupport/
        │   ├── MockASREngine.swift
        │   ├── MockLLMClient.swift
        │   ├── MockTextInjector.swift
        │   ├── InMemoryRepositories.swift
        │   ├── TemporaryDatabaseFactory.swift
        │   └── TestFixtures.swift
        ├── Dictation/
        │   ├── DictationOrchestratorTests.swift
        │   └── DictationStateMachineTests.swift
        ├── TextProcessing/
        │   ├── TextProcessingPipelineTests.swift
        │   ├── ReplacementProcessorTests.swift
        │   ├── GlossaryContextBuilderTests.swift
        │   ├── StyleResolverTests.swift
        │   └── PromptBuilderTests.swift
        ├── Providers/
        │   ├── ASRProviderRegistryTests.swift
        │   ├── ASRManagerTests.swift
        │   ├── LLMProviderRegistryTests.swift
        │   ├── OpenAICompatibleClientTests.swift
        │   └── ProviderHealthCheckTests.swift
        ├── Data/
        │   ├── DatabaseMigrationTests.swift
        │   ├── HistoryRepositoryTests.swift
        │   ├── GlossaryRepositoryTests.swift
        │   ├── StyleRepositoryTests.swift
        │   └── KeychainCredentialStoreTests.swift
        ├── Injection/
        │   ├── PasteboardSnapshotTests.swift
        │   ├── InputSourceGuardTests.swift
        │   └── TextInjectorTests.swift
        ├── Settings/
        │   ├── ShortcutManagerTests.swift
        │   ├── PermissionServiceTests.swift
        │   └── SettingsServiceTests.swift
        ├── FileTranscription/
        │   ├── TranscriptionJobServiceTests.swift
        │   └── TranscriptionExportServiceTests.swift
        ├── Notes/
        │   └── NoteServiceTests.swift
        └── UISmoke/
            ├── MainNavigationSmokeTests.swift
            └── SettingsSmokeTests.swift
```

---

## 12. 组件拆分说明

### 12.1 App 层

| 组件 | 职责 |
|---|---|
| `AppDelegate` | 启动应用、初始化环境、菜单栏、权限预检、窗口协调器 |
| `AppEnvironment` | 持有所有服务实例，注入 SwiftUI Environment |
| `DependencyContainer` | 创建真实实现或测试实现 |
| `WindowCoordinator` | 打开/关闭主窗口、设置窗口、弹窗 |
| `MenuBarController` | 菜单栏图标、菜单项、状态展示 |

### 12.2 Presentation 层

| 组件 | 职责 |
|---|---|
| `MainShellView` | 主窗口容器，左侧导航和内容区域 |
| `SidebarView` | 导航列表、选中状态、底部入口 |
| `HomeViewModel` | 加载统计和历史，处理搜索/复制/删除 |
| `GlossaryViewModel` | 管理词汇表和替换规则 |
| `StyleEditorViewModel` | Prompt 编辑、预览、保存、Provider 绑定 |
| `DictationModelsViewModel` | Provider 列表、筛选、健康检查 |
| `SettingsViewModel` | 设置读取、保存、权限刷新 |
| `FileTranscriptionViewModel` | 文件导入、任务队列、进度 |
| `NotesViewModel` | 笔记列表、搜索、编辑 |
| `OverlayWindowController` | 非激活 HUD 窗口 |

### 12.3 Service 层

| 服务 | 职责 |
|---|---|
| `DictationOrchestrator` | 听写全链路编排 |
| `AudioCaptureService` | 录音、音量、设备选择 |
| `ASRManager` | 创建和驱动 ASR session |
| `TextProcessingPipeline` | 文本处理流水线 |
| `LLMRefiner` | 调用 LLM 做保守纠错/风格处理 |
| `TextInjectionService` | 调用注入、恢复输入法和剪贴板 |
| `HistoryService` | 历史保存、查询、删除 |
| `GlossaryService` | 词库管理和导入导出 |
| `StyleService` | 风格管理、内置风格初始化 |
| `PermissionService` | 权限状态查询和跳转 |
| `MetricsService` | 统计指标计算 |
| `TranscriptionJobService` | 文件转写任务 |
| `NoteService` | 笔记 CRUD |
| `ImportExportService` | 全量备份恢复 |

### 12.4 Data 层

| 组件 | 职责 |
|---|---|
| `SQLiteConnection` | 打开/关闭数据库、执行 SQL |
| `DatabaseQueue` | 串行化数据库访问 |
| `DatabaseMigrator` | 管理 migration |
| `SQLite*Repository` | SQL 实现 |
| `KeychainCredentialStore` | API Key 安全存储 |
| `LegacyPreferencesMigrator` | 从 UserDefaults 迁移旧配置 |

---

## 13. UI 细节规范

## 13.1 主窗口

| 属性 | 要求 |
|---|---|
| 最小尺寸 | 1100 x 720 |
| 推荐尺寸 | 1280 x 820 |
| 左侧栏宽度 | 220 |
| 内容最大宽 | 900-1000，可居中 |
| 背景 | 浅色/深色跟随系统 |
| 圆角 | 卡片 12-16 |
| 间距 | 页面 24-32，卡片内 16-24 |

## 13.2 首页

组件：

```text
HomeView
├── Header: 欢迎回来 + 快捷统计
├── GoalProgressCard
├── SearchAndFilterBar
└── HistoryList
    ├── DateSection
    └── HistoryRow
```

历史行内容：

- 时间。
- 最终文本摘要。
- 状态标记：已纠错 / 原文 / 失败回退。
- 操作：复制、详情、删除、重新处理。

## 13.3 词汇表

组件：

```text
GlossaryView
├── ModeTabs: 易错词 / 文本替换
├── AddInputArea
├── SearchBar
├── TermList 或 ReplacementRuleList
└── ImportExportActions
```

## 13.4 风格

组件：

```text
StyleListView
├── EnableToggle
├── CategorySegmentedControl
├── ContextHintCard
└── StyleGrid
    └── StyleCard
```

编辑器：

```text
StyleEditorView
├── Header: 返回 + 保存
├── BasicInfoSection
├── PromptSection
├── ProviderParameterDisclosure
├── PreviewSection
│   ├── InputEditor
│   └── OutputPreview
└── DangerZone
```

## 13.5 听写模型

组件：

```text
DictationModelsView
├── FilterPills
└── ProviderList
    └── ProviderCard
        ├── Icon
        ├── Name + Badges
        ├── Description
        ├── Actions: 配置 / 查看模型 / 测试
        └── SelectionControl
```

## 13.6 设置中心

设置是 modal window，不应嵌入主窗口也可从主窗口导航打开。要求：

- 左侧二级导航。
- 右侧滚动内容。
- 权限状态实时刷新。
- 保存即时生效。
- 危险操作二次确认。

---

## 14. Provider 协议设计

### 14.1 ASR 协议

```swift
protocol ASREngine: AnyObject {
    var providerID: String { get }
    var displayName: String { get }
    var capabilities: ASRProviderCapabilities { get }

    func prepare(configuration: ASRConfiguration) async throws
    func startStreaming(locale: LocaleIdentifier) async throws -> AsyncThrowingStream<ASRPartialResult, Error>
    func appendAudioBuffer(_ buffer: AudioPCMBuffer) async throws
    func stopStreaming() async throws -> ASRResult
    func transcribeFile(_ file: MediaFile, progress: @escaping (Double) -> Void) async throws -> ASRResult
    func cancel()
}
```

### 14.2 LLM 协议

```swift
protocol LLMClient {
    func complete(_ request: LLMRequest) async throws -> LLMResponse
    func testConnection(provider: LLMProvider) async throws -> ProviderHealthResult
    func listModels(provider: LLMProvider) async throws -> [String]
}
```

### 14.3 Provider Registry

```swift
final class ASRProviderRegistry {
    func register(_ descriptor: ASRProviderDescriptor)
    func descriptors(matching filter: ASRProviderFilter) -> [ASRProviderDescriptor]
    func makeEngine(providerID: String) throws -> ASREngine
    func defaultProvider() async throws -> ASRProviderDescriptor
}
```

```swift
final class LLMProviderRegistry {
    func enabledProviders() async throws -> [LLMProvider]
    func defaultProvider() async throws -> LLMProvider?
    func provider(for style: StyleProfile) async throws -> LLMProvider?
    func test(providerID: UUID) async -> ProviderHealthResult
}
```

---

## 15. 隐私与安全设计

### 15.1 默认策略

| 项 | 默认 |
|---|---|
| LLM | 关闭 |
| 云 ASR | 关闭 |
| 本地历史 | 开启 |
| 保存音频 | 关闭 |
| 使用分析 | 关闭或首次询问 |
| API Key | Keychain |
| 日志 | 脱敏 |

### 15.2 数据发送说明

必须在 Data & Privacy 页面展示：

| 功能 | 发送内容 | 发送到哪里 | 何时发送 |
|---|---|---|---|
| Apple Speech | 音频或系统处理数据 | Apple 服务/系统框架，取决于系统配置 | 使用 Apple Speech 时 |
| 本地 ASR | 不发送 | 本机 | 使用本地模型时 |
| 云 ASR | 音频片段或文件 | 用户配置的 provider | 用户选择云 ASR 时 |
| LLM 纠错 | ASR 后文本，不含音频 | 用户配置的 provider | 用户开启 LLM/风格时 |
| 使用分析 | 匿名统计 | 暂无或用户配置 | 用户开启分析时 |

### 15.3 日志脱敏规则

- API Key 只显示前 4 后 4，中间替换为 `***`。
- URL query 中疑似 token 参数移除。
- 不记录完整识别文本，除非 debug 开关明确打开。
- 不记录剪贴板内容。
- 文件路径可记录文件名，不记录完整用户目录，或用 `~` 替代 home。

---

## 16. 测试计划

## 16.1 单元测试矩阵

| 测试文件 | 覆盖 |
|---|---|
| `DictationStateMachineTests` | 状态合法转移、非法转移拒绝 |
| `DictationOrchestratorTests` | start/stop/fallback/history 保存 |
| `TextProcessingPipelineTests` | 替换、风格、LLM 回退、空文本 |
| `ReplacementProcessorTests` | exact/contains/regex、优先级、禁用 |
| `GlossaryContextBuilderTests` | 词库筛选、去重、Prompt 限长 |
| `StyleResolverTests` | 默认风格、按应用自动选择、关闭状态 |
| `PromptBuilderTests` | 模板变量、硬约束、词库注入 |
| `ASRProviderRegistryTests` | 注册、筛选、默认、fallback |
| `LLMProviderRegistryTests` | 默认 provider、风格绑定、不可用回退 |
| `OpenAICompatibleClientTests` | URL 归一化、响应解析、错误解析 |
| `DatabaseMigrationTests` | 新库初始化、旧配置迁移、幂等 |
| `KeychainCredentialStoreTests` | 保存、读取、删除、覆盖 |
| `PasteboardSnapshotTests` | 多 item、多类型恢复 |
| `InputSourceGuardTests` | CJK 检测、安全输入源选择、恢复 |
| `ShortcutManagerTests` | 右 Command 默认、自定义快捷键、短按行为 |
| `PermissionServiceTests` | 权限状态聚合、跳转 URL 构造 |
| `TranscriptionJobServiceTests` | 队列、取消、重试、导出 |
| `NoteServiceTests` | CRUD、搜索、从历史生成 |

## 16.2 集成测试场景

| ID | 场景 | 步骤 | 预期 |
|---|---|---|---|
| IT-001 | 无 LLM 听写 | Mock ASR 返回文本 | 直接注入，保存历史 |
| IT-002 | LLM 成功 | Mock LLM 返回修正文本 | 注入修正文本，记录 provider |
| IT-003 | LLM 超时 | Mock LLM sleep 超时 | 注入原文，记录 warning |
| IT-004 | ASR fallback | 当前 ASR 抛错 | 回退备用 provider |
| IT-005 | 数据迁移 | 准备旧 UserDefaults | 迁移到 SQLite/Keychain |
| IT-006 | 文件转写 | Mock file ASR | 任务完成，可导出 |

## 16.3 手工测试清单

| 编号 | 测试 | 结果 |
|---|---|---|
| MAN-001 | 微信输入框听写 | 文本正确注入 |
| MAN-002 | Chrome 地址栏听写 | 文本正确注入 |
| MAN-003 | VS Code 编辑器听写 | 文本正确注入 |
| MAN-004 | Xcode 编辑器听写 | 文本正确注入 |
| MAN-005 | Terminal 听写 | 文本正确注入 |
| MAN-006 | 飞书/企业微信输入框听写 | 文本正确注入 |
| MAN-007 | 当前剪贴板为图片 | 听写后图片仍在剪贴板 |
| MAN-008 | 当前剪贴板为富文本 | 听写后富文本仍在剪贴板 |
| MAN-009 | 中文输入法状态 | 注入后输入法恢复 |
| MAN-010 | 关闭网络 | LLM/云 ASR 回退 |
| MAN-011 | 未授权麦克风 | 设置页提示明确 |
| MAN-012 | 未授权辅助功能 | 快捷键提示明确 |
| MAN-013 | 大文件转写取消 | 状态变 cancelled |
| MAN-014 | 数据导出导入 | 数据完整恢复 |

---

## 17. 完整 Task List

> 这些 task 必须全部完成。编号可直接变成 GitHub Issues 或 Codex 子任务。  
> 标记说明：`[P0]` 核心必需；`[P1]` 完整体验必需；`[P2]` 加分但本次也要做基础可用。

### 17.1 项目准备与文档

- [ ] TASK-0001 [P0] 新建 `docs/PRD.md`，写入产品定义、用户故事、验收标准。
- [ ] TASK-0002 [P0] 新建 `docs/TECHNICAL_DESIGN.md`，写入架构、数据层、Provider、状态机。
- [ ] TASK-0003 [P0] 新建 `docs/ARCHITECTURE.md`，写入目录结构和模块边界。
- [ ] TASK-0004 [P0] 新建 `docs/TEST_PLAN.md`，写入单元/集成/手工测试清单。
- [ ] TASK-0005 [P0] 新建 `docs/CODEX_GOAL.md`，写入可执行 Goal。
- [ ] TASK-0006 [P0] 新建 `docs/PRIVACY.md`，写入隐私策略和数据发送说明。
- [ ] TASK-0007 [P0] 把交互参考图复制到 `docs/interaction-references/`。
- [ ] TASK-0008 [P0] 更新 README，说明新增工作台能力。
- [ ] TASK-0009 [P0] 更新 CONTEXT，写清楚新模块边界和禁止越界规则。

### 17.2 基础架构重组

- [ ] TASK-0101 [P0] 新建 `AppEnvironment`，集中持有服务。
- [ ] TASK-0102 [P0] 新建 `DependencyContainer`，负责组装真实服务。
- [ ] TASK-0103 [P0] 新建 `WindowCoordinator`，管理主窗口、设置窗口、弹窗。
- [ ] TASK-0104 [P0] 保持 `AppDelegate` 简洁，只负责生命周期和依赖启动。
- [ ] TASK-0105 [P0] 抽象 `Clock`，便于测试时间相关逻辑。
- [ ] TASK-0106 [P0] 新建 `AppLogger`，统一 OSLog 和脱敏。
- [ ] TASK-0107 [P0] 新建 `ApplicationSupportPaths`，统一数据目录。
- [ ] TASK-0108 [P0] 建立 SwiftUI Theme：颜色、字体、间距、卡片样式。

### 17.3 数据库与 Repository

- [ ] TASK-0201 [P0] 实现 `SQLiteConnection`。
- [ ] TASK-0202 [P0] 实现 `SQLiteStatement`。
- [ ] TASK-0203 [P0] 实现 `DatabaseQueue` 串行执行。
- [ ] TASK-0204 [P0] 实现 `DatabaseMigrator`。
- [ ] TASK-0205 [P0] 创建 `schema_migrations` 表。
- [ ] TASK-0206 [P0] 创建 `dictation_history` 表。
- [ ] TASK-0207 [P0] 创建 `glossary_terms` 表。
- [ ] TASK-0208 [P0] 创建 `replacement_rules` 表。
- [ ] TASK-0209 [P0] 创建 `style_profiles` 表。
- [ ] TASK-0210 [P0] 创建 `asr_providers` 表。
- [ ] TASK-0211 [P0] 创建 `llm_providers` 表。
- [ ] TASK-0212 [P0] 创建 `transcription_jobs` 表。
- [ ] TASK-0213 [P0] 创建 `notes` 表。
- [ ] TASK-0214 [P0] 创建 `app_settings` 表。
- [ ] TASK-0215 [P0] 实现 `HistoryRepository`。
- [ ] TASK-0216 [P0] 实现 `GlossaryRepository`。
- [ ] TASK-0217 [P0] 实现 `ReplacementRuleRepository`。
- [ ] TASK-0218 [P0] 实现 `StyleRepository`。
- [ ] TASK-0219 [P0] 实现 `ASRProviderRepository`。
- [ ] TASK-0220 [P0] 实现 `LLMProviderRepository`。
- [ ] TASK-0221 [P0] 实现 `TranscriptionJobRepository`。
- [ ] TASK-0222 [P0] 实现 `NoteRepository`。
- [ ] TASK-0223 [P0] 实现 `SettingsRepository`。
- [ ] TASK-0224 [P0] 为所有 Repository 增加单元测试。

### 17.4 Keychain 与旧配置迁移

- [ ] TASK-0301 [P0] 实现 `SecureCredentialStore` 协议。
- [ ] TASK-0302 [P0] 实现 `KeychainCredentialStore`。
- [ ] TASK-0303 [P0] LLM API Key 从 UserDefaults 迁移到 Keychain。
- [ ] TASK-0304 [P0] 迁移成功后删除 UserDefaults 中的明文 Key。
- [ ] TASK-0305 [P0] 日志中禁止打印 API Key。
- [ ] TASK-0306 [P0] Provider 删除时同步删除 Keychain 项。
- [ ] TASK-0307 [P0] 增加 Keychain 保存/读取/覆盖/删除测试。

### 17.5 主窗口与导航

- [ ] TASK-0401 [P0] 实现 `MainWindowController`。
- [ ] TASK-0402 [P0] 实现 `MainShellView`。
- [ ] TASK-0403 [P0] 实现 `NavigationRoute`。
- [ ] TASK-0404 [P0] 实现 `SidebarView`。
- [ ] TASK-0405 [P0] 左侧导航包含：首页、词汇表、风格、文件转写、笔记、听写模型、设置、帮助。
- [ ] TASK-0406 [P0] 底部保留设置和帮助入口。
- [ ] TASK-0407 [P0] 菜单栏增加“打开主窗口”。
- [ ] TASK-0408 [P0] 主窗口关闭不退出应用。
- [ ] TASK-0409 [P0] 主窗口状态恢复上次大小和位置。
- [ ] TASK-0410 [P1] 支持浅色/深色模式。

### 17.6 首页

- [ ] TASK-0501 [P0] 实现 `HomeViewModel`。
- [ ] TASK-0502 [P0] 实现统计加载：累计字符、今日字符、CPM、连续使用。
- [ ] TASK-0503 [P0] 实现 `StatsSummaryView`。
- [ ] TASK-0504 [P0] 实现目标进度卡。
- [ ] TASK-0505 [P0] 实现历史按日期分组。
- [ ] TASK-0506 [P0] 实现历史搜索。
- [ ] TASK-0507 [P0] 实现复制历史文本。
- [ ] TASK-0508 [P0] 实现删除历史。
- [ ] TASK-0509 [P1] 实现历史详情 sheet。
- [ ] TASK-0510 [P1] 实现原文/最终文本展示。
- [ ] TASK-0511 [P1] 实现历史重新处理。
- [ ] TASK-0512 [P0] 实现空状态。
- [ ] TASK-0513 [P0] 增加 `MetricsService` 测试。

### 17.7 核心听写编排

- [ ] TASK-0601 [P0] 抽出 `DictationOrchestrator`。
- [ ] TASK-0602 [P0] 定义 `DictationState`。
- [ ] TASK-0603 [P0] 定义 `DictationSession`。
- [ ] TASK-0604 [P0] 连接 HotkeyService -> DictationOrchestrator。
- [ ] TASK-0605 [P0] 连接 AudioCaptureService -> ASRManager。
- [ ] TASK-0606 [P0] 连接 ASR partial -> Overlay。
- [ ] TASK-0607 [P0] 实现 final bounded timeout。
- [ ] TASK-0608 [P0] 实现 latest partial fallback。
- [ ] TASK-0609 [P0] 实现 LLM fallback。
- [ ] TASK-0610 [P0] 实现注入成功后保存历史。
- [ ] TASK-0611 [P0] 失败时显示非阻塞提示。
- [ ] TASK-0612 [P0] 增加状态机测试。
- [ ] TASK-0613 [P0] 增加听写链路集成测试。

### 17.8 快捷键系统

- [ ] TASK-0701 [P0] 保留右 Command 默认值。
- [ ] TASK-0702 [P0] 保留左 Command 不受影响。
- [ ] TASK-0703 [P0] 实现快捷键录制 UI。
- [ ] TASK-0704 [P0] 实现长按阈值配置。
- [ ] TASK-0705 [P0] 实现短按行为配置。
- [ ] TASK-0706 [P0] 快捷键配置即时生效。
- [ ] TASK-0707 [P0] 快捷键冲突提示。
- [ ] TASK-0708 [P0] 增加 ShortcutManager 测试。

### 17.9 HUD/Overlay

- [ ] TASK-0801 [P0] 保持 HUD non-activating。
- [ ] TASK-0802 [P0] 实现录音状态显示。
- [ ] TASK-0803 [P0] 实现实时文本显示。
- [ ] TASK-0804 [P0] 实现波形显示。
- [ ] TASK-0805 [P0] 实现 processing/refining/injecting 状态。
- [ ] TASK-0806 [P0] 实现失败提示状态。
- [ ] TASK-0807 [P0] HUD 不抢焦点测试或手工验证。

### 17.10 文本注入

- [ ] TASK-0901 [P0] 保留 `PasteboardSnapshot` 多类型快照。
- [ ] TASK-0902 [P0] 保留 `InputSourceGuard`。
- [ ] TASK-0903 [P0] 注入前切安全输入源。
- [ ] TASK-0904 [P0] 注入后恢复输入源。
- [ ] TASK-0905 [P0] 注入后恢复剪贴板。
- [ ] TASK-0906 [P0] 注入失败也尝试恢复。
- [ ] TASK-0907 [P0] 增加多 item 剪贴板测试。
- [ ] TASK-0908 [P0] 增加 CJK 输入法测试。

### 17.11 词汇表

- [ ] TASK-1001 [P0] 定义 `GlossaryTerm`。
- [ ] TASK-1002 [P0] 定义 `ReplacementRule`。
- [ ] TASK-1003 [P0] 实现 `GlossaryService`。
- [ ] TASK-1004 [P0] 实现 `ReplacementProcessor`。
- [ ] TASK-1005 [P0] 实现易错词 UI。
- [ ] TASK-1006 [P0] 实现文本替换 UI。
- [ ] TASK-1007 [P0] 实现批量添加。
- [ ] TASK-1008 [P0] 实现搜索。
- [ ] TASK-1009 [P0] 实现启用/禁用。
- [ ] TASK-1010 [P0] 实现删除。
- [ ] TASK-1011 [P1] 实现导入 JSON/CSV。
- [ ] TASK-1012 [P1] 实现导出 JSON/CSV。
- [ ] TASK-1013 [P0] 词汇表进入 PromptBuilder。
- [ ] TASK-1014 [P0] 增加 Glossary 测试。

### 17.12 风格系统

- [ ] TASK-1101 [P0] 定义 `StyleProfile`。
- [ ] TASK-1102 [P0] 实现内置风格 seeder。
- [ ] TASK-1103 [P0] 内置原文风格。
- [ ] TASK-1104 [P0] 内置正式风格。
- [ ] TASK-1105 [P0] 内置日常风格。
- [ ] TASK-1106 [P0] 内置元气风格。
- [ ] TASK-1107 [P0] 内置编程风格。
- [ ] TASK-1108 [P0] 内置邮件风格。
- [ ] TASK-1109 [P0] 实现风格列表 UI。
- [ ] TASK-1110 [P0] 实现风格卡片。
- [ ] TASK-1111 [P0] 实现分类切换。
- [ ] TASK-1112 [P0] 实现全局风格开关。
- [ ] TASK-1113 [P0] 实现风格编辑器。
- [ ] TASK-1114 [P0] 实现 Prompt 编辑。
- [ ] TASK-1115 [P0] 实现 LLM 参数配置。
- [ ] TASK-1116 [P0] 实现调试预览。
- [ ] TASK-1117 [P0] 实现设为默认。
- [ ] TASK-1118 [P1] 实现复制风格。
- [ ] TASK-1119 [P1] 实现删除自定义风格。
- [ ] TASK-1120 [P1] 实现按应用自动选择。
- [ ] TASK-1121 [P0] 增加 StyleResolver 测试。
- [ ] TASK-1122 [P0] 增加 PromptBuilder 测试。

### 17.13 LLM Provider

- [ ] TASK-1201 [P0] 定义 `LLMProvider`。
- [ ] TASK-1202 [P0] 实现 `OpenAICompatibleClient`。
- [ ] TASK-1203 [P0] 实现 Base URL 归一化。
- [ ] TASK-1204 [P0] 实现 Provider CRUD。
- [ ] TASK-1205 [P0] 实现 LLM 配置弹窗。
- [ ] TASK-1206 [P0] 实现 API Key 显示/隐藏。
- [ ] TASK-1207 [P0] 实现测试连接。
- [ ] TASK-1208 [P1] 实现模型列表获取。
- [ ] TASK-1209 [P1] 实现测速展示。
- [ ] TASK-1210 [P0] 实现 Provider 错误展示。
- [ ] TASK-1211 [P0] 实现默认 provider。
- [ ] TASK-1212 [P0] 风格绑定 provider。
- [ ] TASK-1213 [P0] LLM 失败回退。
- [ ] TASK-1214 [P0] 增加 URL 归一化和响应解析测试。

### 17.14 ASR Provider

- [ ] TASK-1301 [P0] 定义 `ASRProvider` 和 capabilities。
- [ ] TASK-1302 [P0] 实现 `ASRProviderRegistry`。
- [ ] TASK-1303 [P0] 接入 Apple Speech provider。
- [ ] TASK-1304 [P0] 接入 Qwen3-ASR provider。
- [ ] TASK-1305 [P0] 实现本地模型下载状态 UI。
- [ ] TASK-1306 [P0] 实现模型文件校验。
- [ ] TASK-1307 [P0] 实现听写模型列表页。
- [ ] TASK-1308 [P0] 实现标签筛选。
- [ ] TASK-1309 [P0] 实现 provider 配置弹窗。
- [ ] TASK-1310 [P0] 实现 provider 健康检查。
- [ ] TASK-1311 [P0] 实现默认 ASR provider。
- [ ] TASK-1312 [P0] 实现 ASR 回退策略。
- [ ] TASK-1313 [P1] 实现云 ASR provider 基础协议。
- [ ] TASK-1314 [P1] 实现 provider 测速。
- [ ] TASK-1315 [P0] 增加 ASRProviderRegistry 测试。

### 17.15 设置中心

- [ ] TASK-1401 [P0] 实现 `SettingsRootView`。
- [ ] TASK-1402 [P0] 实现左侧二级导航。
- [ ] TASK-1403 [P0] 实现通用设置页。
- [ ] TASK-1404 [P0] 实现输入设备选择。
- [ ] TASK-1405 [P0] 实现快捷键设置区。
- [ ] TASK-1406 [P0] 实现录音模式设置。
- [ ] TASK-1407 [P0] 实现系统设置页。
- [ ] TASK-1408 [P0] 实现提示音开关。
- [ ] TASK-1409 [P1] 实现录音时静音开关。
- [ ] TASK-1410 [P0] 实现声音增强开关。
- [ ] TASK-1411 [P1] 实现声音增强参数。
- [ ] TASK-1412 [P1] 实现性能优化开关。
- [ ] TASK-1413 [P0] 实现数据与隐私页。
- [ ] TASK-1414 [P0] 实现权限状态卡片。
- [ ] TASK-1415 [P0] 实现跳转系统设置。
- [ ] TASK-1416 [P0] 实现刷新权限状态。
- [ ] TASK-1417 [P0] 实现分析开关。
- [ ] TASK-1418 [P0] 实现清空历史。
- [ ] TASK-1419 [P0] 实现清空缓存。
- [ ] TASK-1420 [P0] 实现导出全部数据。
- [ ] TASK-1421 [P1] 实现导入数据。
- [ ] TASK-1422 [P1] 实现重置所有设置。

### 17.16 文件转写

- [ ] TASK-1501 [P0] 定义 `TranscriptionJob`。
- [ ] TASK-1502 [P0] 实现 `TranscriptionJobService`。
- [ ] TASK-1503 [P0] 实现任务队列。
- [ ] TASK-1504 [P0] 实现文件拖拽区域。
- [ ] TASK-1505 [P0] 实现选择文件按钮。
- [ ] TASK-1506 [P0] 实现格式校验。
- [ ] TASK-1507 [P0] 实现任务列表。
- [ ] TASK-1508 [P0] 实现任务进度。
- [ ] TASK-1509 [P0] 实现取消。
- [ ] TASK-1510 [P0] 实现重试。
- [ ] TASK-1511 [P0] 实现导出 txt。
- [ ] TASK-1512 [P0] 实现导出 md。
- [ ] TASK-1513 [P1] 实现导出 srt。
- [ ] TASK-1514 [P0] 实现保存为笔记。
- [ ] TASK-1515 [P0] 增加任务服务测试。

### 17.17 笔记

- [ ] TASK-1601 [P0] 定义 `Note`。
- [ ] TASK-1602 [P0] 实现 `NoteService`。
- [ ] TASK-1603 [P0] 实现笔记列表。
- [ ] TASK-1604 [P0] 实现搜索。
- [ ] TASK-1605 [P0] 实现新建。
- [ ] TASK-1606 [P0] 实现编辑。
- [ ] TASK-1607 [P0] 实现删除。
- [ ] TASK-1608 [P0] 实现从历史保存。
- [ ] TASK-1609 [P0] 实现从文件转写保存。
- [ ] TASK-1610 [P1] 实现标签。
- [ ] TASK-1611 [P0] 实现导出 Markdown。
- [ ] TASK-1612 [P0] 增加 NoteService 测试。

### 17.18 帮助页

- [ ] TASK-1701 [P0] 实现帮助页。
- [ ] TASK-1702 [P0] 展示官网入口。
- [ ] TASK-1703 [P0] 展示 GitHub Releases 入口。
- [ ] TASK-1704 [P0] 展示反馈入口。
- [ ] TASK-1705 [P0] 展示 Bug 报告入口。
- [ ] TASK-1706 [P1] 展示社区入口。
- [ ] TASK-1707 [P0] 所有外链用 `NSWorkspace.shared.open` 打开。

### 17.19 导入导出与备份

- [ ] TASK-1801 [P0] 定义备份 JSON 格式。
- [ ] TASK-1802 [P0] 导出历史。
- [ ] TASK-1803 [P0] 导出词库。
- [ ] TASK-1804 [P0] 导出替换规则。
- [ ] TASK-1805 [P0] 导出风格。
- [ ] TASK-1806 [P0] 导出 provider 配置但不导出 API Key 明文。
- [ ] TASK-1807 [P0] 导出笔记。
- [ ] TASK-1808 [P1] 导入备份。
- [ ] TASK-1809 [P1] 导入冲突处理。

### 17.20 发布与构建

- [ ] TASK-1901 [P0] 确保 `make build` 成功。
- [ ] TASK-1902 [P0] 确保 `make run` 成功。
- [ ] TASK-1903 [P0] 确保 `make install` 成功。
- [ ] TASK-1904 [P0] 确保 `make release` 成功。
- [ ] TASK-1905 [P0] 确保 Universal Binary。
- [ ] TASK-1906 [P0] 更新 DMG/Release 文案。
- [ ] TASK-1907 [P1] 增加版本号和构建号展示。

### 17.21 测试与质量

- [ ] TASK-2001 [P0] 所有新增 service 有单元测试。
- [ ] TASK-2002 [P0] 所有 repository 有测试。
- [ ] TASK-2003 [P0] 核心听写链路有集成测试。
- [ ] TASK-2004 [P0] Provider 失败回退有测试。
- [ ] TASK-2005 [P0] 剪贴板恢复有测试。
- [ ] TASK-2006 [P0] 输入法恢复有测试。
- [ ] TASK-2007 [P0] 数据迁移有测试。
- [ ] TASK-2008 [P0] `swift test` 通过。
- [ ] TASK-2009 [P0] `make build` 通过。
- [ ] TASK-2010 [P0] 无 API Key 明文泄漏。
- [ ] TASK-2011 [P0] README 与实际一致。

---

## 18. Codex 执行顺序建议

> 注意：这不是分期交付，只是一次性实现时的安全顺序。

```text
1. 建立 docs 和目标目录结构。
2. 引入 AppEnvironment / DependencyContainer / WindowCoordinator。
3. 建立 SQLite3 数据层和迁移。
4. 建立 KeychainCredentialStore 并迁移旧 LLM Key。
5. 抽出 DictationOrchestrator，保证旧听写链路通过。
6. 建立 TextProcessingPipeline，把现有 LLMRefiner 接入流水线。
7. 实现主窗口 Shell 和左侧导航。
8. 实现首页和历史服务。
9. 实现词汇表和替换规则。
10. 实现风格系统和 Prompt 预览。
11. 实现 LLM Provider 管理。
12. 实现 ASR Provider 管理。
13. 实现设置中心。
14. 实现文件转写。
15. 实现笔记。
16. 实现导入导出。
17. 补齐所有测试。
18. 更新 README/CONTEXT/文档。
19. 运行 make clean && make build && swift test。
20. 修复所有编译、测试、lint、运行问题。
```

---

## 19. Definition of Done

### 19.1 功能完成

- [ ] 主窗口所有导航可用。
- [ ] 首页统计和历史是真数据。
- [ ] 词汇表增删改查可用。
- [ ] 替换规则参与听写流水线。
- [ ] 风格编辑和预览可用。
- [ ] LLM Provider 可配置、测试、保存。
- [ ] API Key 存 Keychain。
- [ ] ASR Provider 页可筛选和选择默认。
- [ ] 设置中心可管理权限、快捷键、音频、隐私。
- [ ] 文件转写可导入文件并生成结果。
- [ ] 笔记可新建、编辑、搜索、导出。
- [ ] 导入导出可用。

### 19.2 稳定性完成

- [ ] 无 LLM 时听写可用。
- [ ] 无网络时听写可用。
- [ ] LLM 失败回退原文。
- [ ] ASR 失败回退可用 provider。
- [ ] 剪贴板恢复通过测试。
- [ ] 输入法恢复通过测试。
- [ ] HUD 不抢焦点。
- [ ] 菜单栏常驻。

### 19.3 工程完成

- [ ] `make clean` 成功。
- [ ] `make build` 成功。
- [ ] `make run` 成功。
- [ ] `swift test` 成功。
- [ ] 文档与代码一致。
- [ ] 没有硬编码测试 API Key。
- [ ] 没有明文保存 API Key。
- [ ] 新增文件结构和 CONTEXT 模块边界一致。

---

## 20. 给 Agent 的禁止事项

- [ ] 不要把项目改名为任何第三方产品名。
- [ ] 不要删除当前核心听写能力。
- [ ] 不要为了 UI 重构破坏右 Command 行为。
- [ ] 不要让 HUD 抢焦点。
- [ ] 不要只恢复纯文本剪贴板。
- [ ] 不要默认开启 LLM。
- [ ] 不要默认上传音频。
- [ ] 不要把 API Key 写入 SQLite、UserDefaults、日志或测试快照。
- [ ] 不要让 Provider 失败导致崩溃。
- [ ] 不要生成只有静态页面的假功能。
- [ ] 不要跳过测试。
- [ ] 不要让 README 夸大未实现能力。

---

## 21. 建议提交拆分

虽然最终目标是一次性完成，但提交可以拆得清晰：

```text
commit 1: docs: add complete workbench goal and architecture docs
commit 2: refactor: introduce app environment and dependency container
commit 3: data: add sqlite database, migrations, repositories
commit 4: security: migrate credentials to keychain
commit 5: dictation: introduce orchestrator and text pipeline
commit 6: ui: add main window shell and navigation
commit 7: home: add metrics and history dashboard
commit 8: glossary: add glossary and replacement rules
commit 9: styles: add style profiles, editor and prompt preview
commit 10: llm: add provider management and health checks
commit 11: asr: add provider registry and model management
commit 12: settings: add settings center and permissions
commit 13: files: add file transcription queue and export
commit 14: notes: add notes management
commit 15: backup: add import/export
commit 16: tests: add full unit and integration coverage
commit 17: docs: update readme and context
```

---

## 22. 最终验收命令

```bash
make clean
make build
swift test
make run
```

手工验收：

```text
1. 打开 App，菜单栏出现图标。
2. 打开主窗口，所有导航页面可进入。
3. 在任意输入框按住右 Command 说话，松手后文字注入。
4. 添加词汇表规则，再听写，输出被修正。
5. 选择编程风格，技术词保留。
6. 配置 LLM Provider，测试成功。
7. 关闭网络，LLM 回退原文。
8. 切换中文输入法，听写后输入法恢复。
9. 复制一张图片到剪贴板，听写后图片仍在剪贴板。
10. 拖入音频文件，完成转写，导出 Markdown。
11. 保存转写为笔记，笔记页可搜索。
12. 导出全部数据，重启应用后数据仍在。
```
