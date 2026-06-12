# CODEX_GOAL.md

```text
你是一个高级 macOS Swift 工程 Agent。请在 VoiceInput 仓库中一次性实现完整语音输入工作台。

仓库： https://github.com/xingbofeng/VoiceInput

绝对约束：
- 不改项目名称。
- 不引用任何第三方产品名称。
- 保留右 Command 听写核心链路。
- HUD 不抢焦点。
- 注入后必须恢复输入法和完整剪贴板。
- API Key 必须存 Keychain。
- 默认不开启 LLM，不默认上传音频。
- 所有 Provider 失败必须回退。
- 页面必须有真实数据流，不要静态假 UI。
- 完成后 `make clean && make build && swift test` 必须通过。

请实现：
1. AppEnvironment、DependencyContainer、WindowCoordinator。
2. SQLite3 数据层、迁移、Repository。
3. KeychainCredentialStore 和旧配置迁移。
4. DictationOrchestrator 和 TextProcessingPipeline。
5. 主窗口 Shell 和左侧导航。
6. 首页统计、历史搜索、复制、删除、重新处理。
7. 词汇表和替换规则。
8. 风格系统、风格编辑器、Prompt 预览。
9. LLM Provider 管理。
10. ASR Provider 管理。
11. 设置中心：通用、系统、数据与隐私。
12. 文件转写：拖拽、队列、进度、导出、保存笔记。
13. 笔记：Markdown、搜索、标签、导出。
14. 导入导出。
15. 完整测试和文档。
```
