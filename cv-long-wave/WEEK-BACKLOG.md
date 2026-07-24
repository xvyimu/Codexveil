# Codexveil · WEEK-BACKLOG · 7 日续航

**总控：** `cv-coord` · `cv-long-wave/`  
**产品：** `D:\orca\Codexveil` · `xvyimu/Codexveil` · base `main`  
**开波日：** 2026-07-24  
**续航窗：** 约 7 日（日循环至 W13）  
**G0：** AUTHORIZED（侧车稳定 + 主题/契约债 + ADR0005 仅文档 DEFER）

---

## 北极星（本周）

doctor / smoke / 主题 / 契约门闩 **全绿可重复**；PAIN 有关闭证据；**ADR0005 仅 1 页 DEFER**（无壳代码）。

## 硬红线

| 禁 | 说明 |
|----|------|
| 第二 injector / 第二守护 | 单 watch 产品线 |
| 改 Codex asar | 永久非目标 |
| `vendor/` | ADR 0006 |
| 擅自 `publish-runtime` / push main | **另授** |
| live 实现 wt **>3** | 日循环：收 DONE→stop→rm --force→开下一项 |
| Agent×N 冒充舰队 | 只用 Orca child wt |

## 日循环

```text
巡检 live → 收 DONE/in-review evidence
  → 总控审（边界 · exit code · 无密钥）
  → 人闸需要时停
  → child stop → worktree rm --force
  → 开 WEEK-BACKLOG 下一项（live ≤3）
  → 更新 progress.md + 本文件状态列
```

**永不** stop `name:orca` / `path:D:\orca`。

---

## 队列

| ID | wt 名 | 目标 | 状态 | 依赖 | 验收要点 |
|----|-------|------|------|------|----------|
| **W1** | `cv-scout-health` | doctor/smoke 命令表 · PAIN 摘 · themes/contracts 缺口 · 派发建议 | **ACCEPT** · branch `9e2ba87` · wt rm | — | evidence 齐 · 总控 PASS |
| **W2** | `cv-themes-contracts` | `test:themes` · `themes-contracts` · `store` · `adapter` 复跑/复核 | **ACCEPT** `65c38a3` · origin · wt rm · **NO-CODE** | W1 | 全 exit 0 |
| **W3** | `cv-test-store-adapter-fix` | W2 失败项最小修复 | **SKIP**（W2 全绿） | W2 红 | — |
| **W4** | `cv-doctor-smoke-docs` | doctor 路径文档化 + smoke 证据 | **ACCEPT** `2aa2b0b` · origin · wt rm | W1 | map + doctor 0 · smoke skip idle |
| **W5** | `cv-cdp-url-guard` | cdp-url / freshness 门闩复核 | **ACCEPT** `5032a98` · origin · NO-CODE | W1 | cdp-url · freshness · deps **0** |
| **W6** | `cv-catalog-budget` | catalog budget 门闩 | **ACCEPT** `fb9f4d4` · origin · NO-CODE | W1 | budget · quality **0** · arina-only |
| **W7** | `cv-launcher-tray-stability` | launcher/tray 第一方源小稳 | **ACCEPT** `a2d03c0` · origin · NO-CODE | W4 | 单 watch 路径表 |
| **W8** | `cv-core-runtime-boundary` | core↔runtime 依赖方向审计 | **ACCEPT** `f08112c` · origin · NO-CODE | — | deps **0** · 互引 0 |
| **W9** | `cv-theme-arina-only-docs` | arina-only 与 catalog 纪律文档 | **ACCEPT** `f48255d` · origin · NO-CODE | W1 | themes/quality **0** |
| **W10** | `cv-pain-close-batch` | PAIN 可关项批量关单（有证据） | **ACCEPT** `908ca42` · origin | W4+ | 不假关 #21/#24/#25 |
| **W11** | `cv-adr0005-onepager` | 薄壳评估 1 页 **DEFER 实现** | **ACCEPT** `b4cbc94` · origin · wt rm | — | 无壳代码 |
| **W12** | `cv-long-verify` | `npm test` 及触及 script **全记 exit** | **ACCEPT** `40e5796` · origin · **全 0** | W2–W8 | exit 表齐 |
| **W13** | （总控） | `INTEGRATE.md` · 合入计划 | **READY_FOR_HUMAN_GATE** | W12 | **publish/merge main 另授** · 总控不自动合 |

### 基线（总控 2026-07-24 @ main `ebc3568`）

| 命令 | exit |
|------|------|
| test:themes / themes-contracts / store / adapter / deps | **0** |
| `npm test` | **0** |

→ W2/W3 默认倾向 **绿则 NO-CODE**；W1 缺口表可推翻。

### 建议并行度（live ≤3）

```text
时刻 0：W1 alone
W1 收：W2 + W4 + W8（或 W5）≤3
红修：W3 插队占 1 槽
收尾：W9–W11 文档可并行 2 + W12 串行
W13 总控写 INTEGRATE · 等人
```

---

## 状态板（总控更新）

| 日 | 完成 | live | 备注 |
|----|------|------|------|
| D0 2026-07-24 | G0 · 基线 npm test 0 · W1 LIVE | W1 | 开波 |
| D0 同日 | W1 ACCEPT `9e2ba87` · rm wt · 开 W2+W4+W11 | **W2 W4 W11** | live=3 · W3 skip 默认 |
| D0 催办 | W2/W4/W11 ACCEPT · origin push · rm · 开 W5+W6+W8 | **W5 W6 W8** | W3 SKIP · scout push 新支 |
| D0 强制续航 | W5/W6/W8 ACCEPT · origin 齐 · rm · 开 W9+W10+W12 | **W9 W10 W12** | 无 review-findings fix wt |
| D0 7m 巡检 | W9+W12 ACCEPT push · rm · W13 DRAFT · 开 W7 | **W10 W7** | `npm test` 全 0 入 INTEGRATE |
| D0 7m+ | W7+W10 ACCEPT push · rm · **live 0** | **coord only** | 周实现项尽 · 等人合入 |
| D0 7m INTEGRATE | 整理 INTEGRATE 人 gate 就绪 · 无新 child | **coord only** | READY_FOR_HUMAN_GATE · 勿停总控 |

---

## Evidence 约定

- 路径：`docs/ops/cv-<id>-evidence-YYYY-MM-DD.md`  
- 必含：命令 + **exit code** · 边界一句 · 风险一句 · 总控回执小节  
- commit OK on feature；**push / publish 另授**

## 关联

- 进度 SSOT：[`progress.md`](./progress.md)  
- W1 brief：[`scout-health-brief.md`](./scout-health-brief.md)  
