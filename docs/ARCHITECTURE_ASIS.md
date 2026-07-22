# Codexveil / codex-skin — As-Is 架构测绘

> **角色**：架构测绘（只读）· 2026-07-22  
> **HEAD**：`77892f8` · 分支 `xvyimu/cv-1`  
> **总规划 SSOT**：`D:\orca\docs\architecture-stack-refactor-master-2026-07-22.md`  
> **产品线标签（建议）**：**TOOL** — 维持 TS/Node + Shell；**默认不建 Vue 面板**  
> **性质**：开发者/终端用户 **Windows CDP 换肤工具**，不是云网关、不是 AI 核心服务、不是内容站。

---

## 1. 一句话定位

给 OpenAI **Codex Desktop**（Windows Store / Electron）做 **CDP 注入式皮肤**（背景图、调色板、多主题热切换、托盘/F6），**不**改官方 asar/MSIX，**不**跨平台主路径。

| 维度 | As-Is |
|------|--------|
| 产品名（安装态） | CodexDreamSkin · `%LOCALAPPDATA%\Programs\CodexDreamSkin` |
| GitHub | `xvyimu/Codexveil`（ADR 0006 独立线 · 仅 `origin`） |
| Runtime 线 | `1.3.25`（权威：`publish-runtime.ps1 -Version` · ADR 0003） |
| 默认 CDP / 控制面 | `127.0.0.1:9335` / `127.0.0.1:9336` |
| 平台 | **Windows only**（macOS 永久非目标） |

---

## 2. 目录与模块图

```text
codex-skin / Codexveil
├── apps/
│   ├── launcher/          # 用户入口 .ps1（open/tray/focus/smoke…）
│   └── native/CodexFastLaunch/  # C# 小 exe · 独立 AUMID 任务栏快启
├── packages/
│   ├── core/              # Node ESM：CLI · CDP 发现 · doctor · kick 客户端
│   │   ├── cdp/ · discover/ · state/
│   ├── core-win/          # PowerShell 共享库（launcher-ui / common / theme）
│   ├── runtime/           # 生产 watch injector + CSS/JS + control-plane
│   │   ├── scripts/       # injector.mjs（巨石）· control-plane · stamp …
│   │   ├── assets/        # dream-skin.css · renderer-inject.js
│   │   └── core/          # image-metadata 真实现
│   ├── themes/            # theme schema / store / heige→DreamSkin adapter
│   └── contracts/         # 开发态 TS+Zod 契约（ADR 0004 · 不进 versions/）
├── themes/                # 11 套内置主题源（heige 格式）
├── scripts/windows/       # publish · 产品包 · 探针 · 快捷方式 · E2E
├── docs/                  # PROJECT / ADR / PAIN / 本文件
├── package.json           # Node≥20 · ESM · pnpm workspace 壳
└── .github/workflows/     # themes-gate（轻量 CI）
```

### 2.1 运行时调用关系

```text
用户 · 任务栏 Codex.lnk / CodexFastLaunch.exe
  → apps/launcher/*.ps1 + packages/core-win/launcher-ui.ps1
  → versions/<id>/scripts/injector.mjs --watch
  → CDP evaluate(payload) → Codex renderer (app://)
  → 同进程 control-plane 127.0.0.1:9336

CLI apply --theme
  → packages/core/cli.mjs
  → packages/themes (write active-theme)
  → POST /kick (token) → 进程内热应用
  → 降级：同版本 injector --once（非第二守护）
```

### 2.2 包边界（硬）

| 规则 | 说明 |
|------|------|
| `core ↛ runtime` 静态互引 | `test:deps` + ADR 0004 |
| 主题写入只经 `packages/themes` + `themes/<id>/` | 禁止旁路写 active-theme |
| 单 watch injector | dual-open-policy；禁止第二守护路径 |
| 安装态 runtime 默认零第三方 npm | contracts/TS 仅开发平面 |

---

## 3. 语言与体量占比（工作树粗测）

排除 `node_modules` / `.git` 后（近似 **行数**）：

| 语言/形态 | 文件数（约） | 行数（约） | 角色 |
|-----------|-------------|-----------|------|
| **PowerShell (`.ps1`)** | 34 | **~8400** | 启动/托盘/发布/UX · **主运维面** |
| **Node ESM (`.mjs`)** | 47 | **~7600** | CLI · injector · themes · probes · **主逻辑** |
| **JS (`.js`)** | 1 | ~815 | `renderer-inject.js`（注入页内） |
| **CSS** | 1 | ~675 | `dream-skin.css` |
| **TypeScript** | 6 | ~200 | `packages/contracts` only |
| **C#** | 1 | ~305 | `CodexFastLaunch` 原生入口 |
| **Markdown** | 46 | （文档重） | 架构/ADR/痛点 |
| **主题资源** | webp/jpg + theme.json | — | 11 themes |

