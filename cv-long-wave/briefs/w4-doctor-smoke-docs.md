# M-CV-doctor-smoke-docs · W4 brief

产品：Codexveil  
模块：M-CV-doctor-smoke-docs · WEEK W4  
依赖：W1 scout ACCEPT

## 边界

- **做：** doctor 路径 **文档化** + 注入触及 smoke **证据/索引**（装态只读对照）  
  - 优先：`docs/ops/cv-doctor-smoke-map-2026-07-24.md`（可裁剪 scout §1 命令表）  
  - 可选交叉：`docs/usage.md` 故障速查 / `docs/ops/cv-day-ready-2026-07-24.md` §4 链到 map（**最小 diff**）  
  - 本机：`npm run doctor` 只读 · exit + freshness/runtimeId 摘要进 map 或 evidence  
  - 若用户机 Codex **已运行** 可可选装态 smoke（源 `apps/launcher/smoke-dream-skin.ps1`）记 exit；**未运行则跳过 smoke 实跑并写明**  
- **禁：** publish-runtime · 主动备份装态 · check-and-fix 当默认验证 · 改 injector 逻辑 · asar · 第二 injector · push  

## 先读

`docs/ops/cv-scout-health-evidence-2026-07-24.md` §1 · `docs/usage.md` · `docs/ops/cv-day-ready-2026-07-24.md` · `docs/ops/cv-runtime-gap-card-2026-07-25.md`

## 验收

- map 文档齐：命令 / 何时用 / 风险 / 与 npm test 关系  
- evidence：`docs/ops/cv-doctor-smoke-docs-evidence-2026-07-24.md`（总控回执 + exit）  
- commit `docs(ops):` · in-review  

风险一句。
