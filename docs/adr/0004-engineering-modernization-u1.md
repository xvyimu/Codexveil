# ADR 0004 — 工程现代化与受控依赖放宽（U1）

- **状态**：**Accepted**（2026-07-21 · 用户确认「Accept 0004 + feat/u1-workspace」）
- **日期**：2026-07-21
- **相关**：0001 单产品线 · 0002 上游 · 0003 单一版本源 · **0005** U3 薄壳
- **表单结论**：主包 **U1+U3** · 硬边界 **长期放宽（需 ADR）** · U1 四组件全选 · 实施自 `feat/u1-workspace`

## 背景

产品线在 v6/v7 已收口：palette 跨层根因、断言探针、远程 themes-gate、peer 矩阵。下一阶段瓶颈不再是「缺功能」，而是：

1. **跨层契约不可执行**（文档有、类型无 → v5 假关闭类静默失败可复现）  
2. **injector 巨石**（透传 / 重注决策 / CDP 会话耦合）  
3. **探针与测试碎片化**（手写 assert、三探针重复 CDP 样板）  
4. **「零 npm 生产依赖」** 阻碍 TS/合约测试/lint 规则固化，却未阻止 PS/Node 脚本债增长  

用户在交互表单中选择：**长期放宽部分工程约束**，并优先落地 U1 四组件：TS+contracts、probe-kit、stamp Reconciler、Vitest+禁互引 lint。

## 决策

### D1. 依赖策略：从「零生产依赖」改为「双平面」

| 平面 | 允许 | 禁止 |
|------|------|------|
| **安装态 runtime**（`versions/<id>/` 打进用户机） | 默认仍 **零第三方 npm**；若引入须单独 ADR 且可审计 | 任意重框架、自动更新外连、遥测默认开 |
| **开发/CI 平面**（repo 构建、测试、lint、类型） | **允许** TypeScript、Vitest、Zod/Valibot、ESLint/oxlint/Biome、pnpm | 把 devDep 误打进 versions/ |

`package.json` 的 `"private": true` 保持；新增 `pnpm-workspace` 或 npm workspaces 显式包。

### D2. TypeScript 渐进 + `@codex-skin/contracts`

- 新建（名可微调）`packages/contracts`：palette 四色、theme manifest 子集、doctor 顶层字段、control-plane 响应形状。  
- 运行时校验：Zod（或 Valibot）**一份 schema** → TS 类型 + 单测。  
- 迁移序：`packages/themes` → `packages/core` → `packages/runtime`（runtime 可先 JSDoc+checkJs，后 TS）。  
- **发布物**：runtime 仍产出 **可直接 node 的 JS**（tsc/esbuild 编译进 publish 流水线），安装态用户不装 TypeScript。

### D3. `probe-kit` 统一探针

- 抽出：loopback URL 校验、CDP 会话、`pass/failed/exitCode` 协议、结果 JSON 写盘。  
- `probe-white-flash` / `probe-project-hd` / `probe-session-dom` 改为薄封装。  
- 协议字段稳定后可被自托管 Windows runner 复用（见排期，非 U1 必需）。

### D4. stamp Reconciler（注入架构）

从 `injector.mjs` 逻辑拆分（可仍同包内模块）：

| 模块 | 职责 |
|------|------|
| **PayloadBuilder** | theme → CDP payload（palette 全量等） |
| **Stamp** | `hash(engineVersion + css + themeFingerprint + rendererRev)` |
| **Reconciler** | 仅 stamp 变化或 target 新建时 inject；幂等 |
| **TargetRegistry** | page/targetId → lastStamp / lastError |
| **CdpSession** | 连接、evaluate、超时 |

**禁止**借拆分引入第二 watch 进程。

### D5. Vitest + 禁互引 lint

- 现有 `*.test.mjs` 迁 Vitest（可分批）；`npm test` / CI 入口改为 vitest run。  
- Lint/自定义规则：**core ↛ runtime 静态 import**、**runtime ↛ core 静态 import**（与 `test:deps` 双保险）。  

### D6. 仍不放宽（硬底线）

- 不修改 / 不镜像官方 asar·MSIX 为产品主路径  
- 不劫持商店 AUMID  
- 主题默认 **data-only**（禁顶层 scripts/hooks/eval）  
- control-plane：**loopback + mutating token**  
- CDP：**127.0.0.1**；不把调试端口暴露到非本机  
- **单一 watch 守护**；kick 降级 `--once` 纪律不变（dual-open-policy）  
- macOS **不**因本 ADR 自动成为一等公民（平台扩张另案）  
- ADR 0003：**publish -Version 仍是 runtime 线权威**

### D7. 与「零依赖」文档的关系

- `PROJECT.md` / CONTRIBUTING 中「零 npm 生产依赖」改为引用本 ADR：**安装态 runtime 默认零第三方；开发平面允许 lockfile 依赖**。  
- `test:deps` 语义调整为：扫描 **runtime 发布图** 无第三方，而非整个 repo 无 node_modules 用途。

## 结果（期望）

- 跨层字段缺失在 **类型/校验阶段** 失败，而非用户闪白。  
- 探针与 CI 共享协议；「dump=pass」类回归更难。  
- injector 可测单元变多；stamp 减少无效 inject。  
- 为 ADR 0005（Tauri 壳）提供稳定 **OpenAPI/JSON 契约** 而不嵌入 GUI。

## 权衡 / 代价

| 代价 | 缓解 |
|------|------|
| 工具链变重（pnpm/TS/CI 时长） | 缓存；runtime 发布物仍简单 |
| 迁移期 JS/TS 混存 | 包级 `allowJs`；禁新 JS 大文件进 core |
| 贡献者门槛 | CONTRIBUTING 补「只改 themes 仍可不碰 TS」路径 |
| 误把 devDep 打进 versions/ | publish 流水线白名单 + CI 检查 versions 无 node_modules |

## 非目标（本 ADR）

- Tauri / 桌面 GUI（→ **0005**）  
- `.codexskin` 成为唯一包格式（可选后续 ADR）  
- 云端 ubuntu「假视觉 CI」  
- OV 代码签名采购（仍见 codesign-decision；可并行评估）

## 实施状态

**Accepted · 实施中**（2026-07-21 · 用户确认）。  
排期：[`plans/u1-u3-two-week-plan-2026-07-21.md`](../plans/u1-u3-two-week-plan-2026-07-21.md)。  
分支：`feat/u1-workspace` — `packages/contracts` + pnpm workspace + `tsconfig.base.json`。

## 参考

- 仓内：`ARCHITECTURE.md` 跨层契约 · v7 报告 · `github-peer-matrix`  
- 外部方法：awesome-codex-skins stamp/pack 门 · Styler evidence 话术 · heige control token 威胁模型  
