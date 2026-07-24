# M-CV-scout-health · Phase0 深扫 brief

产品：Codexveil · 仓根本 worktree（git 检出）  
模块 ID：M-CV-scout-health  
总控进度（只读对照，勿改它仓路径纪律）：`C:\Users\yuanjia\orca\workspaces\Codexveil\cv-coord\cv-long-wave\progress.md`

## 边界

- **做：** 只读扫描 + 写 `docs/ops/cv-scout-health-evidence-2026-07-24.md`；可本地 commit 本 feature 支  
- **先读：** `docs/PROJECT.md` · 根 `CLAUDE.md` · `docs/PAIN-POINTS.md` · `docs/ops/cv-day-ready-2026-07-24.md` · `docs/ops/cv-runtime-gap-card-2026-07-25.md` · 根 `package.json` scripts  
- **栈锁：** Node ESM + 单 injector CDP；core↔runtime 禁双向；主题只经 `packages/themes` + `themes/<id>/`  
- **禁：** push · 第二 injector · vendor/ · 改 Codex asar · 自建桌面壳 · publish-runtime · 主动备份装态 · 大面积业务码 · 改它仓  

## 产出（必须）

`docs/ops/cv-scout-health-evidence-2026-07-24.md`，文首含「总控回执」小节，正文：

1. **doctor / smoke 命令现状表**  
   - 从 package.json、CLAUDE.md、docs（day-ready / usage / PROJECT）列出：doctor、smoke、check-and-fix、status、list、probe:session 等  
   - 每条：命令、用途、是否进 npm test、是否需 live CDP/装态、风险  
   - 本机可跑则：`npm run doctor`（只读）记 **exit** + freshness/runtimeId 摘要；失败也记  

2. **PAIN-POINTS 摘录**  
   - open / 需 publish / 硬限（至少 #21 #24 #25 + 未标已修）  
   - 映射本波：themes/contracts · doctor 文档化  

3. **themes / contracts 测试缺口表**  
   - 对照：test:themes, test:themes-contracts, test:store, test:adapter, test:catalog-quality, test:contracts  
   - 总控基线 main 2026-07-24：`test:themes|themes-contracts|store|adapter|deps` + **`npm test` 均为 exit 0**  
   - 写覆盖盲区与假绿风险；建议 `cv-themes-contracts`：**NO-CODE / evidence-only** 若仍绿，否则列红项  

4. **test:deps** 一句：含义 + 是否建议每实现 child 重跑  

5. **派发建议（1 段）**  
   - cv-themes-contracts：做 / 跳过 / 仅文档  
   - cv-doctor-smoke：文档落点建议  
   - ADR0005：DEFER 1 页建议路径（如 `docs/ops/cv-adr0005-defer-2026-07-24.md`）  

## 验证

复跑触及 script 记 exit；doctor 只读。完成标准：evidence 齐 + 风险一句 + 本地 commit（conventional `docs(ops):`）· workspace **in-review** · **DONE 先回执总控**（写在 evidence 总控回执）。

风险一句写在 evidence 末。
