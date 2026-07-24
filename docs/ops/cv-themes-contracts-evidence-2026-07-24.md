# M-CV-themes-contracts · W2 evidence-only · 2026-07-24

**MODE：** `cv-themes-contracts` · **WRITE_POLICY：** `local-commit`（仅本 evidence + 本地 commit；**禁止 push / asar / publish-runtime / 第二 injector / 业务码**）  
**WT / 支：** `C:\Users\yuanjia\orca\workspaces\Codexveil\cv-themes-contracts` · `xvyimu/cv-themes-contracts`  
**基线 tip：** `ebc3568`（≡ main · `docs(ops): CV tip vs install runtime gap card`）  
**STACK_SSOT：** [`docs/PROJECT.md`](../PROJECT.md) §1.5  
**Brief：** `cv-coord/cv-long-wave/briefs/w2-themes-contracts.md`  
**前序：** [`cv-scout-health-evidence-2026-07-24.md`](./cv-scout-health-evidence-2026-07-24.md) §3 · W1 **ACCEPT** · 建议 **NO-CODE**

---

## 总控回执

| 项 | 值 |
|----|-----|
| 模块 | **M-CV-themes-contracts** |
| Phase | WEEK **W2** · evidence-only **DONE** |
| workspaceStatus | **in-review**（请总控审 exit 表 → ACCEPT / 合入 W13） |
| 产出 | 本文 `docs/ops/cv-themes-contracts-evidence-2026-07-24.md` |
| 业务码 | **未改**（全 exit 0 → NO-CODE） |
| push / publish / asar | **未做** |
| 本机复核 | 见 §1 命令表 · 全部 **exit 0** |
| 对 W1 / 总控基线 | 与 scout §3 · progress §0.3 main@`ebc3568` 一致：**themes/contracts 无红** |
| **结论** | **NO-CODE · PASS** |
| 下一步（总控） | 审本卡 → W2 **ACCEPT**；**W3 store-adapter-fix 保持 SKIP**（无红驱动）；勿开 themes 修码 child |

---

## 1. 命令表 + exit（本 WT 复跑 · 2026-07-24）

环境：Node `v24.16.0` · npm `11.13.0` · 支 `xvyimu/cv-themes-contracts` @ `ebc3568`。

| 命令 | exit | 覆盖要点 / 输出摘要 |
|------|------|---------------------|
| `npm run test:themes` | **0** | schema 双形态、危险键、对比度、`loadTheme`、**bundled count===1 arina-only** · `theme-schema.test: all passed` |
| `npm run test:themes-contracts` | **0** | `build:contracts` + `normalizeColors` ⊂ contracts palette；`CSS_COLOR_RE` ↔ `theme-load.mjs` 源钉 · arina palette 四色 survive · `theme-contracts-align.test: all passed` |
| `npm run test:store` | **0** | `listThemes` 默认/includeSkipped、坏 JSON/缺 id、ENOENT 根 · `theme-store.test: all passed` |
| `npm run test:adapter` | **0** | heige→Dream 映射、`writeActiveThemeFromHeige` 写盘（tmpdir） · `dream-adapter.test: all passed` |
| `npm run test:catalog-quality` | **0** | budget 常量源钉、inject setTheme 路径、bundled art on disk（arina `hero.jpg`） · `theme catalog quality tests passed` |
| `npm run test:contracts` | **0** | isCssColor / parsePalette / doctor slice / control error / kick surface · **14 pass / 0 fail** |

**必跑 4 项（brief）：** themes · themes-contracts · store · adapter → **全 0**  
**可选 2 项（brief 建议）：** catalog-quality · contracts → **全 0**

### 1.1 与 W1 scout 对照

| 命令 | W1 scout 复核 | W2 本卡复跑 |
|------|---------------|-------------|
| test:themes | 0 | **0** |
| test:themes-contracts | 0 | **0** |
| test:store | 0 | **0** |
| test:adapter | 0 | **0** |
| test:catalog-quality | 0 | **0** |
| test:contracts | 0（14 pass） | **0**（14 pass） |

无漂移、无新增红项。

---

## 2. 业务码 / 边界声明

| 项 | 状态 |
|----|------|
| `packages/**` · `themes/**` · `apps/**` · scripts | **未改** |
| catalog 膨胀 / 第二 injector / vendor | **未做** |
| `git push` · publish-runtime · asar | **未做** |
| 仅新增 | 本 evidence 文档（+ 本地 `docs(ops):` commit） |

W1 §3.2 建议成立：无红项可修 → **跳过改码**。

---

## 3. 覆盖盲区（继承 scout · 不归本卡修）

| 盲区 | 说明 | 本卡动作 |
|------|------|----------|
| 无 live CDP | unit 不证真注入 / F6 | **不修码**；归 doctor-smoke 文档 |
| 装态 vs tip | 不测 `versions/<id>/` 字节 | 已有 gap 卡；本卡不 stamp |
| contracts 不进 versions/ | ADR 0004 设计 | 勿当装态依赖 |
| arina-only 硬钉 | count===1 防 silent 膨胀 | 扩 catalog 须 ADR 后再改测 |

---

## 4. 验证记录

| 步骤 | 结果 |
|------|------|
| 先读 brief · PROJECT §1.5 · scout §3 · package.json | 完成 |
| `npm run test:themes` | exit **0** |
| `npm run test:themes-contracts` | exit **0** |
| `npm run test:store` | exit **0** |
| `npm run test:adapter` | exit **0** |
| `npm run test:catalog-quality` | exit **0** |
| `npm run test:contracts` | exit **0** · 14 pass |
| 业务码 diff | **无** |
| push / publish / asar / 第二 injector | **未做** |

---

## 风险（一句）

**themes/contracts unit 全绿仍 ≠ 用户机有皮：** 盲区在 live CDP / 装态路径（#21 入口、#25 F6 装态叙事）；本卡 **NO-CODE · PASS**，下一体验债仍归 doctor-smoke 文档与（若需）受权 publish，而非 themes 改码。

---

## 状态

| 项 | 值 |
|----|-----|
| 卡状态 | **DONE** · **in-review** |
| 结论 | **NO-CODE · PASS** |
| 总控 | 请审 §总控回执 + §1 exit 表 |
| Agent 停步 | 不 push、不 publish、不改 runtime / themes 业务码 |
