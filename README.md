# Codexveil

**GitHub：** [xvyimu/Codexveil](https://github.com/xvyimu/Codexveil)  
**产品线（安装态）：** CodexDreamSkin · **开发仓：** `D:\orca\Codexveil`  
**平台：** Windows 10/11 · OpenAI Codex Desktop（Store）  
**许可：** [MIT](./LICENSE) · Copyright (c) 2026 xvyimu  

> **独立产品线**（ADR 0006）：仅 `origin` → 本仓；**无** upstream remote / 无 fork parent。  
> **产品显示名**（开始菜单 / 安装路径 `CodexDreamSkin`）与 GitHub 仓名分离。  
> 身份卡：[GITHUB_IDENTITY.md](./GITHUB_IDENTITY.md)

## 产品方案与文档地图

| 文档 | 用途 |
|------|------|
| [PRODUCT-LAYERS](docs/PRODUCT-LAYERS.md) | L0 身份 · L4 验收命令 |
| [PROJECT](docs/PROJECT.md) | 形态与栈 SSOT · 边界 · 验收 |
| [CONTRIBUTING](CONTRIBUTING.md) | 贡献入口（公开 Issue/PR） |
| [SECURITY](SECURITY.md) | 漏洞报告（勿公开 Issue） |
| [ARCHITECTURE](docs/ARCHITECTURE.md) | 实现映射 · 调用链 |

协作详规与威胁模型长文：[`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) · [`docs/SECURITY.md`](docs/SECURITY.md)。

## 它是什么

统一 **Codex Desktop CDP 换肤** 产品线：单条 watch injector 守护 + 多主题热切换（F6 / 托盘 / CLI）。

| 层 | 说明 | 本仓 |
|----|------|:----:|
| CLI TUI 主题 | 终端 Codex 配色 | 否 |
| 官方 Appearance | Desktop 官方外观 | 否 |
| **CDP Skin** | 经 CDP 注入 CSS/JS | **是 · Windows only** |

## 状态

- 主线 runtime **1.3.25** · 内置主题 **arina-only**（`themes/preset-arina-hashimoto`；扩 catalog 须 ADR）  

- 版本权威：`publish-runtime.ps1 -Version` 写入 `SKIN_VERSION_TOKEN`（ADR 0003）  
- CI：`themes-gate` → `npm test`（**不等于**本机 doctor / live CDP）  
- 架构：[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · 总纲：[`docs/PROJECT.md`](docs/PROJECT.md) · 安全：[`docs/SECURITY.md`](docs/SECURITY.md)

## 目录

```text
apps/launcher          用户入口（薄 PS1 · 含 tray/launch/restore 第一方源）
apps/native/           CodexFastLaunch
packages/core          发现 / CDP / doctor / kick / CLI
packages/themes        schema / catalog / heige→DreamSkin
packages/runtime       watch injector + assets（self-contained 发布）
packages/core-win      PowerShell 共享库
packages/contracts     开发态 TypeScript 契约（ADR 0004）
scripts/windows        发布 / 打包 / 探针
themes/                内置主题源
docs/                  PROJECT · ARCHITECTURE · ADR · 报告
```

## 快速开始（开发）

```powershell
cd D:\orca\Codexveil
node packages/core/cli.mjs help
node packages/core/cli.mjs doctor
npm test
```

安装态入口：开始菜单 / 任务栏 **Codex** → `%LOCALAPPDATA%\Programs\CodexDreamSkin`（**不要**用商店磁贴裸启）。

## 产品包

```powershell
# 维护者打 zip
pwsh -NoProfile -File scripts\windows\Build-ProductPackage.ps1 -Version 1.3.25
# 用户解压后
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

发布到本机开发安装态：

```powershell
pwsh -NoProfile -File scripts\windows\publish-runtime.ps1 -RepoRoot D:\orca\Codexveil -Version 1.3.25
```

## 硬边界

- 单 watch injector；`packages/core` ↔ `packages/runtime` **禁止**互引  
- 安装态 runtime **零第三方 npm**；主题写入只经 `packages/themes`  
- 不改 Codex `.asar` / 不做 macOS 主路径 / 不镜像整棵安装树  

## 关于本项目 / 许可

- **独立产品线**（ADR 0006）：本仓代码与发行以 **Codexveil / CodexDreamSkin** 身份维护；MIT · [LICENSE](./LICENSE) · 说明见 [NOTICE](./NOTICE)。  
- **不**作为任何第三方皮肤仓的 fork 同步副本；本地仅 `origin` → 本仓。  
- 宿主应用为 OpenAI Codex Desktop（第三方）；本项目不主张其商标或程序本体的权利。  
- 身份卡：[GITHUB_IDENTITY.md](./GITHUB_IDENTITY.md)

## 链接

- 仓库：https://github.com/xvyimu/Codexveil  
- 默认 CDP：`9335` · 控制面：`9336`（loopback）  
- 变更记录：[`docs/CHANGELOG.md`](docs/CHANGELOG.md)
