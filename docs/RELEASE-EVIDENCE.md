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
  **勾选前提（硬）**：evidence `status=ran` 且 **`conversationCovered=true`**（或 `summary.inConversation=true`）且 `summary.conversationPass=true`；`releaseCheckHints.conversationOk=true` 时更佳；exit 0（失败 exit 3）  
  **禁止**：仅因 `conversationPass=true` 而 `inConversation=false`（vacuous true，home 跑也会绿）就勾 conversation

- [ ] **会话视觉抽检（UX-4 / U5，目视，不进 CI）**  
  在 **conversationCovered=true** 的同一次（或紧随其后的）真机会话上确认：  
  - [ ] 用户/助手气泡区内**正文可读**（非灰融底）  
  - [ ] composer 输入字对比足够  
  - [ ] 装饰/hero **未挡住**输入框与主要按钮  
  - [ ] 无明显闪烁或持续重布局（动效克制）  
  未开对话则 **不得**勾本项。

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
- 代码签名 / SmartScreen（#24）：近期不购证；决策见 [plans/codesign-decision-2026-07-21.md](./plans/codesign-decision-2026-07-21.md)
- 链：PROJECT §6 · CONTRIBUTING §C-3/C-4 · §9.4 · 建议 baseline：`write-baseline.ps1` · 留痕：`docs/evidence/`
- [v6 调研（2026-07-21）](./research/2026-07-21-master-research-v6-palette-root-and-hd-bubble.md)：闪白根因补丁 48b5bae 全量透传 palette 四色 + HD art + 气泡双模式 0326abb · v5 假关闭教训 + BASELINE；probe-white-flash pass（过程文献；合入见下）
- **v6 squash 合入 main（2026-07-21）**：PR [#1](https://github.com/xvyimu/Codex-Dream-Skin/pull/1) · merge `b80bf4e` · themes-gate PR [run 29814826310](https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29814826310) success · main push [run 29814915657](https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29814915657) success（**仅 npm test**，不证明 CDP 视觉）
- [v7 调研（2026-07-21）](./research/2026-07-21-master-research-v7-gate-hygiene-and-ux.md)：门禁诚实化 · `probe-project-hd` 断言型（pass/failed/exitCode）· 证据 URL 入库 · BASELINE 对齐 tip · surfaceLuma `#rrggbb` 边界文档
