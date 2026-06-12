# Implementation Notes

## Production readiness - 2026-06-07

**目标**：把 macOS 菜单栏语音输入原型调试到可构建、可安装、核心行为可测试，并补齐公开文档。

**设计决策**：保留轻量 AppKit 模块边界，将热键状态、转录收尾、波形包络、URL 归一化、输入源判断与剪贴板快照提成可测试逻辑。系统集成继续使用 Speech、AVFoundation、Carbon 和 CoreGraphics，不引入运行时第三方依赖。

**偏差说明**：自动化无法伪造可信的物理全局修饰键事件，因此“物理右 Command + 真实麦克风 + 当前输入框注入”必须与自动化验证分开记录。

**已完成验证**：
- `swift test`：29 个普通测试通过，真实服务集成测试按环境变量单独运行。
- 真实 OpenAI-compatible LLM 请求通过。
- 严格 Debug/Release 编译通过。
- 完整 pasteboard items/types 恢复、CJK 输入源判断、RMS 波形和收尾竞态均有测试。

**待确认**：
- [ ] 使用物理右 Command 完成一次按住录音、松开注入。

## Hot key migration - 2026-06-07

**目标**：将热键从 Fn 迁移为右 Command，降低系统快捷功能冲突。

**设计决策**：使用右 Command 虚拟键码 `54`，只吞掉该键的 `flagsChanged` 事件；左 Command 键码 `55` 与其他修饰键原样放行。根据右 Command 自身事件翻转状态，避免依赖无法区分左右键的聚合 `.maskCommand`。

**偏差说明**：原需求指定 Fn；用户后续明确要求右 Command，代码、测试、README、官网与设计文档统一采用新热键。

## Brand, website, and release - 2026-06-07

**目标**：生成项目 Logo 与 App Icon，建设中英文 GitHub Pages 落地页，并通过 GitHub Actions 持续打包和发布。

**设计决策**：品牌符号采用“五段声波 + 文本插入光标”。保留 GPT Image 2 母版、生成提示词、标准 iconset 与 `.icns`。Release 构建使用 `arm64 + x86_64` Universal Binary，Pages 从 `docs/` 直接部署。

**偏差说明**：GPT Image 2 返回 1254px 母版；iconset 按 Apple 标准缩放到最高 1024px，并补全图标外透明通道。

**待确认**：
- [ ] GitHub Actions 的 CI、Release 与 Pages 工作流全部通过。
- [ ] Release zip、SHA-256 和 GitHub Pages 页面可公开访问。

## Settings window clickability - 2026-06-08

**目标**：修复设置窗口按钮不可点击、快捷键录制收不到默认修饰键的问题。

**设计决策**：让 `NSTabView` 继续管理每个 tab item 根视图的 frame，只对根视图内部控件使用 Auto Layout；打开设置窗口时先激活 app，再置前并设为 main window。全局快捷键 event tap 在 VoiceInput 自己 active 时放行事件，避免设置页和快捷键录制被全局热键吞掉。

**偏差说明**：Computer Use 无法读取 `LSUIElement` 菜单栏 app 的 accessibility tree，改用代码审查、真实安装重启、截图确认进程与桌面状态、自动化测试和编译验证。

**权衡分析**：
- 方案一：打开设置时暂停整个 `KeyMonitor`。优点是直观；缺点是需要新增窗口生命周期回调，设置窗口关闭/异常状态容易遗漏。
- 方案二：在 event tap 内按 `NSApp.isActive` 放行快捷键事件。优点是改动小，设置页、sheet 和未来本 app 窗口都能收到本地按键；缺点是 app active 时不能触发全局录音热键。
- 选择方案二，因为设置窗口激活期间用户预期是在操作设置而不是触发全局录音。

**待确认**：
- [ ] 你在设置窗口中手动点击 ASR/LLM/快捷键 tab、Qwen3-ASR、录制快捷键是否符合预期。

## Qwen3 ASR settings gate and downloader - 2026-06-08

