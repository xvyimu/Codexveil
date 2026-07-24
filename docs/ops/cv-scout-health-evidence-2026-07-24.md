# M-CV-scout-health · Phase0 深扫 evidence · 2026-07-24

**MODE：** `cv-scout-health` · **WRITE_POLICY：** `local-commit`（仅本 evidence + 可选 commit；**禁止 push / asar / publish-runtime / 第二 injector**）  
**WT / 支：** `C:\Users\yuanjia\orca\workspaces\Codexveil\cv-scout-health` · `xvyimu/cv-scout-health`  
**基线 tip：** `ebc3568`（≡ main · `docs(ops): CV tip vs install runtime gap card`）  
**STACK_SSOT：** [`docs/PROJECT.md`](../PROJECT.md) §1.5  
**Brief：** `cv-coord/cv-long-wave/scout-health-brief.md`  
**前序：** [`cv-day-ready-2026-07-24.md`](./cv-day-ready-2026-07-24.md) · [`cv-runtime-gap-card-2026-07-25.md`](./cv-runtime-gap-card-2026-07-25.md)

---

## 总控回执

| 项 | 值 |
|----|-----|
| 模块 | **M-CV-scout-health** |
| Phase | Phase0 深扫 **DONE** |
| workspaceStatus | **in-review**（请总控审 evidence → 再开 Phase1 / 实现 child） |
| 产出 | 本文 `docs/ops/cv-scout-health-evidence-2026-07-24.md` |
| 业务码 | **未改**（只读扫描 + docs） |
| push / publish / asar | **未做** |
| 本机复核 | `test:themes|themes-contracts|store|adapter|deps|catalog-quality|contracts` 均为 **exit 0**；`npm run doctor` **exit 0** |
| 对总控基线 | 与 progress §0.3 main@`ebc3568` 一致：**themes/contracts 无红** |
| **派发建议（摘要）** | `cv-themes-contracts` → **NO-CODE / evidence-only（跳过改码）**；`cv-doctor-smoke` → **文档落点**（usage §故障 / day-ready §4 / 可选 ops 单卡）；ADR0005 → **DEFER 1 页** `docs/ops/cv-adr0005-defer-2026-07-24.md`（无壳代码） |
| 下一步（总控） | 审本卡 → 标 scout DONE → 开 `cv-doctor-smoke`（文档）+ ADR0005 DEFER；**勿**默认开 themes 修码 child |

---

## 1. doctor / smoke 命令现状表

来源：`package.json` scripts · 根 `CLAUDE.md` · `docs/PROJECT.md` · `docs/usage.md` · `docs/ops/cv-day-ready-2026-07-24.md` · `apps/launcher/*`。

