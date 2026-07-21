# Codexveil / codex-skin — 架构

> 合并自 `architecture.md` + `modularization.md` + `source-map.md`（1.3.1 起草；1.3.25 校准）。  
> GitHub：`xvyimu/Codexveil`（原 `Codex-Dream-Skin`）。

## 目标

一条产品线，清晰边界，安装态与开发仓同源。

- **日常入口**：开始菜单 / 任务栏 / 桌面 **Codex**（→ `CodexFastLaunch.exe`）
- **安装态根**：`%LOCALAPPDATA%\Programs\CodexDreamSkin\`（产品显示名未随 GitHub 改名）
- **开发仓**：`D:\orca\codex-skin`（入口 junction：`D:\orca\Codexveil`）
- **默认 CDP 端口**：9335
- **控制面端口**：9336（loopback）
- **产品线**：DreamSkin 级守护 + heige 级多主题（合并前是两条独立线）
- **当前主线**：runtime `1.3.25` · 11 套内置主题 · 产品 zip 分发

---

## 目录结构

```text
codex-skin/
├── apps/
│   ├── launcher/            # 用户入口 (.ps1) — 薄，只 dot-source lib
│   └── native/CodexFastLaunch/  # 任务栏原生入口（独立 AUMID）
├── packages/
│   ├── core/                # Node ESM — 发现 Codex / CDP / 常量 / 守卫
│   │   ├── constants.mjs
│   │   ├── cli.mjs
│   │   ├── cdp/             #   Chrome DevTools Protocol 客户端 / 目标 / 端口
│   │   ├── discover/        #   Codex app 定位 · 进程扫描 · 路径工具
│   │   └── state/           #   DreamSkin 守卫 · kick · injector 新鲜度
│   ├── themes/              # 主题 schema / 目录库 / heige→DreamSkin 适配
│   ├── runtime/             # 生产 watch injector + CSS/JS 资源
│   │   ├── assets/          #   ← 打进 versions/<id>/assets 分发
│   │   ├── scripts/         #   ← 打进 versions/<id>/scripts 分发
│   │   └── core/            #   ← image-metadata 真实现（scripts 是薄壳）
│   └── core-win/            # PowerShell 共享库（launcher-ui / common / theme）
├── scripts/windows/         # 发布 / 产品包 / 导入主题 / 快捷方式 / 开发探针 / E2E
├── themes/                  # 内置主题源（heige 格式，11 套；含 preset-arina-hashimoto）
├── vendor/
│   └── dreamskin/           # 上游 Fei-Away/Codex-Dream-Skin 只读快照
└── docs/                    # 本文件所在
```

---

## 运行时数据（安装态）

| 路径 | 用途 |
|------|------|
| `%LOCALAPPDATA%\Programs\CodexDreamSkin\` | 入口脚本 + `lib\` + `versions\<id>\` |
| `%LOCALAPPDATA%\Programs\CodexDreamSkin\current.json` | 指针：当前 runtime + relative path（`schemaVersion: 1`） |
| `%LOCALAPPDATA%\CodexDreamSkin\active-theme\` | 当前皮肤（watch 热加载） |
| `%LOCALAPPDATA%\CodexDreamSkin\themes\` | 多主题 catalog（F6 / 托盘） |
| `%LOCALAPPDATA%\CodexDreamSkin\state.json` | injector pid / browserId / port / controlPort（**运行时 schemaVersion: 3**） |
| `%LOCALAPPDATA%\CodexDreamSkin\control.port` | 控制面 loopback 端口 |
| `%LOCALAPPDATA%\CodexDreamSkin\paused` | 存在=暂停皮肤 |
| `%LOCALAPPDATA%\CodexDreamSkin\wait-shell.mjs` | 由 publish 拷入，供 open launcher 复用 |

### state.json schema（单一真相）

| 版本 | 谁写 | 谁读 |
|------|------|------|
| **3**（现行） | `launcher-ui` 规范化写出（`schemaVersion = 3`） | injector / doctor / check-and-fix |
| 1–2 | 历史 | `common-windows` 读路径仍接受 `1..3`，缺字段时放宽 |

`packages/core/constants.mjs` 的 `STATE_SCHEMA_NODE_MARKER`（弃用别名 `STATE_SCHEMA_VERSION`）**不是** state.json 写出版本号（见该文件注释）；主题 manifest 用 `THEME_SCHEMA_VERSION = 1`。

---

## 调用关系

```text
用户点 Codex.lnk / FastLaunch
  → apps/launcher/open-codex-dream-skin.ps1
  → packages/core-win/launcher-ui.ps1   (安静 UI / 托盘 / 焦点)
  → versions/.../scripts/injector.mjs --watch
  → watch injector 注入 active-theme

用户 CLI apply --theme X
  → packages/core/cli.mjs
  → packages/themes/dream-adapter.writeActiveThemeFromHeige
  → 改 active-theme 文件戳
  → packages/core/state/kick-inject → 控制面 POST /kick
  → watch 热更新
  → （仅当控制面不可达）同 runtime injector --once 单次降级 apply