**目标**：Qwen3-ASR 未下载时不可切换；设置页下载按钮直接下载模型并显示进度；菜单入口统一为一级“设置...”。

**设计决策**：把 Qwen3 可用性收敛到 `ASRManager`，只有本地模型目录存在时 `canSelectEngine(.qwen3)` 才为真，设置页、菜单和运行时录音都使用同一门禁。新增 `Qwen3ModelDownloader`，按 Hugging Face direct `resolve/main/...` 文件清单逐个下载 CoreML 文件到 `~/Library/Application Support/VoiceInput/Models/`，设置页用进度条和状态文字显示当前文件与总体进度。

**偏差说明**：原先“下载模型...”打开网页；按用户反馈改为应用内直接下载。下载完成后写入模型路径并启用 Qwen3。

**权衡分析**：
- 方案一：依赖 `huggingface-cli` 或 git-lfs。优点是仓库同步完整；缺点是新增外部工具依赖，不适合菜单栏 app。
- 方案二：内置 URLSession downloader，维护必要文件 manifest。优点是无额外依赖、能显示进度；缺点是文件清单需要随模型仓库变化维护。
- 选择方案二，因为用户明确要求点击下载按钮后直接开始下载并显示进度。

**待确认**：
- [ ] 真实点击 `下载模型...` 完成大文件下载后的磁盘空间、耗时和 UI 体验是否可接受。

## Qwen3 ASR FluidAudio integration - 2026-06-08

**目标**：让下载后的 Qwen3-ASR 模型进入真实 CoreML 推理路径，而不是只提供设置页占位。

**设计决策**：引入 FluidAudio SwiftPM 依赖，`Qwen3ASREngine` 负责把录音 buffer 重采样为 16kHz mono samples，并在 `endAudio()` 中用 `Qwen3AsrManager.loadModels(from:)` 和 `transcribe(audioSamples:language:)` 执行本地转写。模型可用性检查从“目录存在”升级为检查 FluidAudio 需要的 encoder、decoder、embedding 和 vocab/manifest 文件，避免空目录误启用。

**偏差说明**：Qwen3 推理需要 macOS 15 或更新版本；低版本会返回明确错误。真实大模型下载和真实音频转写未在本轮自动执行，避免未经用户确认消耗大量磁盘、网络和麦克风环境。

**权衡分析**：
- 方案一：在项目内手写 Qwen3 CoreML encoder/decoder/KV cache 管线。优点是依赖少；缺点是实现复杂、错误面大，且已有成熟库维护这些细节。
- 方案二：复用 FluidAudio 的 Qwen3 ASR 管线。优点是直接匹配模型文件结构并覆盖 tokenizer、mel/encoder/decoder 流程；缺点是引入较大的第三方依赖，Release 构建会显示该依赖自身警告。
- 选择方案二，因为用户要的是下载后可用的本地 Qwen3-ASR，而不是继续维护 stub。

**待确认**：
- [ ] 用户点击 `下载模型...` 后完成真实模型下载，并用物理麦克风验证 Qwen3-ASR 转写质量。

## Stable local code signing - 2026-06-08

**目标**：避免每次 `make install` 重新打包后 macOS 辅助功能权限反复失效。

**设计决策**：本地打包优先自动选择钥匙串中的有效 `Developer ID Application` 或 `Apple Development` 代码签名身份；找不到证书时才回退到 ad-hoc 签名。这样 designated requirement 绑定 bundle identifier 和证书，而不是每次构建都会变化的 cdhash。

**偏差说明**：从历史 ad-hoc 签名切换到证书签名的第一次，macOS 可能仍会要求重新授予一次辅助功能权限；之后同一证书签出的新包应复用同一 TCC 身份。

**权衡分析**：
- 方案一：继续 ad-hoc 签名。优点是任何机器都能构建；缺点是每次二进制变化都会产生新的 cdhash，辅助功能权限会反复掉。
- 方案二：强制写死当前开发证书。优点是本机稳定；缺点是换机器或 CI 会失败。
- 方案三：自动发现本机可用签名证书，缺失时回退 ad-hoc。优点是本机权限稳定且保留无证书环境的可构建性；缺点是不同开发机首次授权仍需各自完成一次。
- 选择方案三，因为它解决本机反复授权问题，同时不破坏其他环境。