| 命令 | 用途 | 进 `npm test`？ | 需 live CDP / 装态？ | 风险 |
|------|------|-----------------|----------------------|------|
| `npm run doctor` / `node packages/core/cli.mjs doctor` | 只读诊断：Codex 发现、CDP 9335、injector 存活、control 9336、`injectorPathFreshness`、主题计数 | **否** | 读装态 `state`/`current`；CDP 可选（未开也 exit 0 + diagnosis） | **低**（只读） |
| `npm run status` / `cli.mjs status` | 运行态摘要（与 doctor 同族 CLI） | **否** | 同 doctor | **低** |
| `npm run list` / `cli.mjs list` | 列仓内 + 用户 catalog 主题 | **否** | 读 themes/ + stateRoot catalog | **低** |
| `npm run help` / `cli.mjs help` | 子命令帮助 | **否** | 否 | **无** |
| `npm run probe:session` | live CDP DOM 会话探针（`scripts/windows/probe-session-dom.mjs`） | **否** | **是** · 需 Codex+CDP | **中**（触 DOM；不进 CI） |
| 装态 `…\smoke-dream-skin.ps1`（源：`apps/launcher/smoke-dream-skin.ps1`） | 装态冒烟：runtimeId、catalog/lock、CDP 身份、injector alive、`--verify`、payload | **否** | **是** · 装态 programRoot + live CDP | **中**（写日志；verify 触 CDP） |
| 装态 `…\check-and-fix.ps1`（源：`apps/launcher/check-and-fix.ps1`） | 一键修复：CDP/injector/catalog；必要时 reattach / open | **否** | **是** · 可起/杀 injector | **高**（会动 watch 进程；禁当 CI） |
| 装态 `open-codex-dream-skin.ps1` | 日常 open 路径 | **否** | 起 Codex + injector | **中高**（用户路径） |
| 装态 `post-update-regression.ps1` | 商店更新后修复回归 | **否** | live | **中高** |
| `npm run test:control` | control-plane loopback 单测 | **否**（不进 `test:unit`） | 本机 loopback | **低**（文档：不进 CI） |
| `npm test` / `test:unit` + `test:contracts` | 单元 + contracts 门闩 | **是（本身）** | **否**（无 live CDP） | **低** |
| `npm run test:freshness` / `test:cdp-url` / `test:catalog-budget` / `test:stamp` / `test:theme-load` / `test:payload-builder` / `test:probe-kit` | 分项 unit（freshness、URL 守卫、catalog 预算、stamp、load、payload、probe-kit） | **是**（经 `test:unit`） | **否** | **低** |
| `cli.mjs apply [--theme]` | 写 active-theme + kick | **否** | 需 injector 才可见皮 | **中**（写盘 active-theme） |
| `publish-runtime.ps1 -Version` | stamp 装态 versions/ | **否** | 写装态 | **极高** · **本波禁** |

文档落点对照：

| 文档 | 覆盖 |
|------|------|
| `docs/usage.md` | CLI doctor/list/apply；装态 smoke / check-and-fix 路径表；F6/#21/#25 故障 |
| `docs/PROJECT.md` §9 / §11 | doctor 健康画像、验收勾 doctor+smoke、诊断矩阵 |
| `docs/ops/cv-day-ready-2026-07-24.md` §4 | 故障树「先 doctor」+ 健康画像字段 |
| 根 `CLAUDE.md` | doctor/list/status/help · `probe:session` · 不把 control 进 CI |
| CI | themes-gate 类 unit **≠** doctor/live CDP（PROJECT 明示） |

### 1.1 本机 `npm run doctor`（只读 · 2026-07-24）

| 字段 | 值 |
|------|-----|
| **exit** | **0** |
| `appFound` | `true`（Store Codex `OpenAI.Codex_26.715.7063.0`） |
| `processRunning` | `false`（会话时 Codex 未开） |
| `portOpen` | `false` · CDP 9335 |
| `dreamSkin.summary` | `installed-idle` |
| `injectorAlive` | `false`（idle 预期；state 仍记旧 `injectorPid`） |
| `control.port` / `tokenPresent` | **9336** / **true** |
| `themeCount` / `userThemeCount` | **1** / **1**（arina-only） |
| **`injectorPathFreshness`** | **`fresh: true`** · `reason: ok` |
| `expectedRuntimeId` / `actualRuntimeId` | **`1.3.25-da2adc`** / **`1.3.25-da2adc`** |
| expected/actual injectorPath | `…\versions\1.3.25-da2adc\scripts\injector.mjs`（一致） |
| `diagnosis` | `not-running：Codex 未在运行；watch injector 未检测到，请先点任务栏 Codex；injector 路径与 current runtime 对齐` |

→ 与 gap 卡 / day-ready：**装态 runtimeId 对齐、fresh=true**；无皮肤因 **Codex 未运行**，非 versions 撕裂。

---

## 2. PAIN-POINTS 摘录

源：[`docs/PAIN-POINTS.md`](../PAIN-POINTS.md)。历史 P0–P1（#1–#20 等）表内多为 **已修 / 已改善 / 已绕过**。