```

### 控制面

```text
watch injector 启动
  → packages/runtime/scripts/control-plane.mjs
  → 监听 127.0.0.1:9336（写入 state.controlPort + control.port 文件）
  → stateRoot：优先 --state-root，否则 dirname(--theme-dir)
  → GET /health（免 token）· POST /focus · /kick · /open-healthy（需 x-codex-skin-token）
```

主路径：POST `/kick`（带 `control.token`）→ 毫秒级进程内 apply。  
**降级**：控制面不可达时 spawn 同版本 `injector --once` 做一次 apply——**不是**第二守护、不是 heige 旁路、CLI 不暴露该开关。见 `dual-open-policy.md`。

---

## 跨层字段契约（injector → CDP → renderer）

> **TD-V5-LESSON**（v6）：「已修」须同时具备命令级证据 + 根因一句话 + 代码路径:行号。  
> v5 假关闭根因：`loadTheme` 只透传 `palette.accent`，`surface` 未进 payload → renderer `surfaceLuma` 无效 → 暗色主题可挂 `dream-theme-light` → 开项目闪白。  
> 根因补丁：`48b5bae` · `packages/runtime/scripts/injector.mjs` `loadTheme` / `loadCatalogMember`。

### palette 四色必传

| 字段 | 类型（经 CSS color 正则） | 用途 | 缺失后果 |
|------|---------------------------|------|----------|
| `accent` | string | 品牌色 / 描边 / 高亮 | 主题无品牌色 |
| `secondary` | string | 次要强调 | 次要元素无色 |
| `surface` | string | **surfaceLuma → dark/light 类** | **闪白回归**：`surfaceLuma` 非 number → 回落 shell auto |
| `text` | string | 正文色 + B 对比度门 | 正文无色 / 对比不足 |

**透传实现**：`packages/runtime/scripts/injector.mjs` 对 `accent|secondary|surface|text` 循环校验并写入 `theme.palette`（`loadTheme` 与 catalog member 一致）。  
**消费实现**：`packages/runtime/assets/renderer-inject.js` 读四色；`surfaceLuma` 当前仅对 `#rrggbb` 6 位 hex 计算（`oklab`/`rgb()` surface → `null` → shell 回落）。  
**判定阈值**：`surfaceLuma ≤ 0.45` → dark；`≥ 0.62` → light；中间带走 `detectShellAppearance()`，最终 auto 缺省偏 dark。  
**验收探针**：`node scripts/windows/probe-white-flash.mjs`（需本机 CDP 9335；`pass=true` 且 `surfaceLuma` 有限数字）。  
**`probe-project-hd.mjs`**（v7）：断言型——`pass`/`failed`/exit 1（CDP 不可达）/ exit 2（检查失败）；校验 dark/not light、`surfaceLuma` 有限、气泡模式类、（若存在 `.dream-task`）任务 art 尺寸与 ambient。**snapshot-only 旧行为已废止。**

改 injector 透传或 renderer 消费时：**两边对照本表**；缺字段不得只靠「本层单测绿」声明完成。

---

## 包边界

