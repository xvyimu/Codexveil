# codex-skin 五层深度优化变更报告

| 项 | 值 |
|----|----|
| 日期 | 2026-07-21 |
| 分支 | `feature/five-layer-internal-opt-2026-07-21` |
| 基线 | `feat/u1-workspace` @ `6e5e546` |
| 顶层准则 | `docs/PROJECT.md` · `docs/ARCHITECTURE.md` · `CLAUDE.md` |
| 范围 | **packages/core + packages/runtime 层内实现**；不改分层、不新增 npm 依赖、不 publish 安装态 |
| 主分支 | **未修改 `main` 内容路径上的生产发布** |
| 测试 | `npm test` **exit 0**（含 `test:state-io` · `test:fs-io`） |
| 状态 | **已 commit 待 PR → feat/u1-workspace** |

---

## 0. 项目架构理解（优化前置）

### 0.1 工作区

| 路径 | 角色 |
|------|------|
| `D:\orca` | 多项目沙盒；根无 git |
| `D:\orca\codex-skin` | 主产品线；ARCHITECTURE + git |

### 0.2 四层模型（PROJECT §2.1 · 最高准则）

```text
L1 交互   apps/launcher · 托盘 · F6 · CLI 用户命令
L2 调度   core/cli · core-win/launcher-ui · control-plane
L3a 状态  state.json · current.json · freshness · guard · kick
L3b 主题  packages/themes
L4 执行   runtime injector · core/cdp · discover
```

**硬边界未破：** core ↛ runtime；runtime ↛ core；主题只经 themes；单 injector；安装态零第三方 npm。

### 0.3 用户「五层」映射

| 用户层 | 本仓对应 | 本轮 |
|--------|----------|------|
| 1 架构解耦 | L3a state IO 三处重复；路径双源 | core `state-io`；guard → `resolveStudioPaths` |
| 2 代码重构 | 端口字面量散落 | `isValidPort` / MIN·MAX |
| 3 核心逻辑 | kick / freshness 语义 | **不改**判定 reason 码；不改 `--once` 降级 |
| 4 配额性能 | 无 RPM/TPM；kick 多端口 timeout | **收敛** control kick 仅 resolved+9336 |
| 5 工程 | 测试门禁 / 注释 | `test:state-io` · `test:fs-io` · 报告 |

「记忆策略 / 9RPM·TPM」属 LLM 智能体域，**本仓是 CDP 换肤**——不假装实现。

---

## 1. 第一层：架构解耦

### 缺陷
`kick-inject` / `state-freshness` / `dreamskin-guard` 各写 `pathExists` + JSON；guard 手拼 `LOCALAPPDATA` 未走 `resolveStudioPaths`；BOM 处理不一致。

### 思路
`packages/core/state/state-io.mjs`：`pathExists` · `readJsonFile` · `readTextTrim` · `isProcessAlive`。**不**从 `index.mjs` 稳定面导出（避免扩 public API）。runtime **不得** import 该文件。

### 收益
- IO 单点；BOM 一致；路径 SSOT

---

## 2. 第二层：代码重构

### 缺陷
端口 `1024`/`65535` 字面量多处；control.port 脏数据可缺上界校验。

### 思路
`cdp-helpers.isValidPort`；`constants.DEFAULT_CONTROL_PORT=9336`；process-win / kick / guard / cdp-port 共用。

### 收益
端口策略单点；非法端口不进 kick 扫描。

---

## 3. 第三层：核心逻辑（语义冻结）

| 行为 | 是否改变 |
|------|----------|
| kick 优先 control-plane，失败 `--once` | **否** |
| freshness reason 码 | **否** |
| shouldBlockApplyForDreamSkin | **否** |
| dualOpen 文案 | **否** |

---

## 4. 第四层：性能（克制）

| 项 | 旧 | 新 |
|----|----|-----|
| kick 端口扫描 | controlPort + 9336–9340（最多 5 次 timeout） | **仅** resolveControlPort + DEFAULT_CONTROL_PORT |
| 探活缓存 | 无 | **仍不加**（防 doctor 陈旧） |

---

## 5. 第五层：工程

| 项 | 内容 |
|----|------|
| 测试 | `test:state-io` · `test:fs-io` 并入 `test:unit` |
| 注释 | core `index.mjs` 标明 state-io 包内 |
| 报告 | 本文 |

---

## 6. 第二阶段：runtime 内 IO（用户批准）

| 项 | 内容 |
|----|------|
| 约束 | runtime **禁止** import core（publish 自包含） |
| 新增 | `packages/runtime/scripts/fs-io.mjs` + `fs-io.test.mjs` |
| 改写 | `control-plane.mjs` · `thumb.mjs` |
| 未改 | `injector.mjs`（无独立 pathExists 辅助块） |
| 与 core | **概念镜像、代码故意不共享** |

---

## 7. 变更文件清单

| 路径 | 动作 |
|------|------|
| `packages/core/state/state-io.mjs` | 新增 |
| `packages/core/state/state-io.test.mjs` | 新增 |
| `packages/core/state/kick-inject.mjs` | state-io · isValidPort · 端口扫描收敛 |
| `packages/core/state/state-freshness.mjs` | state-io |
| `packages/core/state/dreamskin-guard.mjs` | state-io · resolveStudioPaths · isValidPort |
| `packages/core/cdp/cdp-helpers.mjs` | `isValidPort` |
| `packages/core/cdp/cdp-port.mjs` | isValidPort |
| `packages/core/discover/process-win.mjs` | isValidPort |
| `packages/core/constants.mjs` | `DEFAULT_CONTROL_PORT` |
| `packages/core/index.mjs` | 导出 DEFAULT_CONTROL_PORT + 注释 |
| `packages/runtime/scripts/fs-io.mjs` | 新增 |
| `packages/runtime/scripts/fs-io.test.mjs` | 新增 |
| `packages/runtime/scripts/control-plane.mjs` | fs-io |
| `packages/runtime/scripts/thumb.mjs` | fs-io |
| `package.json` | test:state-io · test:fs-io |
| `docs/reports/2026-07-21-five-layer-internal-opt-report.md` | 本报告 |

---

## 8. 验证

```text
npm test                     → exit 0
npm run test:deps            → core↔runtime 无互引
npm run test:state-io        → pass
npm run test:fs-io           → pass
npm run test:freshness       → pass
```

---

## 9. 风险与回滚

| 风险 | 缓解 |
|------|------|
| kick 不再扫 9337–9340 | control-plane 仍写 state.controlPort + control.port；异常绑定需依赖文件 |
| BOM 统一 | 坏 JSON 仍 try/catch |
| 误用跨包 IO | test:deps + 双文件镜像 |

回滚：`git revert` 本分支提交；或 PR 关闭。

---

## 10. 审核决议（用户 2026-07-21）

1. **commit** 到 feature 分支 — 执行  
2. PR 目标 **`feat/u1-workspace`** — 执行  
3. **第二阶段 runtime fs-io** — 已纳入同分支  

未 publish 安装态；未合 main。
