# Codexveil · W3 re-publish gate dossier

> **PUBLISH: NOT EXECUTED**  
> Agent 只做卷宗 + 预检。**禁止**运行 `publish-runtime.ps1`，除非人原文授权 + VERSION。  
> 装态保持 **`1.3.25-eee7c8`** 直到人 gate。

| 字段 | 值 |
|------|-----|
| **波次** | portfolio-arch-upgrade-2026h2 · **W3** |
| **工作树** | `C:\Users\yuanjia\orca\workspaces\Codexveil\w3-cv-claude` |
| **分支** | `xvyimu/w3-cv-claude` |
| **tip (W3 开跑)** | `6910a22` · `6910a22419bc596c0cea57931e39ff64fac4b45a` |
| **装态 runtimeId** | **`1.3.25-eee7c8`**（`current.json` · 2026-07-22T17:10:42Z） |
| **建议 VERSION 线** | 仍 **`1.3.25`**（ADR 0003 · publish 会自戳 `1.3.25-<6hex>`） |
| **相关** | `true-publish-gate-checklist.md` · W2 报告 · `publish-runtime.ps1` · `soft-reattach.ps1` |

---

## 1. 为何需要 re-publish（一句话）

装态仍是 **wave 前后 tip 快照**（`eee7c8` 段）；**tip 已合入 W1 视觉 + W2 payload-builder S3**，injector 现 **静态 import** `./payload-builder.mjs`。  
若把 tip 的 `injector.mjs` 拷进装态而不 publish 白名单整图，会 **`ERR_MODULE_NOT_FOUND: payload-builder.mjs`**。

---

## 2. tip vs 装态差异

### 2.1 身份

| 面 | tip / 源树 | 装态 `versions/1.3.25-eee7c8` |
|----|------------|-------------------------------|
| git | `6910a22`（含 form-stack SSOT + W2） | 发布戳 `1.3.25-eee7c8`（**非**完整 git SHA 指针；hash 为 publish 随机 6 hex） |
| `current.json.version` | n/a（源树） | `1.3.25` |
| 默认 assets theme | `preset-arina-hashimoto` | **同** arina（装态已粉系默认） |

### 2.2 Runtime ESM 图（关键）

| 文件 | tip required | 装态 eee7c8 | 风险 |
|------|--------------|-------------|------|
| `injector.mjs` | 是 · ~1048 行 · **import payload-builder** | 有 · ~1139 行 · **内联 loadPayload** | tip 装入无 builder → 炸 |
| `theme-load.mjs` | required | **有** | 已在 Dual-B/wave8 闭合 |
| **`payload-builder.mjs`** | **required (W2 S3)** | **缺** | **主缺口** |
| `control-plane.mjs` | required | **有** | ok |
| `fs-io.mjs` | required | **有** | ok |
| `cdp-url-guard.mjs` | required | **有** | ok |
| `theme-catalog-budget.mjs` | required | **有** | ok |
| `image-metadata.mjs` (+ `core/`) | required | **有** | ok |

装态 scripts 实测（W3 探针）：

```text
payload-builder.mjs : False
theme-load.mjs      : True
control-plane.mjs   : True
fs-io.mjs           : True
injector.mjs        : True
```

### 2.3 行为 / 产品差（非 exhaustive · 相对 eee7c8 装态）

| 变更簇 | 代表 commit | 装态是否含 |
|--------|-------------|------------|
| theme-load 抽出 + publish required | Dual-B / wave8 | 部分（theme-load 有；**无** payload-builder） |
| W1 V2 arina 视觉 promote + stack-matrix | `88c91bb` | assets 默认已 arina；CSS/inject 细节以装态文件为准，**未**与 tip 字节对齐保证 |
| W2 contracts inject 面 + **payload-builder S3** + catalog-quality | `8e09b45` | **无** payload-builder · contracts **不**进 versions（开发态） |
| form/stack SSOT 文档 | `5484049` / merge `6910a22` | docs only |

**contracts（`packages/contracts`）**：ADR 0004 · **永不**进 `versions/`；re-publish 不携带。

### 2.4 若强行「只拷 tip injector」

```text
node …/versions/<id>/scripts/injector.mjs
→ ERR_MODULE_NOT_FOUND: Cannot find module '…/payload-builder.mjs'
```

**唯一正确路径**：`publish-runtime.ps1` 的 `$requiredRuntimeScripts`（含 `payload-builder.mjs`）整图拷贝 + flip `current.json`。

---

## 3. 自动预检（agent 已跑 · 2026-07-23 · 本 worktree）

| Check | Command | Exit |
|-------|---------|------|
| Unit + contracts | `npm test` | **0** |
| Publish whitelist dry-run | `pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1` | **0** |

`verify-publish-runtime-payload.ps1` 覆盖（含 W3 硬化）：

- `$requiredRuntimeScripts` 与 `publish-runtime.ps1` 锁步（含 **payload-builder.mjs**）
- repo 文件存在 + temp stage 拷贝
- staged Node import：`theme-load` · **`payload-builder`** · `control-plane`(+fs-io)
- injector 静态边：`./theme-load.mjs` · `./payload-builder.mjs` · 动态 `./control-plane.mjs`
- **不**写 `%LOCALAPPDATA%\Programs\CodexDreamSkin` · **不** flip `current.json`

