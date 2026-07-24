# M-CV-cdp-url-guard · W5 brief

产品：Codexveil  
模块：M-CV-cdp-url-guard · WEEK W5  
依赖：W1/W2 ACCEPT · unit 基线绿

## 边界

- **做：** 复跑 `npm run test:cdp-url` · `npm run test:freshness`（建议加 `npm run test:deps`）记 **exit**  
  - 写 `docs/ops/cv-cdp-url-guard-evidence-2026-07-24.md`  
  - **全 0 → NO-CODE**；仅非 0 时最小修 `packages/runtime/scripts/cdp-url-guard*` / `packages/core/state/*freshness*`  
- **禁：** 第二 injector · asar · vendor · publish · push（总控 push）· 扩 CDP 端口默认 · 改 injector 热路径除非测红  

## 先读

`docs/PROJECT.md` §1.5 · `packages/runtime/scripts/cdp-url-guard*.mjs` · `packages/core/state/*freshness*` · scout evidence 盲区表

## 验收

- evidence 含命令+exit · 风险一句 · 总控回执  
- 本地 `docs(ops):` 或 `fix:` commit · **in-review**  

若修码：`npm test` 触及面至少 unit 相关 + deps。
