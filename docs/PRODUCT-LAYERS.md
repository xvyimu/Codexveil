# Codexveil · 产品分层方案（PRODUCT-LAYERS）

> **组合总纲：** `D:\orca\.planning\portfolio-product-docs-program-2026-07-23\PORTFOLIO-PRODUCT-PROGRAM.md`  
> **形态与栈 SSOT：** [`PROJECT.md`](./PROJECT.md)  
> **tip：** `ff42fbe` · 视觉 V3 = **文档 DEFER arina-only**（见 `design/atelier-v3-matrix.md`）

---

## L0 · 产品身份

| 项 | 内容 |
|----|------|
| **一句话** | **Codex Desktop 换肤产品线**：DreamSkin 启动/守护 + 主题资源（当前目录 **仅 arina**）。 |
| **核心问题** | 在不改 Codex asar 安装树的前提下，提供可维护的换肤与守护体验。 |
| **主用户** | **本机 Codex Desktop 用户**（Windows 为主） |
| **明确不做** | 第二 injector/守护 · 改 Codex asar · 多主题目录膨胀（产品决议 arina-only）· Startup 强行自启（当前 off） |
| **价值** | first-party 启动/托盘 · 契约与 doctor · 可发版 runtime 版本钉 |

---

## L1 · 形态与栈

见 PROJECT / ARCHITECTURE：Node ESM monorepo · packages/core|runtime|themes|contracts · apps/launcher。

---

## L2 · 运行与边界

| 项 | 内容 |
|----|------|
| 开发仓 | `D:\orca\Codexveil` · 入口 `D:\projects\Codexveil` |
| 装态 | `%LOCALAPPDATA%\Programs\CodexDreamSkin`（显示名与 GitHub 可分离） |
| 版本 | `publish-runtime.ps1 -Version`（ADR 0003） |
| 红线 | **禁止** asar 镜像植入 · 无 `vendor/` 树 · 仅 `origin` |

---

## L3 · 架构与扩展

| 包 | 职责 |
|----|------|
| core | CLI · CDP/发现/状态 |
| runtime | 注入/元数据/控制面 |
| themes | schema/store/adapter · `themes/<id>/` |
| contracts | 开发态 TS 契约（不进 versions/） |
| launcher | 启动/切主题/托盘 **第一方源** |
| **禁止** | core↔runtime 双向依赖 · 第二套守护路径 · 主题写入绕 themes 包 |

---

## L4 · 验收与质量

| 命令 | 用途 |
|------|------|
| `npm test` | unit + contracts |
| `npm run doctor` / smoke | 注入/CDP 相关 |
| `npm run test:themes` 等 | 主题与契约 |

发版：publish 脚本 + 装态探针；**不**把密钥写入仓。

---

## L5 · 协作与合规

| 项 | 内容 |
|----|------|
| 许可 | **MIT** |
| 安全 | 根 `SECURITY.md` · docs 威胁模型 |
| 贡献 | 根 [`CONTRIBUTING.md`](../CONTRIBUTING.md) · 详规见 `docs/CONTRIBUTING.md`（若存在） |

---

## L6 · 路线图与维护

| 周期 | 内容 |
|------|------|
| 近 | arina 体验与 doctor 稳定 · 文档矩阵保持 |
| 中 | contracts 扩圈 · 注入边界硬化 |
| 远 | 若产品决议开放主题：单独 ADR + catalog 门闩 |
| 安全/性能 | CDP 面最小权限 · 无第二注入路径 |

---

## 文档地图

PROJECT · ARCHITECTURE · overview · design-tokens · design/atelier-v3-matrix · ADR 0003–0006 · PAIN-POINTS
