# codex-skin 项目文档

> **产品**：统一 Codex Desktop 换肤产品线（DreamSkin 守护 + heige 多主题）  
> **仓库**：https://github.com/xvyimu/Codex-Dream-Skin  
> **开发仓**：`D:\orca\codex-skin`  
> **安装态**：`%LOCALAPPDATA%\Programs\CodexDreamSkin`  
> **当前主线**：runtime `1.3.25` · HEAD 以 `git rev-parse HEAD` 为准（全面检查见 [`AUDIT-2026-07-20.md`](./AUDIT-2026-07-20.md)）  
> **文档原则**：先约束，后生成｜先架构，后界面｜先验证，后合并  
> **适用**：Agent / 开源工具 / AI 辅助开发协作

---

## 0. 读这份文档的方式

| 角色 | 先读 | 再读 |
|------|------|------|
| 新人上手 | §1 产品边界 · §2 分层 | §7 开发命令 · §9 验收 |
| 改功能 | §3 模块契约 · §4 依赖规则 | §5 关键路径 · §8 任务模板 |
| 发版 | §6 发布与版本 | ADR 0003 · CHANGELOG |
| 同步上游 | ADR 0002 · §10 上游 | `docs/upstream-sync.json` |
| 排查故障 | §11 诊断矩阵 · PAIN-POINTS | `doctor` / smoke |

**相关文档索引**

| 文档 | 职责 |
|------|------|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | 目录、调用链、源码映射（实现侧） |
| [`AUDIT-2026-07-20.md`](./AUDIT-2026-07-20.md) | 全面检查报告（边界 · 模块 · 发现项 · hygiene） |
| [`plans/residual-g1-g3-g4-g5-2026-07-20.md`](./plans/residual-g1-g3-g4-g5-2026-07-20.md) | 残差 G1/G3/G4/G5 多方案对比与推荐组合 |
| [`CHANGELOG.md`](./CHANGELOG.md) | 版本时间线 |
| [`PAIN-POINTS.md`](./PAIN-POINTS.md) | 已知痛点与状态 |
| [`GLOSSARY.md`](./GLOSSARY.md) | 领域术语 |
| [`design-tokens.md`](./design-tokens.md) | 视觉 CSS 变量 · 主题调色约定 |
| [`SECURITY.md`](./SECURITY.md) | 威胁模型 · 报告渠道 · 在/出范围 |
| [`usage.md`](./usage.md) | 用户侧使用说明 |
| [`dual-open-policy.md`](./dual-open-policy.md) | 入口纪律与 kick 降级 |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | PR 必答 7 问 · 8 类规范 · 禁止事项速查表 |
| [`plans/task-cards-2026-07-21.md`](./plans/task-cards-2026-07-21.md) | 维护任务卡（P1–P3） |
| [`prompts/agent-maintain-task-cards-zh.md`](./prompts/agent-maintain-task-cards-zh.md) | 维护 Agent 可粘贴提示词 |
| [`research/2026-07-21-peer-landscape-and-architecture.md`](./research/2026-07-21-peer-landscape-and-architecture.md) | 同类项目对照 · 技术债 · 架构优化调研（长文） |
| [`research/2026-07-21-github-peer-matrix.md`](./research/2026-07-21-github-peer-matrix.md) | GitHub 细矩阵 · C/D/E 分层 |
| [`adr/0004-engineering-modernization-u1.md`](./adr/0004-engineering-modernization-u1.md) | **Accepted** 工程现代化 / 依赖双平面 · 实施中 |
| [`adr/0005-thin-product-shell-u3.md`](./adr/0005-thin-product-shell-u3.md) | **Proposed** 薄产品壳（不替换守护） |
| [`plans/u1-u3-two-week-plan-2026-07-21.md`](./plans/u1-u3-two-week-plan-2026-07-21.md) | U1+U3 两周排期 |
| [`research/2026-07-21-progress-aligned-debt-and-portfolio.md`](./research/2026-07-21-progress-aligned-debt-and-portfolio.md) | 进度对齐：已关债 · 多方案组合 · 打磨卡片（长文） |
| [`research/2026-07-21-integrated-master-research.md`](./research/2026-07-21-integrated-master-research.md) | 整合总册（中期） |
| [`research/2026-07-21-master-research-v2-frozen.md`](./research/2026-07-21-master-research-v2-frozen.md) | 选代入口 v2（四包后） |
| [`research/2026-07-21-master-research-v3-ux-visual.md`](./research/2026-07-21-master-research-v3-ux-visual.md) | 选代入口 v3：工程冻结 + UX/视觉升级方案库 |
| [`research/2026-07-21-master-research-v4-u3u4-product.md`](./research/2026-07-21-master-research-v4-u3u4-product.md) | 选代入口 v4：U3/U4 后进度 + 五件套 + 方案评分 |
| [`research/2026-07-21-master-research-v5-visual-sync-and-next.md`](./research/2026-07-21-master-research-v5-visual-sync-and-next.md) | **选代入口 v5**：闪白修后 · ahead 交付 · 市场/架构/规范/路线图/API + 方案评分 |
| [`adr/`](./adr/) | 架构决策（0001 合并 · 0002 上游 · 0003 版本源） |
| 根目录 `CLAUDE.md` | Agent 短索引 |