**目标栈对照占比**

| SSOT 层 | 本仓现状 |
|---------|----------|
| C | **无**业务 C；仅副线无关 |
| Python | **无** |
| Go | **无** |
| TS + Vue3 + NaiveUI | TS **仅 contracts**；**无 Vue / 无 NaiveUI / 无 SPA 管理台** |
| 嵌入式 | **无** |
| Git / Shell / SQL | **Git + Shell(pwsh) 重度**；**无 SQL / 无 DB 服务** |

**结论**：主栈是 **Node ESM + PowerShell + 极薄 C#**，与「Gateway/AI-Core/Console」产品组合 **正交**；应标 **TOOL**，不走旗舰绞杀迁移。

---

## 4. 对外 API 与接口面

### 4.1 CLI（`node packages/core/cli.mjs` / `npm run doctor|list|status|help`）

| 能力 | 形态 | 备注 |
|------|------|------|
| `doctor` | JSON stdout | 发现 Codex、CDP、DreamSkin 状态、control 摘要、injector 新鲜度 |
| `list` / 主题列表 | JSON | `listThemes({ dedupe:true })` |
| `status` / `help` | JSON/文本 | 产品状态与帮助 |
| `apply --theme` 等 | 写 active-theme + kick | 主题热路径（见 cli 模块注释） |

输出约定：成功路径多为 **JSON**；错误 stderr + exit≠0。

### 4.2 控制面 HTTP（loopback only）

**宿主**：watch injector 内 `control-plane.mjs`  
**绑定**：`127.0.0.1`，默认 **9336**（扫描 9336..9346）  
**鉴权**：突变接口要求头 `x-codex-skin-token`；**GET /health 免 token**（FastLaunch 探针）

| 方法 | 路径 | 用途 |
|------|------|------|
| GET | `/health` | 健康/存活（tokenPresent 布尔，不回明文 token） |
| POST | `/kick` | 毫秒级重载 active-theme 并 apply |
| POST | `/focus` | 焦点窗口（常 spawn PS） |
| POST | `/open-healthy` | 打开/健康路径（异步 focus 等） |

**非对外公网 API**：无多租户、无 OpenAPI 网关、无远程管理。

### 4.3 CDP

- 客户端连 **本机** Codex 调试端口（默认 9335）  
- 注入 payload：CSS + art data URL + theme JSON + catalog（F6）  
- URL 校验：`cdp-url-guard.mjs`（防非 loopback / 畸形 browser id）

### 4.4 进程/入口 API（OS 级）

| 入口 | 技术 |
|------|------|
| 任务栏 / 开始菜单 | `CodexFastLaunch.exe`（C#）+ `.lnk` / `.ps1` / `.vbs` |
| 托盘 | `tray-dream-skin.ps1` + launcher-ui |
| F6 窗内循环 | `renderer-inject.js` catalog cycle（PAIN #25；安装态需 publish） |

---

## 5. 数据存储（无 RDBMS）