**待确认**：
- [ ] 首次切换到证书签名后，在系统设置中重新授予一次辅助功能权限。

## Qwen3 ASR runtime activation - 2026-06-08

**目标**：修复设置页已选择 Qwen3-ASR 但录音运行时仍像 Apple Speech 一样受语音识别权限影响的问题。

**设计决策**：新增 `RecordingPermissionPolicy`，把“当前引擎需要哪些权限”变成可测试规则。热键按下时按当前 `ASRManager.effectiveSelectedEngineType` 重新刷新权限状态，而不是复用启动时缓存；Qwen3-ASR 只要求麦克风权限，Apple Speech 才同时要求麦克风和 Apple 语音识别权限。

**偏差说明**：无法用自动化伪造可信的物理右 Command 全局按键完成完整录音链路；改用策略单元测试、已安装 App 的权限弹窗验证，以及 `VOICEINPUT_TEST_QWEN3_LIVE=1` live smoke test 直接加载本地 Qwen3 模型处理合成音频。

**权衡分析**：
- 方案一：设置页切换 ASR 时通知 `AppDelegate` 重新请求权限。优点是显式；缺点是设置页与运行时生命周期耦合更重，菜单切换也要补通知。
- 方案二：每次热键开始前按当前引擎刷新权限状态。优点是覆盖设置页、菜单和外部 defaults 变化；缺点是不在热键按下时弹首次授权请求。
- 选择方案二，因为启动时已有权限请求流程，热键入口更应该保证运行时状态与当前引擎一致。

**待确认**：
- [ ] 使用物理右 Command 做一次真实 Qwen3-ASR 录音，确认识别文本质量符合预期。

## Swift concurrency cleanup and release asset refresh - 2026-06-09

**目标**：把本轮提交中引入的并发边界收紧到可编译、可测试的状态，同时保留发布工作流和演示资源的最新形态。

**设计决策**：将设置窗口视为纯 UI 主线程对象，把 Qwen3 模型下载进度回调改成主线程语义，避免在 `Task` / URLSession 回调里跨 actor 捕获窗口控制器。同步移除几处不再需要的 `nonisolated(unsafe)` 标注，让并发意图更明确，也减少编译警告噪音。

**偏差说明**：原始改动里为了压住并发警告，曾使用更激进的 `@MainActor` / `Task` 包装；实际落地时改为让下载器直接把进度送回主线程，再由设置窗口更新 UI，这样测试和运行时语义更一致。

**CI 失败根因**：GitHub Actions run `27101092565` 的 `Run tests` 和 `Build with warnings as errors` 已通过，真正失败点是 `Build release DMG` 中的 `make dmg`。当时的 `swift build -c release --arch arm64 --arch x86_64` 仍带目标级 Swift 5 language mode，CI 上的 SwiftPM/Xcode 组合报出 unsupported Swift language version、空 `SWIFT_VERSION` 和重复输出任务。移除目标级 `swiftLanguageMode(.v5)` 后，本地 `make dmg` 已可完成 Universal Binary、签名、DMG 和 checksum。

**权衡分析**：
- 方案一：把窗口控制器整体标成主线程并保留 `Task` 包装。优点是概念简单；缺点是容易把测试代码一起绑定到 actor 约束里。
- 方案二：把下载器进度回调本身定义成主线程语义，窗口只负责 UI 更新。优点是边界清楚、测试友好；缺点是下载器需要显式把回调切回主线程。
- 选择方案二，因为它更贴近“后台下载，前台更新”的真实职责划分。

**已完成验证**：
- `swift test`：76 个测试通过，2 个集成测试按环境变量跳过。
- `git diff --check`：通过。
- `make dmg`：通过，生成 `dist/VoiceInput-1.0.1-macOS.dmg`。
- CI 后半段等价验证：`codesign --verify --deep --strict`、`lipo -verify_arch arm64 x86_64`、AppIcon 文件检查、DMG 文件检查和 `shasum -a 256 -c` 均通过。
- 仍未执行真实模型下载、物理麦克风录音和远端发布工作流。

