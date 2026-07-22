# Codexveil · 栈矩阵 · 2026-07

> W1 落盘 · W2 更新 · **W3 更新** · 对照 `portfolio-arch-upgrade-2026h2/repos/cv.md` + `crosscut.md`  
> 工作树：`C:\Users\yuanjia\orca\workspaces\Codexveil\w3-cv-claude`  
> 报告：`w1-arch-upgrade-codexveil-claude.md` · `w2-arch-upgrade-codexveil-claude.md` · **`w3-arch-upgrade-codexveil-claude.md`**

## 1. 当前 → 目标 → 波次

| 项 | 当前（W3 实测） | 目标（半年卡） | W1 | W2 已做 | **W3 已做** |
|----|-----------------|----------------|----|---------|-------------|
| **Node engines** | `>=20`（`package.json`） | 产品 runtime 仍 ≥20；开发/CI **22 LTS** | CI themes-gate **22** | 不改 engines | 不改 engines |
| **packageManager** | `pnpm@11.5.0` | 11.5 与组合对齐 | 已对齐 | 不变 | 不变 |
| **TypeScript** | `^5.9.2` | 跟补丁线 | 不 bump | 不 bump | 不 bump |
| **contracts** | `@codex-skin/contracts` 开发态包 | **扩大公共 API 类型** | 不扩 | **扩 inject/kick 面** | 不扩；**不进 versions/** |
| **runtime 版本线** | 源 tip `6910a22` · **装态仍 `1.3.25-eee7c8`** | 同线 · 装态跟人 gate | 无真 publish | **无再 publish** | **re-publish 卷宗 + 预检绿**；**NOT EXECUTED** |
| **注入架构** | theme-load + **payload-builder** + control-plane / fs-io | 模块图强制 | S2 theme-load | **S3 payload-builder** + required | verify **staged import payload-builder**；装态仍缺文件至 publish |
| **主题默认观感** | runtime `assets/theme.json` = **preset-arina-hashimoto** | 默认 arina · 非 Gothic | V2 CSS/inject | 不改默认 | 书面基线：装态/ tip 均为 arina；H1–H7 待 publish 后手测 |
| **测试门** | `npm test` = unit + contracts | DOM probe 纪律 / 主题质量门 | unit + contracts | **+ payload-builder · catalog-quality** | 预检再记 exit 0；verify 硬化 |
| **可选薄壳** | launcher first-party | ADR 0005 W3–W4 | 不做 | **不做** | **不做实现**（Proposed 保留；W4 推进或延期书） |
| **publish 人 gate** | 清单 + wave7/8 checklist | 可重复 re-publish | 清单 | — | **`w3-republish-gate-dossier.md`** |

## 2. 横切对齐（X-NODE / X-PNPM）

| 组合目标 | Codexveil |
|----------|-----------|
| Node CI 22 | **是**（themes-gate） |
| engines 产品 ≥20 | **是** |
| pnpm 11.5 | **是** |
| 换 UI 框架 | **禁止** |

## 3. 架构主刀进度（相对半年卡）

| 主刀 | 波 | 状态 |
|------|-----|------|
| V2 视觉对齐 Fei-Away（arina） | W1–W2 | W1 起步；W2 **未**整换 css；W3 **无** V3 整换 |
| injector 模块图强制 | W2–W3 | S3 完成；装态待人 publish 跟上；verify 含 payload-builder import |
| 主题 schema/质量门 | W2–W3 | catalog-quality + C-2 H1–H7；W3 书面基线（无强制 CDP） |
| publish 白名单 = 模块图测试 | 持续 | required 含 payload-builder；**dossier 等人 gate** |
| 薄壳 ADR 0005 | W3–W4 | **未实施** · 本波无代码 |

## 4. 明确不做（W3）

- **`publish-runtime` 真装机** / asar / ISS  
- vendor · 默认 Gothic · V3 整文件替换 css/inject  
- Node engines 硬升 22  
- ADR 0005 薄壳 MVP 编码  
- push / 合默认分支（总控）

## 5. 验证命令

```powershell
npm test
pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1
# 期望均为 exit 0
# 人 gate 后才：
# pwsh -NoProfile -File scripts/windows/publish-runtime.ps1 -Version 1.3.25
```

## 6. 修订

| 日期 | 说明 |
|------|------|
| 2026-07-23 | W1 初版：CI Node 22 + 视觉 V2 起步 |
| 2026-07-23 | W2：contracts inject 面 · payload-builder S3 · catalog-quality · stack-matrix 列 |
| 2026-07-23 | **W3**：re-publish 卷宗 · verify payload-builder staged import · **PUBLISH NOT EXECUTED** · 装态仍 1.3.25-eee7c8 |