可选（需本机 CDP / 活 Codex · **本波未强制**）：

```powershell
npm run doctor
# 或
node packages/core/cli.mjs doctor
```

---

## 4. 人 gate 步骤表（授权后执行）

> 前置口令示例：「**现在 publish** · VERSION **1.3.25**」+ 指定 checkout（本 wt 或已合入的默认分支 tip）。

| # | 步骤 | 命令 / 动作 | 期望 |
|---|------|-------------|------|
| 0 | 确认 tip 与授权范围 | `git rev-parse HEAD` · 确认含 payload-builder | SHA 可追溯 |
| 1 | 再跑预检 | `npm test` · `verify-publish-runtime-payload.ps1` | 均为 exit **0** |
| 2 | 关锁文件（可选） | 退出/停 DreamSkin watch / 托盘；避免 versions 占用 | 无文件锁 |
| 3 | **真 publish** | 见下框 | 打印新 `runtimeId` |
| 4 | 装态证明 | `Test-Path …\versions\<id>\scripts\payload-builder.mjs` 等 | **True** |
| 5 | 对齐校验 | `pwsh -NoProfile -File scripts/windows/verify-install-matches-repo.ps1` | 按脚本 exit |
| 6 | 活机 | `npm run doctor` · 换肤 / F6 / kick | `fresh=true` · 无 MODULE_NOT_FOUND |
| 7 | 真机主题纪律（可选） | CONTRIBUTING C-2 **H1–H7** | 肉眼一句 |

```powershell
# 从授权 checkout 根目录 — 建议仍 1.3.25 线
pwsh -NoProfile -File scripts/windows/publish-runtime.ps1 -Version 1.3.25
```

发布后立刻：

```powershell
$root = "$env:LOCALAPPDATA\Programs\CodexDreamSkin"
$cur  = Get-Content "$root\current.json" -Raw | ConvertFrom-Json
$ver  = Join-Path $root $cur.relativeEnginePath
@(
  "payload-builder.mjs",
  "theme-load.mjs",
  "control-plane.mjs",
  "fs-io.mjs",
  "injector.mjs"
) | ForEach-Object { "$_ : $(Test-Path (Join-Path $ver "scripts\$_"))" }
# 全部 True；current.runtimeId 形如 1.3.25-<6hex> 且 ≠ eee7c8（除非巧合）
```

---

## 5. 回滚 / soft reattach / GC 注意

| 机制 | 行为 | 操作者注意 |
|------|------|------------|
| **`current.json.bak-*`** | publish 前备份旧 current | 回滚：把 bak 内容写回 `current.json`（注意 UTF-8 **无 BOM**）并指回旧 `versions/<id>` |
| **versions GC** | 保留 **current + previous**（优先 bak 中的 runtimeId） | 再 publish 会删更旧目录；**回滚窗 = 上一装态**，勿连 publish 两次再指望更早版本 |
| **soft reattach** | `soft-reattach.ps1`：杀旧 `versions/*/injector.mjs` watch → 用新 runtime 起 `--watch` + `--theme-dir` 状态根 `active-theme` | post-update Quiet 失败/超时 → 自动 soft reattach；**非**发版失败（G5-C） |
| **state 根** | `%LOCALAPPDATA%\CodexDreamSkin`（非 Programs） | reattach 必须带 `--state-root`，避免 stateRootGuess 落到 versions |
| **程序锁** | injector / node 占脚本 | 回滚或 re-publish 前停旧 watch |
| **禁止** | 手拷半套 scripts；改 asar；agent 自跑 publish | — |

手动 soft reattach 思路（仅人操作 · 路径以新 runtime 为准）：

```powershell
# 点源后调用（参数与 publish 失败降级一致）
. .\scripts\windows\soft-reattach.ps1
Invoke-CodexSkinSoftReattach `
  -RuntimeRoot "$env:LOCALAPPDATA\Programs\CodexDreamSkin\versions\<NEW_ID>" `
  -RuntimeId "<NEW_ID>" `
  -StateRoot "$env:LOCALAPPDATA\CodexDreamSkin"
```

若 soft reattach 返回 false（无 live injector / browserId）：**点任务栏 Codex** 走正常启动路径。

---

## 6. 明确不做（本卷宗 / W3 agent）

| 禁止 | 状态 |
|------|------|
| 运行 `publish-runtime.ps1` | **NOT EXECUTED** |
| 改装态 / flip `current.json` | 否 |
| asar / vendor / push main | 否 |
| ADR 0005 薄壳实现 | 否（仍 Proposed · W3–W4 设计窗） |
| 把 contracts 塞进 versions | 否 |

---

## 7. 签字栏（人 gate）

| 项 | 填写 |
|----|------|
| 授权原文（摘录） | |
| 执行人 | |
| 执行 tip SHA | |
| VERSION | `1.3.25`（建议） |
| 新 runtimeId | |
| post-update / soft reattach 结果 | |
| doctor / H1–H7 | |
| 日期 | |

**状态：** 卷宗齐 · 预检绿 · **等待人 gate** · 装态仍 **1.3.25-eee7c8**。