---

## 1. 产品边界

### 1.1 解决什么问题

给 OpenAI **Codex Desktop**（Electron / Store 包）换皮肤：背景图、品牌字、主题色、多主题热切换，且不破坏官方签名与安装包。

### 1.2 本版本做 / 不做

| 做 | 不做 |
|----|------|
| 一条 injector 常驻守护（watch） | 修改 Codex `.asar` / 安装包 |
| CDP 注入 CSS/JS（默认端口 9335） | **macOS / 跨平台主路径**（永久非目标；上游有，本 fork **Windows only**） |
| 多主题 catalog + F6 / 托盘 / CLI 切换 | 商店磁贴/AUMID 裸启拦截（OS 限制 · #21） |
| 控制面 `/kick` 毫秒级热应用 | 多 injector 并行 |
| publish 自包含 `versions/<id>/` | 自动 merge 上游（结构已分叉） |
| doctor / smoke / verify · CI `test:themes` | 把 UI 皮肤逻辑塞进 `packages/core` |

**本仓 = CDP Skin（Windows only）**，不是 CLI TUI 主题串，也不是官方 Appearance。三层对照与链接见根目录 [`README.md`](../README.md)「三层 Codex 换肤」。

### 1.3 用户与入口

| 入口 | 路径 | 谁用 |
|------|------|------|
| 日常 | 任务栏 / 开始菜单 **Codex** → 安装态 launcher | 终端用户 |
| 开发 CLI | `node packages/core/cli.mjs <cmd>` | 开发 / Agent |
| 换肤 | 托盘「换肤…」· F6 · `apply --theme` | 用户 / 自动化 |
| 发布（开发） | `scripts/windows/publish-runtime.ps1 -Version` | 维护者 · 写回 git tree 版本 |
| 产品 zip | `Build-ProductPackage.ps1` → `Install.ps1` | 终端用户分发 · 只 stamp 包内/安装态 |

### 1.4 成功标准（产品级）

1. Codex 运行时，皮肤可见且与 active-theme 一致。  
2. 换肤体感 < 100ms 量级（kick 路径，非冷启动）。  
3. 任意时刻只允许 **一条** watch injector。  
4. 安装态 runtime 与 `current.json` 对齐；`doctor` 报告 `injectorPathFreshness.fresh=true`。  
5. 改动能回退：publish GC 保留 current + 上一版；git 可审查。

---

## 2. 架构总览（优化后分层）

### 2.1 四层模型（映射 Vibe Coding Agent 分层）

手册要求：`交互层 → 调度层 → 记忆层 / 执行层`。本项目落地为：

