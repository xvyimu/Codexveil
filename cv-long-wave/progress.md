# Codexveil · cv-long-wave progress

**总控：** `cv-coord` · `xvyimu/cv-coord` @ **`fb792e0`+**（本轮将再 commit）  
**产品：** `D:\orca\Codexveil` · base `main` @ `ebc3568`  
**红线：** 单 injector · 禁 asar · 禁 vendor · 禁擅自 publish · **feature push OK**  

SSOT：[`WEEK-BACKLOG.md`](./WEEK-BACKLOG.md)

---

## 0. 状态机（2026-07-24 催办后）

| 项 | 状态 |
|----|------|
| W1 scout | **ACCEPT** · `9e2ba87` · **origin 已 push** |
| W2 themes-contracts | **ACCEPT** · `65c38a3` · origin · wt **rm** · **NO-CODE PASS** |
| W3 store-adapter-fix | **SKIP**（W2 全绿无红） |
| W4 doctor-smoke-docs | **ACCEPT** · `2aa2b0b` · origin · wt **rm** |
| W11 adr0005 DEFER | **ACCEPT** · `b4cbc94` · origin · wt **rm** · 零壳代码 |
| **W5** cdp-url-guard | **LIVE** |
| **W6** catalog-budget | **LIVE** |
| **W8** core-runtime-boundary | **LIVE** |
| W7/W9/W10/W12/W13 | QUEUED |

**live 槽：** 3/3（W5 · W6 · W8）

### 0.1 催办收口摘要

| 动作 | 结果 |
|------|------|
| 三线 dirty | 仅 seed untracked（brief/scout 拷贝）→ **丢弃未提交**；产物已在 tip commit |
| stop/rm | W2/W4/W11 wt **force rm** · branch 在 origin 保留 |
| push feature | scout **新 push**；W2/W4/W11/coord **origin 已齐**（rm 前已跟踪） |
| W3 | **未开**（无失败项） |

### 0.2 origin 支 tip

| branch | tip | 内容 |
|--------|-----|------|
| xvyimu/cv-scout-health | `9e2ba87` | Phase0 evidence |
| xvyimu/cv-themes-contracts | `65c38a3` | W2 NO-CODE |
| xvyimu/cv-doctor-smoke-docs | `2aa2b0b` | map + evidence |
| xvyimu/cv-adr0005-onepager | `b4cbc94` | DEFER 1 页 |
| xvyimu/cv-coord | `fb792e0`→本轮 | long-wave SSOT |

---

## 1. 名表（orca）

| displayName | branch | status |
|-------------|--------|--------|
| main | main | 主 |
| cv-coord | xvyimu/cv-coord | 总控 |
| cv-cdp-url-guard | xvyimu/cv-cdp-url-guard | **LIVE W5** |
| cv-catalog-budget | xvyimu/cv-catalog-budget | **LIVE W6** |
| cv-core-runtime-boundary | xvyimu/cv-core-runtime-boundary | **LIVE W8** |

---

## 2. 审核结论（W2/W4/W11）

| 卡 | 边界 | exit / 要点 | 审核 |
|----|------|-------------|------|
| W2 | 无业务码 | themes/store/adapter/contracts **全 0** | **PASS** |
| W4 | 无 injector 改 | doctor **0** · fresh · smoke **skipped**（Codex idle）· map 齐 | **PASS** |
| W11 | 无壳代码 | DEFER 页钉 Proposed | **PASS** |

---

## 3. 下一批（槽空后）

W9 arina-only docs · W10 pain-close · W7 launcher · W12 long-verify · W13 INTEGRATE  

---

## 4. 红线复核

- [x] 无 asar  
- [x] 无第二 injector  
- [x] 无 vendor  
- [x] 无 publish  
- [x] feature push 仅 feature 支  
