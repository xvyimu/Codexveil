# Codexveil · 栈矩阵 · 2026-07

> W1 落盘 · 对照 `portfolio-arch-upgrade-2026h2/repos/cv.md` + `crosscut.md`  
> 工作树：`C:\Users\yuanjia\orca\workspaces\Codexveil\w1-cv-claude`  
> 基线 HEAD：见同波报告 `w1-arch-upgrade-codexveil-claude.md`

## 1. 当前 → 目标 → 本波

| 项 | 当前（W1 实测） | 目标（半年卡） | 本波（W1）已做 / 状态 |
|----|-----------------|----------------|------------------------|
| **Node engines** | `>=20`（`package.json`） | 产品 runtime 仍 ≥20；开发/CI **22 LTS** | **已钉 CI**：`.github/workflows/themes-gate.yml` → `node-version: "22"`；注释说明 pnpm 11.5+ 需 ≥22.13 |
| **packageManager** | `pnpm@11.5.0` | 11.5 与组合对齐 | **已对齐**；本波不改 lock 策略 |
| **TypeScript** | `^5.9.2`（devDependencies） | 跟补丁线 | 本波不 bump；contracts 构建走现网 |
| **contracts** | `@codex-skin/contracts` 开发态包 | W1–W2 **扩大公共 API 类型** | W1 **不扩 API**（留给 W2）；`npm run test:contracts` 仍进 `npm test` |
| **runtime 版本线** | `1.3.25` · stamp `publish-runtime.ps1 -Version`（ADR 0003） | 同 | 本波 **不真 publish**；`verify-publish-runtime-payload.ps1` 白名单校验 |
| **注入架构** | single watch injector · theme-load / control-plane / fs-io | W2 模块图强制下一刀 | W1 仅 **视觉相关** CSS/inject；**保留** F6 / catalog 四参 |
| **主题默认观感** | runtime `assets/theme.json` = **preset-arina-hashimoto** 粉系 | 默认 arina 粉 · 非 Gothic | **保持**；视觉 V2 promote 映射进 oklch token |
| **测试门** | `npm test` = unit + contracts | W2 + DOM probe 纪律 / 主题质量门 | W1：`npm test` + verify-payload **exit 0** |
| **可选薄壳** | launcher first-party | ADR 0005 W3–W4 | **不做** |

## 2. 横切对齐（X-NODE / X-PNPM）

| 组合目标 | Codexveil |
|----------|-----------|
| Node CI 22 | **是**（themes-gate） |
| engines 产品 ≥20 | **是**（装机/旁路 Node 可低于 22） |
| pnpm 11.5 | **是** |
| 换 UI 框架 | **禁止**（无 React/Vue 产品面） |

## 3. 架构主刀进度（相对半年卡）

| 主刀 | 波 | W1 状态 |
|------|-----|---------|
| V2 视觉对齐 Fei-Away（arina） | W1–W2 | **起步**：映射表 + 白名单 CSS/inject promote（见 `visual-align-fei-away-diff-2026-07-23.md`） |
| injector 模块图强制 | W2 | 未动业务拆分 |
| 主题 schema/质量门 | W2 | 未扩门 |
| publish 白名单 = 模块图测试 | 持续 | verify-payload 仍过；无 publish |

## 4. 明确不做（本波）

- `publish-runtime` 真装机 / asar 覆盖  
- vendor 整树 · 恢复 upstream remote（ADR 0006）  
- 默认改 Gothic · V3 整文件替换 css/inject  
- Node engines 硬升到 22（破坏装机旁路）  
- contracts 公共 API 大扩（W2）

## 5. 验证命令

```powershell
npm test
pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1
# 期望均为 exit 0
```

## 6. 修订

| 日期 | 说明 |
|------|------|
| 2026-07-23 | W1 初版：CI Node 22 已在仓；本波记矩阵 + 视觉 V2 起步 |
