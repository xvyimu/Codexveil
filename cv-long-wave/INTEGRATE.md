# Codexveil · W13 INTEGRATE · 人 gate 就绪 · 2026-07-24

**MODE：** 总控合入计划 · **STATUS：READY_FOR_HUMAN_GATE**  
**WRITE_POLICY：** 仅 feature / 人批 merge；**禁止** 自动 merge `main` · **禁止** `publish-runtime` · **禁止** asar / D7 / 生产 CSP  
**总控 tip：** `xvyimu/cv-coord` @ **`cf99b2d`+**（本文件更新后随 commit）  
**产品 base：** `main` / `origin/main` @ **`ebc3568`**（合入前再 `git fetch`）  
**实现 child：** **live 0** · W1–W12 **ACCEPT**（W3 SKIP）

---

## 一句话

长波交付 = **docs/ops 证据 + 门闩全绿（NO-CODE 业务）**。  
**下一步只等人：** 按下方序把 feature docs 合入 `main`；**不** stamp 装态，**不**自动 push main。

---

## 0. 验收总表（已齐 · 勿再开实现 wt）

| ID | branch | origin tip | 状态 |
|----|--------|------------|------|
| W1 | `xvyimu/cv-scout-health` | `9e2ba87` | ACCEPT |
| W2 | `xvyimu/cv-themes-contracts` | `65c38a3` | ACCEPT NO-CODE |
| W3 | — | — | **SKIP**（themes 全绿） |
| W4 | `xvyimu/cv-doctor-smoke-docs` | `2aa2b0b` | ACCEPT |
| W5 | `xvyimu/cv-cdp-url-guard` | `5032a98` | ACCEPT NO-CODE |
| W6 | `xvyimu/cv-catalog-budget` | `fb9f4d4` | ACCEPT NO-CODE |
| W7 | `xvyimu/cv-launcher-tray-stability` | `a2d03c0` | ACCEPT NO-CODE |
| W8 | `xvyimu/cv-core-runtime-boundary` | `f08112c` | ACCEPT NO-CODE |
| W9 | `xvyimu/cv-theme-arina-only-docs` | `f48255d` | ACCEPT NO-CODE |
| W10 | `xvyimu/cv-pain-close-batch` | `908ca42` | ACCEPT |
| W11 | `xvyimu/cv-adr0005-onepager` | `b4cbc94` | ACCEPT |
| W12 | `xvyimu/cv-long-verify` | `40e5796` | ACCEPT · **npm test 全 0** |
| coord | `xvyimu/cv-coord` | `cf99b2d`+ | 进度 SSOT（可选合 / 可留支） |

### 门闩（稳定运行 · unit + idle 装态）

| 门闩 | exit | 证据支 |
|------|------|--------|
| `npm test`（unit+contracts） | **0** | W12 |
| themes / store / adapter / contracts | **0** | W2 |
| cdp-url / freshness / deps | **0** | W5 · W8 |
| catalog-budget / quality | **0** | W6 · W9 |
| doctor idle | **0** · `fresh` · runtimeId **`1.3.25-da2adc`** | W1 · W4 · W10 · W12 |
| core↔runtime 双向静态 | **0 违规** | W8 |
| 单 open → 单 watch | 审计 PASS | W7 |

**装机有皮：** 仍须用户点任务栏 Codex；unit 绿 **≠** live 会话 / F6 体感（#25 保持开放）。

---

## 1. 相对 `main` 的文件清单（`git diff --name-status origin/main...origin/<branch>`）

### P0 优先合入

| 支 | tip | 相对 main 变更 |
|----|-----|----------------|
| **W4** doctor-smoke | `2aa2b0b` | `A` map + evidence · `A` scout 拷贝 · **`M` usage.md · `M` day-ready** |
| **W12** long-verify | `40e5796` | `A` `docs/ops/cv-long-verify-evidence-2026-07-24.md` |
| **W11** adr0005 | `b4cbc94` | `A` `docs/ops/cv-adr0005-defer-2026-07-24.md` |
| **W1** scout | `9e2ba87` | `A` `docs/ops/cv-scout-health-evidence-2026-07-24.md`（**权威 scout**；W4 内拷贝以 W1 为准） |
| **W10** pain | `908ca42` | `A` pain-close evidence · **`M` PAIN-POINTS.md · CHANGELOG · overview** |

### P1 证据-only（几乎纯 A）

