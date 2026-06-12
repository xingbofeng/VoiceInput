# VoiceInput 完整方案交付包

本包用于把 VoiceInput 升级为完整 macOS 语音输入工作台。

## 文件说明

- `VoiceInput_FULL_GOAL.md`：完整产品方案 + 技术方案 + 架构设计 + 验收标准 + 完整 task list。
- `TASKS.md`：单独抽出的任务清单，适合直接复制到 Issue / Codex。
- `CODEX_GOAL.md`：更短的 Codex Goal Prompt。
- `images/`：本次对话提供的 10 张交互参考图，已按顺序重命名。

## 使用建议

1. 先把 `VoiceInput_FULL_GOAL.md` 放入仓库 `docs/`。
2. 把 `TASKS.md` 拆成 GitHub Issues，或者直接交给 Codex 执行。
3. 把 `CODEX_GOAL.md` 作为 Agent 的顶层目标。
4. 把 `images/` 放到 `docs/interaction-references/`。
5. 要求 Agent 完成后运行：

```bash
make clean
make build
swift test
```