```text
┌─────────────────────────────────────────────────────────────┐
│ L1 交互层  Interaction                                        │
│  apps/launcher/*.ps1 · 托盘 · F6 · 快捷方式 · CLI 用户命令     │
│  负责：入口、展示、用户意图                                     │
│  不负责：主题写入细节、CDP evaluate、进程守护算法               │
└────────────────────────────┬────────────────────────────────┘
                             │ 只调相邻层接口
┌────────────────────────────▼────────────────────────────────┐
│ L2 调度层  Orchestration                                      │
│  packages/core/cli.mjs · packages/core-win/launcher-ui.ps1    │
│  control-plane (/kick /health /focus /open-healthy)           │
│  负责：编排、权限/守卫、路由到写主题或 kick                     │
│  不负责：CSS 内容、主题 schema 解析内部规则                     │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
┌───────────────▼───────────────┐  ┌──────────▼────────────────┐
│ L3a 记忆/状态层  State         │  │ L3b 主题领域  Themes       │
│ state.json · current.json     │  │ packages/themes/*          │
│ active-theme · paused         │  │ theme-schema / store       │
│ control.port · browserId      │  │ dream-adapter              │
│ 负责：持久状态、新鲜度、守卫   │  │ 负责：schema、catalog、适配 │
│ 不负责：决定注入策略           │  │ 不负责：CDP / 进程启动      │
└───────────────┬───────────────┘  └──────────┬────────────────┘
                │                             │
                └──────────────┬──────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ L4 执行层  Runtime / Effect                                    │
│  packages/runtime（watch injector · assets · wait-shell）     │
│  packages/core/{cdp,discover}（探测、会话，无副作用写入主题）  │
│  负责：CDP 注入、shell 等待、缩略图、payload 组装              │
│  不负责：对话式编排、主题业务规则、快捷方式安装                 │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 与手册四准则的对齐

| 准则 | 本项目落地 |
|------|------------|
| Git 从第一天 | `main` 稳定；功能/修复走分支；合并前 doctor + smoke |
| 先定规范再写码 | 本文档 + ARCHITECTURE + ADR + 包 `index.mjs` 边界注释 |
| 架构优先于 UI | 先保证 injector 单路径 / 包边界，再改 CSS 观感 |
| 与成熟实践校准 | 上游 Fei-Away 视觉线；heige 主题模型；Electron CDP 惯例 |

### 2.3 架构优化目标（相对历史双产品线）

| 历史问题 | 优化决策 | 状态 |
|----------|----------|------|
| DreamSkin / heige 双开互盖 | 单产品线 + 单 injector（ADR 0001） | 完成 |
| 注入多路径（watch + `--once`） | watch-only（1.3.15） | 完成 |
| 版本 5 处硬编码 | 单一版本源 token（ADR 0003） | 完成 |
| 文档碎片 25 份 | 合并为 ARCHITECTURE / CHANGELOG / … | 完成 |
| 上游无法 merge | vendor 镜像 + 人工 promote（ADR 0002） | 完成 |
| 包职责混杂 | core / themes / runtime / core-win 拆包 | 完成 |
| kick 走 spawn 慢 | control-plane `/kick` ~45ms | 完成 |

**仍待优化（见 §12 路线图）**：Store 磁贴裸启为 OS 硬限（#21，已文档化，无法代码消除）；其余 #18/#20 与 CHANGELOG 版号已收敛。

---

## 3. 模块契约（框架限定）

### 3.1 包一览

| 包 | 语言 | 依赖方向 | 职责 | 明确非职责 |
|----|------|----------|------|------------|
| `packages/core` | Node ESM | **无 npm**；不依赖 runtime | 发现 Codex、CDP 客户端、常量、doctor、kick 调用、守卫诊断 | 写 active-theme；页面 CSS 注入；托盘 UI |
| `packages/themes` | Node ESM | → core（常量）；动态 → runtime/thumb | schema 校验、catalog 列表、heige→DreamSkin 适配与写入 | 启动进程；CDP evaluate |
| `packages/runtime` | Node ESM + assets | **自包含**，不依赖 core | watch injector、control-plane、CSS/JS 资源、wait-shell、thumb | 主题业务规则；快捷方式；CLI 用户命令解析 |
| `packages/core-win` | PowerShell 5.1 | 无 | launcher 共享库：日志/托盘/焦点/state IO/runtime 解析 | 主题 schema；CDP 协议实现 |
| `apps/launcher` | PowerShell | dot-source core-win | 薄入口：open / check / switch / smoke / kick | 业务算法（只编排） |
| `themes/` | JSON + 图 | 无 | 内置主题源（heige 格式） | 运行时逻辑 |
| `scripts/windows` | PS / mjs | 读仓库 | publish、import、sync 上游、探针 | 常驻守护 |
| `vendor/dreamskin` | 上游快照 | 只读 | 上游资产镜像 | 任何运行时引用（禁止直接 import 进生产路径） |

### 3.2 硬性依赖规则（框架限定 · 违反即拒合）

```text
允许：
  apps/launcher        → packages/core-win
  packages/core/cli    → packages/core/* · packages/themes/*
  packages/themes      → packages/core/constants（及路径常量）
  packages/themes      → packages/runtime/scripts/thumb.mjs（动态，仅生成缩略图）
  publish              → 复制 packages/runtime → versions/<id>/

禁止：
  packages/core        → packages/runtime     （破坏 runtime 自包含）
  packages/runtime     → packages/core        （发布后 versions/ 无 core 包）
  packages/core        → 直接写 active-theme  （必须经 themes 适配器）
  业务脚本硬编码绝对路径（必须 resolveStudioPaths / Get-CodexSkin*Root）
  第二条 heige --once / legacy-inject 注入旁路
  同时运行两个 injector
  生产路径 import vendor/dreamskin
```

**依赖双平面（ADR 0004 Accepted）**

| 平面 | 规则 |
|------|------|
| **安装态 runtime**（`versions/<id>/`） | 默认 **零第三方 npm**；打进用户机的脚本须自包含 |
| **开发 / CI** | 允许 TypeScript、Vitest、Zod、pnpm workspace 等（见根 `package.json` devDependencies） |

`test:deps` 继续守护 core↔runtime **静态互引**；不等于「仓库不得有 node_modules」。

### 3.3 各包公开接口（稳定面）

#### `packages/core`（见 `index.mjs`）

| 导出簇 | 代表符号 | 调用方 |
|--------|----------|--------|
| 常量/路径 | `DEFAULT_CDP_PORT`, `resolveStudioPaths`, `PRODUCT_ID` | cli · themes |
| 发现/诊断 | `discoverCodex`, `runtimeDiagnostics`, `probeCdpPort` | doctor · status |
| 守卫 | `detectDreamSkinRuntime`, `shouldBlockApplyForDreamSkin` | doctor（诊断） |
| CDP | `CdpSession`, `fetchRendererTargets`, … | 探针 / 高级工具 |
| kick | `kickThemeInjectNow` | cli apply |
| 新鲜度 | `inspectInjectorPathFreshness` | doctor |

#### `packages/themes`

| 导出 | 作用 |
|------|------|
| `loadTheme` / `validateThemeManifest` | 读并校验 theme.json |
| `listThemes` / `createSingleImageTheme` | catalog 列表与创建 |
| `writeActiveThemeFromHeige` | 热切换写入 active-theme |
| `importHeigeThemeToCatalog` / `importAllBundledThemes` | 导入内置主题 |
| `heigeManifestToDreamSkin` | 格式适配 |

#### `packages/runtime`（发布面，非 Node import 面）

| 路径 | 作用 |
|------|------|
| `scripts/injector.mjs` | `--watch` 常驻 / `--verify` |
| `scripts/control-plane.mjs` | loopback HTTP |
| `assets/dream-skin.css` | 注入 CSS |
| `assets/renderer-inject.js` | 页面桥（CSS 变量、brand、art） |
| `scripts/wait-shell.mjs` | 冷启动等待 |
| `scripts/thumb.mjs` | 缩略图 |

#### `packages/core-win` 命名规约

- 历史：`DreamSkin-*` 前缀（迁入代码）  
- 新增：`CodexSkin-*` 前缀  
- **不做批量改名**（安装态 dot-source 稳定优先）

### 3.4 主题数据契约（schema 级）

```text
themes/<id>/
  theme.json     # schemaVersion=1 · id · name · palette · art · image …
  hero.webp|jpg  # 主视觉
  （可选 thumb）

安装态：
  %LOCALAPPDATA%\CodexDreamSkin\active-theme\   # 当前生效
  %LOCALAPPDATA%\CodexDreamSkin\themes\<id>\     # catalog（缩略图控制 payload）
```

**字段关键点**（实现以 `theme-schema.mjs` 为准）：

- `palette.accent|secondary|surface|text`：绑定 CSS 变量  
- `art.focusX/focusY/safeArea/taskMode`：构图安全区  
- `brandSubtitle` / `tagline`：左上品牌（空 tagline 不渲染）  
- `image`：相对主题目录的文件名  

**payload 预算**：CDP evaluate ~4MB；catalog **只嵌缩略图**，全图走 active-theme data URL 通道。

---

## 4. 运行时数据与端口

| 资源 | 路径/值 | 所有者 |
|------|---------|--------|
| programRoot | `%LOCALAPPDATA%\Programs\CodexDreamSkin\` | publish / launcher |
| current.json | programRoot 下 | publish 翻页 |
| versions/\<runtimeId\> | programRoot 下 | publish |
| stateRoot | `%LOCALAPPDATA%\CodexDreamSkin\` | injector / launcher |
| state.json | stateRoot | injector 更新 pid/port/browserId |
| controlPort | 默认 **9336**（写入 state + `control.port`） | control-plane |
| control.token | stateRoot 下；POST `/kick` `/focus` `/open-healthy` 必带 header `x-codex-skin-token`（GET `/health` 免 token） | control-plane · kick-inject · Invoke-CodexSkinControl |
| CDP | 默认 **9335** | Codex `--remote-debugging-port` |
| active-theme | stateRoot\active-theme | themes 写入 · runtime 读取 |
| paused | stateRoot\paused 文件存在即暂停 | 用户/托盘 |
| state.json | **schemaVersion 3**（launcher-ui 写出；读接受 1..3） | injector / doctor |
| current.json | **schemaVersion 1**（runtime 指针） | publish / Install |

**runtimeId 格式**：`<semver>-<hash6>`，例 `1.3.18-118f81`。

---

## 5. 关键路径（行为可预期）

### 5.1 冷启动（用户点 Codex）

```text
Codex.lnk
  → open-codex-dream-skin.ps1
  → launcher-ui（安静 UI / 托盘 / 焦点）
  → 读 current.json → versions/<id>/scripts/injector.mjs --watch
  → 发现/启动 Codex（带 CDP 9335）
  → wait-shell → attach browserId
  → control-plane 起 9336
  → 读 active-theme → 注入 CSS/JS
  → 写 state.json
```

**失败行为**：

| 失败点 | 预期 |
|--------|------|
| 找不到 Codex | doctor/appFound=false；launcher 报错可诊断 |
| CDP 未开 | 短重试 + 超时；必要时 full open |
| 已有 injector | 单实例策略；禁止双开 |
| payload 过大 | 注入失败可观测；catalog 必须缩略图 |

### 5.2 热换肤（CLI / 托盘）

```text
cli apply --theme <id>
  → themes.writeActiveThemeFromHeige
  → 更新 active-theme 文件戳
  → core.kickThemeInjectNow → POST http://127.0.0.1:9336/kick
  → watch 重 apply（~45ms）
  → kick 未命中时再降级（若有）spawn 路径（应少见）
```

### 5.3 发布

```text
publish-runtime.ps1 -RepoRoot D:\orca\codex-skin [-Version x.y.z]
  → 拷 packages/runtime → versions/<id>/
  → stamp SKIN_VERSION_TOKEN（源 + 副本）
  → 同步 core-win → lib\ + versions scripts
  → 同步入口 open/check/switch/smoke
  → current.json 翻页 + .bak
  → GC：仅留 current + 上一版
  → 刷新快捷方式
  → （可选）import themes / post-update
```

### 5.4 上游同步（不自动进生产）

```text
sync-upstream-assets.ps1
  → 刷新 vendor/dreamskin 镜像
  → 打印 assets diff 摘要
  → 列出上游 PS 相关 commit 标题
  → 人决定是否 promote 到 packages/runtime/assets
  → 更新 docs/upstream-sync.json 基线
```

---

## 6. 版本与发布策略

遵循 **ADR 0003 单一版本源**：

- 权威：`publish-runtime.ps1 -Version`  
- 源文件使用 `SKIN_VERSION_TOKEN = "__SKIN_VERSION__"`，publish 替换  
- 未 stamp 时 `SKIN_VERSION = "dev"`  
- verify 必须 `version === expectedVersion`  

**发版检查清单**

完整勾选见 [RELEASE-EVIDENCE.md](./RELEASE-EVIDENCE.md)。

- [ ] 分支干净或明确 WIP 说明  
- [ ] `node packages/core/cli.mjs doctor` 关键字段正常  
- [ ] `publish-runtime.ps1` 成功，`current.json` 指向新 runtimeId  
- [ ] `injectorPathFreshness.fresh === true`  
- [ ] smoke `SMOKE_PASS`  
- [ ] （有 Codex 运行时）`apply --theme` + kick 成功  
- [ ] CHANGELOG 记一节  
- [ ] 需要时 push `main` / tag  

---

## 7. 开发命令

```powershell
cd D:\orca\codex-skin

# 诊断
node packages/core/cli.mjs doctor
node packages/core/cli.mjs list
node packages/core/cli.mjs status
node packages/core/cli.mjs help

# 热切换（需 injector 存活；Codex 可后开）
node packages/core/cli.mjs apply --theme genshin-night

# 导入内置主题到用户 catalog
node packages/core/cli.mjs import-themes

# 发布
powershell -File scripts\windows\publish-runtime.ps1 -RepoRoot D:\orca\codex-skin

# 上游只读同步
powershell -File scripts\windows\sync-upstream-assets.ps1
```

**Shell 约定**：Windows 脚本优先 **pwsh / PowerShell 7**；安装态兼容 5.1 的 launcher 保持可运行。

---

## 8. 给 AI / Agent 的任务模板

```text
目标：
完成范围：
不做的事：
涉及模块与边界：（只改 L? / packages/? ）
现有接口/数据结构：
实现要求：
  - 遵守 docs/PROJECT.md §3 依赖规则
  - 不新增注入旁路
  - 路径走 resolveStudioPaths / Get-CodexSkin*
验收标准：
验证命令：
  node packages/core/cli.mjs doctor
  （如改 runtime）publish + smoke
  （如改主题）apply --theme <id>
```

**示例**

```text
目标：为新主题 wuthering-xxx 补 accent 绑定
完成范围：themes/wuthering-xxx + 必要时 dream-adapter 字段透传
不做的事：不改 injector 注入调度；不改 CDP 端口逻辑
涉及模块：L3b packages/themes · themes/ 资源
验收：list 可见；apply 后品牌字颜色= palette.accent
验证：doctor · list · apply --theme wuthering-xxx
```

---

## 9. 验收标准（完成定义）

### 9.1 通用

1. **边界明确**：依赖方向符合 §3.2，无跨层直连 / 循环依赖。  
2. **模块单一**：一个 PR 只解决一类问题；无关重构拆开。  
3. **行为可预期**：正常 / 异常 / 边界有定义；失败可追踪。  
4. **可审查可回退**：git diff 清晰；publish 可回上一 runtime。  

### 9.2 命令级门禁

| 改动类型 | 最低验证 |
|----------|----------|
| 文档 only | 链接有效、术语与 GLOSSARY 一致 |
| 主题资源 | `list` 含 id · `apply` 不炸 · `npm run test:themes` · **CI themes-gate** |
| core / themes 逻辑 | `doctor` + 相关 cli 子命令 · `npm run test:themes` |
| runtime / CSS / renderer | `publish` + smoke +（有条件）verify / live probe |
| launcher / core-win | open 路径手动或 check-and-fix exit 0 |
| 上游 promote | vendor diff 已读 · ADR 0002 流程 · 本地覆盖未丢 |

### 9.3 doctor 健康画像（参考基线 2026-07-20）

```text
appFound: true
processRunning: false | true
dreamSkin.injectorAlive: true
injectorPathFreshness.fresh: true
themeCount / userThemeCount: ≥ 内置导入数
diagnosis: not-running | active-injector | …
paused/locked: false（正常使用时）
```

### 9.4 发版后可选 probe 验收表（不进 CI）

前置：用任务栏 **Codex** 打开、CDP `9335`、皮肤已注入。**不要**把下表写进 GitHub Actions。

| 场景 | 命令 | 期望 |
|------|------|------|
| home | `node scripts\windows\probe-session-dom.mjs`（或安装树 `node "%LOCALAPPDATA%\Programs\CodexDreamSkin\probe-session-dom.mjs"`） | JSON 含 `"ok": true`、`"dreamStyle": true`、`"pass": true`；exit 0（无 page → exit 2，先开 Codex） |
| conversation | 打开任一对话后再跑同上 | `"conversationPass": true` 且 exit 0；失败 exit 3 |
| 可选辅助 | `node scripts\windows\probe-dom.mjs` | home shell 标记如 `dreamStyle` / `mainSurface` |
| 静态（可选） | `Test-Path scripts\windows\probe-session-dom.mjs` | `True` |

脚本契约见 `scripts/windows/probe-session-dom.mjs`（`pass` / `conversationPass` / exit）。  
发版留痕：`docs/evidence/` + `pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1`（见 [evidence/README.md](./evidence/README.md)；真实 `runs/*.json` gitignore，skipped ≠ 发版完成）。

---

## 10. 上游与 fork 关系

| 远程 | URL | 角色 |
|------|-----|------|
| origin | `xvyimu/Codex-Dream-Skin` | 开发主线 |
| upstream | `Fei-Away/Codex-Dream-Skin` | 上游参考 |

- `main` 与上游 **零共同历史**（重构 force-push 后），禁止幻想 `git merge upstream/main`。  
- 吸收通道仅：**视觉资产文件级** + **PS 修复人工移植**（ADR 0002）。  
- 基线：`docs/upstream-sync.json` → `lastSyncedUpstreamSha`（当前 `e776fa6`；**2026-07-21 D-sync 已复跑**：上游无新提交；runtime 资产与 vendor **有意分叉**，勿盲 promote，见 JSON `note`）。  

---

## 11. 诊断矩阵

| 现象 | 先查 | 动作 |
|------|------|------|
| 无皮肤 | doctor · processRunning · portOpen · injectorAlive | 启动 Codex 或 reattach |
| 换肤无效 | active-theme 是否更新 · kick 是否 200 | `apply` + 看 controlPort |
| 双 injector | state.injectorPid · 进程列表 | 杀旧留一；check-and-fix |
| 版本错乱 | current.json vs state.runtimeId vs SKIN_VERSION | 重新 publish |
| 无背景图 | art 通道 / `__DREAM_ART_JSON__` · theme image 路径 | 对照 1.3.18 修复说明 |
| 焦点失败 | Focus-CodexSkinWindow · EnumWindows | 已知半好；见 PAIN-POINTS #4 |
| 会话卡顿 | backdrop-filter · mutation 节流 | 暂停皮肤 30s + kick；见 1.3.12/13 |
| payload 失败 | catalog 是否塞了全图 | 只保留缩略图 |

---

## 12. 路线图与优化 backlog

### 12.1 已完成里程碑（摘要）

| 里程碑 | 要点 |
|--------|------|
| M0 停双开 | guard |
| M1 建仓合并 | heige + DreamSkin |
| M2 多主题 + 守护 | runtime 1.3.0+ |
| M3 托盘/F6/回归 | smoke / post-update |
| 1.3.14 | 拆包 / 合文档 |
| 1.3.15 | watch-only |
| 1.3.16 | 单一版本源 |
| 1.3.18 | heige-fused 视觉（右半 hero · 左上 brand · 单岛 composer） |
| 1.3.19–1.3.21 | 会话 probe 实锤 · 气泡去描边 · D3D Enable · open-healthy 异步 · FastLaunch |
| 1.3.22–1.3.24 | publish reattach · UTF-8 控制台 · tray native focus · wait-shell 冷启 |
| 1.3.25 + `f833ee8` | 安装 runtime 1.3.25-4dca30；git 主题 catalog 11 套 + schema 双格式 |
| v6 调研（2026-07-21） | 闪白根因补丁 `48b5bae` 全量透传 palette 四色 · HD art + 气泡双模式（`0326abb`）· v5 假关闭教训 · BASELINE；**已 squash 合 main**（PR #1 · `b80bf4e`） |
| v7 门禁/证据（2026-07-21） | `probe-project-hd` 断言化 · RELEASE-EVIDENCE CI URL · BASELINE 对齐 tip · overview/CHANGELOG · surfaceLuma `#rrggbb` 边界文档 | 

### 12.2 下一阶段建议（按优先级）

| 优先级 | 项 | 模块 | 验收 |
|--------|----|------|------|
| ~~P1~~ | ~~probe-project-hd 假 pass~~ | scripts/windows | **v7** · 断言型 pass/failed/exitCode |
| ~~P1~~ | ~~合入后 CI 证据入库~~ | docs | **v7** · PR #1 + actions run URL |
| P2 | surfaceLuma 仅 `#rrggbb` | renderer-inject | 文档边界；非 hex 主题再开算法卡 |
| ~~P0~~ | ~~会话页玻璃 / chat bubble~~ | — | **已完成** · conversationPass + 去描边 |
| ~~P0~~ | ~~发布后 reattach 双 injector~~ | — | **已完成** · post-update drift reattach |
| ~~P1~~ | ~~`cli list` 主题去重~~ | — | **已完成** · `listThemes({ dedupe:true })` |
| ~~P1~~ | ~~post-update 报告自动刷新~~ | — | **已完成** · PSModulePath harden + report 写 current |
| ~~P1~~ | ~~焦点 EnumWindows 稳定性~~ | — | **已完成/绕过** · bounded retry + native focus |
| ~~P2~~ | ~~控制台 GBK 乱码~~ | — | **已完成** · UTF-8 入口 |
| ~~P2~~ | ~~修复/回归工具快捷方式 UX（#18）~~ | — | **已完成** · install-ux 唯一源 + Codex 工具文件夹 |
| ~~P2~~ | ~~清理 heige studio 残留（#20）~~ | — | **已完成** · 扫删 lnk + 文档；本机无独立目录 |
| 已知限 | Store AUMID / 商店磁贴裸启（#21） | OS | **已文档化** · usage + dual-open；日常钉任务栏；**不**劫持包 AUMID |
| 已知限 | SmartScreen 未签名入口（#24） | UX | **已文档化** · PAIN #24 + usage；OV 签名属长期可选 |
| ~~规划~~ | ~~残差 G1/G3/G4/G5~~ | docs/plans | **已实现推荐组合** · G1-B CI · G3-A Windows-only · G4-A 文档 · G5-C publish 超时 |
| ~~文档~~ | ~~CHANGELOG unreleased 并入正式版号~~ | — | **已完成** · 记入 1.3.25 |
| ~~维护~~ | ~~任务卡 2026-07-21（12 张）~~ | docs/plans | **已完成** · CONTRIBUTING · token 测试 · doctor control/stateSchema · TOC 等 |
| 可选 | PR 模板 / 扩 freshness 单测 / seed-art 已修 | — | 见 CONTRIBUTING · 非阻塞 |
| 可选 | 产品 zip 重打（`Build-ProductPackage`） | scripts | 终端用户分发时再打；开发路径走 publish |

### 12.3 明确不在范围

- 修改 OpenAI 签名包  
- 在 core 内实现 UI 皮肤  
- 自动无审 promote 上游 CSS  
- macOS 一等公民支持（**永久非目标**，见 residual 规划 G3-A）
- 劫持 / 改写微软商店 Codex 包 AUMID（#21 OS 硬限）
- 云端 CI 跑完整 doctor/smoke（无 Store Codex/CDP；仅 `test:themes`）

---

## 13. 目录速查

```text
codex-skin/
├── apps/launcher/           # L1 薄入口
├── packages/
│   ├── core/                # L2/L4 逻辑：cli · cdp/ · discover/ · state/
│   ├── themes/              # L3b 主题领域
│   ├── runtime/             # L4 自包含发布蓝图
│   └── core-win/            # L1/L2 Windows 共享库
├── scripts/windows/         # 发布 · 同步 · 探针 · E2E
├── themes/                  # 11 套内置主题源（含 preset-arina-hashimoto）
├── vendor/dreamskin/        # 上游只读镜像
├── docs/                    # 本文件与 ADR 等
├── package.json             # bin: codex-skin → cli.mjs
└── CLAUDE.md                # Agent 短索引
```

**体量参考（约，2026-07-21）**：injector ~1420（含 TOC 注释）· launcher-ui ~1081 · common-windows ~658 · dream-skin.css ~630 · renderer-inject ~480 · control-plane ~300 · cli ~280。

---

## 14. 里程碑复盘清单（每个版本结束时勾）

- [ ] 是否有跨层调用、循环依赖、重复逻辑？  
- [ ] 模块职责和接口是否仍清晰、可替换？  
- [ ] 新功能能否在不修改无关模块的情况下接入？  
- [ ] 文档、测试与实现是否一致？（PROJECT / ARCHITECTURE / CHANGELOG / GLOSSARY）  
- [ ] doctor · smoke ·（如适用）verify 是否通过？  
- [ ] 是否仍只有一条 injector、一条注入路径？  

---

## 15. 结论

- **代码可以交给 AI；架构、约束、验收和迭代节奏由人掌控。**  
- 本项目的不可谈判约束是：  
  1）单产品线单 injector；  
  2）runtime 自包含与 core 双向隔离；  
  3）主题写入只经 `packages/themes`；  
  4）版本只认 publish `-Version`；  
  5）上游只镜像、不盲合。  

违反以上任一条件的 PR / Agent 产出：**默认拒绝合并**，先回到本文件 §3 / §8 改任务边界。

---

## 附录 A · 当前环境快照（2026-07-20 晚 · 审计后 hygiene）

| 项 | 值 |
|----|-----|
| Codex 包 | `OpenAI.Codex_26.715.4045.0` |
| Runtime | `1.3.25-*`（以 `current.json` / doctor `injectorPathFreshness` 为准） |
| 用户主题 | 11 套（import-themes · list 去重） |
| 热切换 | kick ~55–80ms 量级 |
| Git | `main`：以 `git rev-parse HEAD` 为准；审计见 AUDIT-2026-07-20 |
| 上游基线 | `e776fa6`（nothing absorbed） |
| 产品包 | Release [v1.3.25](https://github.com/xvyimu/Codex-Dream-Skin/releases/tag/v1.3.25)；本地 `Build-ProductPackage` → dist（gitignore） |
| package.json | `"version": "1.3.25"`（产品线元数据；stamp 权威仍是 publish `-Version`） |
| 主题门禁 | `npm run test:themes` |

## 附录 B · 内置/用户主题 ID

`dalao-dianyan` · `naruto-hokage` · `naruto-sasuke` · `deepspace-dawn` · `deepspace-star` · `wuthering-echo` · `wuthering-tide` · `preset-arina-hashimoto` · `genshin-dawn` · `genshin-night` · `miku-488137`

## 附录 C · ADR 索引

| ID | 标题 | 状态 |
|----|------|------|
| 0001 | 合并 DreamSkin 与 heige 为一条产品线 | Accepted |
| 0002 | 上游同步策略 | Accepted |
| 0003 | 单一版本源 | Accepted · 1.3.16 起实施 |

## 附录 D · 贡献规范与任务卡

PR / 模块依赖 / 主题·runtime·publish 验收 / 命名 / 小步提交 / `--once` / 禁止事项：见 [`CONTRIBUTING.md`](./CONTRIBUTING.md)（§C-1–C-9）。

维护 backlog 任务卡：[`plans/task-cards-2026-07-21.md`](./plans/task-cards-2026-07-21.md)。  
维护 Agent 提示词：[`prompts/agent-maintain-task-cards-zh.md`](./prompts/agent-maintain-task-cards-zh.md)。
