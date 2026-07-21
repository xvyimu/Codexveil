# 第三方快照说明 · 归档（原「上游 promote 决策」）

> **状态**：归档 · 被 [ADR 0006](../adr/0006-independent-product-line.md) 废止在线同步  
> **日期**：原 2026-07-21；修订 2026-07-22

本文件曾记录「对 `Fei-Away/Codex-Dream-Skin` 做 vendor promote」的决策。  
**现行规则**：

- 无 `upstream` remote；仅 `origin` → `xvyimu/Codexveil`
- `vendor/dreamskin/` = **冻结**第三方快照（`NOTICE`），不自动刷新
- `sync-upstream-assets.ps1` 已退役（exit 2）
- 若要对某冻结资产做人工移植，写当期 research 笔记 + 人工 diff，**不**重建 remote

历史快照记录见 [`docs/upstream-sync.json`](../upstream-sync.json)（`status: retired`）。
