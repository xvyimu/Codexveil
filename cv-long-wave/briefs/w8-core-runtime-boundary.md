# M-CV-core-runtime-boundary · W8 brief

产品：Codexveil  
模块：M-CV-core-runtime-boundary · WEEK W8  

## 边界

- **做：** `npm run test:deps` + 只读审计 `packages/core` ↔ `packages/runtime` import 方向  
  - 写 `docs/ops/cv-core-runtime-boundary-evidence-2026-07-24.md`（依赖方向表 · 违规零/非零）  
  - 绿则 **NO-CODE**；红则最小拆边（禁造第二 injector）  
- **禁：** asar · vendor · 双向依赖「临时允许」· publish · 大重构  

## 先读

`scripts/check-package-deps.mjs` · PROJECT §依赖 · CLAUDE 不可谈判 #2

## 验收

evidence + exit deps=0 · in-review · commit
