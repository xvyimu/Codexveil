# Evidence — 发版 home / conversation probe 留痕

本目录存放 **发版可出示** 的 session DOM probe 脚手架与（本机生成的）运行结果。

**不进 CI / 不进 `npm test`。** 真机 dump 可能含 DOM 选择器、title、dataAttrs → **不提交** `runs/*.json`。

## 目的

- 发版勾选 [RELEASE-EVIDENCE.md](../RELEASE-EVIDENCE.md) 的 home / conversation 时，能指出本机留痕路径。
- 包装脚本在 **无 CDP** 时写 `status=skipped` 留痕，**不算**发版完成（脚手架交付成功 ≠ probe pass）。

## 目录

| 路径 | 提交？ | 说明 |
|------|--------|------|
| `README.md`（本文件） | 是 | 约定与命令 |
| `SAMPLE.md` | 是 | **虚构**字段样例，无真实用户 DOM |
| `runs/.gitkeep` | 是 | 保证目录存在 |
| `runs/probe-session-*.json` | **否** | 真机 / skip 留痕（gitignore） |

运行态（安装侧，既有）：

`%LOCALAPPDATA%\CodexDreamSkin\session-dom-probe.json`

## 生成命令

```powershell
# 默认：CDP 预检 → 有则跑 probe 写 runs/；无则 skip 留痕 exit 0
pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1

# 仅打印纪律（不连 CDP、不写 evidence）
pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1 -SkipRun

# 无 CDP 时强制失败（exit 2）
pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1 -RequireCdp

# 跑 probe 但不写仓库留痕（仍写 LOCALAPPDATA 运行态）
pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1 -NoEvidence

# 直接 probe（不经包装层 evidence）
npm run probe:session
# 或
node scripts/windows/probe-session-dom.mjs
```

可选：`node packages/core/cli.mjs doctor` 看端口/进程是否就绪。

## 输出

- **仓库留痕**：`docs/evidence/runs/probe-session-YYYYMMDD-HHmmssZ.json`（UTC 时间戳 + 字面 `Z`）
- **运行态**：`%LOCALAPPDATA%\CodexDreamSkin\session-dom-probe.json`（由 `probe-session-dom.mjs` 写入）

包装层 JSON（`schemaVersion: 1`，`kind: "release-probe-session"`）关键字段：

| 字段 | 含义 |
|------|------|
| `status` | `"ran"` 或 `"skipped"` |
| `reason` | skip 时必填：`no-cdp` / `probe-script-missing` 等 |
| `cdpReachable` | CDP `/json/list` 预检 |
| `probeExitCode` | 透传 node probe exit；skip 可为 `null` |
| `conversationCovered` | `ran` 时：是否观测到会话 DOM（`inConversation`） |
| `releaseCheckHints.homeOk` | 是否可勾 home（ok+dreamStyle+pass） |
| `releaseCheckHints.conversationOk` | **仅** `conversationCovered` 时才可能为 true |
| `summary.ok` / `dreamStyle` / `pass` / `conversationPass` | 从 probe stdout 抽取；skip 时全 `null` |
| `summary.onHome` / `inConversation` | 场景提示 |
| `probe` | 解析后的 probe 对象；skip 为 `null`；stdout 非 JSON 时可能含 `rawStdout`（截断） |

## home vs conversation

| 场景 | 操作 | 勾选前提 |
|------|------|----------|
| **home** | Codex 开着、皮肤已注入即可跑 | evidence `status=ran` 且 `summary.pass=true`（及 ok / dreamStyle） |
| **conversation** | **须先打开任一对话** 再跑 | `status=ran` 且 `summary.conversationPass=true`；建议 `inConversation=true` |

若 `inConversation=false`，Host 会提示 conversation 未覆盖；请开对话后重跑。

## 无 CDP / SkipRun

| 情况 | 脚本行为 | 可否勾 RELEASE-EVIDENCE 完成 |
|------|----------|------------------------------|
| 无 CDP（默认） | 写 `status=skipped`，`reason=no-cdp`，exit **0** | **否** — 未跑真机不算发版完成 |
| 无 CDP + `-RequireCdp` | 同样 skip 留痕，exit **2** | **否** |
| `-SkipRun` | 不连 CDP、不写 runs JSON，exit **0** | **否** |
| 有 CDP 真跑 | `status=ran`，exit 透传 probe（0/2/3…） | 按 summary 关键字判断 |

**禁止**把 `status=skipped` 或仅 `-SkipRun` 当成勾选通过。

## 敏感与 gitignore

- 真实 `probe` 可能含 `url` / `title` / `dataAttrs` → **`docs/evidence/runs/*.json` 已 gitignore**。
- 只提交本 README、`SAMPLE.md`、`runs/.gitkeep`。
- 不要 `git add docs/evidence/runs/*.json`。

## 相关

- [RELEASE-EVIDENCE.md](../RELEASE-EVIDENCE.md) — 发版勾选
- [PROJECT.md §9.4](../PROJECT.md) — 验收表
- `scripts/windows/Run-ReleaseProbes.ps1` — 包装 + 留痕
- `scripts/windows/probe-session-dom.mjs` — 探测核心（本脚手架默认不改）
