# Codexveil · 栈矩阵 · 2026-07

> W1 落盘 · W2 更新 · W3 更新 · **W4 收口** · 对照 `portfolio-arch-upgrade-2026h2/repos/cv.md` + `crosscut.md`  
> 工作树：`C:\Users\yuanjia\orca\workspaces\Codexveil\w4-cv-claude`  
> 报告：`w1` · `w2` · `w3` · **`w4-arch-upgrade-codexveil-claude.md`** · 装态证明：`w4-install-align-2026-07.md`

## 1. 当前 → 目标 → 波次

| 项 | 当前（W4 实测） | 目标（半年卡） | W1 | W2 | W3 | **W4 收口** |
|----|-----------------|----------------|----|----|-----|-------------|
| **Node engines** | `>=20`（`package.json`） | 产品 runtime 仍 ≥20；开发/CI **22 LTS** | CI themes-gate **22** | 不改 | 不改 | **完成**：CI 22 · engines ≥20 不变 |
| **packageManager** | `pnpm@11.5.0` | 11.5 与组合对齐 | 已对齐 | 不变 | 不变 | **完成** |
| **TypeScript** | `^5.9.2` | 跟补丁线 | 不 bump | 不 bump | 不 bump | 跟线 · 无强制 bump |
| **contracts** | `@codex-skin/contracts` 开发态 · inject/kick 面 | **扩大公共 API 类型** | 不扩 | **扩 inject/kick** | 不扩 · **不进 versions/** | **完成一轮扩**（ADR 0004）· 不进装态 |
| **runtime 版本线** | tip `4914631` · **装态 `1.3.25-d403fa`** | 同线 · 装态跟人 gate | 无真 publish | 无 | 卷宗 · **NOT EXECUTED**（当时 eee7c8） | **装态已 d403fa**（人侧 publish 先于本波）· **本波不再 stamp** · **PUBLISH NOT EXECUTED** |
| **注入架构** | theme-load + **payload-builder** + control-plane / fs-io | 模块图强制 | S2 theme-load | **S3 payload-builder** | verify staged import | **装态 ESM 五件套与 tip 字节 MATCH**（见 align 页） |
| **主题默认观感** | runtime `assets/theme.json` = **preset-arina-hashimoto** | 默认 arina · 非 Gothic | V2 CSS/inject | 不改默认 | 书面基线 | **完成**：装态/ tip 均为 arina |
| **测试门** | `npm test` = unit + contracts | DOM probe 纪律 / 主题质量门 | unit + contracts | + payload-builder · catalog-quality | 预检 0 | **npm test 0 · verify 0 · doctor 0**（本 wt） |
| **可选薄壳** | launcher first-party | ADR 0005 W3–W4 | 不做 | 不做 | 不做实现 | **书面延期**（仍 Proposed · 见 §4 backlog） |
| **publish 人 gate** | 清单 + dossier 可重复 | 可重复 re-publish | 清单 | — | **w3-republish-gate-dossier** | **装态已对齐** · 再 publish 仅当 tip 再漂；清单仍有效 |

## 2. 横切对齐（X-NODE / X-PNPM）

| 组合目标 | Codexveil |
|----------|-----------|
| Node CI 22 | **是**（themes-gate） |
| engines 产品 ≥20 | **是** |
| pnpm 11.5 | **是** |
| 换 UI 框架 | **禁止** |

## 3. 架构主刀进度（相对半年卡 · S5）

| 主刀 | 波 | **半年完成度** |
|------|-----|----------------|
| V2 视觉对齐 Fei-Away（arina） | W1–W2 | **达标**：默认 arina · 无 V3 整换 |
| injector 模块图强制 | W2–W3 | **达标**：S2+S3 在 tip **且装态 d403fa 含 payload-builder** |
| 主题 schema/质量门 | W2–W3 | **达标**：catalog-quality + C-2 H1–H7 文档；doctor 活机绿 |
| publish 白名单 = 模块图测试 | 持续 | **达标**：verify + 人 gate 清单可重复 |
| 薄壳 ADR 0005 | W3–W4 | **未实施** · W4 **书面延期**（下半年 backlog） |

## 4. 下半年 backlog（3 条）

1. **ADR 0005 薄壳**：U1 契约已够用；MVP 仍未开刀 → **延期到 2026H2 后段**，仅在有「壳 UX」产品优先级时 enact；禁止第二套 watch injector。  
2. **injector 再分区**：`CdpSession` / Apply 区从 ~1k 行 `injector.mjs` 继续抽出（S4+）；外围脚本（`cdp-url-guard` / `theme-catalog-budget` / `image-metadata`）装态 vs tip 可有小 DIFF，下一刀 publish 时整图对齐。  
3. **PAIN 残留复核**：#24 SmartScreen/未签名（codesign No-Go 维持）；#25 F6 装态随 d403fa 应已闭合——真机 H1–H7 / F6 手测一句记入下一 ops 笔记；主题包生态文档（导入/校验/目录约定）补一页。

## 5. 明确不做（W4）

- **`publish-runtime` 再 stamp**（装态已 d403fa · 本波禁止）  
- asar · ISS · vendor · push / 合默认分支（总控）  
- Node engines 硬升 22 · ADR 0005 MVP 编码 · V3 整换 css/inject  

## 6. 验证命令

```powershell
npm test
pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1
npm run doctor   # 可选活机；本波 exit 0
# 仅 tip 再漂且人授权后：
# pwsh -NoProfile -File scripts/windows/publish-runtime.ps1 -Version 1.3.25
```

## 7. 修订

| 日期 | 说明 |
|------|------|
| 2026-07-23 | W1 初版：CI Node 22 + 视觉 V2 起步 |
| 2026-07-23 | W2：contracts inject 面 · payload-builder S3 · catalog-quality |
| 2026-07-23 | W3：re-publish 卷宗 · verify payload-builder · 装态仍 eee7c8 · **PUBLISH NOT EXECUTED** |
| 2026-07-23 | **W4 收口**：装态 **1.3.25-d403fa** · 关键 ESM MATCH · 半年主刀达标 · backlog 3 · **本波不再 publish** |
