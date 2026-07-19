# codex-skin

统一 Codex Desktop 换肤产品线。

- **日常入口（安装态）**：开始菜单 / 任务栏 **Codex**（走 `%LOCALAPPDATA%\Programs\CodexDreamSkin`）
- **开发仓（本仓库）**：`D:\orca\codex-skin`
- **默认 CDP**：`9335`
- **原则**：只允许一条 injector；DreamSkin 级守护 + heige 级多主题

## 状态

见 [`docs/CHANGELOG.md`](docs/CHANGELOG.md) 里的里程碑与最新 runtime。当前主线 `1.3.15-4b1f91`。

## 架构

详见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

```text
apps/launcher       用户入口（薄，dot-source lib）
packages/core       Node：发现 / CDP / doctor / 常量 / kick + CLI
packages/themes     主题 schema / catalog / heige→DreamSkin 适配
packages/runtime    watch injector + 资源（发布到 versions/，self-contained）
packages/core-win   PowerShell 共享库（launcher-ui / common / theme）
scripts/windows     发布 / 导入主题 / 快捷方式 / 探针
themes/             10 套内置主题源（heige 格式）
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

发布 runtime：

```powershell
powershell -File scripts\windows\publish-runtime.ps1 -RepoRoot D:\orca\codex-skin
```

## 日常使用

1. 点任务栏 **Codex**（启动器 + watch injector）
2. 换肤走统一 CLI `apply --theme` 或托盘「换肤…」

## 文档

- [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) — 目录 · 边界 · 调用链 · 源码映射
- [`CHANGELOG.md`](docs/CHANGELOG.md) — 版本时间线（1.3.1 ~ 1.3.13）
- [`PAIN-POINTS.md`](docs/PAIN-POINTS.md) — 痛点合集与状态
- [`usage.md`](docs/usage.md) — 使用说明
- [`dual-open-policy.md`](docs/dual-open-policy.md) — 过渡期双开规则
- [`adr-0001-merge-product-line.md`](docs/adr-0001-merge-product-line.md) — 产品线合并决策
