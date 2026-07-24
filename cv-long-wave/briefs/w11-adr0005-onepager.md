# M-CV-adr0005-onepager · W11 brief

产品：Codexveil  
模块：M-CV-adr0005-onepager · WEEK W11  

## 边界

- **做：** 仅 1 页文档 `docs/ops/cv-adr0005-defer-2026-07-24.md`  
  - 重申 ADR 0005 **Proposed** · 本波 **DEFER 实现**  
  - 壳↔核：仅 control-plane/CLI · **禁止**壳内第二 watch/CDP 守护  
  - 依赖 0004 契约已绿 ≠ Accepted 壳  
  - MVP 成功标准 / out-of-scope / 何时可 reopen（Accepted + 人批）  
- **禁：** 任何壳脚手架 · Tauri/Electron 产品壳代码 · apps/shell · push · publish · asar  

## 先读

`docs/adr/0005-thin-product-shell-u3.md` · `docs/adr/0004-engineering-modernization-u1.md` · `docs/PROJECT.md` §1.5 · scout evidence §5

## 验收

- 一页 DEFER 齐 · **零业务/壳代码**  
- 可选 evidence 可与 onepager 同文或短 `docs/ops/cv-adr0005-onepager-evidence-2026-07-24.md`  
- commit `docs(ops):` · in-review  

风险一句：误把 DEFER 当开工令。
