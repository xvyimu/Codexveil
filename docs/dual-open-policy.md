# 双开策略与入口纪律

> 1.3.15 起产品线只有 **一条** watch injector。本文件约定「日常入口唯一」与历史 heige 的边界。

## 规则（现行）

1. **日常入口唯一**：任务栏 / 开始菜单 / 桌面 **Codex**（或 ChatGPT）→ `CodexFastLaunch.exe` → 安装态 open 脚本 → watch injector  
2. **injector 唯一**：`packages/runtime/scripts/injector.mjs --watch`（安装态 `versions/<id>/scripts/injector.mjs`）  
3. **主题写入唯一**：`packages/themes` → `active-theme`；CLI `apply --theme` 只走 kick  
4. **禁止第二套注入**：旧 heige `--once` / legacy-inject 已删除；勿从别处再起 CDP 注入  

## 入口分层（PAIN #18）

| 层 | 入口 | 谁用 |
|----|------|------|
| 日常 | Codex · ChatGPT · Codex 换肤 | 所有人 |
| 工具 | 开始菜单 **Codex 工具**（皮肤修复 / 商店更新后修复 / 使用说明） | 出问题再进 |
| 开发 | `node packages/core/cli.mjs …` · `publish-runtime.ps1` | 维护者 |

`install-ux-shortcuts.ps1` 是快捷方式**唯一源**；`refresh-shortcuts.ps1` 仅转发。

## heige 残留（PAIN #20）

| 位置 | 状态 |
|------|------|
| 本仓 `packages/` | heige 能力已吸收（schema / store / adapter）；**无**独立 heige 进程入口 |
| 本仓 `vendor/heige/` | **已删除** |
| 本仓 `packages/legacy-inject/` | **已删除**（1.3.15） |
| 用户开始菜单 / 桌面名含 `heige` / `Codex Studio` 的 lnk | `install-ux-shortcuts` 会删 |
| 本机 `%LOCALAPPDATA%\Programs` 下独立 heige 安装目录 | 本机扫描为空则无需处理；若存在请手动卸/删，避免双开诱惑 |

检测：`doctor` 的 `dreamSkin.summary` / `dailyEntry`；应看到日常入口为 CodexDreamSkin。

## 商店磁贴裸启（PAIN #21 · OS 硬限）

微软商店包激活走 `OpenAI.Codex_…!App` AUMID，**不能**被第三方改写 Target。

- FastLaunch 使用独立 AUMID `CodexDreamSkin.FastLaunch`，避免任务栏把我们的钉归组回商店包  
- 无法阻止用户点商店磁贴本身  
- 文档与 `usage.md` 明确：**日常只用任务栏钉 / 开始菜单 Codex**  

缓解（已做）：

1. 任务栏 / 桌面 / 开始菜单 Codex → FastLaunch  
2. open 路径发现「裸 Codex」时安静 reattach / 必要时重启带 CDP  
3. post-update 重绑快捷方式  

## 历史调试开关

- `--force-dual-open`：**已移除**（1.3.15）  
- 需要暂停皮肤：托盘暂停，或写 `%LOCALAPPDATA%\CodexDreamSkin\paused`  

## 相关

- [`usage.md`](./usage.md) — 用户侧入口表  
- [`PAIN-POINTS.md`](./PAIN-POINTS.md) — #18 / #20 / #21  
- ADR 0001 — 产品线合并  