**待确认**：
- [ ] 新的下载进度 UI 文案和节奏是否符合预期？
- [ ] `docs/voiceinput-demo-land.mp4` 是否作为本次发布资产一并保留？

## LLM API Key security and log redaction - 2026-06-09

**目标**：停止把 LLM API Key 明文保存在 `UserDefaults`，并建立统一日志脱敏边界，为后续 Provider 管理奠定安全基础。

**设计决策**：新增 `CredentialStore` 协议和 `KeychainCredentialStore` 实现，`LLMRefiner` 继续用 `UserDefaults` 保存非敏感开关、Base URL 和 Model，但 API Key 只通过 CredentialStore 读写。初始化时自动迁移旧的 `LLMRefiner_APIKey`，无论迁移结果如何都会删除旧明文，避免继续把敏感值留在偏好文件里。新增 `AppLogger` 统一 OSLog 输出，并在进入日志前脱敏 Bearer token、API Key 键值、JSON 字段和 URL query。

**偏差说明**：本轮只完成现有单一 LLM 配置的 Keychain 迁移和日志脱敏基础；完整 LLM Provider CRUD、Provider 删除时同步删除 Keychain 项、SQLite Provider 表仍在后续任务中完成。

**权衡分析**：
- 方案一：直接把 Keychain 读写写进 `LLMRefiner`。优点是改动少；缺点是后续多 Provider 和测试会被 Security.framework 细节绑住。
- 方案二：抽 `CredentialStore` 协议，生产使用 Keychain，测试使用内存实现。优点是边界清楚、可测试；缺点是多一个小抽象。
- 选择方案二，因为目标要求后续 Provider、迁移和导入导出都不能泄漏密钥，安全存储需要先成为独立边界。

**已完成验证**：
- `swift test --filter LLMRefinerTests --filter RepositoryBrandIntegrityTests`：13 个测试通过，1 个 live LLM 集成测试按环境变量跳过。
- `swift test --filter AppLoggerTests`：5 个日志脱敏测试通过。

**待确认**：
- [ ] 在真实应用设置页保存一次 LLM API Key，并确认重启后仍可测试连接。

## Architecture foundation utilities - 2026-06-09

**目标**：补齐后续数据层、任务队列和统计模块会共用的基础设施，避免路径和时间逻辑散落在业务代码里。

**设计决策**：新增 `AppClock` 协议和 `SystemClock`，刻意避开 Swift 标准库 `Clock` 的命名冲突；新增 `ApplicationSupportPaths`，统一生成 `~/Library/Application Support/VoiceInput/voiceinput.sqlite`、`Exports/` 和 `Models/` 路径。`Qwen3ModelDownloader` 改为复用 `ApplicationSupportPaths.modelsDirectory`，不再自己拼 Application Support 路径。

**偏差说明**：本轮只落地基础路径和时间抽象；`AppEnvironment`、`DependencyContainer`、`WindowCoordinator` 以及 SQLite 数据层仍待后续接入。

**权衡分析**：
- 方案一：继续在各模块里按需拼路径和直接调用 `Date()` / `Task.sleep`。优点是眼前改动少；缺点是数据库、导出、模型和任务队列会形成重复路径逻辑，时间相关测试也会变脆。
- 方案二：先提供小而稳定的基础设施对象。优点是后续模块可复用且易测试；缺点是暂时只有少量调用点。
- 选择方案二，因为目标包含 SQLite、文件转写、导入导出和统计，这些模块都需要一致路径与可替换时钟。

**已完成验证**：
- `swift test --filter ApplicationSupportPathsTests --filter ClockTests`：4 个测试通过。

**待确认**：
- [ ] 后续 SQLite 接入时是否继续使用默认 `voiceinput.sqlite` 文件名。

## SQLite foundation and initial schema - 2026-06-09

