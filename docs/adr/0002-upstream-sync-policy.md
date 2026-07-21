# ADR 0002 — 上游同步策略（Upstream Sync Policy）

- **状态**：**Superseded by [ADR 0006](./0006-independent-product-line.md)**（2026-07-22）
- **日期**：2026-07-20
- **相关**：0001（产品线合并）、0003（单一版本源）、**0006（独立产品线）**

> **废止说明（ADR 0006）**：本仓已删除 `upstream` remote；`sync-upstream-assets.ps1`
> 退役；`vendor/dreamskin` 仅作冻结快照。下文保留为历史决策记录，**不再执行**。

## 背景

本仓库是 `Fei-Away/Codex-Dream-Skin` 的 GitHub fork，但 `main` 已用完全重构版
force-push 覆盖，与上游**零共同历史**，且目录结构完全不同：

| | 上游 | 本 fork |
|---|---|---|
| 布局 | `windows/ macos/ core/ scripts/` | `packages/ apps/ themes/` |
| 皮肤资产 | `windows/assets/{dream-skin.css,renderer-inject.js}` | `packages/runtime/assets/…` |
| 启动器 | `windows/scripts/*.ps1` | `apps/launcher/` + `packages/core-win/`（已重写） |

因此 `git merge upstream/main` 不可行（冲突+结构错位）。但上游仍在演进，
两类东西值得持续吸收：① 皮肤视觉资产 ② PowerShell 逻辑修复（bugfix）。

## 决策

采用**两条独立机制**，由单个幂等脚本 `scripts/windows/sync-upstream-assets.ps1`
驱动，脚本只读上游、只写 `vendor/` 与基线 JSON，**从不自动改 runtime、从不 apply PS 改动**。

### 线 A — 视觉资产（文件级）

```
upstream/windows/assets/{dream-skin.css,renderer-inject.js}
  → vendor/dreamskin/assets/               （镜像层，脚本刷新）
  → [人看 diff]
  → packages/runtime/assets/               （promote，人工决定）
```

- 脚本把上游两文件抽到 `vendor/dreamskin/assets/`（镜像快照）。
- 脚本打印 `vendor/dreamskin/assets` ↔ `packages/runtime/assets` 的 diff 摘要。
- **promote 由人决定**：runtime 那份带本地覆盖（去 blur、artDataUrl null-safe、
  `SKIN_VERSION_TOKEN`），不能盲目覆盖。

### 线 B — PowerShell 修复（只自动发现）

- 脚本列出上游自基线以来动过 `windows/scripts/**` 与 `windows/*.ps1` 的 commit 标题：
  `git log <lastSyncedUpstreamSha>..upstream/main --oneline -- windows/scripts/ windows/*.ps1`
- 人读标题判断哪条值得搬；**移植是手动的**（本 fork 的 PS 已重写，无路径对应，不能盲搬）。
- 脚本不尝试 apply 任何 PS diff。

### 基线

- 受控文件 `docs/upstream-sync.json`：
  ```json
  { "lastSyncedUpstreamSha": "<sha>", "syncedAt": "<iso>", "note": "<free text>" }
  ```
- 脚本读它作为 `git log` 下界。
- 人工确认本轮吸收完成后，把 `lastSyncedUpstreamSha` 更新到最新 `upstream/main` 并提交。
- 初始基线：`fd6a118`（本 fork 分叉时上游 main）。

## 结果

- 跑一次脚本即知：有哪些新 CSS 可 promote + 哪些 PS 修复值得看，无需手动 `gh api | base64`。
- 视觉与逻辑分治：文件级可自动，逻辑级只发现不 apply。
- runtime promote 始终经人，保护本地覆盖不被上游冲掉。

## 权衡 / 已知代价

- PS 修复仍是**人工移植**，不省移植成本，只省发现成本——这是结构分叉的必然。
- `vendor/dreamskin/` 与上游可能短暂不同步（脚本未自动跑时）；以基线 SHA 为准。
- 不吸收 macos / CI / 文档；如未来需要再补 ADR。

## 未实施

本 ADR 只记录策略；`sync-upstream-assets.ps1` 与首个 `upstream-sync.json`
留待后续单独实现（当前轮次只出 ADR + 术语表）。
