# codex-skin

Codex Desktop 换肤：DreamSkin 启动/守护 + 多主题引擎。Node ≥20，ESM。

## 结构

| 路径 | 职责 |
|------|------|
| `packages/core/` | CLI + CDP/发现/状态（跨平台逻辑） |
| `packages/core-win/` | Windows PowerShell 运行时封装 |
| `packages/runtime/` | 注入/元数据/控制面脚本 |
| `packages/themes/` | 主题 schema / store / adapter |
| `apps/launcher/` | 启动器、切换主题 UI、冒烟 |
| `themes/` | 主题资源（`theme.json` + hero 图） |
| `vendor/dreamskin/` | 上游 DreamSkin 脚本与资产 |
| `docs/` | usage / ADR / 痛点 |

## 常用命令

```bash
npm run doctor
npm run list
npm run status
npm run help
npm run test:themes
npm run test:deps
npm run test:control   # 本机 loopback；不进 CI
npm test
# 等价: node packages/core/cli.mjs <cmd>
```

## 约定

- **先读** [`docs/PROJECT.md`](docs/PROJECT.md)：边界、分层、依赖禁止项、验收门禁、Agent 任务模板
- **PR / 规范**：[`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)（§C-1 模块依赖 7 问 · §C-8 禁止速查表）
- **维护任务卡**：[`docs/plans/task-cards-2026-07-21.md`](docs/plans/task-cards-2026-07-21.md) · 提示词 [`docs/prompts/agent-maintain-task-cards-zh.md`](docs/prompts/agent-maintain-task-cards-zh.md)
- 全面检查基线：[`docs/AUDIT-2026-07-20.md`](docs/AUDIT-2026-07-20.md)
- 残差规划（CI / mac / #21 / Quiet）：[`docs/plans/residual-g1-g3-g4-g5-2026-07-20.md`](docs/plans/residual-g1-g3-g4-g5-2026-07-20.md)
- 改主题：`themes/<id>/theme.json` + 资源；注册见 `packages/themes/`；改 schema 跑 `npm run test:themes`
- Windows 启动路径优先 `apps/launcher/*.ps1`（用 **pwsh**）
- 注入/CDP 相关改动先跑 `doctor` / 既有 smoke，勿盲改端口发现
- 硬性禁止：`core ↔ runtime` 互依赖、第二**守护**路径、生产 import `vendor/`（kick 的 injector `--once` 单次降级除外，见 dual-open-policy）
- 详见 `docs/ARCHITECTURE.md`、`docs/usage.md`、`docs/PAIN-POINTS.md`、`docs/adr/`