**目标**：为完整工作台的数据流提供 SQLite 基础层和首版 schema，覆盖历史、词汇表、替换规则、风格、ASR/LLM Provider、文件转写任务、笔记和设置。

**设计决策**：新增 `SQLiteConnection`、`SQLiteStatement`、`DatabaseQueue`、`DatabaseMigrator` 和 `AppDatabase`。迁移记录使用 `schema_migrations` 表；首个 migration 创建目标文档中的 P0 表和关键索引。`llm_providers` 只保存 `api_key_ref`，不提供 `api_key` 明文字段，继续由 Keychain 保存真实密钥。

**偏差说明**：本轮完成 SQLite 基础设施和表结构；具体 Repository 协议、SQLite Repository 实现、内置数据 seed 和 UI 数据绑定仍在后续任务中完成。

**权衡分析**：
- 方案一：先做页面和内存数据，再回填 SQLite。优点是可更快看到 UI；缺点是容易产生假数据流，不符合目标里的“页面必须有真实数据流”。
- 方案二：先把数据库连接、迁移和表结构落稳，再接 Repository 和页面。优点是后续模块都能复用同一真实数据层；缺点是短期可见 UI 进展较少。
- 选择方案二，因为首页、词汇表、风格、文件转写和笔记都依赖同一个本地数据源。

**已完成验证**：
- `swift test --filter SQLiteFoundationTests`：6 个测试通过。

**待确认**：
- [ ] 是否需要在首版 migration 中加入更多外键约束，还是保持当前轻约束便于导入导出和回退。

## SQLite repositories - 2026-06-09

**目标**：为工作台页面和服务提供真实 SQLite Repository，而不是静态 UI 或内存假数据。

**设计决策**：新增 History、Glossary、ReplacementRule、Style、ASRProvider、LLMProvider、TranscriptionJob、Note、Settings 的 Repository 协议与 SQLite 实现。Repository 只负责数据持久化和查询，不承载网络请求、ASR 推理、LLM 调用或 UI 状态。JSON 字段目前以字符串边界保存，服务层后续负责解释 capabilities、tags、config、warnings 等结构。

**偏差说明**：本轮完成基础 CRUD / list / search / status update 能力，足以支撑后续服务和页面接入；批量导入导出、复杂筛选、Provider 删除时同步删除 Keychain 项、全文索引和分页优化仍在后续任务中补齐。

**权衡分析**：
- 方案一：为每个业务模块先做 ViewModel，再按需补 SQL。优点是页面推进快；缺点是数据契约会被 UI 牵着走。
- 方案二：先把 Repository 契约压实，再让服务和 ViewModel 消费这些契约。优点是模块边界清楚、测试稳定；缺点是短期代码量集中在数据层。
- 选择方案二，因为目标明确要求 SQLite + Repository + Migration，并要求页面是真数据流。

**已完成验证**：
- `swift test --filter SQLiteSettingsRepositoryTests`：4 个测试通过。
- `swift test --filter SQLiteHistoryRepositoryTests`：3 个测试通过。
- `swift test --filter SQLiteGlossaryRepositoryTests`：3 个测试通过。
- `swift test --filter SQLiteNoteRepositoryTests`：3 个测试通过。
- `swift test --filter SQLiteProviderAndStyleRepositoryTests`：3 个测试通过。

**待确认**：
- [ ] 后续是否需要为历史、笔记和词库增加 FTS5 全文搜索。

## Dependency container and environment - 2026-06-09

**目标**：把新数据层、路径、时钟和安全存储统一装配，避免后续服务和 SwiftUI ViewModel 直接创建具体实现。

**设计决策**：新增 `DependencyContainer`，提供 `live()` 和 `inMemory()` 两种入口：live 使用 `ApplicationSupportPaths.databaseURL` 并自动执行迁移，in-memory 用于测试；新增 `AppEnvironment: ObservableObject`，把 Repository 协议和基础设施暴露给后续 SwiftUI 工作台与服务层。

