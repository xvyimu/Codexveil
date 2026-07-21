# Codex Dream Skin — 文档索引

## 主调研报告（增量升级，最新在前）

| 版本 | 日期 | 链接 | 要点 |
|------|------|------|------|
| **v7** | 2026-07-21 | [v7-gate-hygiene-and-ux](./research/2026-07-21-master-research-v7-gate-hygiene-and-ux.md) | squash 合 main · 双 CI 绿 · probe-project-hd **断言化** · RELEASE-EVIDENCE CI URL · BASELINE 对齐 · surfaceLuma `#rrggbb` 边界 |
| v6 | 2026-07-21 | [v6-palette-root-and-hd-bubble](./research/2026-07-21-master-research-v6-palette-root-and-hd-bubble.md) | 闪白根因补丁 48b5bae + HD art + 气泡双模式 0326abb · v5 假关闭教训 · BASELINE 自动生成（过程中曾 ahead，已 squash 归零） |
| v5 | 2026-07-21 | [v5-visual-sync-and-next](./research/2026-07-21-master-research-v5-visual-sync-and-next.md) | 闪白表面修 e01d0ef + ahead 4 + 五件套首版 |
| v4 | 2026-07-21 | [v4-u3u4-product](./research/2026-07-21-master-research-v4-u3u4-product.md) | U3/U4 产品视角 |
| v3 | 2026-07-21 | [v3-ux-visual](./research/2026-07-21-master-research-v3-ux-visual.md) | UX/视觉 |
| v2 | 2026-07-21 | [v2-frozen](./research/2026-07-21-master-research-v2-frozen.md) | 冻结 |
| v1 | 2026-07-21 | [integrated-master-research](./research/2026-07-21-integrated-master-research.md) | 集成首版 |

## 同类对照与债务

- [**github-peer-matrix（2026-07-21）**](./research/2026-07-21-github-peer-matrix.md) — GitHub 细矩阵：引擎/编辑器/标准/镜像反例 · 可借鉴/不要抄 · 复现命令
- [peer-landscape-and-architecture](./research/2026-07-21-peer-landscape-and-architecture.md) — 上游/Styler/awesome 架构长文
- [progress-aligned-debt-and-portfolio](./research/2026-07-21-progress-aligned-debt-and-portfolio.md) — 进度对齐债务 F1-F6

## 核心文档

- [PROJECT.md](./PROJECT.md) — 项目总纲（§3.2 依赖规则 / §12 路线图）
- [ARCHITECTURE.md](./ARCHITECTURE.md) — 四层模型 + 包契约 + 主题 schema
- [CHANGELOG.md](./CHANGELOG.md) — 版本历史
- [PAIN-POINTS.md](./PAIN-POINTS.md) — 痛点合集（25 项）
- [CONTRIBUTING.md](./CONTRIBUTING.md) — 贡献规范 §C-1–C-9
- [GLOSSARY.md](./GLOSSARY.md) — 术语表
- [SECURITY.md](./SECURITY.md) — 威胁模型
- [usage.md](./usage.md) — 使用说明
- [dual-open-policy.md](./dual-open-policy.md) — 双开策略
- [RELEASE-EVIDENCE.md](./RELEASE-EVIDENCE.md) — 发版证据清单
- [BASELINE.generated.md](./BASELINE.generated.md) — 自动生成基线（write-baseline.ps1）

## ADR

- [0001-merge-product-line](./adr/0001-merge-product-line.md) — 合并 heige + DreamSkin 单产品线
- [0002-upstream-sync-policy](./adr/0002-upstream-sync-policy.md) — 上游 vendor 镜像 + 人工 promote
- [0003-single-version-source](./adr/0003-single-version-source.md) — 单一版本源
- [0004-engineering-modernization-u1](./adr/0004-engineering-modernization-u1.md) — **Accepted** U1：双平面依赖 · TS/contracts · probe-kit · stamp · Vitest
- [0005-thin-product-shell-u3](./adr/0005-thin-product-shell-u3.md) — **Proposed** U3：薄 Tauri/L1 壳，不替换 watch 守护
- 排期：[u1-u3-two-week-plan-2026-07-21](./plans/u1-u3-two-week-plan-2026-07-21.md) · 分支 `feat/u1-workspace`

## 决策与计划

- [task-cards-2026-07-21](./plans/task-cards-2026-07-21.md) — 12 张任务卡（均已完成）
- [codesign-decision-2026-07-21](./plans/codesign-decision-2026-07-21.md) — 签名 No-Go 决策
- [residual-g1-g3-g4-g5-2026-07-20](./plans/residual-g1-g3-g4-g5-2026-07-20.md) — 残差加固
- [upstream-promote-decision-2026-07-21](./plans/upstream-promote-decision-2026-07-21.md) — 上游 promote 决策