| 包 | 语言 | 依赖 | 说明 |
|---|---|---|---|
| `packages/core` | Node ESM | 无 npm 依赖 | 只做纯逻辑（发现 / CDP / kick / 守卫）；不直接写 active-theme；不做页面注入 |
| `packages/themes` | Node ESM | `packages/core`（常量）· 动态 `packages/runtime/scripts/thumb.mjs` | schema · store · heige→DreamSkin 适配 |
| `packages/runtime` | Node ESM + assets | 自包含（不依赖 packages/core） | 打进 `versions/<id>/` 独立分发 |
| `packages/core-win` | PowerShell 5.1 | 无 | dot-source 到 apps/launcher；publish 时同步到 install `lib\` |

**关键规则**：

- `packages/core` 不依赖 `packages/runtime`（runtime 是发布蓝图，独立可发布）
- `packages/runtime` 不依赖 `packages/core`（保持 self-contained，publish 一次 copy 即完整）
- 页面**守护**注入只有一条路径：watch injector
- kick **降级** `--once` 允许，且必须与 current runtime 同树；禁止独立 heige / legacy-inject 产品线

---

## 发布流程

### 开发安装态（写回 git tree）

`scripts/windows/publish-runtime.ps1 -RepoRoot D:\orca\codex-skin [-Version 1.3.25] [-SkipImportThemes]`

会同步：

1. `programRoot\versions\<id>\` — 新 runtime（scripts + assets + core）
2. stamp `SKIN_VERSION_TOKEN`（源 + 副本）— **唯一写回 git 的版本权威**
3. `programRoot\lib\launcher-ui.ps1` — 共享 UI 库
4. `programRoot\open-*.ps1` / `check-and-fix.ps1` / `switch-theme-ui.ps1` / `smoke-*.ps1`
5. `stateRoot\wait-shell.mjs`
6. `current.json` 翻页 + 备份 `.bak`
7. GC 旧 runtime，只留 current + 上一版
8. 刷新 UX 快捷方式

### 产品 zip（不写 git tree）

`scripts/windows/Build-ProductPackage.ps1 [-Version 1.3.25]` → `dist/CodexDreamSkin-<ver>-win-x64.zip`  
Install / Uninstall 只 stamp 安装树。见 ADR 0003 产品包表。

---

## 源码映射（追溯）

| 统一仓路径 | 来源 |
|-----------|------|
| `packages/core/cdp/*.mjs` | heige `src/cdp-*`（1.3.14 归入子目录） |
| `packages/core/discover/codex-app.mjs` | heige `src/codex-app.mjs`（含 WindowsApps/CDP 发现修复） |
| `packages/core/state/dreamskin-guard.mjs` | heige（M0 双开守卫；现仅诊断） |
| `packages/core/cli.mjs` | 新建统一 CLI |
| `packages/themes/*` | heige theme-schema / theme-store + DreamSkin 双格式 |
| `packages/runtime/scripts/injector.mjs` | DreamSkin watch 引擎（扩展至 1.3.25） |
| `packages/runtime/assets/*` | DreamSkin CSS/JS + heige-fused 视觉 |
| `themes/*` | heige 内置主题 + preset-arina-hashimoto（11 套） |
| `apps/launcher/*` | DreamSkin 入口脚本 |
| `apps/native/CodexFastLaunch` | 本仓原生任务栏入口 |
| `vendor/dreamskin/*` | Fei-Away/Codex-Dream-Skin 上游只读参考 |

---

## 里程碑

| 里程碑 | 状态 | 释义 |
|---|---|---|
| M0 停双开 | 完成 | dreamskin-guard 检测运行中的 DreamSkin |
| M1 建仓 + 迁内核 | 完成 | heige/DreamSkin 合并为单仓 |
| M2 多主题接入守护 | 完成 | runtime 1.3.0 热切换验证通过 |
| M3 托盘/F6/归档/回归 | 完成 | SMOKE_PASS + POST_UPDATE_PASS |
| 模块化 + 安静启动 | 完成 | launcher-ui 共享库 + 包 index 出口 |
| runtime 1.3.1–1.3.13 | 完成 | 焦点/CDP/GC/会话节流等 · 见 CHANGELOG |
| runtime 1.3.14 | 完成 | repo 架构重构（拆包/合文档） |
| runtime 1.3.15 | 完成 | 删 legacy-inject · 用户路径 watch-only |
| runtime 1.3.16 | 完成 | ADR 0003 单一版本源 TOKEN |
| runtime 1.3.18 | 完成 | heige-fused 视觉（右半 hero · 左上 brand · 单岛 composer） |
| runtime 1.3.19–1.3.24 | 完成 | 会话 probe · FastLaunch · wait-shell · tray native focus · UTF-8 |
| runtime 1.3.25 | 完成 | 11 主题 catalog · 快捷方式 #18 · 产品 zip · soft reattach |

---

## scripts/windows 探针（非生产）

| 文件模式 | 用途 | 是否进产品 zip |
|----------|------|:--------------:|
| `probe-*.mjs` · `probe-session-dom.mjs` | 开发态 DOM / F6 探针 | 否 |
| `e2e-pain-test.ps1` | 痛点回归 | 否 |
| `publish-runtime.ps1` · `Build/Install/Uninstall-Product.ps1` | 发布 / 分发 | Install 脚本进 zip |
| `install-ux-shortcuts.ps1` | 快捷方式唯一源 | 经 publish / Install 调用 |

`dist/` 与 `dist/_probe` 均在 `.gitignore`；本地探针目录可随时删，不影响 git。

## 注释约定

- 每个包 `index.mjs` 说明边界与非职责
- 公共函数用 JSDoc / PowerShell comment-based help
- 禁止在业务脚本里散落硬编码路径，统一走 `resolveStudioPaths` (Node) / `Get-CodexSkin*Root` (PS)

---

## 相关文档

- `PROJECT.md` — **项目总纲**（分层 · 模块契约 · 验收 · 路线图）
- `overview.md` — 调研报告索引（v1–v6）
- `research/2026-07-21-master-research-v6-palette-root-and-hd-bubble.md` — v6 根因与契约背景
- `audit/2026-07-21-v6-review.md` · `audit/2026-07-21-v6-advance.md` — v6 无证不信审核 / 推进
- `AUDIT-2026-07-20.md` — 全面检查报告
- `README.md` — 项目入口
- `CHANGELOG.md` — 版本时间线
- `PAIN-POINTS.md` — 痛点合集
- `adr/` — 架构决策（0001 合并 · 0002 上游 · 0003 版本源）
- `GLOSSARY.md` — 领域术语表
- `usage.md` — 使用说明
- `dual-open-policy.md` — 入口纪律与 kick 降级
