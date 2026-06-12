# VoiceInput 一次性完整实现任务清单

> 这是从完整方案中抽出的 Codex 执行任务列表。所有任务均需要完成；P0/P1/P2 只是实现优先级，不是可选范围。

## 0. Codex 总目标

```text
在 https://github.com/xingbofeng/VoiceInput 中一次性完成完整 macOS 语音输入工作台：保留现有右 Command 听写核心链路，新增主窗口、首页、词汇表、风格系统、LLM Provider、ASR Provider、设置中心、文件转写、笔记、本地数据库、Keychain、导入导出、完整测试和文档。不要改项目名称，不要引用任何第三方产品名称。
```

## 1. 文档任务

- [x] TASK-0001 [P0] 新建 `docs/PRD.md`。
- [x] TASK-0002 [P0] 新建 `docs/TECHNICAL_DESIGN.md`。
- [x] TASK-0003 [P0] 新建 `docs/ARCHITECTURE.md`。
- [x] TASK-0004 [P0] 新建 `docs/TEST_PLAN.md`。
- [x] TASK-0005 [P0] 新建 `docs/CODEX_GOAL.md`。
- [x] TASK-0006 [P0] 新建 `docs/PRIVACY.md`。
- [x] TASK-0007 [P0] 复制交互参考图到 `docs/interaction-references/`。
- [x] TASK-0008 [P0] 更新 README。
- [x] TASK-0009 [P0] 更新 CONTEXT。

## 2. 架构任务

- [x] TASK-0101 [P0] 新建 `AppEnvironment`。
- [x] TASK-0102 [P0] 新建 `DependencyContainer`。
- [x] TASK-0103 [P0] 新建 `WindowCoordinator`。
- [x] TASK-0104 [P0] 精简 `AppDelegate`。
- [x] TASK-0105 [P0] 新建 `Clock` 抽象。
- [x] TASK-0106 [P0] 新建 `AppLogger`。
- [x] TASK-0107 [P0] 新建 `ApplicationSupportPaths`。
- [x] TASK-0108 [P0] 建立 SwiftUI Theme。

## 3. 数据与安全

- [x] TASK-0201 [P0] 实现 SQLite3 连接、Statement、DatabaseQueue、Migrator。
- [x] TASK-0202 [P0] 创建 migration 表。
- [x] TASK-0203 [P0] 创建 history/glossary/replacement/style/asr/llm/jobs/notes/settings 表。
- [x] TASK-0204 [P0] 实现所有 Repository 协议与 SQLite 实现。
- [x] TASK-0205 [P0] 增加 Repository 测试。
- [x] TASK-0301 [P0] 实现 KeychainCredentialStore。
- [x] TASK-0302 [P0] 迁移旧 LLM API Key 到 Keychain。
- [x] TASK-0303 [P0] 删除 UserDefaults 中旧明文 Key。
- [x] TASK-0304 [P0] 日志脱敏。

## 4. 主窗口与导航

- [x] TASK-0401 [P0] 实现 `MainWindowController`。
- [x] TASK-0402 [P0] 实现 `MainShellView`。
- [x] TASK-0403 [P0] 实现 `SidebarView` 和 `NavigationRoute`。
- [x] TASK-0404 [P0] 导航包含首页、词汇表、风格、文件转写、笔记、听写模型、设置、帮助。
- [x] TASK-0405 [P0] 菜单栏打开主窗口。
- [x] TASK-0406 [P0] 主窗口关闭不退出应用。

## 5. 核心听写

- [x] TASK-0501 [P0] 抽出 `DictationOrchestrator`。
- [x] TASK-0502 [P0] 定义 `DictationState` 与状态机。
- [x] TASK-0503 [P0] 串接 Hotkey、Audio、ASR、HUD、TextPipeline、Injector、History。
- [x] TASK-0504 [P0] final bounded timeout。
- [x] TASK-0505 [P0] latest partial fallback。
- [x] TASK-0506 [P0] LLM failure fallback。
- [x] TASK-0507 [P0] 保留输入法恢复和剪贴板恢复。
- [x] TASK-0508 [P0] 单元和集成测试。

## 6. 首页

- [x] TASK-0601 [P0] 首页统计：累计字符、今日字符、CPM、连续使用。
- [x] TASK-0602 [P0] 目标进度卡。
- [x] TASK-0603 [P0] 历史按日期分组。
- [x] TASK-0604 [P0] 搜索、复制、删除。
- [x] TASK-0605 [P1] 详情和重新处理。

## 7. 词汇表

