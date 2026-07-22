# W4 · Codexveil 架构/栈升级报告 · Claude

> **PUBLISH: NOT EXECUTED**  
> 装态已是 **`1.3.25-d403fa`**（payload-builder 在位 · 关键 ESM 与 tip MATCH）。  
> 本波 **不再** `publish-runtime` stamp · **不** push。

| 字段 | 值 |
|------|-----|
| **波次** | portfolio-arch-upgrade-2026h2 · **W4 收口** |
| **产品** | Codexveil（GitHub `xvyimu/Codexveil`） |
| **工作树** | `C:\Users\yuanjia\orca\workspaces\Codexveil\w4-cv-claude` |
| **分支** | `xvyimu/w4-cv-claude` |
| **tip (HEAD)** | `4914631` · `49146312ca2d99bfe8a69b8eb57af956a97c052d` |
| **装态** | **`1.3.25-d403fa`**（`current.json` · 2026-07-22T18:37:50Z） |
| **Agent** | solo Claude · 2026-07-23 |
| **对照** | `prompts/w4-shared.md` · `prompts/w4-cv.md` · `w3-arch-upgrade-codexveil-claude.md` · `w3-scores.md` · `progress.json`（Codexveil tip `4914631` · cvPublish d403fa） |

---

## 1. 交付摘要

| # | 题单项 | 结果 |
|---|--------|------|
| 1 | stack-matrix **W4 收口** | **已做** · 终态列 · 半年完成度 · backlog 3 · 注明装态 d403fa |
| 2 | 装态对齐证明页 | **已做** · `w4-install-align-2026-07.md`（runtimeId · Test-Path · SHA256 · 只读） |
| 3 | 可选 doctor | **已跑** · exit **0** · `fresh=true` · runtimeId 对齐 |
| 4 | 文首 **PUBLISH NOT EXECUTED** | **是** · 本波不 stamp |
| 5 | 报告本文件 | **已做** |
| 6 | 真 publish / push / asar | **未做**（禁止） |

---

## 2. 相对 W3 的状态跃迁

| 面 | W3（eee7c8） | W4 实测 |
|----|--------------|---------|
| `payload-builder.mjs` | **缺**（主缺口） | **有 · tip MATCH** |
| tip vs 装态 injector | 不可盲拷 tip injector | 装态 injector **= tip 字节** |
| re-publish 紧迫性 | 卷宗等人 gate | **装态已跟上** · 本波 **无需再 publish** |
| 默认 arina | 是 | 是 |

说明：装态从 eee7c8 → d403fa 由**人侧/他窗 publish**完成（`updatedAt` 2026-07-22）；本 agent **未**执行 `publish-runtime.ps1`。

---

## 3. 可审 diff 要点

仅文档收口（无业务代码 / 无 publish）：

| 路径 | 动作 |
|------|------|
| `docs/ops/stack-matrix-2026-07.md` | W4 收口列 + 完成度 + backlog 3 |
| `docs/ops/w4-install-align-2026-07.md` | **新建** · 装态证明 |
| `docs/ops/w4-arch-upgrade-codexveil-claude.md` | **新建** · 本报告 |

---

## 4. 验证证据

```text
npm test
→ npm_test_exit=0
  (themes / themes-contracts / store / adapter / deps / freshness /
   cdp-url / catalog-budget / stamp / theme-load / payload-builder /
   catalog-quality / probe-kit / contracts)

pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1
→ verify_payload_exit=0
  VERIFY OK publish runtime payload closed
  (… + node:import-payload-builder + injector:imports-payload-builder)

npm run doctor
→ doctor_exit=0
  dreamSkin.summary = active-injector
  injectorPathFreshness.fresh = true
  expectedRuntimeId = actualRuntimeId = 1.3.25-d403fa
  diagnosis = ok（端口开放 · watch 存活 · 路径对齐）
```

装态关键文件（摘要 · 全表见 align 页）：

```text
current.runtimeId = 1.3.25-d403fa
payload-builder / theme-load / control-plane / fs-io / injector = True · SHA256 MATCH tip
cdp-url-guard / theme-catalog-budget / image-metadata = True · DIFF tip（外围 · 非 S3 阻塞）
eee7c8/payload-builder = False（历史）· 非 current
assets theme id = preset-arina-hashimoto
```

---

## 5. 半年卡（S5）收口判断

| S5 要素 | 状态 |
|---------|------|
| 注入模块边界 | **达标**（theme-load + payload-builder + control-plane/fs-io · 装态闭合） |
| 视觉 V2 arina | **达标**（默认 preset-arina-hashimoto） |
| contracts 扩一圈 | **达标**（W2 inject/kick · 不进 versions） |
| publish 人 gate 可重复 | **达标**（verify + dossier + checklist；本波因装态已新 **不**再执行） |

ADR 0005 薄壳：**未**进半年必过线 → W4 **书面延期**（stack-matrix backlog #1）。

---

## 6. 明确不做（本波遵守）

| 禁止 | 遵守 |
|------|------|
| `publish-runtime.ps1` 再装机 | **是 · NOT EXECUTED** |
| push / 合默认分支 | 是 |
| vendor / asar / ISS | 是 |
| ADR 0005 MVP 编码 | 是（延期书） |
| D7 / 生产 CSP | N/A（他仓） |

---

## 7. 风险与残留

| 风险 | 缓解 / 残留 |
|------|-------------|
| 外围三脚本 install≠tip | 不阻塞关键图；下一 tip 漂 → 人 gate 整图 publish |
| eee7c8 目录仍在 | GC 正常 previous；current 已 d403fa |
| 薄壳 ADR 0005 | 下半年 backlog · 无第二守护 |
| injector 仍 ~1k 行 | backlog：再分区 |
| SmartScreen #24 | codesign No-Go 维持 |

---

## 8. 产出路径

| 路径 | 角色 |
|------|------|
| `docs/ops/w4-arch-upgrade-codexveil-claude.md` | 本报告 |
| `docs/ops/w4-install-align-2026-07.md` | 装态对齐证明 |
| `docs/ops/stack-matrix-2026-07.md` | 栈矩阵 W4 收口 |

---

## 9. 建议下一刀（人 / 总控）

1. 人审本分支 docs → merge（**非**本 agent push）  
2. **无需**为本 tip 再 publish，除非外围 DIFF 或后续代码再漂  
3. 可选：真机 H1–H7 + F6 一句；更新 PAIN #25 状态  
4. 下半年：ADR 0005 仅当产品优先级到再 enact  

**状态：** W4 enact **完成**（矩阵 + 装态证明 + 验证绿 · **无 publish · 无 push**）。
