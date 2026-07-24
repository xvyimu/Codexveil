# Codexveil · cv-long-wave progress

**总控 WT：** `cv-coord` · `…/Codexveil/cv-coord` · `xvyimu/cv-coord`  
**产品仓：** `D:\orca\Codexveil` · base `main`  
**会话日：** 2026-07-24 · **G0 续航 7 日**  
**红线：** 单 injector · 禁 asar · 禁 vendor · 禁擅自 publish/push  

SSOT 队列：[`WEEK-BACKLOG.md`](./WEEK-BACKLOG.md)

---

## 0. 状态机

| Phase | 状态 |
|-------|------|
| G0 | **AUTHORIZED** · 一周续航 |
| W1 scout-health | **ACCEPT** · branch `xvyimu/cv-scout-health` @ `9e2ba87` · wt **已 rm** |
| W2 themes-contracts | **LIVE** |
| W3 store-adapter-fix | **SKIP 除非 W2 红** |
| W4 doctor-smoke-docs | **LIVE** |
| W5–W10 · W12 | QUEUED |
| W11 adr0005-onepager | **LIVE** |
| W13 INTEGRATE | QUEUED · publish 另授 |

**live 槽：** 3/3（W2 · W4 · W11）

### 0.1 本波 / 一周北极星

doctor/smoke/主题/契约门闩全绿可重复；PAIN 有关闭证据；ADR0005 **仅文档 DEFER**。

### 0.2 基线（main `ebc3568`）

| 命令 | exit |
|------|------|
| test:themes / themes-contracts / store / adapter / deps | **0** |
| `npm test` | **0** |

### 0.3 W1 总控审核

| 项 | 结论 |
|----|------|
| evidence | `docs/ops/cv-scout-health-evidence-2026-07-24.md` @ `9e2ba87` |
| 边界 | 只读 + docs · 无业务码 · 无 push/publish |
| doctor | exit **0** · fresh=true · runtimeId `1.3.25-da2adc` · Codex idle |
| themes 建议 | **NO-CODE** |
| 审核 | **PASS · ACCEPT** |

---

## 1. Worktree 名表

| displayName | branch | path | status |
|-------------|--------|------|--------|
| main | main | `D:/orca/Codexveil` | 主 · `ebc3568` |
| cv-coord | xvyimu/cv-coord | `…/cv-coord` | 总控 |
| cv-themes-contracts | xvyimu/cv-themes-contracts | `…/cv-themes-contracts` | **LIVE** W2 |
| cv-doctor-smoke-docs | xvyimu/cv-doctor-smoke-docs | `…/cv-doctor-smoke-docs` | **LIVE** W4 |
| cv-adr0005-onepager | xvyimu/cv-adr0005-onepager | `…/cv-adr0005-onepager` | **LIVE** W11 |

**已收：** `cv-scout-health` wt rm · branch 保留 `xvyimu/cv-scout-health` @ `9e2ba87`

**注：** 三 live 从 main 起；W1 evidence 已 **拷入** 各 wt `docs/ops/`（未进 main）；合入走 W13。

---

## 2. 派发日志

| 时间 | 事件 | 结果 |
|------|------|------|
| 2026-07-24 | G0 · progress · 基线 npm test 0 | ok |
| 2026-07-24 | W1 create scout-health | LIVE |
| 2026-07-24 | W1 evidence `9e2ba87` · 总控 PASS | ACCEPT |
| 2026-07-24 | W1 stop + `worktree rm --force` | preserved branch |
| 2026-07-24 | WEEK-BACKLOG.md 落盘 | ok |
| 2026-07-24 | W2+W4+W11 create（live=3） | LIVE |

---

## 3. Child 回执

| ID | status | commit / 注 |
|----|--------|-------------|
| W1 scout | **ACCEPT** | `9e2ba87` docs only |
| W2 themes | LIVE | NO-CODE 预期 |
| W4 doctor-smoke | LIVE | map + evidence |
| W11 adr0005 | LIVE | DEFER 1 页 |

---

## 4. 下一批（槽空后）

建议序：W8 `cv-core-runtime-boundary` · W5 `cv-cdp-url-guard` · W6 `cv-catalog-budget` · W9 arina-only docs · W10 pain-close · W7 launcher（后）· W12 long-verify · W13 INTEGRATE

W3 仅 W2 红时开。

---

## 5. 审核门

- [x] W1 边界 / exit / 无密钥  
- [ ] W2–W11 各 evidence  
- [ ] W13 合入计划 · push/publish 人闸  