- [x] TASK-0701 [P0] 易错词 CRUD。
- [x] TASK-0702 [P0] 文本替换 CRUD。
- [x] TASK-0703 [P0] exact/contains/regex。
- [x] TASK-0704 [P0] beforeLLM/afterLLM apply stage。
- [x] TASK-0705 [P0] 批量导入、去重、搜索。
- [x] TASK-0706 [P1] JSON/CSV 导入导出。
- [x] TASK-0707 [P0] 接入 PromptBuilder 和 TextPipeline。

## 8. 风格系统

- [x] TASK-0801 [P0] 内置原文、正式、日常、元气、编程、邮件风格。
- [x] TASK-0802 [P0] 风格列表、分类、卡片。
- [x] TASK-0803 [P0] 风格编辑器。
- [x] TASK-0804 [P0] Prompt 编辑和重置。
- [x] TASK-0805 [P0] LLM provider/model/temperature。
- [x] TASK-0806 [P0] 调试预览。
- [x] TASK-0807 [P0] 默认风格。
- [x] TASK-0808 [P1] 按应用自动选择。

## 9. LLM Provider

- [x] TASK-0901 [P0] OpenAI-compatible client。
- [x] TASK-0902 [P0] Base URL 归一化。
- [x] TASK-0903 [P0] Provider CRUD。
- [x] TASK-0904 [P0] 配置弹窗。
- [x] TASK-0905 [P0] 测试连接。
- [x] TASK-0906 [P1] 模型列表和测速。
- [x] TASK-0907 [P0] 风格绑定 Provider。
- [x] TASK-0908 [P0] 失败回退。

## 10. ASR Provider

- [x] TASK-1001 [P0] ASRProviderCapabilities。
- [x] TASK-1002 [P0] ASRProviderRegistry。
- [x] TASK-1003 [P0] Apple Speech provider。
- [x] TASK-1004 [P0] Qwen3-ASR provider。
- [x] TASK-1005 [P0] 本地模型下载/校验/删除。
- [x] TASK-1006 [P0] 听写模型列表和标签筛选。
- [x] TASK-1007 [P0] 默认模型和回退策略。
- [x] TASK-1008 [P1] 云 ASR provider 基础协议。

## 11. 设置中心

- [x] TASK-1101 [P0] 设置窗口三分组：通用、系统、数据与隐私。
- [x] TASK-1102 [P0] 输入设备选择。
- [x] TASK-1103 [P0] 快捷键录制、长按阈值、短按行为。
- [x] TASK-1104 [P0] 提示音、声音增强。
- [x] TASK-1105 [P1] 录音时静音、性能优化。
- [x] TASK-1106 [P0] 权限状态和系统设置跳转。
- [x] TASK-1107 [P0] 分析开关。
- [x] TASK-1108 [P0] 清空历史、清空缓存、导出数据。
- [x] TASK-1109 [P1] 导入数据、重置设置。

## 12. 文件转写

- [x] TASK-1201 [P0] 文件拖拽和选择。
- [x] TASK-1202 [P0] 格式校验。
- [x] TASK-1203 [P0] 任务队列。
- [x] TASK-1204 [P0] 进度、取消、重试。
- [x] TASK-1205 [P0] 导出 txt/md。
- [x] TASK-1206 [P1] 导出 srt。
- [x] TASK-1207 [P0] 保存为笔记。

## 13. 笔记

- [x] TASK-1301 [P0] 笔记 CRUD。
- [x] TASK-1302 [P0] Markdown 编辑。
- [x] TASK-1303 [P0] 搜索。
- [x] TASK-1304 [P0] 从历史保存。
- [x] TASK-1305 [P0] 从文件转写保存。
- [x] TASK-1306 [P1] 标签。
- [x] TASK-1307 [P0] 导出 Markdown。

## 14. 帮助与发布

- [x] TASK-1401 [P0] 帮助页和外链。
- [x] TASK-1402 [P0] 版本号展示。
- [x] TASK-1403 [P0] `make build` 成功。
- [x] TASK-1404 [P0] `swift test` 成功。
- [x] TASK-1405 [P0] README/CONTEXT/docs 与实际代码一致。

## 15. 最终验收

- [x] 主窗口所有页面可用。
- [x] 右 Command 听写可用。
- [x] 剪贴板完整恢复。
- [x] 输入法恢复。
- [x] LLM 可关闭、可配置、可回退。
- [x] ASR provider 可选择、可回退。
- [x] API Key 只在 Keychain。
- [x] 首页统计是真数据。
- [x] 文件转写可生成结果。
- [x] 笔记可保存和搜索。
- [x] 导入导出可用。
- [x] `make clean && make build && swift test` 全部通过。