### 2.1 仍 open / 硬限 / 需 publish

| # | 摘要 | 状态 | 本波映射 |
|---|------|------|----------|
| **21** | 商店磁贴 / AUMID / Codex-X 裸启无 CDP | **已知硬限** · 文档化 · FastLaunch 独立 AUMID | doctor-smoke 文档：日常钉任务栏 Codex；勿当软件 bug 修 asar |
| **24** | 首次 SmartScreen 拦未签名入口 / FastLaunch | **已知** · 未 OV；点「仍要运行」；购证 No-Go | 文档债；**不**本波签名工程 |
| **25** | 窗内 F6 / toast | **代码已恢复；需 publish 到安装态** | gap 卡：关键 ESM+assets 已与 tip 对齐 → **默认不 publish**；F6 行为以装态 `renderer-inject` 为准；本波 **不** stamp |
| 其余未标已修 | 表内 #1–#20 等已闭环 | — | 不派修码 |

### 2.2 映射本波目标

| 本波 child | 与 PAIN / 债的关系 |
|------------|-------------------|
| **themes/contracts** | 非 PAIN 编号项；工程门闩（ADR 0004）· **当前绿** → 无「修红」驱动 |
| **doctor 文档化** | 支撑 #21/#24/#25 用户解释 + day-ready 故障树；降低误用 check-and-fix / 误 publish |
| **ADR 0005** | Proposed 薄壳 · **非** 痛点紧急项 · 仅 DEFER 页 |

---

## 3. themes / contracts 测试缺口表

总控基线 main @ `ebc3568`（progress §0.3）与 **本 WT 复核** 一致：

| 命令 | 总控基线 exit | 本 WT 复核 exit | 覆盖要点 |
|------|---------------|-----------------|----------|
| `test:themes` | 0 | **0** | schema 双形态、危险键、对比度、`loadTheme`、**bundled count===1 arina-only** |
| `test:themes-contracts` | 0 | **0** | `normalizeColors` ⊂ contracts palette；CSS_COLOR_RE ↔ `theme-load.mjs` 源钉 |
| `test:store` | 0 | **0** | `listThemes` 默认/includeSkipped、坏 JSON/缺 id、ENOENT 根 |
| `test:adapter` | 0 | **0** | heige→Dream 映射、`writeActiveThemeFromHeige` 写盘（tmpdir） |
| `test:catalog-quality` | （unit 内） | **0** | budget 常量源钉、inject setTheme/cycleTheme、bundled art on disk |
| `test:contracts` | 0 | **0** | isCssColor / parsePalette / doctor slice / control error / kick surface · **14 pass** |
| `test:deps` | 0 | **0** | core↔runtime 无静态双向；themes 仅允许 thumb 动态 |
| `npm test` | **0** | （本会话未整包重跑；分项全 0 + 总控基线 0） | unit 全链 + contracts |

### 3.1 覆盖盲区 / 假绿风险

