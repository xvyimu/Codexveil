# ADR 0005 — 薄产品壳（U3 · 一页纸）

## Context

- 长文：`docs/adr/0005-thin-product-shell-u3.md`（Proposed · 2026-07-21）
- 本页：**工作快照**，不替代长文；用于决策回顾与触发条件审计

### 核心问题

同类产品（Codex-NN、Styler、Jason Theme Studio）提供桌面 GUI 做主题切换/预览/导入，**降低脚本恐惧**。本仓差异化是 **Windows 运行时守护**，不是 Creator IDE。用户表单选择 U1+U3：在工程现代化（U1 · ADR 0004）之后，增加 **薄产品壳**，**明确不替换** `injector --watch`。

### 与前驱 ADR 的关系

| ADR | 关系 | 边界 |
|-----|------|------|
| 0001（产品线合并） | 前置 | 单产品线单 injector 纪律已奠定 |
| 0003（单一版本源） | **兼容** | 壳取版本号仍从 publish `-Version`；壳可独立版本号 |
| 0004（工程现代化） | **前置** | contracts 面 + control/doctor 类型 + kick 客户端可测后才起壳 |
| 0006（独立 origin） | **兼容** | 壳本身是 first-party 模块，不引入第三方 remote |

## Decision

### D1. 壳与核分离

```
[Tauri/L1 壳] --HTTP/IPC--> [control-plane 9336 + CLI] --kick--> [watch injector L4]
                禁止：壳内再起第二套 CDP 长驻注入器
```

| 组件 | 允许 | 禁止 |
|------|------|------|
| **壳（U3）** | 列表主题、apply、预览缩略图、打开 doctor 摘要、导入主题目录/zip | 自建 watch CDP 守护、绕过 token、改 asar |
| **核（现 runtime）** | 唯一页面注入与 reattach | 被壳进程生命周期 bind 死（壳退出 ≠ 卸皮，除非用户显式 restore） |

### D2. 技术选型（默认）

- **Tauri 2** + 前端轻量（React/Svelte/Solid 三选一，实施时定；优先包体与安全默认值）
- 调用面：优先 **已有** control-plane + `cli.mjs`；若需新 API，先扩 contracts（0004）再实现
- 分发：可选便携 zip；**Authenticode 不绑定 MVP**

### D3. 平台与安全

- **Windows 第一**；macOS 壳不在本 ADR 范围
- 壳不读对话、不读 API key
- 主题导入走 **同核校验**（schema/对比度/路径），不在壳内 `eval`
- 若壳起本地 HTTP：仅 `127.0.0.1` + 短命 token

### D4. 与 U1 的顺序

1. **0004** 至少完成：contracts 初版 + control/doctor 类型 + kick 客户端可测
2. 再脚手架 Tauri 调 `apply`/`list`/`doctor`
3. stamp/probe-kit 可并行，不阻塞壳的只读管理功能

## 非强制主路径的边界

| 边界 | 说明 |
|------|------|
| **当前状态** | Proposed — 壳**不**是产品默认入口；托盘/F6/CLI 仍是第一方路径 |
| **升 Accepted 触发条件** | 见下文「升 Accepted 触发条件」 |
| **壳不阻塞核心功能** | 无壳时 `doctor`/`apply`/`list`/`kick` 全部正常 |
| **壳不扩大 injector 面** | 不存在壳内第二条 CDP 注入路径 |
| **壳独立版本号** | 不影响 runtime 的 ADR 0003 版本线 |
| **壳退出 ≠ 卸皮** | 不破坏 restore 语义 |

### 升 Accepted 触发条件

以下 **全部满足** 时可升 Accepted：

1. ADR 0004（工程现代化）至少 contracts 初版 + control/doctor 类型 **已实施并合并**
2. 有明确实施计划（脚手架、MVP 范围、验收）
3. 薄壳与现有 CLI/托盘路径 **共存方案**（不抢默认入口）已文档化
4. 团队确认 **不引入第二 injector 路径** 的纪律已写入壳的 CI 门禁
5. 壳的 MVP 功能清单冻结（禁止范围膨胀成 Styler）

## Consequences

### 正面

- L1 体验接近竞品管理器，**不放弃零第二守护纪律**
- 壳可独立版本号；runtime 线仍 0003
- 壳退出不影响主题持续生效

### 权衡 / 代价

| 代价 | 缓解 |
|------|------|
| Rust/Node 双工具链 | 壳仓可 `apps/shell` 隔离；文档分受众 |
| 包体与 SmartScreen | 文档「仍要运行」；可选后续签名 |
| 范围膨胀成 Styler | MVP 清单冻结；伴侣/AI 生成 **Out** |

### 非目标

- 窗内 F6 完整 catalog 热循环（#25 另卡）
- 主题市场、账号系统
- 2GB 安装树镜像
- 替换 publish-runtime 为「仅 GUI 发布」

## Status

**Proposed**（与本目录长文一致）

---

*本页是 ADR 0005 的工作快照，维护于 2026-07-26。完整背景与讨论见 `0005-thin-product-shell-u3.md`。*