**偏差说明**：本轮只装配已存在的数据和基础设施；`DictationOrchestrator`、`TextProcessingPipeline`、窗口协调器、SwiftUI 主窗口和 ViewModel 会在后续接入。

**权衡分析**：
- 方案一：在 AppDelegate、WindowController 或 ViewModel 中按需创建 Repository。优点是局部快；缺点是依赖散落，测试和替换实现困难。
- 方案二：集中在 `DependencyContainer` 装配真实实现，UI 和服务只消费协议。优点是边界清楚，后续更容易切 in-memory 测试；缺点是需要先维护一个容器对象。
- 选择方案二，因为完整工作台需要多页面共享同一数据库和服务实例。

**已完成验证**：
- `swift test --filter DependencyContainerTests`：2 个测试通过。

**待确认**：
- [ ] 主窗口和设置中心接入时，是否保留旧 AppKit 设置窗口作为兼容入口，还是迁入 SwiftUI 设置页后删除旧窗口。

## SwiftUI workbench shell - 2026-06-09

**目标**：建立 VoiceInput 主工作台的窗口生命周期、左侧导航和页面骨架，并通过真实 Repository 读取基础数据快照。

**设计决策**：新增 `WindowCoordinator` 管理主动打开的主窗口和既有设置窗口；新增 `MainWindowController` 承载 SwiftUI `MainShellView`；`SidebarView` + `NavigationRoute` 覆盖首页、词汇表、风格、文件转写、笔记、听写模型、设置、帮助。`WorkbenchViewModel` 从 Repository 读取历史、词库、风格、笔记、Provider 数量，避免纯静态页面。

**偏差说明**：本轮完成主窗口骨架和真实数据快照；各页面的完整交互、编辑器、队列、导入导出和设置中心细节仍需继续实现。旧 AppKit 设置窗口仍作为菜单入口保留，避免一次性迁移破坏现有 ASR/LLM/快捷键设置。

**权衡分析**：
- 方案一：一次性把所有页面做完再接菜单入口。优点是用户看到的是完整界面；缺点是风险集中，容易影响现有菜单栏听写链路。
- 方案二：先接主窗口生命周期和路由，再逐页把服务接进来。优点是窗口边界、依赖注入和导航先稳定；缺点是部分页面暂时只有数据摘要。
- 选择方案二，因为目标要求不能破坏核心听写和注入链路。

**已完成验证**：
- `swift test --filter WorkbenchViewModelTests`：2 个测试通过。
- `swift test`：117 个测试通过，2 个环境依赖测试按环境变量跳过。
- `make build`：通过，生成并签名 `.build/VoiceInputApp.app`。

**待确认**：
- [ ] 主窗口视觉细节需要继续按参考图细化。

## Core dictation orchestration - 2026-06-09

**目标**：把右 Command 听写生命周期从 `AppDelegate` 中抽出，统一管理录音、ASR、final timeout、文本处理、注入和历史保存，同时保持现有输入体验不退化。

**设计决策**：新增 `DictationStateMachine` 和 `DictationOrchestrator`。`AppDelegate` 只保留菜单、权限提示、热键入口和 HUD 回调；编排器负责 ASR engine 创建、audio start/stop、partial/final 收束、15 秒 final timeout、latest partial fallback、`TextProcessingPipeline`、`TextInjector` 和 `HistoryRepository`。`TextProcessingPipeline` 先封装现有 LLM 纠错，并在失败时返回原文和 warning，为后续词汇表、替换规则、风格系统接入留出单一入口。

**偏差说明**：本轮没有改变真实注入实现，仍复用 `TextInjector` 的输入法切换、剪贴板快照、粘贴和恢复逻辑；没有做物理右 Command + 麦克风手工验证，只完成编排器和现有注入组件的自动化测试。

**权衡分析**：
- 方案一：继续在 `AppDelegate` 中补历史保存和 timeout fallback。优点是改动最少；缺点是状态、设备、UI、网络和持久化继续耦在一个对象里。
- 方案二：抽出可注入依赖的编排器，让 `AppDelegate` 只做运行时适配。优点是核心链路可测试、后续词汇表和风格系统有明确入口；缺点是需要新增几个协议边界。
- 选择方案二，因为目标要求核心听写稳定、业务逻辑不塞进 WindowController/View，并且 ASR/LLM 失败必须可测试地 fallback。

