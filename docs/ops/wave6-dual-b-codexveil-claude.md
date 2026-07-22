# Wave6 Dual-B · Codexveil · claude

| 项 | 值 |
|----|-----|
| **agent** | claude |
| **worktree** | `C:\Users\yuanjia\orca\workspaces\Codexveil\dual-b-cv-claude` |
| **branch** | `xvyimu/dual-b-cv-claude` |
| **baseline tip** | `dc8dee9` (`dc8dee9b0cc0bdb7ef64ba2b892bbb7dd8b23e9b`) · `refactor(runtime): extract theme-load (T-CV-002)` |
| **dirty at start** | clean |
| **策略** | TOOL · Dual-A 胜方 codex · P0 两侧一致 |
| **日期** | 2026-07-22 |

> 路径以本 worktree 为准；**不是**主 checkout `D:\orca\Codexveil`。

---

## 1. 做了什么

### P0-1 · 修复 publish 漏拷 `theme-load.mjs`

`injector.mjs`（tip T-CV-002）已 `import … from "./theme-load.mjs"`，但 `scripts/windows/publish-runtime.ps1` 只强制拷贝 `injector` / `cdp-url-guard` / `theme-catalog-budget` / `image-metadata`，**未**拷 `theme-load.mjs` → 装态 `versions/<id>/scripts/` 启动会 `ERR_MODULE_NOT_FOUND`.

**改动**（`scripts/windows/publish-runtime.ps1`）：

- 引入 `$requiredRuntimeScripts`：`injector.mjs`、**`theme-load.mjs`**、`cdp-url-guard.mjs`、`theme-catalog-budget.mjs`、`image-metadata.mjs`
- 缺源文件 → **throw**（不再静默漏拷）
- 可选环增加 `payload-builder.mjs`（S3 未落地时 skip；落地后自动进 versions）

### P0-2 · 闭包 / dry-run 验证

新增 `scripts/windows/verify-publish-runtime-payload.ps1`：

- **不**写 `%LOCALAPPDATA%\Programs\CodexDreamSkin` / `current.json`
- 静态：`publish-runtime.ps1` 文本含 required 文件名
- 仓内：required 源文件存在
- 临时 stage：拷贝 scripts + `core/image-metadata.mjs`（`image-metadata.mjs` 解析 `../core/…`）
- Node：staged `import { loadTheme } from "./theme-load.mjs"` + `node --check injector.mjs`
- injector 仍 import `./theme-load.mjs`

**exit**：`0` 闭包绿 · `1` 洞/导入失败 · `3` 意外错误

同步 `scripts/windows/verify-install-matches-repo.ps1`：`theme-load.mjs` + `image-metadata.mjs` 标 **Required**（装态 hash 对齐）；`payload-builder.mjs` optional。

### 报告

本文件。

---

## 2. 没做什么

| 项 | 原因 |
|----|------|
| 真 `publish-runtime.ps1 -Version` 覆盖装机 | 人 gate · 题单禁止 |
| `payload-builder.mjs` 抽出（injector-split S3） | P1；只预留 optional 白名单 |
| Vue 面板 / 第二 injector / 大重构 | TOOL 硬边界 |
| `git push` / 合 main / 开 PR | Dual-B 硬约束 |
| 改 `SKIN_VERSION` / 发版 stamp | 非本切片 |

---

## 3. 验证命令 + exit code

在 worktree 根执行：

| 命令 | exit |
|------|------|
| `pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1` | **0** |
| `npm run test:theme-load` | **0** |
| `npm test`（unit + contracts） | **0** |

未跑（需装机 / CDP / 人确认）：

- 真 `publish-runtime.ps1 -Version …`（会 stamp 仓内 token + 翻 `current.json`）
- `npm run doctor` / `probe:session` / `verify-install-matches-repo.ps1`（依赖本机已装 CodexDreamSkin；装态未 re-publish 前 `theme-load` 仍可能缺）

### 复现 dry-run（总控/对侧）

```powershell
cd C:\Users\yuanjia\orca\workspaces\Codexveil\dual-b-cv-claude
pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1
# expect: VERIFY OK …  + exit 0
```

真 publish（**人 gate**，本 Dual-B **未执行**）：

```powershell
pwsh -NoProfile -File scripts/windows/publish-runtime.ps1 -Version 1.3.25
# then: Test-Path "$env:LOCALAPPDATA\Programs\CodexDreamSkin\versions\<id>\scripts\theme-load.mjs"
```

---

## 4. 变更清单

| 路径 | 动作 |
|------|------|
| `scripts/windows/publish-runtime.ps1` | required 白名单含 `theme-load.mjs`；optional `payload-builder.mjs` |
| `scripts/windows/verify-publish-runtime-payload.ps1` | **新增** dry-run 闭包 |
| `scripts/windows/verify-install-matches-repo.ps1` | install hash 对 `theme-load` / `image-metadata` 必检 |
| `docs/ops/wave6-dual-b-codexveil-claude.md` | 本报告 |

---

## 5. 对侧可吸收（假设 3 点）

1. **required 数组 + throw**：比「多一行 Copy-Item」更能防下一模块（payload-builder）再漏；源缺即失败。  
2. **dry-run stage 要带 `core/image-metadata.mjs`**：只 stage scripts 会误报 theme-load 失败（adapter 找 `../core`）。  
3. **装态对齐脚本同步 Required**：`verify-install-matches-repo` 不抬 `theme-load` 则 post-publish 仍可能「绿」而实际洞。

---

## 6. 残留风险

- 装机目录在 **人工 re-publish 前** 仍可能缺 `theme-load.mjs`；本切片只修 **tip 脚本闭包**。  
- `payload-builder` 尚未抽出；optional 已预留，S3 合入后应再跑 dry-run 并把 optional→required（若 injector import 它）。  
- dry-run **不**跑完整 `publish-runtime.ps1` 副作用（GC / post-update / stamp 写回）——有意隔离。

---

## 7. 判定（自检）

| P0 | 状态 |
|----|------|
| publish 白名单含 theme-load | **PASS** |
| dry-run/闭包可复现 + exit 0 | **PASS** |
| 报告含 worktree/tip/验证 | **PASS** |
| 无真 publish / 无 push | **PASS** |

**停止等待总控评分。**