| 位置 | 内容 | 形态 |
|------|------|------|
| `%LOCALAPPDATA%\Programs\CodexDreamSkin\` | 入口脚本、`versions/<id>/`、`current.json` | 文件树 |
| `%LOCALAPPDATA%\CodexDreamSkin\` | `active-theme/`、`themes/`、`state.json`、`control.port`、`control.token`、`ui-prefs.json`、`paused`、`injector.log` | JSON / 文本 / 目录 |
| 仓内 `themes/` | 内置 11 主题 | theme.json + 图 |
| **SQL** | — | **无** |
| **对象存储/云** | — | **无**（产品 zip 本地分发） |

`state.json`：**schemaVersion 3**（launcher-ui 写）；读路径兼容 1..3。  
`control.token`：本地文件；**不进日志明文**（SEC-02）。

---

## 6. 与目标栈偏离清单

| 目标栈组件 | 偏离 | 处置建议 |
|------------|------|----------|
| Vue3 + NaiveUI 面板 | **完全缺失**；交互为托盘/PS/CLI/F6 | **默认不建**；仅当产品要「远程主题商店/多机管理」再开 Console 子项目 |
| Go 网关 | **无**；仅 loopback 控制面 | **不引入**；公网化会破坏威胁模型 |
| Python AI 核心 | **无** | **不引入**；本产品无 LLM 编排职责 |
| 标准 C / 嵌入式 | **无** | 无关；SIDE 独立仓 |
| SQL | **无** | 文件状态足够；除非做云同步 |
| TS 主工程 | 运行时以 **`.mjs` 非 TS** 为主；contracts 薄 | **TOOL 维持**；TS 渐进可选（ADR 0004），非栈迁移 |
| 现有 PowerShell 体量 | SSOT 允许 Shell 工具 | **保留**为运维一等公民 |
| C# FastLaunch | 非 C/Go/Python | **允许的原生边车**（Windows 入口性能）；勿扩成 .NET 业务层 |

**反模式（禁止借「架构重构」做）**

- 把 injector 重写成 Go/Python「网关」  
- 为换肤做多租户 SaaS  
- 在本 monorepo 嵌 STM32/固件  
- 用 React/Next 补「管理台」（与 SSOT 前端冲突且本产品不需要）

---

## 7. 迁移风险（若强行对齐「完整栈」）

| 风险 | 等级 | 说明 |
|------|------|------|
| 误标 P0 旗舰 | **高** | 与 TransitHub 抢节奏；ROI 负 |
| 拆 PS→Go 启动链 | **高** | Windows 托盘/快捷方式/SmartScreen 面全在 PS/C#；重写易回归双 injector |
| 引入云控制面 | **高** | 突破 loopback+token 模型；密钥与 CDP 暴露面上升 |
| Vue 面板无后端可接 | **中** | 仅本地 JSON；做 SPA 变成「文件浏览器」，价值低 |
| injector 巨石 (~1.5k 行) | **中** | 工程债真实，但属 **TOOL 内聚模块化**，不是栈迁移 |
| contracts/Zod 打进 versions/ | **中** | 违反双平面；publish 体积与审计变差 |
| 停更 Windows 工具去追 SSOT 形式 | **高** | 用户价值在 kick 延迟与主题体验，不在语言纯度 |

**推荐策略（对齐总规划 §2 行）**

- 标签：**TOOL**  
- 维持 **TS/Node + Shell + 必要 C#**  
- 契约/脚本用 **Git + pwsh**  
- **不**强制 Vue 面板  
- 架构级精力投向 **TransitHub / MindSync**，本仓只做产品维护与边界硬化

---

## 8. 建议标签与 backlog 边界

### 8.1 标签

| 标签 | 适用 |
|------|------|
| **TOOL** | **主标签** — 开发者工具 / 本地 CDP skin |
| 非 P0 / 非 P1 栈迁移 | 不进 Gateway/AI-Core/Console 重组主航道 |
| 非 L2 内容遗留 | 非博客/导航站 |
| 非 LEGACY | 仍活跃维护（runtime 1.3.25 线） |
| 非 SIDE | 无嵌入式 |

### 8.2 允许的后续（仍 TOOL 内）

- 文档：`ARCHITECTURE_TARGET.md` 一页纸指向总规划（Phase 0）  
- 测试/发布卫生：`npm test`、publish 白名单、doctor  
- ADR 0004 内 **可选** 模块化（须单独决策；**halt** 后不自动恢复 injector 微重构）  
- 安全：控制面 loopback + token 纪律保持  

### 8.3 明确不做（本测绘结论）

- Vue3+NaiveUI 产品控制台（默认）  
- Go 公网 API / Python AI worker  
- SQL 持久化层  
- 跨平台 / macOS  
- 与支付/订单等无关域模型  

---

## 9. 关键风险与债（As-Is 快照，非迁移任务）

| 项 | 状态 |
|----|------|
| `injector.mjs` 巨石 | 已知；ADR 0004 D4 曾规划抽取；**战略纠偏后非当前 P0** |
| PAIN #25 F6 | 仓内已修；安装态依赖 publish |
| SmartScreen 未签名 | PAIN #24 · 长期 P3 |
| 商店磁贴裸启 | OS 硬限 #21 |
| PS 体量大 | 可维护性债；与 TOOL 定位共存 |

---

## 10. 测绘方法与限制

- **只读**：扫目录、扩展名/LOC 粗计、读 PROJECT/ARCHITECTURE/constants/cli/control-plane；**未**改业务代码、**未** commit/push。  
- LOC 为 PowerShell `Get-Content` 行计近似，非 cloc 权威。  
- 未跑 live doctor/CDP（安装态依赖本机 Codex）。  
- 工作区若存在未跟踪方案笔记（如历史 `injector-split-*.md`），**不**代表当前战略交付。

---

## 11. 给协调员的一页结论

**Codexveil = TOOL（Node/TS ESM + PowerShell + 薄 C#）**；与目标栈 **C/Python/Go/Vue** 无强制对齐义务。  
对外面 = **本地 CLI JSON + loopback control-plane + CDP**；存储 = **本地文件/JSON**，无 SQL。  
迁移主战场不在本仓；本仓保持边界硬化与发版工具链即可。
