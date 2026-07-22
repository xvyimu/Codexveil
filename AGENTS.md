# Codexveil

Codex Desktop 换肤：DreamSkin 启动/守护 + 多主题。Node ≥20，ESM。  
仓：`D:\orca\Codexveil` · 安装态：`%LOCALAPPDATA%\Programs\CodexDreamSkin`  
（与 `CLAUDE.md` **同大纲**；改一处请同步另一处意图。）

## 先读

1. [`docs/PROJECT.md`](docs/PROJECT.md) — **形态与栈 SSOT**（§1.5）· 边界、分层、验收  
2. 改功能：[`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) §C-1 / §C-8  
3. 实现映射：[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)  
4. 归档索引：[`docs/overview.md`](docs/overview.md)（文档地图 / ADR / 审计）  
5. 全局门闩：形态/栈未入档禁业务编码 → Claude `~/CLAUDE.md` §8 · 本机 `principle.md`

## 结构

| 路径 | 职责 |
|------|------|
| `packages/core/` | CLI + CDP/发现/状态 |
| `packages/core-win/` | Windows pwsh 运行时封装 |
| `packages/runtime/` | 注入/元数据/控制面 |
| `packages/themes/` | 主题 schema / store / adapter |
| `packages/contracts/` | 开发态 TS 契约（ADR 0004 · 不进 versions/） |
| `apps/launcher/` | 启动器、切主题、冒烟 · **tray/launch/restore 第一方源** |
| `themes/` | 主题资源 |
| `docs/` | PROJECT / ADR / 痛点；长文见 overview |

## 命令

```bash
npm run doctor | list | status | help
npm run test:themes
npm run test:themes-contracts   # themes normalizeColors ⊂ contracts palette
npm run test:store
npm run test:adapter
npm run test:deps
npm run test:freshness
npm run test:cdp-url
npm run test:catalog-budget
npm run build:contracts
npm run test:contracts
npm test                  # unit + contracts
npm run probe:session     # live CDP DOM probe；不进 npm test
# node packages/core/cli.mjs <cmd>
# pwsh -NoProfile -File scripts/windows/publish-runtime.ps1 -Version 1.3.25
# pwsh -NoProfile -File scripts/windows/write-baseline.ps1
```

启动/发布脚本用 **pwsh**。`rtk` 包装器可选，**非**仓库硬依赖。

## 不可谈判

1. 单产品线、单 watch injector（禁止第二守护路径）  
2. `packages/core` ↔ `packages/runtime` **禁止**双向依赖  
3. 主题写入只经 `packages/themes` + `themes/<id>/`  
4. 版本只认 `publish-runtime.ps1 -Version`（ADR 0003）；产品包只 stamp payload  
5. 独立产品线（ADR 0006）：仅 `origin`；**无** `vendor/` 树；publish 只拷 first-party  

## 不要做

- 不擅自 `git push` / 改 `main`  
- 不新建 `vendor/` 或重建 `upstream` remote  
- 不新建第二套 injector/守护  
- 不主动备份安装态/配置（除非用户要）  
- 不扩 scope 到无关包  

## 完成标准（DoD）

1. 相关测试：`npm test`（主题/依赖变更至少跑触及的 script）  
2. 动到注入/CDP/启动：`npm run doctor` 或既有 smoke 说清结果  
3. diff 小、可说明；残留风险一句  

## 工作约定

- 改主题：`themes/<id>/theme.json` + 资源；改 schema → `npm run test:themes`  
- 注入/CDP：先 doctor/smoke，勿盲改端口发现  
- 维护卡 / 审计 / 痛点：`docs/plans/` · `docs/PAIN-POINTS.md` · 归档见 overview  
- 探针：`probe-session-dom` / `probe-white-flash` / `probe-project-hd`（**不要** ad-hoc probe-dom*）  
