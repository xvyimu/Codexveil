# codex-skin

Codex Desktop 换肤：DreamSkin 启动/守护 + 多主题。Node ≥20，ESM。  
仓：`D:\orca\codex-skin` · 安装态：`%LOCALAPPDATA%\Programs\CodexDreamSkin`  
（与 `CLAUDE.md` 同大纲；改一处请同步另一处意图。）

## 先读

1. `docs/PROJECT.md` — 边界、分层、禁止依赖、验收  
2. 改功能：`docs/CONTRIBUTING.md` §C-1 / §C-8  
3. 实现映射：`docs/ARCHITECTURE.md`

## 结构

| 路径 | 职责 |
|------|------|
| `packages/core/` | CLI + CDP/发现/状态 |
| `packages/core-win/` | Windows pwsh 运行时封装 |
| `packages/runtime/` | 注入/元数据/控制面 |
| `packages/themes/` | 主题 schema / store / adapter |
| `apps/launcher/` | 启动器、切主题、冒烟 · tray/launch/restore 第一方源 |
| `themes/` | 主题资源 |
| `vendor/dreamskin/` | 冻结第三方快照（生产勿 import/ship · NOTICE） |
| `docs/` | PROJECT / ADR / 痛点 / 任务卡 |

## 命令

```bash
npm run doctor | list | status | help
npm run test:themes
npm run test:store
npm run test:adapter
npm run test:deps
npm run test:freshness
npm run test:cdp-url
npm run test:catalog-budget
npm test                  # themes + store + adapter + deps + freshness + cdp-url + catalog-budget
npm run test:control      # 本机 loopback；不进 CI
npm run probe:session     # live CDP DOM probe；不进 npm test
# node packages/core/cli.mjs <cmd>
# pwsh -NoProfile -File scripts/windows/write-baseline.ps1
```

启动/发布用 **pwsh**。若本机配置了 `rtk` 包装器可选用；**非**仓库硬依赖。

## 不可谈判

1. 单产品线、单 watch injector（禁止第二守护）  
2. `core` ↔ `runtime` 禁止双向依赖  
3. 主题只经 `packages/themes` + `themes/<id>/`  
4. 版本只认 `publish-runtime.ps1 -Version`（ADR 0003）  
5. 独立产品线（ADR 0006）：仅 `origin`；无 upstream；`vendor/` 冻结快照、生产禁止 import

## 不要做

- 不擅自 push / 改 main  
- 不把业务修复写进 vendor  
- 不新建第二 injector/守护  
- 不主动备份（除非用户要）  
- 不扩无关 scope

## 完成标准（DoD）

1. 相关 `npm test` / 触及的 script 通过  
2. 动注入/CDP/启动：`npm run doctor` 或 smoke 有结果  
3. 小 diff + 残留风险一句

## 工作约定

- 改主题：`themes/<id>/theme.json`；改 schema → `npm run test:themes`  
- 注入/CDP：先 doctor/smoke  
- 任务卡 / 审计 / 痛点：`docs/plans/` · `docs/AUDIT-*.md` · `docs/PAIN-POINTS.md`（以最新为准）
