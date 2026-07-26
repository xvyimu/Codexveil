# M-CV2-adr-0005-onepager 证据

## 任务

M-CV2-adr-0005-onepager — 薄产品壳一页纸 + 主题契约索引

## 完成

### 交付物

| 文件 | 类型 | 说明 |
|------|------|------|
| `docs/adr/0005-thin-product-shell-onepager.md` | ADR 一页纸 | 快照 ADR 0005，补充「非强制主路径」边界与升 Accepted 触发条件 |
| `docs/ops/cv-themes-contracts-index-2026-07-26.md` | 操作索引 | 主题契约索引、catalog schema、apply/kick 流程、不改 asar 边界 |

### 不做

- 改 asar / injector / 运行时代码 ✅ 未做
- publish-runtime ✅ 未做
- 改 ADR 0005 状态从 Proposed → Accepted ✅ 未做（需人决策）
- push main ✅ 未做

### 验收

1. 文档 commit 2 个：`docs(adr): 0005 thin product shell one-pager (WAVE-2)` + `docs(ops): themes contracts index (WAVE-2)` ✅
2. 证据文件 ✅

## 文件清单

```
docs/adr/0005-thin-product-shell-onepager.md
docs/ops/cv-themes-contracts-index-2026-07-26.md
docs/ops/cv-opt-adr-0005-onepager-evidence-2026-07-26.md
```