# Codexveil — 文档索引

> **日常只读**：根目录 `CLAUDE.md` / `AGENTS.md` → [`PROJECT.md`](./PROJECT.md) → [`ARCHITECTURE.md`](./ARCHITECTURE.md)。  
> 本页 = 文档地图；不替代 PROJECT 约束。

## 0. 当前真相（2026-07-22）

| 项 | 值 |
|----|-----|
| GitHub | [xvyimu/Codexveil](https://github.com/xvyimu/Codexveil) · **非 fork** · 仅 `origin` |
| 产品线 | ADR **0006** 独立 · 安装名 **CodexDreamSkin** |
| 主线 runtime | **1.3.25** · publish 权威见 ADR 0003 |
| 装机脚本 | tray / launch / restore ∈ `apps/launcher/` |
| 工作树 | **无** `vendor/` · **无** `docs/research/`（已删；仅 git history） |

## 1. 核心文档（常读）

- [PROJECT.md](./PROJECT.md) · [ARCHITECTURE.md](./ARCHITECTURE.md)
- [CHANGELOG.md](./CHANGELOG.md) · [PAIN-POINTS.md](./PAIN-POINTS.md) · [CONTRIBUTING.md](./CONTRIBUTING.md)
- [GLOSSARY.md](./GLOSSARY.md) · [SECURITY.md](./SECURITY.md) · [usage.md](./usage.md) · [dual-open-policy.md](./dual-open-policy.md)
- [RELEASE-EVIDENCE.md](./RELEASE-EVIDENCE.md) · [BASELINE.generated.md](./BASELINE.generated.md)
- [design-tokens.md](./design-tokens.md) · [design/atelier-v3-matrix.md](./design/atelier-v3-matrix.md)（V3 SKIP/DEFER arina-only） · [contracts/post-update-report.md](./contracts/post-update-report.md)

## 2. ADR

| ID | 状态 | 摘要 |
|----|------|------|
| [0001](./adr/0001-merge-product-line.md) | Accepted | 单产品线 |
| [0002](./adr/0002-upstream-sync-policy.md) | **Superseded by 0006** | 旧在线同步（已废止） |
| [0003](./adr/0003-single-version-source.md) | Accepted | 单一版本源 |
| [0004](./adr/0004-engineering-modernization-u1.md) | Accepted | 双平面 · contracts |
| [0005](./adr/0005-thin-product-shell-u3.md) | Proposed | 薄产品壳 |
| [0006](./adr/0006-independent-product-line.md) | Accepted | 独立产品线 · 无 vendor/research 树 |

## 3. 计划

- [u1-u3-two-week-plan-2026-07-21](./plans/u1-u3-two-week-plan-2026-07-21.md)
- [task-cards-2026-07-21](./plans/task-cards-2026-07-21.md)
- [codesign-decision-2026-07-21](./plans/codesign-decision-2026-07-21.md)
- [residual-g1-g3-g4-g5-2026-07-20](./plans/residual-g1-g3-g4-g5-2026-07-20.md)

## 4. 审计 / 报告（仓内）

- [AUDIT-2026-07-20](./AUDIT-2026-07-20.md) · [SCAN-OPTIMIZE-2026-07-20](./SCAN-OPTIMIZE-2026-07-20.md)
- [audit/](./audit/) · [reports/](./reports/)
- [prompts/](./prompts/) · [evidence/](./evidence/)

## 5. 已删除（仅 git history）

| 路径 | 说明 |
|------|------|
| `vendor/dreamskin/` | 原冻结第三方快照 |
| `docs/research/*` | 原调研长文 v1–v7 / peer |
| `scripts/windows/sync-upstream-assets.ps1` | 原上游同步 |
| `docs/upstream-sync.json` | 原同步基线 |
