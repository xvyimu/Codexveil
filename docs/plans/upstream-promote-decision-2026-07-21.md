# 上游 promote 决策 · 2026-07-21

- 上游基线：[`docs/upstream-sync.json`](../upstream-sync.json) → `lastSyncedUpstreamSha: e776fa6`
- 策略：[`docs/adr/0002-upstream-sync-policy.md`](../adr/0002-upstream-sync-policy.md)（vendor 镜像 + 人工 promote；禁止盲合）
- 本轮决策：**不 promote**（默认 A；无用户可见上游新修复）

| 资产 | 与上游关系 | 本地覆盖原因 | 决策 | 重评条件 |
|------|------------|--------------|------|----------|
| packages/runtime/assets/dream-skin.css | runtime ≠ vendor（us-ahead 本地覆盖） | de-blur 等本地视觉覆盖 | **不 promote（当前）** | 上游 e776fa6 之后有明确视觉修复且 diff 可人工摘取 |
| packages/runtime/assets/renderer-inject.js | 同上 | artDataUrl null-safety；`SKIN_VERSION_TOKEN` stamp 机制 | **不 promote（当前）** | 同上；promote 后必须保留 stamp / null-safe |
| vendor/dreamskin/assets/* | 镜像层 | sync 脚本刷新；非生产 import | 保持镜像；不自动进 runtime | 每次 `sync-upstream-assets.ps1` 后复看 |

禁止：`Copy-Item` 上游/vendor 覆盖 runtime 而不经人工 diff。

验收：本文存在；无 runtime 资产内容变更。
