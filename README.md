# codex-skin

统一 Codex Desktop 换肤产品线（**Windows only**）。

- **日常入口（安装态）**：开始菜单 / 任务栏 **Codex**（走 `%LOCALAPPDATA%\Programs\CodexDreamSkin`）
- **开发仓（本仓库）**：`D:\orca\codex-skin`
- **默认 CDP**：`9335`
- **原则**：只允许一条 injector；DreamSkin 级守护 + heige 级多主题
- **平台**：Windows 10/11 + OpenAI Codex（Store）。**不做 macOS** 一等公民支持（见 PROJECT §1.2）
- **入口纪律**：请用任务栏 **Codex** 钉，**不要**用微软商店磁贴开 Codex（OS 硬限，裸启无皮肤 · PAIN #21）

## 状态

见 [`docs/CHANGELOG.md`](docs/CHANGELOG.md)。当前主线 **runtime `1.3.25`** · **11 套内置主题**。

**版本号怎么读**

| 位置 | 含义 |
|------|------|
| `package.json` `"version"` | 与 runtime **产品线**对齐的 npm 元数据（现 `1.3.25`）；**不是** stamp 权威 |
| `packages/runtime` `SKIN_VERSION_TOKEN` | 由 `publish-runtime.ps1 -Version` 写入（ADR 0003 唯一写回 git） |
| 安装态 `current.json` / `runtimeId` | 本机当前引擎，如 `1.3.25-d14cf4` |

全面检查：[`docs/AUDIT-2026-07-20.md`](docs/AUDIT-2026-07-20.md)。  
残差规划（G1 CI / G3 mac / G4 #21 / G5 Quiet）：[`docs/plans/residual-g1-g3-g4-g5-2026-07-20.md`](docs/plans/residual-g1-g3-g4-g5-2026-07-20.md)。

**CI**：GitHub Actions `themes-gate` 在 push/PR 跑 `npm run test:themes`（**不等于**本机 `doctor`/smoke；完整诊断仍在 Windows 安装态）。

## 产品包（终端用户）

```powershell
# 从开发仓打 zip（-Version 必填，或先 publish 让 runtime token 已 stamp）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\Build-ProductPackage.ps1 -Version 1.3.25

# 解压后安装
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

# 卸载（默认保留用户主题；加 -RemoveState 清 catalog）
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

产物：`dist/CodexDreamSkin-<ver>-win-x64.zip`（Install / Uninstall / 11 主题 / runtime / CLI / FastLaunch / 换肤 VBS / 使用说明）。  
版本：包内 stamp **不写回** git；开发发版仍走 `publish-runtime.ps1 -Version`（ADR 0003）。

## 架构

详见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

```text
apps/launcher       用户入口（薄，dot-source lib）
packages/core       Node：发现 / CDP / doctor / 常量 / kick + CLI
packages/themes     主题 schema / catalog / heige→DreamSkin 适配
packages/runtime    watch injector + 资源（发布到 versions/，self-contained）
packages/core-win   PowerShell 共享库（launcher-ui / common / theme）
scripts/windows     发布 / 产品打包 / 导入主题 / 快捷方式 / 探针
themes/             11 套内置主题源（heige 格式，含 preset）
vendor/dreamskin    上游 Fei-Away/Codex-Dream-Skin 只读快照
```

## 开发命令

```powershell
cd D:\orca\codex-skin
node packages/core/cli.mjs help
node packages/core/cli.mjs doctor
node packages/core/cli.mjs list
node packages/core/cli.mjs apply --theme genshin-night   # 热切换 active-theme
node packages/core/cli.mjs import-themes                 # 导入内置主题到 DreamSkin themes
npm run test:themes                                      # 主题 schema 双格式最小门禁
```

发布 runtime（本机开发路径）：

```powershell
powershell -File scripts\windows\publish-runtime.ps1 -RepoRoot D:\orca\codex-skin -Version 1.3.25
```

## 日常使用

1. 点任务栏 **Codex**（启动器 + watch injector）
2. 换肤走统一 CLI `apply --theme` 或托盘「换肤…」 / F6

## 文档

- [`PROJECT.md`](docs/PROJECT.md) — **项目总纲**（边界 · 分层 · 模块契约 · 验收 · 路线图；Agent 先读）
- [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) — 目录 · 边界 · 调用链 · 源码映射
- [`AUDIT-2026-07-20.md`](docs/AUDIT-2026-07-20.md) — 全面检查报告（规范 · 模块 · 前后端映射 · 发现项）
- [`plans/residual-g1-g3-g4-g5-2026-07-20.md`](docs/plans/residual-g1-g3-g4-g5-2026-07-20.md) — 残差 G1/G3/G4/G5 多方案对比与推荐
- [`CHANGELOG.md`](docs/CHANGELOG.md) — 版本时间线
- [`PAIN-POINTS.md`](docs/PAIN-POINTS.md) — 痛点合集与状态
- [`usage.md`](docs/usage.md) — 使用说明
- [`dual-open-policy.md`](docs/dual-open-policy.md) — 入口纪律与 kick 降级
- [`adr/`](docs/adr/) — 架构决策记录（0001 产品线合并 · 0002 上游同步 · 0003 单一版本源）
- [`GLOSSARY.md`](docs/GLOSSARY.md) — 领域术语表
