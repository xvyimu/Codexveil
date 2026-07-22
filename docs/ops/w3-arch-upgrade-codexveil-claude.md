# W3 · Codexveil 架构/栈升级报告 · Claude

> **PUBLISH: NOT EXECUTED**  
> 装态保持 **`1.3.25-eee7c8`** 直至人 gate。

| 字段 | 值 |
|------|-----|
| **波次** | portfolio-arch-upgrade-2026h2 · **W3** |
| **产品** | Codexveil（GitHub `xvyimu/Codexveil`） |
| **工作树** | `C:\Users\yuanjia\orca\workspaces\Codexveil\w3-cv-claude` |
| **分支** | `xvyimu/w3-cv-claude` |
| **开工 HEAD** | `6910a22`（form-stack SSOT merge · W2 tip 已在内） |
| **装态** | **1.3.25-eee7c8**（本波 **不** re-publish） |
| **Agent** | solo Claude · 2026-07-23 |
| **对照** | `prompts/w3-shared.md` · `prompts/w3-cv.md` · `repos/cv.md` · `task_plan.md` §2/§6 |

---

## 1. 交付摘要

| # | 题单项 | 结果 |
|---|--------|------|
| 1 | `docs/ops/w3-republish-gate-dossier.md` | **已做** · tip vs 装态 · 预检 · 人 gate 表 · 回滚/soft reattach · **PUBLISH NOT EXECUTED** |
| 2 | 可选硬化：verify staged import payload-builder | **已做** · `verify-publish-runtime-payload.ps1` + `node:import-payload-builder` |
| 3 | 主题质量 / doctor 书面基线 | **一句**：见 §4；CDP doctor **可选未强制** |
| 4 | `npm test` · `verify-publish-runtime-payload.ps1` | **exit 0** / **exit 0** |
| 5 | 报告 + stack-matrix **W3 已做**列 | 本文件 · `stack-matrix-2026-07.md` |
| 6 | 真 publish / push / asar | **未做**（禁止） |

---

## 2. 可审 diff 要点

### 2.1 卷宗（主交付）

`docs/ops/w3-republish-gate-dossier.md`：

- 装态缺 **`payload-builder.mjs`**；tip injector **静态 import** → re-publish 为唯一闭合路径  
- 预检 exit 记录  
- 人 gate：建议 **VERSION 仍 1.3.25**；post-check `Test-Path` payload-builder  
- 回滚：`current.json.bak-*` + GC 只保 current+previous · soft reattach 纪律  

### 2.2 硬化（小 diff）

| 路径 | 动作 |
|------|------|
| `scripts/windows/verify-publish-runtime-payload.ps1` | staged Node import **payload-builder**（补 theme-load / control-plane 对称门） |

无 injector 行为改动 · 无 core↔runtime 新边 · 无 publish 执行。

### 2.3 stack-matrix

`docs/ops/stack-matrix-2026-07.md` 增 **W3 已做** 列（re-publish 卷宗 + verify 硬化；**无** 真装机）。

---

## 3. 验证证据

```text
npm test
→ npm_test_exit=0
  (themes / themes-contracts / store / adapter / deps / freshness /
   cdp-url / catalog-budget / stamp / theme-load / payload-builder /
   catalog-quality / probe-kit / contracts)

pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1
→ verify_payload_exit=0
  VERIFY OK publish runtime payload closed
  (… + node:import-payload-builder)
```

装态探针（只读 · 未写）：

```text
current.runtimeId = 1.3.25-eee7c8
versions/1.3.25-eee7c8/scripts/payload-builder.mjs = False
theme-load / control-plane / fs-io / injector = True
assets theme id = preset-arina-hashimoto（与 tip 默认一致）
```

---

## 4. 主题质量 / doctor 书面基线

| 项 | 状态 |
|----|------|
| 机器门 `test:catalog-quality` / `test:themes` | 含于 `npm test` **0** |
| CONTRIBUTING C-2 **H1–H7** 真机纪律 | 文档已在 W2；**装态未 re-publish → 本波不跑装态手测** |
| `npm run doctor`（CDP 活机） | **可选** · 未作为 W3 硬门（无强制 CDP 会话） |
| 默认观感 arina | 装态与 tip assets **均为** `preset-arina-hashimoto` |

---

## 5. 明确不做（本波遵守）

| 禁止 | 遵守 |
|------|------|
| `publish-runtime.ps1` 真装机 | **是 · NOT EXECUTED** |
| push / 合默认分支 | 是 |
| vendor / asar / ISS | 是 |
| V3 整换 css/inject | 是 |
| ADR 0005 薄壳代码 | 是（仍 Proposed · 不进本波实现） |
| D7 / 生产 CSP | N/A（他仓） |

---

## 6. 风险与残留

| 风险 | 缓解 / 残留 |
|------|-------------|
| 装态无 payload-builder；若误拷 tip injector | **仅**经 publish 白名单；卷宗已写炸点 |
| GC 只留两版 | 回滚前勿连发两次 publish 清掉 eee7c8 |
| post-update Quiet 失败 | soft reattach 正式降级；非发版失败（G5-C） |
| 薄壳 ADR 0005 | W3–W4 设计/延期窗；本波无 MVP 代码 |
| injector 仍 ~1k 行 | backlog：CdpSession / Apply 分区 |

---

## 7. 产出路径

| 路径 | 角色 |
|------|------|
| `docs/ops/w3-arch-upgrade-codexveil-claude.md` | 本报告 |
| `docs/ops/w3-republish-gate-dossier.md` | re-publish 人 gate 卷宗 |
| `docs/ops/stack-matrix-2026-07.md` | 栈矩阵 W3 列 |
| `scripts/windows/verify-publish-runtime-payload.ps1` | staged payload-builder import |

---

## 8. 建议下一刀（人 / W4）

1. 人审本分支 diff → merge（非本 agent push）  
2. 人原文授权 → `publish-runtime.ps1 -Version 1.3.25` → 装态跟上 tip（**含 payload-builder**）  
3. doctor + 可选 H1–H7  
4. W4：主题包生态文档 · PAIN 清零复核 · ADR 0005 推进或**书面延期书**  

**状态：** W3 enact **完成**（卷宗 + 预检绿 · **无 publish · 无 push**）。
