# codex-skin

统一 Codex Desktop 换肤产品线。

- **日常入口（安装态）**：开始菜单 / 任务栏 **Codex**（走 `%LOCALAPPDATA%\Programs\CodexDreamSkin`）
- **开发仓（本仓库）**：`D:\orca\codex-skin`
- **默认 CDP**：`9335`
- **原则**：只允许一条 injector；DreamSkin 级守护 + heige 级多主题

## 状态

见 [`docs/CHANGELOG.md`](docs/CHANGELOG.md)。当前主线 **runtime `1.3.25`** · **11 套内置主题**。

## 产品包（终端用户）

```powershell
# 从开发仓打 zip
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\Build-ProductPackage.ps1 -Version 1.3.25

# 解压后安装
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

# 卸载（默认保留用户主题；加 -RemoveState 清 catalog）
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

产物：`dist/CodexDreamSkin-<ver>-win-x64.zip`（含 Install / Uninstall / 11 主题 / runtime / CLI）。

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
- [`CHANGELOG.md`](docs/CHANGELOG.md) — 版本时间线
- [`PAIN-POINTS.md`](docs/PAIN-POINTS.md) — 痛点合集与状态
- [`usage.md`](docs/usage.md) — 使用说明
- [`dual-open-policy.md`](docs/dual-open-policy.md) — 过渡期双开规则
- [`adr/`](docs/adr/) — 架构决策记录（0001 产品线合并 · 0002 上游同步 · 0003 单一版本源）
- [`GLOSSARY.md`](docs/GLOSSARY.md) — 领域术语表
