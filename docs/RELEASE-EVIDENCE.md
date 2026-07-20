# 发版证据清单（维护者）

产品线版本：`package.json` / publish `-Version` 对齐（当前 **1.3.25**）。不抬版本号 unless intentional。

## 每次发版前

- [ ] `npm test`（themes + store + adapter + deps + freshness + cdp-url）
- [ ] 建议：`pwsh -NoProfile -File scripts/windows/write-baseline.ps1` → 刷新并核对 `docs/BASELINE.generated.md`（short HEAD / expectedRuntimeId）
- [ ] 若改 `packages/runtime/**`：`pwsh scripts/windows/publish-runtime.ps1 -Version <line>`（**下次 publish 会带上** `scripts/cdp-url-guard.mjs`）
- [ ] `pwsh scripts/windows/verify-install-matches-repo.ps1 -RepoRoot <repo>` → exit 0
- [ ] `node packages/core/cli.mjs doctor` → `injectorPathFreshness.fresh=true`
- [ ] 可选 probe：见下节 home / conversation（**不进 CI** / **不进** `npm test`）
- [ ] 若改 control-plane token：`npm run test:control`（本机 loopback）
- [ ] 可选 TD-02 摘要演练：`pwsh -NoProfile -File scripts/windows/verify-post-update-failure-summary.ps1` → exit 0

## 可选 probe（不进 CI；详表 PROJECT §9.4）

前置：任务栏 Codex、CDP 9335、皮肤已注入。

**留痕路径（本机生成，真实 JSON 不提交）：**

- 仓库：`docs/evidence/runs/probe-session-*.json`（gitignore；脚手架见 [docs/evidence/README.md](./evidence/README.md)）
- 运行态：`%LOCALAPPDATA%\CodexDreamSkin\session-dom-probe.json`

**如何生成：**

```powershell
pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1
# 仅打印纪律、不连 CDP：
pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1 -SkipRun
# 直接 probe（不写仓库 evidence 包装层）：
npm run probe:session
```

勾选规则：

- [ ] **home**  
  命令：`pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1`（或 `npm run probe:session`）  
  **留痕**：`docs/evidence/runs/probe-session-*.json` 与/或 `%LOCALAPPDATA%\CodexDreamSkin\session-dom-probe.json`  
  **勾选前提**：某次 evidence `status=ran` 且 `summary.pass=true`（及 `ok` / `dreamStyle`）；JSON 关键字 `"ok": true`、`"dreamStyle": true`、`"pass": true`；exit 0  
  （无 page → exit 2）

- [ ] **conversation**  
  **须先打开任一对话**，再跑同上  
  **留痕**：同上路径（建议另存/另次时间戳文件）  
  **勾选前提**：`status=ran` 且 `summary.conversationPass=true`（建议 `inConversation=true`）；exit 0（失败 exit 3）

- [ ] 包装纪律（打印 §9.4 期望 + 可选实跑 / skip 留痕）：  
  `pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1`  
  仅纪律不连 CDP：`…\Run-ReleaseProbes.ps1 -SkipRun`

**未跑真机不算发版完成：**

- `status=skipped`（如 `reason=no-cdp`）→ **不得**勾 home / conversation 完成  
- 仅 `-SkipRun` → **不得**勾完成  
- 无 CDP 时包装默认可 exit 0（脚手架/skip 留痕成功），**不是** probe pass

完整命令、字段与 gitignore 策略见 [evidence/README.md](./evidence/README.md)；安装树路径见 [PROJECT.md §9.4](./PROJECT.md)。

## 说明

- Quiet post-update exit=2 + soft reattach OK = 正式降级，**不算**发版失败（见 publish 日志 `soft reattach OK` + 失败 check 摘要）
- 链：PROJECT §6 · CONTRIBUTING §C-3/C-4 · §9.4 · 建议 baseline：`write-baseline.ps1` · 留痕：`docs/evidence/`