| 盲区 | 说明 | 假绿风险 |
|------|------|----------|
| **无 live CDP** | `npm test` 不证 injector 真注入 / F6 真循环 | **高对装机体验、低对 CI** — doctor/smoke 才是体验门 |
| **装态 vs tip** | unit 测仓内源；不测 `versions/<id>/` 字节 | 已由 gap 卡对照；runtimeId 后缀≠git SHA |
| **check-and-fix / smoke** | 无自动化门闩 | 文档 + 人工 smoke；误当「CI 绿=机子健康」 |
| **user catalog 扩主题** | store/schema 有合成样例；真用户脏 catalog 仅路径级 | 中 — import/schema 拒绝危险键已有测 |
| **contracts 不进 versions/** | ADR 0004 · 用户机无 zod 契约面 | 设计如此；**勿**把 contracts 当装态依赖 |
| **source-text pin** | catalog-budget / cssColor 靠读源码字符串 | 重构改格式可假红；改逻辑未改字面可假绿 — 已用双站 regex 等缓解 |
| **arina-only 硬钉** | count===1 + id 字面 | 扩 catalog 须 ADR 后改测 — 防 silent 膨胀 **有意** |
| **test:control** | 不进 `npm test` | 控制面回归靠本机 loopback / live |

### 3.2 `cv-themes-contracts` 建议

| 结论 | **NO-CODE / evidence-only** |
|------|-----------------------------|
| 理由 | 基线与本 WT 分项 **全 exit 0**；无红项可修 |
| 动作 | **跳过改码 child**；总控可记「复核绿」合入本 evidence，或开空 evidence-only 短卡 |
| 仅当 | 后续改 schema/palette/theme-load 正则 / 扩 catalog → 再开修码并重跑表中 scripts |

---

## 4. `test:deps` 一句

**含义：** 静态扫 `packages/core` 与 `packages/runtime` 的 `.mjs/.js` import/require，禁止 **core↔runtime 双向静态依赖**；`themes` 除允许的 `thumb.mjs` 动态路径外不得静态/动态拉 runtime（ADR 0001 / PROJECT §3.2）。  

**是否每实现 child 重跑：** **是** — 任何动到 `packages/core|runtime|themes` import 图的 child 合并前应 `npm run test:deps`（或整包 `npm test`）；纯 docs/ops 卡可免。

---

## 5. 派发建议（1 段）

1. **`cv-themes-contracts`：** **跳过实现 / 仅本 evidence**（NO-CODE）。红项为零；盲区属 live/装态面，不归 themes unit 修。  
2. **`cv-doctor-smoke`：** **文档落点**（优先，少码）：  
   - 主：`docs/usage.md` 故障速查 + 关键路径表（已有骨架，可补「doctor 字段速读 / 何时 smoke / 勿把 check-and-fix 当 CI」）；  
   - 辅：`docs/ops/cv-day-ready-2026-07-24.md` §4 故障树交叉链；  
   - 可选单卡：`docs/ops/cv-doctor-smoke-map-2026-07-24.md`（命令表可直接裁本节 §1）；  
   - 验证：触及 docs 即可；**可选**装态 smoke（需用户开 Codex）记 exit，**禁止**默认 publish。  
3. **ADR0005：** **DEFER 1 页** 建议路径 `docs/ops/cv-adr0005-defer-2026-07-24.md`：重申 Proposed、壳不写第二 injector、U1 契约已绿但仍 **不 Accepted 不写壳代码**、MVP 成功标准与 out-of-scope、本波停在文档。无 `apps/shell` 脚手架。

---

## 6. 验证记录

| 步骤 | 结果 |
|------|------|
| 先读 PROJECT / CLAUDE / PAIN / day-ready / gap / package.json | 完成 |
| `npm run test:themes` | exit **0** |
| `npm run test:themes-contracts` | exit **0** |
| `npm run test:store` | exit **0** |
| `npm run test:adapter` | exit **0** |
| `npm run test:deps` | exit **0** |
| `npm run test:catalog-quality` | exit **0** |
| `npm run test:contracts` | exit **0**（14 pass） |
| `npm run doctor` | exit **0** · fresh=true · runtimeId `1.3.25-da2adc` · not-running idle |
| push / publish / asar / 第二 injector | **未做** |

---

## 风险（一句）

**CI/unit 全绿 ≠ 用户机有皮：** 本机会话 doctor 已证 runtime **fresh** 但 Codex **未运行**；体验债在 live 路径（#21 入口硬限、#25 装态 F6 叙事、#24 SmartScreen），默认 **不 publish**；下一实现 child 应做 doctor/smoke **文档化** 而非 themes 改码。

---

## 状态

| 项 | 值 |
|----|-----|
| 卡状态 | **DONE** · **in-review** |
| 总控 | 请审 §总控回执 + §5 派发 |
| Agent 停步 | 不 push、不 publish、不改 runtime |