**已完成验证**：
- `swift test --filter "Dictation|TextProcessingPipeline|TranscriptionSession"`：14 个测试通过。
- `swift test`：128 个测试通过，2 个环境依赖测试按环境变量跳过。

**待确认**：
- [ ] 使用真实右 Command、麦克风和目标编辑器手工验证 HUD、粘贴、剪贴板恢复、输入法恢复和历史保存。

## Home dashboard and SwiftUI theme - 2026-06-09

**目标**：建立统一 SwiftUI Theme，并让首页使用真实历史数据展示统计、目标进度、分组历史和基础操作。

**设计决策**：新增 `AppTheme` 集中管理紧凑半径、间距和基础颜色；新增 `HomeDashboardViewModel` 独立计算累计字符、今日字符、平均 CPM、连续使用天数和每日目标进度。历史数据继续通过 `HistoryRepository` 读取，搜索走 repository 查询，复制通过 `ClipboardWriting` 注入以便测试，删除使用 soft delete 后重新加载。

**偏差说明**：本轮完成首页 P0 操作，不包含详情页和重新处理能力；每日目标先读 `home.dailyCharacterGoal` 设置，未做设置 UI。

**权衡分析**：
- 方案一：把统计计算直接写在 SwiftUI View 里。优点是文件少；缺点是难测试、后续目标设置和搜索行为会挤进 UI。
- 方案二：独立首页 ViewModel，View 只展示与触发动作。优点是数据真实且可测试；缺点是新增一个页面模型。
- 选择方案二，因为首页是后续历史详情、重处理和目标设置的入口。

**已完成验证**：
- `swift test --filter "AppTheme|HomeDashboard|WorkbenchViewModel"`：7 个测试通过。
- `swift test`：133 个测试通过，2 个环境依赖测试按环境变量跳过。

**待确认**：
- [ ] 首页视觉和交互需要在真实 App 窗口中手工确认。
## Glossary CRUD and Replacement Pipeline - 2026-06-09

**目标**：实现词汇表 P0 能力：易错词 CRUD、文本替换 CRUD、exact/contains/regex、beforeLLM/afterLLM 阶段、批量导入、去重和搜索，并让替换规则进入真实文本处理管线。

**设计决策**：新增 `GlossaryViewModel` 管理词条、替换规则、搜索和导入合并；扩展 `ReplacementRuleRepository` 支持全量列表和搜索；新增 `ReplacementRuleEngine`，按优先级应用 exact、contains 和 regex。`DefaultTextProcessingPipeline` 在 LLM 前应用 beforeLLM 规则，在 LLM 成功或失败后应用 afterLLM 规则，并把无效正则和 LLM 失败都记录为 warning。

**偏差说明**：本轮完成替换规则真实生效，但还没有实现 JSON/CSV 导入导出，也没有把易错词作为 PromptBuilder 上下文注入 LLM；这两项仍留给 `TASK-0706` 和 `TASK-0707`。

**权衡分析**：
- 方案一：只做词汇表 UI，不接入文本处理。优点是页面快；缺点是用户配置不会影响听写结果。
- 方案二：同时做 ViewModel、Repository 查询和管线规则引擎。优点是配置立即进入核心链路；缺点是新增一层规则应用逻辑。
- 选择方案二，因为目标要求页面不是静态配置，替换规则必须参与 before/after LLM 的真实处理。

**已完成验证**：
- `swift test --filter "GlossaryViewModel|ReplacementRuleEngine|SQLiteGlossaryRepository|TextProcessingPipeline"`：12 个测试通过。
- `swift test`：139 个测试通过，2 个环境依赖测试按环境变量跳过。

**待确认**：
- [ ] 在真实主窗口中手工确认词汇表页面布局、导入体验和替换规则对实际听写结果的影响。
