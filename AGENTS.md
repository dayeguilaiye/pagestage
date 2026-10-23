# AGENTS.md

## Agent skills

### Issue tracker

Issue 和规格放在本仓库的 GitHub Issues，用 `gh` 操作。See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context：根目录一个 `GLOSSARY.md` + `docs/adr/`。See `docs/agents/domain.md`.

## 付费服务商 key

`.pagestage/providers.json`（Git 忽略）存放真实的 LLM、MiniMax、百炼 key，每次请求都花用户的钱。CLI 只在命令显式带 `--config`，或设置了 `*_API_KEY`、`LLM_KEY` 环境变量时发真实请求。

- 测试、`dart analyze` 和日常验证走离线路径：假适配器和 HTTP 契约夹具。
- 真实请求要先获得用户同意：说明目的、命令、服务商和模型、范围（哪本书、哪几章）、预计请求数；获准后只跑这个范围，超出时再问。用户直接交代的调试任务，在该任务范围内视为已同意。
- 范围取能说明问题的最小真实样本：真实章节、真实模型和配置。复用建档续跑与合成缓存，已完成的部分不重跑；失败时停下来汇报。跑完报告请求数和用量。
- key 只通过 `--config .pagestage/providers.json` 交给 CLI；读取、打印、复制文件内容或导出环境变量，须由用户明确要求。
