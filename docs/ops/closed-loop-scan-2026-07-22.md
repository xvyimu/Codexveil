# Codexveil 闭环扫描 · T-CV-001 · 2026-07-22

> **角色**：QA · 只读扫描 · 禁止功能开发 / Vue 面板 / 大重构  
> **仓库**：`D:\orca\Codexveil` · 分支 `main`  
> **任务**：T-CV-001 · task_d1b903221ae5

---

## 1. Git 现状

| 项 | 值 |
|----|-----|
| tip | `1743061` (`1743061770f118f59884c02cde180c2e8e6ffff2`) |
| 分支 | `main` |
| dirty | **clean**（scan 开始时 `git status --porcelain` 空） |
| 最近提交 | `1743061` docs: TOOL TARGET + ASIS and path identity · `ca2b418` ASIS + injector-split notes · `f7988ee` ARCHITECTURE_TARGET · `fdeba79` worktree setup · `77892f8` probe-kit tests |

说明：本报告落盘后会出现 **docs-only** 脏文件；无业务代码 diff。

---

## 2. package 脚本 vs 文档 / handoff

### 2.1 根 `package.json`（`codex-skin@1.3.25`）

主要 scripts（与 `CLAUDE.md` / `docs/PROJECT` 约定一致）：

| script | 用途 |
|--------|------|
| `doctor` / `list` / `status` / `help` | CLI 面 |
| `test:unit` | themes/store/adapter/deps/freshness/cdp-url/catalog-budget/stamp/probe-kit + themes-contracts |
| `test` | `test:unit` + `test:contracts` |
| `test:control` | 本机 loopback；**不进** `npm test` |
| `probe:session` | live CDP；**不进** `npm test` |
| `build:contracts` / `typecheck` | contracts 开发平面 |

### 2.2 与近期 handoff / 计划一致性

| 来源 | 声明 | 代码实况 | 一致? |
|------|------|----------|-------|
| `docs/ARCHITECTURE_TARGET.md` | TOOL 线；**不建** Vue/NaiveUI 面板 | 无 Vue 依赖；交互 = 托盘/CLI/F6 | **是** |
| `docs/plans/injector-split-2026-07-22.md` | 抽出 `theme-load.mjs` + `payload-builder.mjs`；`package.json` 增 `test:theme-load` / `test:payload-builder` | 两文件 **不存在**；scripts **未**增加；仅 `injector.mjs` | **方案已写、实现未合 main** |
| `docs/plans/task-cards-2026-07-21.md` | 12 卡均已完成 | 与 tip 文档收口一致；后续债见 PAIN / injector 计划 | **是（卡面）** |
| `docs/PAIN-POINTS.md` #25 F6 | 仓内已恢复；**安装态需 publish** | 文档自述风险；本扫描未跑安装态 smoke | **文档自洽；装态未验** |
| 仓库 handoff 文件 | （无 `*handoff*` 文件） | 侧线 SSOT 在 `D:\orca\docs\` + 本仓 `docs/plans/*` | N/A |

**结论**：脚本面与 **当前 main 交付物**一致；与 **injector-split 计划**不一致属「计划领先于实现」，不是脚本漂移。

### 2.3 测试证据（本扫描）

| 命令 | exit |
|------|------|
| `npm test`（`D:\orca\Codexveil`） | **0**（unit + contracts 全绿） |

未跑：`doctor` / `test:control` / `probe:session`（需本机 Codex Desktop / CDP；非本任务强制）。

---

## 3. 验收对照（T-CV-001）

- [x] 报告落盘 `docs/ops/closed-loop-scan-2026-07-22.md` — **PASS**
- [x] 零业务代码 diff（仅允许 docs）— **PASS**（本任务只写本报告）
- [x] tip / 分支 / dirty 记录 — **PASS**
- [x] package 脚本与 handoff/计划对齐说明 — **PASS**
- [x] 下一 P0 ≤3 条且有证据 — **PASS**（§4）
- [x] 明确 TOOL 线不建 Vue 面板 — **PASS**（§5）

## 结论：**合格**

---

## 4. 建议下一 P0（最多 3 · 均有证据）

1. **[P0] injector 拆分落地（或正式 No-Go 本切片）**  
   证据：`docs/plans/injector-split-2026-07-22.md` 要求 `theme-load.mjs` / `payload-builder.mjs` + publish 白名单 + scripts；`Test-Path` 两者均为 **False**；tip 仅有文档提交。  
   派工：DEV（cv-2）+ TEST（cv-3）；合 main 策略服从 portfolio「cv 微提交不默认合 main」。

2. **[P0] 安装态 publish 对齐（F6 / #25）**  
   证据：`docs/PAIN-POINTS.md` #25 — 仓内 F6 已恢复，安装态 `versions/` 仍旧直至 `publish-runtime.ps1`。用户体感在安装态，不在 git tip。  
   派工：DEV/OPS（发版脚本 + 用户侧 verify）；非 Vue。

3. **[P0-可选] 本机 doctor / smoke 留证**  
   证据：本扫描 `npm test` 绿但未跑 `doctor`/`probe:session`；ARCHITECTURE_TARGET 维护边界要求注入/CDP 变更须 doctor 或 smoke 说清结果。下一切注入相关 PR 应附证据行。  
   派工：QA 附跑 或 DEV DoD。

---

## 5. TOOL 线边界（硬约束 · 写死）

- 产品标签：**TOOL**（非旗舰 SPA 产品线）。  
- **不建** Vue / React / NaiveUI 管理面板；交互保持 **托盘 / CLI / F6 / 快捷方式**。  
- **不**引入 Go 网关 / Python AI-Core / SQL；主栈 **Node ESM + pwsh + 薄 C#**。  
- 依据：`docs/ARCHITECTURE_TARGET.md` §1–§4 · 组合侧线 SSOT。  
- 本闭环 **禁止**以「架构对齐」名义开第二面板战场。

---

## 6. 问题 / 风险（扫描级）

| 级 | 项 | 说明 |
|----|-----|------|
| P1 | 计划未实现 | injector-split 文档在仓，代码未在 tip → 读者易误判已拆分 |
| P2 | 安装态漂移 | F6 等「仓内绿、装态旧」依赖人工 publish |
| P3 | SmartScreen | PAIN #24 已知；codesign No-Go 已文档化 |
| — | 密钥 | 本扫描未发现提交面 token/密钥（未做全树 secret 扫；有发现应 escalation） |

---

## 7. 整改建议（给总控）

- **DEV**：按 injector-split SSOT 实现 S1–S5，或总控书面冻结切片。  
- **OPS/DEV**：需要用户可见 F6 时走 `publish-runtime.ps1 -Version`，并更新 PAIN #25 状态。  
- **DOC**：可选在 overview 链入本扫描；**不要**把 ASIS/TARGET 当实现完成声明。  
- **禁止派工**：Vue 面板、第二 injector/watch、core↔runtime 双向依赖。

---

## 8. 元数据

| 字段 | 值 |
|------|-----|
| 任务 | T-CV-001 |
| 判定 | **合格** · verdict=pass |
| 测试 | `npm test` exit 0 |
| 修改文件 | 仅本报告（+ 新建 `docs/ops/`） |
| 日期 | 2026-07-22 |