| 支 | tip | 变更摘要 |
|----|-----|----------|
| W2 | `65c38a3` | themes-contracts evidence |
| W5 | `5032a98` | cdp-url-guard evidence |
| W6 | `fb9f4d4` | catalog-budget evidence |
| W7 | `a2d03c0` | launcher-tray evidence |
| W8 | `f08112c` | core-runtime-boundary evidence |
| W9 | `f48255d` | arina-only-docs evidence |

### 冲突面（合入时注意）

| 文件 | 出现于 | 处理 |
|------|--------|------|
| `docs/ops/cv-scout-health-evidence-*.md` | W1 权威 · W4 亦 A 拷贝 | **以 W1 tip 为准**；合 W4 时丢弃重复或后覆盖 |
| `docs/usage.md` · `docs/ops/cv-day-ready-*.md` | **仅 W4 M** | 单独审 diff 后合 |
| `docs/PAIN-POINTS.md` · CHANGELOG · overview | **仅 W10 M** | 脚注级；与 W4 无同文件冲突 |

**业务码 / injector / themes 资源：** 各支相对 main **无必合实现 diff**（NO-CODE）。

---

## 2. 建议合入序（人 gate · 可复制）

```text
# 0) 校准
git fetch origin
git checkout main && git pull --ff-only origin main   # 期望仍 ebc3568 或快进

# 1) 开 integrate 支（推荐一条支叠合，或分 PR）
git checkout -b xvyimu/cv-integrate-long-wave origin/main

# 2) P0（审 usage/day-ready/PAIN 后）
git merge --no-ff origin/xvyimu/cv-scout-health -m "docs: W1 scout-health evidence"
git merge --no-ff origin/xvyimu/cv-doctor-smoke-docs -m "docs: W4 doctor/smoke map"
  # 若 scout 文件冲突 → 取 W1 版
git merge --no-ff origin/xvyimu/cv-long-verify -m "docs: W12 long-verify npm test exit 0"
git merge --no-ff origin/xvyimu/cv-adr0005-onepager -m "docs: W11 ADR0005 DEFER"
git merge --no-ff origin/xvyimu/cv-pain-close-batch -m "docs: W10 PAIN close-batch (no fake-close)"

# 3) P1 证据串
for b in cv-themes-contracts cv-cdp-url-guard cv-catalog-budget \
         cv-launcher-tray-stability cv-core-runtime-boundary cv-theme-arina-only-docs; do
  git merge --no-ff origin/xvyimu/$b -m "docs: $b evidence"
done

# 4) 门闩（合入支上）
npm test          # expect exit 0
# 可选：npm run doctor  # idle 只读

# 5) 人：开 PR → main · 合并 · 勿 force main
# 6) publish-runtime：另授 + true-publish checklist + VERSION
```

**分 PR 变体：** PR-A = W1+W4+W12+W11；PR-B = W10；PR-C = 其余 P1。

**不要：** force 推 main · 合入时改 asar · 顺手 publish · 把 `cv-coord` 进度当硬依赖（可选 cherry-pick `cv-long-wave/`）。

---

## 3. 明确不做

| 项 | 状态 |
|----|------|
| 自动 merge / push **main** | **禁** · 等人 |
| `publish-runtime` / 装态 stamp | **另授** |
| ADR0005 壳代码 | **DEFER**（W11 页） |
| PAIN #25 关单 | **不关** 至 live F6 smoke + 人声明 |
| D7 / 生产 CSP / 改 Codex asar | **禁** |
| 第二 injector / vendor | **禁** |

---

## 4. 总控卫生

| 项 | 状态 |
|----|------|
| orca 实现 child | **0**（仅 `cv-coord` + `main`） |
| feature origin tips | 上表齐全 |
| 磁盘残渣 | `…/Codexveil/{cv-long-verify,cv-scout-health,cv-themes-contracts}` 等 **非 git wt** 残留 `node_modules/packages` 碎片 · **不自动 rm**（可选人清） |
| `ship-d1-cv` | 空目录残渣 · 可选删 |

---

## 5. 总控回执

| 项 | 值 |
|----|-----|
| W13 | **READY_FOR_HUMAN_GATE** |
| 自动 merge main | **否** |
| 总控是否停 | **否** · 保持巡检 / 等人批；**不**叠新实现 wt 除非人改北极星 |
| 下一动作 | 人按 §2 合入 · 或明确授权 integrate PR |

**风险一句：** docs 多支 merge 冲突面小但 **W4 改 usage/day-ready**、**W10 改 PAIN** 须人眼；装态 `1.3.25-da2adc` **不**因合 docs 而变。
