# V3 · Codexveil × Atelier 差异矩阵

**Wave:** V3 · Codexveil  
**Verdict:** **SKIP / DEFER · arina-only**  
**日期：** 2026-07-23  
**仓 tip 基线：** `58800ae`（main）  
**强度：** **A0 docs only**（无 A1 runtime token 编辑本波）  
**Portfolio SSOT：** `D:\orca\.planning\portfolio-visual-fluent-glass-2026-07-23\visual-adoption-waves.md` §V3  
**Token principles（只读）：** `…/atelier-token-ssot.md`  
**Pattern：** Chronicle V1a · ChronoPortal V1b「本波零改 runtime」语气  
**本地 token 词汇：** [`docs/design-tokens.md`](../design-tokens.md)（`--dream-*` · 本波不改）  
**产品：** Codexveil · **arina-only**  
**栈：** Node ≥20 · ESM · DreamSkin inject（**不换栈** · **本波零改** packages/runtime）

---

## Product gate

> Codex Desktop 换肤 · 目录仅 `themes/preset-arina-hashimoto/`（Fei arina）· 暗沉浸玫瑰/薰衣草身份 **不得** 被 Atelier 浅纸 + CTA 橙覆盖。

| Red line | 本波 |
|----------|------|
| Catalog | **sole** theme `preset-arina-hashimoto` · **no** catalog expansion |
| asar | **NO** asar repack · no install/publish churn |
| Injector | **single** watch + catalog F6 · **no** second injector |
| Startup | **no** auto-launch / task / registry / Startup VBS changes |
| Glass default-on (MS patterns) | **forbidden** this wave |
| Runtime CSS / theme.json 数值 | **untouched** |

---

## Design Read

> DreamSkin 暗色沉浸 · arina rose accent `#E8A0BF` · surface `#1A1218` · 运行时表面在 `packages/runtime`（本波 **零改**）· V3 仅关闭为 **documented DEFER**，非静默 no-op。

| Dial     | 值 |
| -------- | -- |
| VARIANCE | 3（身份固定 arina） |
| MOTION   | 2–3（沿用现有 ~180ms；不升 A2） |
| DENSITY  | n/a this wave（无 shell 改） |

---

## 1. 现状 vs Atelier vs V3 裁决

| 维 | Codexveil 现状 (docs / theme.json) | Atelier SSOT | V3 裁决 |
|----|-----------------------------------|--------------|---------|
| Catalog | `themes/preset-arina-hashimoto` only | multi-product family look | **keep arina-only** |
| Accent | `#E8A0BF` (`theme.json` `colors.accent`) | CTA `#f97316` | **keep arina rose**；do not recolor |
| Surface | `#1A1218` dark | light paper surfaces | **keep dark immersive** |
| Token surface | `--dream-*` via design-tokens.md + dream-skin.css | `--atelier-*` logical names | **no runtime map this wave** |
| Spacing | not in theme.json；CSS in runtime | 4/8/16/24/32 | **DEFER**（需 CSS/publish） |
| Radius | runtime CSS | 4 / 8 | **DEFER** |
| Blur | composer blur ~8px；sidebar `backdrop-filter: none`（design-tokens） | chrome ≤12 / ≤3 layers | **do not increase blur**；no new glass shell |
| Injector | single watch + catalog F6 | N/A | **untouched** |

---

## 2. 本波文件范围

| 做 | 不做 |
|----|------|
| `docs/design/atelier-v3-matrix.md`（本文件） | 任何 runtime CSS/JS/`theme.json` 数值改动 |
| optional overview 一行链接 | asar / publish / install / Startup |
| | 第二主题、第二 injector、Atelier 色板落地 |
| | `packages/**` · `themes/**` · `apps/**` · `scripts/**` |

**本波零改** `packages/runtime` · `themes/preset-arina-hashimoto` · injector · asar · Startup。

---

## 3. Optional future（explicitly out of V3）

- 若产品日后允许 **parameter-only** 笔记：文档层映射 `--dream-accent` ↔ Atelier 逻辑名，**不**改 inject。
- 任何 CSS spacing / radius 对齐需要 **独立波次**（publish + doctor + probes）——不是本矩阵的实现职责。
- 禁止以「docs mapping」名义新增 `themes/*/tokens.css` 或 `--atelier-*` 注入。
- 禁止把 arina accent 向 Atelier CTA `#f97316`「微调」。
- V2 Fei 对齐文档只读参考：`docs/ops/visual-align-fei-away-diff-2026-07-23.md`——不重开 promote。

---

## 4. 验收 (Coder / Tester)

- [ ] 文件存在于 `docs/design/atelier-v3-matrix.md`
- [ ] 标题或首表明确 **V3 DEFER arina-only** / SKIP
- [ ] 列出红线：asar / second injector / catalog / Startup
- [ ] `git status` / diff **无** `packages/` · `themes/` · `apps/` · `scripts/` 变更
- [ ] **不要求** `publish-runtime` 或 live CDP probes 作为本波门闩

Portfolio 外部进度字段（文档建议，**不** invent 仓内 progress.json）：  
`V3_CV: defer_arina_only` / `done_skip_docs`

---

## 5. 回滚

```text
rm docs/design/atelier-v3-matrix.md
# 若曾加 overview 链接：revert 该一行
```

或单 commit revert。

---

## 6. 修订

| 日期 | 说明 |
|------|------|
| 2026-07-23 | V3 初版：documented SKIP/DEFER arina-only · A0 docs only |
