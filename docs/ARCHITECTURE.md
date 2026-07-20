# Codex Dream Skin — 架构

> 合并自 `architecture.md` + `modularization.md` + `source-map.md`（1.3.1 起草，1.3.13 校准）。

## 目标

一条产品线，清晰边界，安装态与开发仓同源。

- **日常入口**：开始菜单 / 任务栏 / 桌面 **Codex**
- **安装态根**：`%LOCALAPPDATA%\Programs\CodexDreamSkin\`
- **开发仓**：`D:\orca\codex-skin`
- **默认 CDP 端口**：9335
- **产品线**：DreamSkin 级守护 + heige 级多主题（合并前是两条独立线）

---

## 目录结构

```text
codex-skin/
├── apps/
│   └── launcher/            # 用户入口 (.ps1) — 薄，只 dot-source lib
├── packages/
│   ├── core/                # Node ESM — 发现 Codex / CDP / 常量 / 守卫
│   │   ├── constants.mjs
│   │   ├── cdp/             #   Chrome DevTools Protocol 客户端 / 目标 / 端口
│   │   ├── discover/        #   Codex app 定位 · 进程扫描 · 路径工具
│   │   └── state/           #   DreamSkin 守卫 · kick · injector 新鲜度
│   ├── themes/              # 主题 schema / 目录库 / heige→DreamSkin 适配
│   ├── runtime/             # 生产 watch injector + CSS/JS 资源
│   │   ├── assets/          #   ← 打进 versions/<id>/assets 分发
│   │   ├── scripts/         #   ← 打进 versions/<id>/scripts 分发
│   │   └── core/            #   ← image-metadata 真实现（scripts 是薄壳）
│   └── core-win/            # PowerShell 共享库（launcher-ui / common / theme）
├── scripts/windows/         # 发布 / 导入主题 / 快捷方式 / 探针 / E2E
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
| `%LOCALAPPDATA%\Programs\CodexDreamSkin\current.json` | 指针：当前 runtime + relative path |
| `%LOCALAPPDATA%\CodexDreamSkin\active-theme\` | 当前皮肤（watch 热加载） |
| `%LOCALAPPDATA%\CodexDreamSkin\themes\` | 多主题 catalog（F6 / 托盘） |
| `%LOCALAPPDATA%\CodexDreamSkin\state.json` | injector pid / browserId / port / controlPort |
| `%LOCALAPPDATA%\CodexDreamSkin\control.port` | 控制面 loopback 端口 |
| `%LOCALAPPDATA%\CodexDreamSkin\paused` | 存在=暂停皮肤 |
| `%LOCALAPPDATA%\CodexDreamSkin\wait-shell.mjs` | 由 publish 拷入，供 open launcher 复用 |

---

## 调用关系

```text
用户点 Codex.lnk
  → apps/launcher/open-codex-dream-skin.ps1
  → packages/core-win/launcher-ui.ps1   (安静 UI / 托盘 / 焦点)
  → versions/.../scripts/{common,theme,injector}
  → watch injector 注入 active-theme

用户 CLI apply --theme X
  → packages/core/cli.mjs
  → packages/themes/dream-adapter.writeActiveThemeFromHeige
  → 改 active-theme 文件戳
  → packages/core/kick-inject → 控制面 /kick（HTTP POST）
  → watch 热更新
```

### 控制面

```text
watch injector 启动
  → packages/runtime/scripts/control-plane.mjs
  → 监听 127.0.0.1:9336（写入 state.controlPort + control.port 文件）
  → /health · /focus · /kick · /open-healthy
```

任何外部调用（launcher / kick-theme-now / switch-theme-ui）都可以先 POST `/kick`，控制面命中就在毫秒级完成 apply；命中不到再 spawn `injector --once`。

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
- 页面注入只有一条路径：watch injector；不再保留 heige 遗留的 `--once` CDP 旁路

---

## 发布流程

`scripts/windows/publish-runtime.ps1 -RepoRoot D:\orca\codex-skin [-Version 1.3.13] [-SkipImportThemes]`

会同步：

1. `programRoot\versions\<id>\` — 新 runtime（scripts + assets + core）
2. `programRoot\lib\launcher-ui.ps1` — 共享 UI 库
3. `programRoot\open-*.ps1` / `check-and-fix.ps1` / `switch-theme-ui.ps1` / `smoke-*.ps1` — 入口脚本
4. `stateRoot\wait-shell.mjs` — open launcher 用
5. `current.json` 翻页 + 备份 `.bak`
6. GC 旧 runtime，只留 current + 上一版
7. 刷新 UX 快捷方式

---

## 源码映射（追溯）

| 统一仓路径 | 来源 |
|-----------|------|
| `packages/core/cdp-*.mjs` | heige `src/cdp-*` |
| `packages/core/codex-app.mjs` | heige `src/codex-app.mjs`（含 WindowsApps/CDP 发现修复） |
| `packages/core/dreamskin-guard.mjs` | heige（M0 双开守卫） |
| `packages/core/cli.mjs` | 新建统一 CLI |
| `packages/themes/*` | heige theme-schema / theme-store |
| `packages/runtime/scripts/injector.mjs` | DreamSkin 1.2.1 watch 引擎（迁移+扩展至 1.3.14） |
| `packages/runtime/assets/*` | DreamSkin 1.2.1 CSS/JS（迁移+扩展） |
| `themes/*` | heige 10 套内置主题 |
| `apps/launcher/*` | DreamSkin 入口脚本 |
| `vendor/dreamskin/*` | Fei-Away/Codex-Dream-Skin 上游只读参考 |

---

## 里程碑

| 里程碑 | 状态 | 释义 |
|---|---|---|
| M0 停双开 | 完成 | dreamskin-guard 检测运行中的 DreamSkin，拒绝 heige studio 二次启动 |
| M1 建仓 + 迁内核 | 完成 | heige/DreamSkin 合并为单仓 |
| M2 多主题接入守护 | 完成 | runtime 1.3.0 热切换验证通过 |
| M3 托盘/F6/归档/回归 | 完成 | SMOKE_PASS + POST_UPDATE_PASS |
| 模块化 + 安静启动 | 完成 | launcher-ui 共享库 + 包 index 出口 |
| runtime 1.3.1 | 完成 | switch/check 依赖 launcher-ui；core 子模块拆分 |
| runtime 1.3.13 | 完成 | 焦点/CDP 修复 · GC · SKIN_VERSION 对齐 · 见 CHANGELOG |
| runtime 1.3.14 | 完成 | repo 架构重构（拆包/合文档/去死代码），功能不变 |
| runtime 1.3.15 | 完成 | 删 legacy-inject · 注入路径收敛为 watch-only |

---

## 注释约定

- 每个包 `index.mjs` 说明边界与非职责
- 公共函数用 JSDoc / PowerShell comment-based help
- 禁止在业务脚本里散落硬编码路径，统一走 `resolveStudioPaths` (Node) / `Get-CodexSkin*Root` (PS)

---

## 相关文档

- `PROJECT.md` — **项目总纲**（分层优化 · 模块契约 · 验收 · 路线图；规范优先读这个）
- `README.md` — 项目入口
- `CHANGELOG.md` — 版本时间线（合并 12 份 release-*.md）
- `PAIN-POINTS.md` — 痛点合集
- `adr/` — 架构决策记录（0001 合并 · 0002 上游同步 · 0003 单一版本源）
- `GLOSSARY.md` — 领域术语表
- `usage.md` — 使用说明
- `dual-open-policy.md` — 过渡期双开规则
