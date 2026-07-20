# Codex Desktop 换肤赛道调研与本仓架构评估

> **日期**：2026-07-21  
> **对象**：`D:\orca\codex-skin`（GitHub：`xvyimu/Codex-Dream-Skin`）  
> **本机状态**：HEAD 以 `git rev-parse --short HEAD` 为准（调研起草时样本 `34b4714`，ahead origin 1）；安装态 runtimeId 样本 `1.3.25-50fee1`；doctor `fresh=true` · injectorAlive · 11 themes · control 9336  
> **方法**：本仓源码与 ADR/PROJECT 精读；`gh` API 拉取同类仓元数据与 README；对照 awesome 目录与安全边界文档；**不**做渗透、不改 asar、不启动未授权第三方安装  
> **篇幅目标**：万字以上可执行调研（含对照表、实现逻辑、优缺点、架构优化建议与路线图）  
> **读者**：维护者 / Agent / 希望理解「为什么不 merge 上游」的外部协作者  

---

## 0. 执行摘要（先读 2 分钟）

### 0.1 一句话定位

**本仓是 Windows-only、单 watch injector、版本化 runtime（`versions/<id>`）、loopback control-plane 热 kick 的 Codex Desktop CDP 皮肤产品线**——不是 CLI 终端主题、不是官方 Appearance 导入串、也不是把 Codex 重写成 Tauri 应用。

### 0.2 赛道分层（避免学错对象）

| 层 | 机制 | 用户感知 | 代表 | 与本仓 |
|----|------|----------|------|--------|
| **A. CLI TUI** | TextMate `.tmTheme` + `config.toml` | 终端语法高亮 | 官方 32 套、各类 gallery | **无关** |
| **B. 官方桌面 Appearance** | `codex-theme-v1:{json}` 导入 | 色板/字体/语义色 | DexThemes、samuxbuilds 等 | **互补** |
| **C. CDP Skin** | 启动带 `--remote-debugging-port`，本机 CDP 注入 CSS/图 | 壁纸级背景、玻璃、品牌层 | [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)、本仓、[xuhuanstudio/codex-styler](https://github.com/xuhuanstudio/codex-styler) | **本仓主战场** |

划分参考：[mcpso/awesome-codex-themes](https://github.com/mcpso/awesome-codex-themes)。

### 0.3 关键数字（调研时点）

| 项目 | Stars | Forks | 语言重心 | 许可 |
|------|------:|------:|----------|------|
| Fei-Away/Codex-Dream-Skin（上游） | ~11038 | ~1132 | JS / PowerShell / Shell / CSS | （页面未暴露统一 SPDX，社区 MIT 叙述常见） |
| xuhuanstudio/codex-styler | ~14 | 0 | TypeScript 为主 + CSS + Rust + JS | Apache-2.0 |
| mcpso/awesome-codex-themes | ~3 | 3 | 文档目录 | CC0-1.0 |
| xvyimu/Codex-Dream-Skin（本 fork 远程） | 0 | 0 | PowerShell + JS + CSS + C# + VBS | 与 fork 叙述一致（产品线私有维护向） |

本仓体量（约，排除 `.git` / vendor 镜像噪声）：**core ~2.0k LOC · themes ~0.7k · runtime ~3.7k · core-win ~2.9k · launcher ~1.9k · scripts/windows ~2.4k · docs ~3.4k**；最大单文件 `injector.mjs` ~1429 行。

### 0.4 核心结论

1. **工程护城河在「守护与发布」**：单 injector、`current.json` 翻页、GC、soft reattach、control-plane `/kick`、doctor freshness——这是上游「安装即用脚本」与多数皮肤 fork **没有完整抄走**的部分。  
2. **产品叙事与 Creator 体验落后于 Styler / 上游社区运营**：上游 1 万+ star 的内容与安装体验、Styler 的 evidence-gated 发布与 data-only 主题模型，是本仓最值得**学方法、不学扩 scope**的方向。  
3. **最大结构性约束是分叉**：`main` 与上游**零共同历史**，目录完全不同 → 只能 vendor 镜像 + 人工 promote（ADR 0002），幻想 `git merge upstream` 会持续制造假债。  
4. **安全模型诚实**：loopback + 本机 token 防误触，不是跨用户隔离；与 Styler SECURITY 边界表述同族。  
5. **架构不必推倒重来**：四层（L1–L4）与包边界已可维护；优化重点是 **证据门、仓↔安装树一致性、DOM fixture、签名路线图**，不是 monorepo 炫技重写。

### 0.5 建议组合（Portfolio）

| 优先级 | 组合 | 预期 |
|--------|------|------|
| 立即 | 文档三层对照 + CI 全 `npm test` + 发版「必 publish」纪律 | 已部分落地（L0 ship） |
| 近端 | soft reattach 正式降级日志 + probe 验收表 | 已部分落地（L1 ship） |
| 中期 | DOM fixture 最小集、主题 data-only 硬边界、post-update 根因可观测 | 降 CSS/DOM 债 |
| 长期 | Authenticode（#24）、上游资产双周同步节奏 | 信任与内容 |
| 永不 | mac 一等公民、AUMID 劫持、asar 修改、第二 injector、整仓 Tauri 化 | 守边界 |

---

## 1. 研究范围、方法与非目标

### 1.1 范围内

- 本仓：`packages/*`、`apps/*`、`scripts/windows`、`docs/adr`、`docs/PROJECT`、安装态行为（doctor / current.json）  
- 同类：上游 DreamSkin、Codex Styler、awesome 目录、topic `codex-skin` / `codex-theme` 检索到的公开仓  
- 横切：技术栈、边界、约束、目标、关键调用链、安全、测试、发布、技术债  

### 1.2 非范围

- 官方 OpenAI Codex 闭源实现逆向  
- 未授权的商店包修改、签名绕过、检测规避  
- 对第三方 CDN/站点的深度爬取  
- 像素级 UI 评审与用户访谈  
- 把本仓改造成跨平台或 Creator IDE  

### 1.3 证据等级

| 等级 | 含义 |
|------|------|
| **E1** | 本机命令/文件实测（git、doctor、LOC、安装树 Select-String） |
| **E2** | 本仓文档与源码直接引用 |
| **E3** | `gh api` / `gh repo view` 拉取的公开元数据与 README |
| **E4** | 二手汇总（awesome、新闻稿）—仅作导航，不单独作架构结论 |

---

## 2. 问题域：Codex Desktop 为什么需要「皮肤」

### 2.1 官方能力的上限

官方桌面已提供 Appearance（色板、字体、语义 diff 色等），主题以 `codex-theme-v1:` 前缀 JSON 导入（见 awesome 说明与官方设置文档链接）。  
**上限在于**：它优化的是「Chrome 语义色与代码主题 id」，**不是**全屏氛围背景、构图安全区、品牌字层、会话玻璃与多图 catalog 热切换。

### 2.2 CDP Skin 的产品承诺

社区收敛出的安全叙事高度一致（上游 Windows README、Styler SECURITY、本仓 dual-open / PROJECT）：

1. **不修改** `.asar` / WindowsApps / 代码签名  
2. **仅 loopback** 打开调试端口（典型 9335）  
3. **可逆**：暂停 / restore / 卸快捷方式后回官方外观  
4. **原生控件仍可点**：装饰层不抢鼠标（verify 类脚本常检查 pointer-events）  

### 2.3 用户真实失败模式（驱动架构的「痛」）

本仓 PAIN-POINTS 与 dual-open 已编码的失败模式：

| 失败 | 用户感受 | 架构应对 |
|------|----------|----------|
| 商店磁贴裸启 | 「皮肤坏了」 | 文档 + 任务栏钉；**不**劫持 AUMID（#21） |
| 双 injector / 双产品线 | 样式互盖、端口乱 | ADR 0001 单产品线；watch-only |
| 换肤慢 | 2–3s 体感 | control-plane `/kick` ~45–80ms |
| 发版后路径漂移 | 旧引擎还在跑 | freshness + soft reattach + GC |
| payload 过大 | 注入失败 | catalog 缩略图 + art 硬顶 |
| SmartScreen | 首次不敢点 | #24 文档；签名属长期 |

这些痛点解释了：**为什么本仓「看起来比上游脚本重」**——重在把失败模式产品化，而不是多一个 CSS 文件。

---

## 3. 同类项目全景

### 3.1 上游：Fei-Away/Codex-Dream-Skin

**定位**：开源换肤工具；macOS + Windows；本机 CDP；不改官方安装包。  
**规模**：调研时点约 **11k stars / 1.1k forks**（E3），社区与媒体传播极强。  
**布局（E3）**：顶层 `macos/` · `windows/` · `docs` · presets · agents · `SKILL.md` 等；Windows 侧 `scripts/` 含 install/start/restore/verify/tray/injector 等。  
**Windows 技术要点（E3 README）**：

- 要求：Store 注册的 `OpenAI.Codex`、Node ≥22、PowerShell 5.1+  
- 安装写 `%LOCALAPPDATA%\CodexDreamSkin`（active-theme / themes / state / logs）  
- 默认 CDP **9335**，可 `-Port`  
- 安全：CDP 仅 127.0.0.1；不写 API Key/供应商；恢复只动校验过的进程  
- 图片：16MB、边长与总像素上限（与本仓 injector 预算同族）  
- 验证脚本：loopback 归属、皮肤版本、原生控件仍在、装饰不挡点击  

**与本仓关系**：

- 本仓是 GitHub fork 名下产品线，但 **force-push 重构后零共同历史**（ADR 0002）  
- `vendor/dreamskin` 为只读镜像；promote 人工  
- 上游强：安装叙事、预设精选、双语 README、mac 一等公民、社区 skill  
- 上游弱（相对本仓）：**版本化 runtime 翻页、control-plane 热 kick、包边界测试、doctor freshness 体系**在公开 Windows 脚本叙事中不如本仓显式  

### 3.2 Codex Styler（xuhuanstudio/codex-styler）

**定位**：非官方主题**编辑器 + 皮肤创建器**；自定义 UI、背景、2D companion、一键 restore。  
**技术栈（E3）**：

- monorepo：`pnpm` workspace · Node ≥22  
- `apps/desktop`（Tauri）· `apps/site`（Astro）· `packages/theme-core`  
- 语言：TypeScript 体量最大，辅 Rust / CSS / JS  
- 脚本：`lint` · `typecheck` · `test` · `test:e2e` · `theme:validate` · `package:validate` · lighthouse  

**安全边界（SECURITY.md 摘要，E3）**：

- 关注：主题包任意代码/CSS 执行、路径穿越、解压滥用、挂到非相关浏览器调试目标、**非 loopback CDP 暴露**、诊断日志泄密、更新签名  
- 明确：工具用临时本地调试端口启动已装 Codex；**不把 Codex 本身当成安全边界**；不绕过 Codex 认证  

**质量文化（ROADMAP，E3）**：

- **证据门**而非日历承诺：Reliability → Companion → Creator → Beta Hardening → Usability  
- v1 门槛含：mac 公证、Windows Authenticode、SBOM、双端完整生命周期报告  
- 明确延后：多交互实体、视频背景、WebGL、云同步、Linux  

**可学 / 不可学**：

| 学 | 不学 |
|----|------|
| evidence-gated 发布 | 整仓 Tauri 重写 |
| data-only 主题包（禁脚本/远程 URL） | Companion / Composer 改官方设置 |
| DOM fixture 多场景 | 为 star 做在线商店 |
| SECURITY 报告渠道表述 | 把 pre-1.0 复杂度搬进本仓 |

### 3.3 目录与周边（awesome + topic 检索）

[awesome-codex-themes](https://github.com/mcpso/awesome-codex-themes) 的价值主要是**分类导航**：CLI / App / Skins 三分法，减少 issue 里「为什么不能导入 codex-theme-v1」类噪音。

Topic 检索可见的 CDP/皮肤相关仓（E3，星数会变）：

| 仓 | 约 stars | 备注 |
|----|---------:|------|
| aithink001/Codex-Dream-Skin-Themes | ~17 | Skill/主题安装向 |
| xuhuanstudio/codex-styler | ~14 | Creator |
| fantuan-lab/codex-skin-market | ~5 | 市场/beta 叙事 |
| ChannelerH/codex-skin-packs | ~0 | 安全预览包 + agent install prompts |
| 各类 codex-theme-v1 色板仓 | 低 | **层 B**，不是 CDP |

**启发**：生态已分裂为「内容包 / Skill 安装器 / Creator IDE / 守护运行时」。本仓应坚定站在 **守护运行时 + 可分发产品包**，用文档链到内容生态，而不是自己做市场。

### 3.4 heige 线

历史多主题引擎；独立 GitHub 名 `Heige021/codex-skin` 已 404（E3）。  
能力经 ADR 0001 合入本仓 `packages/themes`（schema 双格式、store、adapter）。  
**残留债**：命名与用户本机旧目录（PAIN #20），不是第二代码树。

### 3.5 横向对比总表

| 维度 | 上游 DreamSkin | Styler | **本仓** |
|------|----------------|--------|----------|
| 平台 | mac+win | mac+win | **win only** |
| 形态 | 脚本安装 + 托盘 | Tauri Creator | 安装态 launcher + CLI + FastLaunch |
| 多主题 | 有保存主题；叙事偏预设 | 编辑器级 | **11 catalog + F6 + apply** |
| 热更新 | 再应用/重启路径 | 应用内生命周期 | **`/kick` ~ms 级** |
| 版本模型 | 安装覆盖 engine | 应用版本 + beta 门 | **`versions/<id>` + current.json + GC** |
| 包边界 | 平台目录脚本 | monorepo packages | **core/themes/runtime/core-win** |
| CI | 社区向 | 重（lint/type/e2e） | 轻（`npm test` themes+deps+freshness） |
| 签名 | 社区安装摩擦 | v1 明文门槛 | #24 已知债 |
| 社区运营 | 极强 | 文档站 + beta | 弱（0 star 远程） |

---

## 4. 本仓：目标、边界、约束

### 4.1 产品目标（成功标准）

来自 PROJECT §1.4 / 运行验收（E2+E1）：

1. Codex 运行时皮肤与 active-theme 一致  
2. 热换肤 kick 路径体感 <100ms 量级  
3. 任意时刻 **一条** watch injector  
4. 安装 runtime 与 `current.json` 对齐 · doctor `fresh=true`  
5. 可回退：GC 留 current+prev · git 可审查  

### 4.2 做 / 不做（硬边界）

| 做 | 不做 |
|----|------|
| 一条 watch injector | 改 asar / WindowsApps |
| CDP 注入 CSS/JS（默认 9335） | macOS 一等公民 |
| 多主题 + F6/托盘/CLI | AUMID 劫持（#21） |
| control-plane `/kick` | 多 injector 并行 |
| publish 自包含 versions | 自动 merge 上游 |
| doctor / smoke / 轻 CI | 云端完整 doctor |
| 产品 zip 分发 | 把 UI 皮肤逻辑塞进 core |

### 4.3 架构约束（违反即拒合）

**依赖（PROJECT §3.2）**：

```text
允许：
  apps/launcher → core-win
  core/cli → core/* · themes/*
  themes → core/constants；动态 → runtime/thumb.mjs
  publish 复制 runtime → versions/<id>

禁止：
  core → runtime 静态依赖
  runtime → core 静态依赖
  core 直接写 active-theme
  业务硬编码绝对路径
  复活 heige --once 常驻旁路
  生产 import vendor/
```

**入口纪律（dual-open-policy）**：

- 日常入口唯一：任务栏 Codex → FastLaunch → open → watch  
- kick 降级 `--once`：**单次**、同树、不暴露给用户 CLI  
- control-plane：POST 需 `x-codex-skin-token`；GET `/health` 开放；**query token 已弃用**  

**版本（ADR 0003）**：

- 唯一写回 git 的版本权威：`publish-runtime.ps1 -Version`  
- Build/Install 只 stamp 包/安装树，不写 git  

**上游（ADR 0002）**：

- 视觉资产：vendor 镜像 → 人 promote  
- PS 修复：只自动发现 commit 标题，人工移植  
- 基线：`docs/upstream-sync.json`  

### 4.4 四层模型（实现映射）

```text
L1 交互   apps/launcher · FastLaunch · 托盘 · F6 · CLI 用户命令
L2 调度   cli.mjs · launcher-ui · control-plane
L3a 状态  state.json · current.json · active-theme · control.* · paused
L3b 主题  packages/themes · themes/*
L4 执行   injector --watch · wait-shell · thumb · core/{cdp,discover} 探测
```

这不是 Web 前后端，但用「交互 / 编排 / 状态·领域 / 副作用」拆分后，**Agent 改码边界**变得可执行（CONTRIBUTING 7 问即服务此）。

---

## 5. 技术栈与模块实现逻辑

### 5.1 技术栈清单

| 层 | 技术 | 说明 |
|----|------|------|
| 运行时逻辑 | Node.js ≥20 ESM（`.mjs`） | **零 npm 生产依赖** |
| Windows 壳 | PowerShell 5.1 兼容 + 开发 pwsh 7 | launcher / publish / ux |
| 任务栏入口 | C# winexe FastLaunch | 独立 AUMID，降冷启动 |
| 视觉 | CSS + renderer-inject.js | CDP evaluate 注入 |
| 协议 | Chrome DevTools Protocol | WebSocket loopback only |
| 测试 | 自写 assert 脚本 | themes / deps / freshness / control |
| CI | GitHub Actions ubuntu | 仅 `npm test`（无 CDP） |
| 分发 | zip + Install.ps1 / publish 安装树 | 双通道：开发 publish vs 产品包 |

### 5.2 包职责与公开面

**`packages/core`**（E2 `index.mjs`）：

- 常量与 `resolveStudioPaths`  
- Codex 发现 / 进程 / CDP 端口探测  
- `kickThemeInjectNow`、`inspectInjectorPathFreshness`、dreamskin 诊断  
- **不写** active-theme、**不做**页面注入  

**`packages/themes`**：

- `validateThemeManifest` / `loadTheme`：双格式（heige colors/hero vs DreamSkin palette/image）  
- 路径：`..` 拒绝 + realpath 逃逸检查  
- `listThemes` dedupe：后 root 覆盖前 root（user > bundled）  
- `writeActiveThemeFromHeige`：原子写 active-theme  

**`packages/runtime`**（自包含发布蓝图）：

- `injector.mjs`：parseArgs · CDP session · theme load · payload 预算 · watch · control-plane 启动  
- `control-plane.mjs`：127.0.0.1 · token · `/health|/kick|/focus|/open-healthy`  
- assets：CSS/JS/种子图  
- **禁止** import core（发布后 versions 无 core）  

**`packages/core-win` + `apps/launcher`**：

- 托盘、焦点、state IO、快捷方式、open/check/switch/smoke  
- 命名：历史 `DreamSkin-*` 冻结；新增 `CodexSkin-*`  

### 5.3 关键运行时路径（逻辑）

#### 冷启动

```text
Codex.lnk / FastLaunch
  → open-codex-dream-skin.ps1
  → launcher-ui（安静 UI / 托盘）
  → 读 current.json → versions/<id>/scripts/injector.mjs --watch
       --theme-dir .../active-theme
       --state-root .../CodexDreamSkin
       --browser-id ...
  → 发现/启动 Codex（CDP 9335）
  → wait-shell → attach
  → startControlPlane(9336)
  → loadPayload → Runtime.evaluate 注入
  → 写 state.json（pid / port / browserId / runtimeId / injectorPath）
```

#### 热换肤

```text
cli apply --theme <id>
  → themes.writeActiveThemeFromHeige
  → kickThemeInjectNow
       → 读 control.token → POST 127.0.0.1:9336/kick
       → 失败则同 runtime injector --once（单次）
  → watch 进程内 stamp 变化则重 loadPayload + apply
```

#### 发布

```text
publish-runtime.ps1 -Version 1.3.25
  → 拷 runtime → versions/<semver>-<hash6>
  → stamp SKIN_VERSION_TOKEN（源+副本）
  → 同步 core-win / 入口脚本 / wait-shell
  → current.json 翻页 + bak
  → GC：current + 上一版
  → 快捷方式
  → 可选 import-themes
  → post-update Quiet（60s）→ 失败则 soft reattach（正式降级）
```

### 5.4 安全与预算（实现要点）

**CDP URL 形状**：仅 loopback host；pathname 限制 devtools page/browser id 模式（injector 内 `validatedDebuggerUrl`）。  
**Token**：`randomBytes(16).toString("hex")` 落盘；比对 `timingSafeEqual`；header only。  
**Payload**：

| 常量 | 量级 | 作用 |
|------|------|------|
| evaluate 预算 | ~4MB | CDP 命令上限意识 |
| MAX_ART_BYTES | 16MB | 活动主题全图硬顶 |
| catalog 条数 | 8 | F6 热目录 |
| catalog 总字节 | 1.6MB | 防个人库撑爆 |
| 单条 catalog | 96KB | 缩略图纪律 |
| 入库图 | 8MB | theme-store 创建时 |

**输出截断**：kick spawn stdout/stderr 8KB cap，防日志爆炸。

### 5.5 状态 schema 三轨（认知税）

| 符号 | 值 | 含义 |
|------|----|------|
| `STATE_SCHEMA_VERSION`（Node） | 1 | **文档/导出 marker**，非磁盘写版本 |
| 磁盘 `state.json` | 写 3，读 1..3 | launcher-ui 规范化 |
| `THEME_SCHEMA_VERSION` | 1 | theme.json |
| `current.json` | schemaVersion 1 | runtime 指针 |

doctor 已暴露 `stateSchema` 顶层字段以降低误用（E1）。

---

## 6. 本仓全面优缺点扫描

### 6.1 优点（应保持）

1. **边界可执行**：依赖规则有 `test:deps` 机器门禁，不是 README 愿望。  
2. **单守护可证明**：dual-open 文档 + 启动清扫 + soft reattach 杀旧 versions injector。  
3. **热路径工程化**：control-plane 把「换肤」从秒级 PS 编排压到毫秒级进程内 apply。  
4. **版本可回退**：`runtimeId` 哈希后缀 + GC + freshness 对齐检测。  
5. **主题域干净**：schema 校验、路径逃逸、dedupe、adapter 与 CDP 解耦。  
6. **零生产 npm 依赖**：供应链攻击面极小；Node 标准库足够。  
7. **诊断友好**：doctor 聚合 discovery / dreamSkin / control / freshness / themeCount。  
8. **文档体系完整**：PROJECT / ARCHITECTURE / ADR / CONTRIBUTING / PAIN / dual-open / 任务卡 / 调研（本文）。  
9. **安全叙事与上游/Styler 同族且已加固**：token + header-only + timingSafeEqual 已进安装树样本 `50fee1`。  
10. **Agent 协作面**：CONTRIBUTING 7 问、任务卡提示词、PR 模板，降低「AI 乱改 injector」概率。  

### 6.2 缺点与风险（应正视）

1. **双巨石文件**：injector / launcher-ui 变更成本高、评审难（有意 trade-off，仍是债）。  
2. **仓 ↔ 安装树延迟**：git 绿 ≠ 用户机器绿；必须 publish 纪律（已写 CONTRIBUTING，靠流程）。  
3. **post-update Quiet 仍可能 exit=2**：现以 soft reattach 正式降级；根因观测仍弱。  
4. **CI 不能证明端到端**：无 Store Codex；回归靠本机。  
5. **DOM/CSS 脆弱**：Codex 改 class → 视觉回归；fixture 文化弱于 Styler。  
6. **签名缺失**：SmartScreen #24；FastLaunch / 脚本首次信任成本。  
7. **社区与内容运营弱**：远程 0 star；预设叙事与截图库不如上游。  
8. **schema 三轨认知税**：新人易把 Node marker 当写版本。  
9. **PS 5.1/7 双运行时**：UTF-8、PSModulePath 历史坑（PAIN #11）。  
10. **上游吸收滞后**：`upstream-sync.json` 基线需人工刷新；视觉机会可能错过。  
11. **公开许可/NOTICE 呈现**：远程 licenseInfo 空；对外部贡献者不友好。  
12. **测试覆盖形状**：themes/freshness/deps/control 有；adapter 写路径、publish 脚本、PS 几乎靠手工。  

### 6.3 非缺点（常被误判为债）

| 表象 | 实质 |
|------|------|
| 不做 mac | 产品边界，不是能力不足 |
| 不 merge 上游 | 结构分叉物理限制 |
| injector 不拆文件 | ADR 与发布拷贝模型 |
| 不把 control 进云 CI | 环境不可复现 |
| token 文件本机可读 | 威胁模型是同用户误触，不是多用户 OS 隔离 |

---

## 7. 架构评估与优化设计

### 7.1 当前架构评分（分项）

| 维度 | 分（/10） | 说明 |
|------|----------:|------|
| 产品边界清晰度 | 9.5 | 做/不做表硬 |
| 分层与依赖 | 9.0 | 有机器门禁 |
| 运行时可靠性 | 8.5 | soft reattach / kick 降级 |
| 安全（宣称威胁模型内） | 8.5 | loopback+token；签名缺 |
| 可观测性 | 8.5 | doctor 强 |
| 可测试性 | 7.0 | 纯函数增；E2E 本机 |
| 可维护性（文件级） | 6.5 | 巨石 |
| 社区/内容 | 5.0 | 运营弱 |
| 跨平台 | 2.0 | 有意 |
| **综合** | **8.4** | Windows 主路径生产可用 |

### 7.2 优化原则（再设计时的「宪法」）

1. **不扩大威胁模型**：任何「更方便」若要求非 loopback CDP 或写 asar → 否决。  
2. **不破坏 runtime 自包含**：themes 可动态 thumb；core/runtime 静态隔离不可破。  
3. **发布路径单一权威**：版本只认 publish `-Version`。  
4. **失败可解释**：doctor reason、kick note、soft reattach 日志分级。  
5. **证据优先于愿景**：对标 Styler gate，不写空 ETA。  
6. **演进式，不推倒**：禁止 monorepo 炫技重写、禁止第二 injector。  

### 7.3 目标架构（演进态，非重写）

```text
                    ┌─────────────────────────┐
                    │  Evidence Pack（文档+脚本）│
                    │  doctor · probe 表 · CI   │
                    └───────────┬─────────────┘
                                │
 L1 入口 ──► L2 编排 ──► L3 状态/主题 ──► L4 runtime
                │                           │
                │         control-plane     │
                └──────── /kick header ─────┘
                                │
                     versions/<id> 自包含树
                                │
                     soft-reattach 正式降级
```

**相对现状的增量**：

| 增量 | 做法 | 不做什么 |
|------|------|----------|
| Evidence Pack | PROJECT §9.4 + 发版勾选 + 可选 probe | 不上云 live CDP |
| Theme contract | schema 拒绝可执行扩展字段；文档 data-only | 不上 companion 运行时 |
| Observability | publish 日志分级（已做 soft reattach OK） | 不上远程 telemetry |
| Maintainability | Region + 纯函数单测继续加厚 | 不拆 injector 多文件 |
| Trust | 评估 Authenticode | 不伪造签名 |

### 7.4 模块级改进建议（可直接开任务卡）

#### M1 · 仓安装一致性（P1）

- **问题**：改 control-plane 后未 publish → 用户仍跑旧鉴权（已在 50fee1 修复过一轮）。  
- **方案**：CONTRIBUTING 检查项（已有）+ 可选 `scripts/windows/verify-install-matches-repo.ps1`：比较安装 `control-plane.mjs` 是否含 `tokensEqual` 与 repo 哈希前缀。  
- **验收**：脚本 exit 0/1；doctor fresh。  

#### M2 · post-update 可观测（P1）

- **问题**：Quiet exit=2 根因是「任一 check 失败」聚合，细节淹没。  
- **方案**：post-update 在 Quiet 模式写 `%LOCALAPPDATA%\CodexDreamSkin\post-update-report.json` 已有则保证 publish 打印 `report.pass` 字段摘要；不改 exit 语义。  
- **验收**：失败时 Host 一行含 failed check 名。  

#### M3 · DOM fixture 最小集（P2）

- **问题**：CSS 选择器无回归网。  
- **方案**：固定 `probe-session-dom.mjs` 关键字表（PROJECT 已链）；维护者发版后手工勾；长期把「无 page / 无 dreamStyle」映射到明确 reason。  
- **不学**：Styler 全量浏览器 E2E 重资产。  

#### M4 · 主题 data-only（P2）

- **问题**：未来主题包若夹带脚本会扩大威胁模型。  
- **方案**：schema `additionalProperties` 策略或显式拒绝 `scripts`/`hooks` 字段；CONTRIBUTING 写死。  
- **对齐**：Styler SECURITY「主题包任意代码执行」条目。  

#### M5 · CI 形状（P2）

- **现状**：`npm test` = themes + deps + freshness。  
- **可加**：文档链接检查（可选）；**不可加**：control-plane 云跑（端口/OS）、doctor。  

#### M6 · 巨石治理（P2，持续）

- injector：保持单文件；新增逻辑优先纯函数 + 单测文件旁挂。  
- launcher-ui：按托盘 / control client / state IO 注释分区；禁止无关重构 PR。  

#### M7 · 上游节奏（P3）

- 双周或跟 upstream release：跑 `sync-upstream-assets.ps1`，更新 `upstream-sync.json`。  
- promote CSS 时强制保留本仓 `SKIN_VERSION_TOKEN` / art null-safety 等覆盖点。  

#### M8 · 信任（P3）

- Authenticode 评估表：成本、证书、CI 签名、SmartScreen 声誉时间。  
- 未签名前 usage 保持「更多信息 → 仍要运行」。  

### 7.5 明确否决的「伪优化」

| 提案 | 否决理由 |
|------|----------|
| 与上游 git merge | 零共同历史 + 目录分叉 |
| core 引入 runtime 共享 CDP 客户端 | 破坏自包含 |
| 多 injector 并行提高「可靠性」 | 样式互盖，历史已证伪 |
| 默认开放非 loopback CDP | 安全边界崩塌 |
| 为追 star 上 mac | 维护面翻倍，非用户目标 |
| 整仓 TypeScript/Tauri 化 | 无迁移收益，回归面 Cosmic |
| 云端遥测换肤使用率 | 隐私与非目标 |

---

## 8. 从同类实现中抽取的「模式库」

### 模式 P1 · Loopback-only CDP Skin

- **定义**：调试端口仅 127.0.0.1；注入可逆。  
- **本仓落地**：CDP 9335 + URL 形状校验。  
- **Styler 强化点**：SECURITY 明确「挂到无关浏览器目标」为漏洞类。  
- **行动**：kick/doctor 文档保持；禁止「支持局域网调试」类需求。  

### 模式 P2 · Data-only Theme Package

- **定义**：主题 = JSON + 光栅图；无可执行载荷。  
- **本仓**：theme.json + hero；schema 校验颜色/路径。  
- **缺口**：未系统性拒绝未来 hooks 字段。  
- **行动**：M4。  

### 模式 P3 · Versioned Engine Tree

- **定义**：运行时以不可变目录版本存在，指针翻页。  
- **本仓**：`versions/<id>` + current.json + GC——**差异化优势**。  
- **上游**：更偏安装覆盖。  
- **行动**：保持；加强 verify-install 脚本。  

### 模式 P4 · In-process Hot Apply

- **定义**：守护进程内二次 apply，避免二次冷启动。  
- **本仓**：control-plane `/kick`。  
- **行动**：保持 token；监控 stamp 短路正确性。  

### 模式 P5 · Evidence-gated Release

- **定义**：发布靠证据清单而非感觉。  
- **Styler**：ROADMAP gates。  
- **本仓**：发版清单 + probe 表 + doctor。  
- **行动**：把清单勾选写进 CONTRIBUTING（部分已有）。  

### 模式 P6 · Formal Degraded Path

- **定义**：主路径失败时有**命名过的**降级，而非静默乱试。  
- **本仓**：kick → `--once`；post-update → soft reattach。  
- **行动**：日志语气已改为正式降级（L1）；用户文档可再露一句。  

### 模式 P7 · Content vs Runtime Split

- **定义**：运行时仓库不承担主题市场。  
- **生态**：skin-packs / themes 仓 / Skill 安装器。  
- **本仓**：内置 11 主题足够；外部内容用 import-themes。  
- **行动**：README 链 awesome，不做应用内商店。  

---

## 9. 威胁模型与合规笔记

### 9.1 资产

- 用户本机 Codex 会话可见性（通过 CDP 理论可达 DOM）  
- control.token（本机文件系统）  
- 主题图（用户内容）  
- 安装树脚本（可被同用户篡改）  

### 9.2 攻击者

| 攻击者 | 能力 | 缓解 |
|--------|------|------|
| 同用户恶意脚本 | 读 token、POST kick、读 CDP | 无法防同用户；token 降误触 |
| 局域网攻击者 | 若错误绑定 0.0.0.0 | **禁止**；仅 127.0.0.1 |
| 恶意主题包 | 超大图 DoS、路径穿越 | 大小上限、路径校验 |
| 供应链 | npm 依赖投毒 | **无生产依赖** |
| 钓鱼安装包 | 假冒 zip | 签名长期项；分发渠道自控 |

### 9.3 明确不宣称

- 不宣称防同用户恶意软件  
- 不宣称 Codex 官方支持  
- 不宣称可修复商店磁贴裸启  

---

## 10. 技术债登记册（可导入任务卡）

| ID | 标题 | 优先级 | 类型 | 建议出口 |
|----|------|--------|------|----------|
| TD-01 | 仓↔安装树一致性校验脚本 | P1 | 工程 | **已落地** `scripts/windows/verify-install-matches-repo.ps1` · CONTRIBUTING C-3 |
| TD-02 | post-update Quiet 失败项摘要日志 | P1 | 可靠性 | M2 |
| TD-03 | 文档基线自动生成（防手改漂移） | P2 | 文档 | 小脚本写 BASELINE.md |
| TD-04 | 主题 data-only 硬拒绝 | P2 | 安全 | M4 |
| TD-05 | adapter/writeActiveTheme 单测 | P2 | 测试 | 纯临时目录 |
| TD-06 | DOM probe 发版勾选纪律 | P2 | 质量 | M3 |
| TD-07 | injector 纯函数继续抽测 | P2 | 可维护 | 不拆文件 |
| TD-08 | 上游双周 sync | P3 | 内容 | ADR 0002 节奏 |
| TD-09 | Authenticode 评估 | P3 | 信任 | #24 |
| TD-10 | 公开 LICENSE/NOTICE 呈现 | P3 | 开源卫生 | 与法务/个人意愿 |
| TD-11 | schema 常量重命名 | P3 | 认知 | STATE_SCHEMA_NODE_MARKER |
| TD-12 | listThemes skipped 计数 | P3 | UX/诊断 | doctor 字段 |

**已关闭勿重开**：SEC-01 token、soft-reattach state-root、test:deps、test:freshness、header-only、G1-B/G3-A/G4-A/G5-C 推荐组合、任务卡 12 张。

---

## 11. 路线图建议（90 天视角）

### 0–30 天

- 推送已合 L0/L1 文档与 CI（若尚未 push）  
- TD-01 一致性脚本  
- TD-02 post-update 摘要  
- 跑一轮 upstream sync 只读报告  

### 30–60 天

- TD-04 data-only  
- TD-05 adapter 测试  
- TD-06 发版 probe 勾选养成  
- 主题/截图叙事小幅加强（学上游预设写法，不扩平台）  

### 60–90 天

- TD-09 签名成本表（决策做/不做）  
- TD-07 巨石旁路单测加厚  
- 评估是否需要 product zip 重建（仅分发时）  

### 明确不排期

- mac 端口、AUMID 劫持、asar、第二 injector、Tauri 重写、云 doctor  

---

## 12. 附录

### A. 本机证据命令（复现调研）

```powershell
cd D:\orca\codex-skin
git rev-parse --short HEAD
node packages/core/cli.mjs doctor
npm test
npm run test:control
Get-Content $env:LOCALAPPDATA\Programs\CodexDreamSkin\current.json
Select-String -Path $env:LOCALAPPDATA\Programs\CodexDreamSkin\versions\*\scripts\control-plane.mjs -Pattern 'tokensEqual|timingSafeEqual'
```

### B. 外部链接（学习入口）

- [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)  
- [xuhuanstudio/codex-styler](https://github.com/xuhuanstudio/codex-styler)  
- [mcpso/awesome-codex-themes](https://github.com/mcpso/awesome-codex-themes)  
- Topic：[codex-skin](https://github.com/topics/codex-skin) · [codex-theme](https://github.com/topics/codex-theme)  

### C. 本仓一级文档索引

- `docs/PROJECT.md` — 总纲  
- `docs/ARCHITECTURE.md` — 调用链  
- `docs/adr/0001|0002|0003` — 合并 / 上游 / 版本  
- `docs/dual-open-policy.md` — 入口与 kick  
- `docs/PAIN-POINTS.md` — 痛点与 SEC 摘记  
- `docs/CONTRIBUTING.md` — PR 与发版纪律  
- `docs/AUDIT-2026-07-20.md` · `docs/SCAN-OPTIMIZE-2026-07-20.md` — 历史审计  

### D. 体量快照（调研时）

| Area | Files | Lines（约） |
|------|------:|----------:|
| packages/core | 15 | 2002 |
| packages/themes | 5 | 716 |
| packages/runtime | 11 | 3740 |
| packages/core-win | 6 | 2905 |
| apps/launcher | 9 | 1868 |
| apps/native | 3 | 414 |
| scripts/windows | 17 | 2404 |
| themes | 11 | 256 |
| docs | 18 | 3351 |

### E. 术语速记

| 术语 | 含义 |
|------|------|
| watch injector | 常驻 `--watch` 守护 |
| kick | POST `/kick` 进程内热应用 |
| soft reattach | 发版后杀旧 injector 并起新 watch |
| freshness | current vs state 的 injector 路径/runtimeId 对齐 |
| active-theme | 当前生效主题目录 |
| CDP Skin | 层 C 运行时注入皮肤 |

---

## 13. 实现深潜：关键路径上的决策与代码事实

本章把「架构图」落到**可点名的文件与行为**，供后续 Agent 或审计者对照，避免调研只停留在口号层。

### 13.1 发现 Codex：为什么 candidates 那么长

`packages/core/discover` 一族要在 Windows 上同时覆盖：

- Store 包多版本并存（本机 doctor 曾同时列出 `26.715.4045.0` 与 `26.715.7063.0`）；  
- `WindowsApps` 与用户目录旁路安装；  
- 可执行名在 `ChatGPT.exe` / `Codex.exe` 间漂移；  
- 是否带 `--remote-debugging-port` 与端口是否真的 open。  

**设计含义**：发现层必须**多候选 + 探测**，不能写死单一路径。这也是「云 CI 跑 doctor」几乎无解的根因——没有用户机器上的 Store 包与真实进程，发现结果不可复现。

**学习对照**：上游 Windows README 要求 `Get-AppxPackage -Name OpenAI.Codex` 且「只接受已注册官方包」——与本仓「不从任意 exe 乱启」一致。Styler 则强调「自动安装发现 + 校验过的自定义路径回退」，本仓可用 doctor 的 `appFound` / `candidates` 长度作为健康信号，而不必照搬 Tauri 设置页。

### 13.2 CDP 会话：身份锚与页面目标

injector 内同时维护：

1. **Browser identity anchor**：连上 browser 级 WebSocket，用于感知浏览器进程是否还活着；  
2. **Page sessions**：筛选 `type===page` 且 `url` 以 `app://` 开头的目标，避免误注入 DevTools 自身或无关页；  
3. **`Runtime.evaluate`**：`awaitPromise` + `returnByValue`，把 CSS/JS 载荷推进渲染进程。  

**约束**：`validatedDebuggerUrl` 拒绝非 loopback、拒绝异常 path、拒绝带 userinfo/query/hash 的 WS URL。这是把「CDP 很强」收成「只碰自家 Codex」的关键闸门。

**风险**：Codex 若改变 page URL scheme 或目标类型命名，筛选会静默变空——表现是「injector 活着但无皮肤」。缓解是 probe/verify 检查 `dreamStyle` 等注入标记，而不是只看进程 pid。

### 13.3 Payload 组装：为什么 catalog 只能缩略图

活动主题需要**全图**才能做构图与氛围；F6 目录若再嵌多张全图，会逼近 CDP evaluate 体量上限（社区与本仓都按约 4MB 命令意识设计）。因此：

- 活动主题：允许较大 art（硬顶 16MB，入库侧更严 8MB）；  
- catalog：条数、总字节、单条字节三重上限；  
- 指纹：`theme.json` + 图像字节的 sha256，用于 stamp 变化检测，避免无意义重注入。  

**与 Styler 对照**：Styler 用「场景模型 layers/entities」描述装饰，本仓用「CSS 变量 + renderer 桥 + art 元数据」。二者都在避免「整页 HTML 重写」。本仓更轻，但也更依赖 CSS 选择器稳定性。

### 13.4 control-plane：为什么是「进程内 HTTP」而不是第二 Node

早期换肤路径若每次 `spawn` 新 node 跑 injector，冷启动与模块加载会吃掉秒级时间（PAIN #1 历史 2–3s）。control-plane 的本质是：

- **与 watch 同进程**提供 HTTP 门面；  
- `/kick` 只做「读 active-theme → 可能重载 payload → 对已有 session apply」；  
- `/health` 给 FastLaunch「是否已健康」快速探测；  
- `/open-healthy` 故意**不**同步 await 焦点，避免把 200ms 超时调用方拖死。  

**Token 的真实作用**：在「本机任意进程都能连 127.0.0.1:9336」的前提下，减少误 kick / 脚本扫端口捣乱。它**不是**多用户 ACL。header-only + timingSafeEqual 是纵深，不是换威胁模型。

### 13.5 kick 降级：`--once` 为什么允许却又不允许

允许：控制面挂了时，用户仍应能换肤（韧性）。  
不允许：用户把 `--once` 当第二守护，或 CLI 暴露双开开关（已删）。

实现上 `kick-inject.mjs`：

1. 解析 state 完整性（port、browserId、themeDir）；  
2. 优先 control-plane 多端口尝试（9336 起一小段）；  
3. 401/错 token 换端口继续试，避免扫到旧残留；  
4. 全部失败再 spawn 同 `current.json` 树的 injector `--once`；  
5. 结果格式化成中文 note，避免 CLI 只丢原始 stderr。  

这是「正式降级路径」教科书实现：有顺序、有超时、有输出封顶、无第二常驻。

### 13.6 主题适配：heige 与 DreamSkin 字段为何并存

历史两套字段名（`hero`/`colors`/`copy` vs `image`/`palette`/`brandSubtitle`）若在注入层分叉，会永久双栈。本仓选择：

- **读入**：`theme-schema` 归一成内部 manifest；  
- **写出 active-theme**：`dream-adapter` 写成 DreamSkin 运行时认识的形状；  
- **列表**：store 扫多 root，id dedupe。  

**优点**：主题作者可继续用任一种习惯字段。  
**代价**：文档必须说清双格式；测试必须双路径（`theme-schema.test.mjs` 已覆盖）。

### 13.7 PowerShell 壳：为什么不能「全改 Node」

Windows 快捷方式、托盘、焦点、Store 包探测、开始菜单、SmartScreen 用户路径，都与 PowerShell / Win32 粘合更紧。Node 适合 CDP 与文件原子写；PS 适合壳。  

**双运行时债**：安装态可能是 5.1，开发是 7。UTF-8 与模块路径问题已在 PAIN 中留下痕迹。优化方向是「入口统一 Initialize-Utf8 + 少依赖 7 独有语法」，而不是强行消灭 5.1。

### 13.8 FastLaunch：独立 AUMID 的产品含义

任务栏分组与商店包 AUMID 绑定。若快捷方式最终仍指向商店 activation，用户点钉可能落到裸 Codex。FastLaunch 用**自己的 AUMID** 占住钉位，再拉起带皮肤的 open 路径。  

**学不到的东西**：任何「让商店磁贴也有皮肤」的需求，在 OS 层无合法第三方解；文档必须反复说。

---

## 14.  upstream / Styler / 本仓：决策对照长表

| 决策点 | 上游 DreamSkin | Codex Styler | 本仓选择 | 评价 |
|--------|----------------|--------------|----------|------|
| 是否改 asar | 否 | 否 | 否 | 三方一致，正确 |
| CDP 绑定 | loopback | 临时本地端口 | 9335 loopback | 一致 |
| 平台 | mac+win | mac+win | win only | 本仓有意收缩 |
| 多主题 | 托盘保存/切换 | 编辑器+包 | catalog+F6+CLI | 本仓偏运行时完备 |
| 热更新 | 再应用/重启 | 应用内更新实体 | `/kick` | 本仓最强 |
| 版本 | 安装覆盖 | 应用 semver+beta | versions 树+hash | 本仓最强 |
| 主题包安全 | 图片上限+校验 | data-only 强调 | schema+路径+大小 | 可再学 data-only |
| 测试 | verify 脚本 | lint/type/e2e/fixture | 自写 node 门禁 | Styler 最重 |
| 签名 | 社区摩擦 | v1 门槛 | #24 债 | 均未完全解决 |
| 上游同步 | N/A | N/A | vendor+人工 | 本仓特有 |
| 社区运营 | 极强 | 文档站 | 弱 | 本仓短板 |
| Agent 友好 | SKILL.md | 文档站 | PROJECT+任务卡 | 本仓强于多数 fork |
| 依赖 | Node 脚本 | 重 monorepo | **零 npm prod** | 本仓独特优势 |

**解读**：若目标是「星标与安装转化」，学上游运营与预设；若目标是「长期可维护的本机守护」，守本仓 versions+kick；若目标是「让普通用户自己造皮肤」，那是 Styler 的题，不应硬塞进本仓 runtime。

---

## 15. 场景化走查：从用户故事到模块

### 15.1 新用户首次安装产品 zip

1. 解压 → `Install.ps1` → 写 programRoot / stateRoot / 快捷方式；  
2. SmartScreen 可能拦截（#24）→ 文档指引；  
3. 点任务栏 Codex → FastLaunch → open → watch；  
4. 若未 import 主题，catalog 可能空 → install/publish 常带 import；  
5. 成功标准：有皮肤、doctor 日后 `fresh`（开发机）或至少 injectorAlive。  

**改进点**：安装结束页/使用说明强调「不要用商店磁贴」；签名前保持文案。

### 15.2 老用户换肤

1. 托盘 / F6 / `apply --theme`；  
2. 写 active-theme；  
3. kick 200 → 视觉更新；  
4. 若 kick 失败 note 提示 CDP 未开或 paused。  

**改进点**：paused 状态在托盘与 CLI 的可发现性；错误文案保持中文短句。

### 15.3 维护者改 CSS 后发版

1. 改 `packages/runtime/assets`；  
2. **必须** `publish-runtime.ps1 -Version 1.3.25`（产品线号可不抬）；  
3. soft reattach 或用户重点 Codex；  
4. doctor fresh；可选 probe-session-dom；  
5. git 可见 stamp。  

**失败模式**：只 commit 不 publish → 用户仍旧 CSS。CONTRIBUTING 已强调。

### 15.4 商店更新 Codex 后

1. 包路径变、可能丢调试参数；  
2. post-update / 皮肤修复入口；  
3. 可能 Quiet 非 0 → soft reattach；  
4. 仍失败 → 文档「完全退出再点任务栏 Codex」。  

**改进点**：TD-02 让失败 check 名可见。

### 15.5 双开诱惑（历史 heige）

用户若仍留着旧 heige 快捷方式，可能启动第二注入。本仓删除 legacy-inject、ux 扫删 lnk、文档 PAIN #20。  
**残余**：用户目录手工拷贝的旧脚本无法代码消灭，只能文档与 doctor 提示。

---

## 16. 测试与质量策略：现状与目标态

### 16.1 现状金字塔

```text
        /  手工 smoke·probe·真机  \     ← 窄但真实
       /  control-plane 本机测试    \    ← 不进 CI
      /  freshness 纯函数            \   ← 已进 npm test
     /  theme-schema + 11 loadTheme   \  ← CI
    /  check-package-deps              \ ← CI
```

### 16.2 目标态（不增加云 CDP）

- **保持**金字塔底层机器门禁；  
- **加厚**纯函数（freshness 已做；adapter、payload 预算校验可做）；  
- **固化**发版手工层为勾选表（PROJECT §9.4）；  
- **拒绝**「为了像 Styler 而上一整套 Playwright 云矩阵」——环境不对。  

### 16.3 质量属性场景

| 属性 | 如何证明 | 缺口 |
|------|----------|------|
| 正确性 | themes 测试 + 真机 apply | adapter 单测 |
| 安全性 | token 测试 + 路径测试 | 主题包恶意字段 |
| 性能 | kick 历史计时 | 无持续基准 |
| 可恢复 | soft reattach | Quiet 失败明细 |
| 可维护 | ADR + deps 门禁 | 巨石文件 |
| 兼容 | Store 多版本 candidates | DOM 变更 |

---

## 17. 运营与开源策略（可选，不影响核心架构）

### 17.1 若保持私有维护向

- 继续 0 star 无妨；文档服务未来自己与 Agent；  
- 产品 zip 走 Release；  
- 不把时间花在徽章与官网。  

### 17.2 若希望被社区看见

- README 三层换肤表 + 清晰「Windows CDP Skin」徽章式一句话；  
- LICENSE 元数据可被 GitHub 识别；  
- 与 awesome 目录建立 PR 链接（若接受外部流量）；  
- **不要**为流量承诺 mac。  

### 17.3 内容策略

- 内置 11 主题足够演示；  
- 优秀预设可学上游「源图 vs 预览图」版权话术；  
- 外部包走 import，不建应用内商店（避免审核与恶意包）。  

---

## 18. Agent 协作手册：怎么改这个仓才不会拆家

### 18.1 开干前强制阅读顺序

1. `docs/PROJECT.md` §1–§3  
2. `docs/dual-open-policy.md`  
3. 相关 ADR  
4. 目标模块 `index.mjs` 或文件头边界注释  

### 18.2 任务卡最小字段

目标 / 完成范围 / **不做的事** / 模块边界 / 验收命令。  
缺「不做的事」的任务卡，默认危险。

### 18.3 高危改动清单（需人批准）

- injector 主循环、session 生命周期  
- control-plane 鉴权  
- publish GC 与 current 翻页  
- FastLaunch AUMID  
- 任何「方便一下」的非 loopback  

### 18.4 安全改动清单（Agent 可默认做）

- 文档基线、GLOSSARY、PAIN 状态  
- 纯函数单测  
- 主题 JSON 与资源（经 schema）  
- CONTRIBUTING 检查项  

### 18.5 完成后的证明

至少：`npm test`；若动 runtime：`publish` + doctor fresh；若动 token：`test:control`；若动主题：`test:themes` + 一次 apply。

---

## 19. 架构优化方案库（多方案对比）

对每个真问题给 **≥2 方案**，避免「只有重构一条路」。

### 19.1 问题：injector 太大

| 方案 | 做法 | 收益 | 成本 | 风险 | 推荐 |
|------|------|------|------|------|:----:|
| A 维持单文件+Region | 现状加强注释/纯函数 | 发布简单 | 阅读仍累 | 低 | **是** |
| B 拆多文件同目录 | publish 拷贝列表扩展 | 阅读好 | 易漏拷贝 | 中 | 否 |
| C 构建打包成单文件 | esbuild 出 injector | 源可拆 | 工具链+调试难 | 中高 | 否 |

### 19.2 问题：仓与安装树不一致

| 方案 | 做法 | 推荐 |
|------|------|:----:|
| A 文档纪律 | CONTRIBUTING 必 publish | 已做 |
| B 校验脚本 | 比关键文件哈希/标记 | **下一步** |
| C 开发模式直指 repo runtime | 安装树 symlink | 高风险，否 |

### 19.3 问题：DOM 易碎

| 方案 | 做法 | 推荐 |
|------|------|:----:|
| A 发版 probe 勾选 | PROJECT 表 | **是** |
| B 选择器配置化 | 外置 selectors.json | 可远期 |
| C 整页截图 AI 对比 | 重 | 否 |

### 19.4 问题：SmartScreen

| 方案 | 做法 | 推荐 |
|------|------|:----:|
| A 文档 | 仍要运行 | 已做 |
| B EV/OV 签名 | 买证+管密钥 | 评估后 |
| C 仅商店分发 | 不适用 CDP 工具 | 否 |

### 19.5 问题：想吸收上游新视觉

| 方案 | 做法 | 推荐 |
|------|------|:----:|
| A sync 脚本+人工 promote | ADR 0002 | **是** |
| B 定期 git subtree | 结构不匹配 | 否 |
| C 放弃本地覆盖盲合 | 丢 token/null-safety | 否 |

### 19.6 问题：测试不够

| 方案 | 做法 | 推荐 |
|------|------|:----:|
| A 加纯函数单测 | freshness 模式复制 | **是** |
| B 云端起 Codex | 不可行 | 否 |
| C 只靠人工 | 现状补充 | 不够 |

---

## 20. 九十天执行看板（可打印）

| 周 | 主题 | 产出 | 验收 |
|----|------|------|------|
| 1 | 文档与 CI 已合项推送 | origin 同步 | git status clean vs origin |
| 2 | TD-01 安装一致性脚本 | `verify-install-matches-repo.ps1` | 故意改安装文件能检出 |
| 3 | TD-02 post-update 摘要 | publish 日志含 failed checks | 人为制造 Quiet 失败可读 |
| 4 | 上游 sync 只读 | 更新 note 或确认 nothing | upstream-sync.json 日期新 |
| 5–6 | TD-04 data-only | schema 拒绝危险字段 | 单测 |
| 7 | TD-05 adapter 测试 | 临时目录写 active-theme | npm test |
| 8 | 发版演练 | publish + probe 勾选 | fresh + 表勾完 |
| 9–10 | 巨石旁路单测 | payload 预算纯函数 | 覆盖关键分支 |
| 11 | 签名评估一页纸 | 做/不做决策 | 写入 PAIN #24 |
| 12 | 复盘 | 更新本文附录状态行 | 调研修订记录 |

---

## 21. 反模式手册（见到就停）

1. **「顺便支持一下 mac」** — 边界破裂。  
2. **「把 core 和 runtime 合成一个包省事」** — 发布模型崩。  
3. **「再挂一个 injector 做备份」** — 双开地狱回归。  
4. **「CDP 绑 0.0.0.0 方便手机调」** — 安全事故。  
5. **「主题里放一段 JS 钩子更灵活」** — 主题变攻击面。  
6. **「cloud doctor」** — 假绿或永久红。  
7. **「merge upstream 同步」** — 冲突宇宙。  
8. **「重写 Tauri 一次到位」** — 一年无皮肤。  
9. **「批量重命名 DreamSkin 函数」** — 安装态爆炸。  
10. **「只改 git 不 publish」** — 用户无感，你以为修了。  

---

## 22. 术语与概念扩展（调研用）

| 概念 | 详细说明 |
|------|----------|
| **CDP** | Chrome DevTools Protocol，经 WebSocket 控制渲染进程；Electron/Chromium 系应用可在开启远程调试时接入。 |
| **loopback** | 仅本机回环地址可达，不暴露到局域网。 |
| **active-theme** | 当前生效主题目录；watch 监视其变更。 |
| **catalog** | 用户可切换的主题库；注入时只带缩略信息。 |
| **runtimeId** | `semver-hash6`，标识一次 publish 产物。 |
| **freshness** | 安装指针与正在跑的 injector 是否同一产物。 |
| **kick** | 控制面热应用，非进程重启。 |
| **soft reattach** | 发版后软切换守护进程，尽量保留 browserId。 |
| **FastLaunch** | 原生快速入口，优化任务栏体验与 AUMID。 |
| **heige** | 历史多主题引擎名，现为字段/能力遗产。 |
| **DreamSkin** | 上游产品与安装目录品牌名，本仓沿用 state 路径。 |
| **Appearance 主题** | 官方色板导入，层 B，非本仓。 |
| **data-only 包** | 仅数据与资源，无可执行逻辑。 |
| **evidence gate** | 用可出示证据决定是否发版，而非日期。 |

---

## 23. 结语

Codex 桌面换肤赛道在 2026 年已经**分层清晰**：官方 Appearance 解决色板，CDP Skin 解决氛围与布局装饰，CLI 主题是另一条产品线。上游 DreamSkin 证明了**内容与安装叙事可以爆发**；Styler 证明了**Creator 与证据门可以产品化**；本仓则在 **Windows 守护运行时的版本化、热更新与可诊断性**上走出了可辩护的分叉。

下一步最优策略不是「重新做一个更像 star 的仓」，而是：

1. **守住**单 injector · runtime 自包含 · 单一版本源 · 不碰 asar/AUMID；  
2. **偷师** Styler 的证据门与 data-only、上游的预设叙事；  
3. **还债** 仓安装一致性、post-update 可观测、DOM/主题合同；  
4. **拒绝** mac 扩面、双守护、merge 幻想与重写冲动。  

调研若只开出「重构」处方，是失败的；本报告开出的是**可否决、可验收、可排期**的组合。架构优化的终点不是更漂亮的盒子图，而是：用户点任务栏 Codex 时皮肤在、换肤快、发版可回退、出问题 doctor 说得清、Agent 改码前知道边界。

**代码可以继续交给 Agent；边界、证据与否决权必须留在人与 ADR。**

---

## 24. 附录：FAQ 与决策树

### 24.1 常见问题（维护者 / Agent）

**Q1：为什么不能直接 `git pull` 上游并合并？**  
因为本仓 `main` 在产品线合并时以重构树 force-push，与上游**零共同历史**，目录从 `windows/macos` 变为 `packages/apps`。强行 merge 只会制造无法审的冲突。正确姿势是 ADR 0002：镜像资产、人工 promote。

**Q2：为什么 injector 不拆成十个文件更好维护？**  
发布模型是「拷贝 runtime 树到 `versions/<id>`」。多文件可以做，但必须同步维护拷贝清单与安装态一致性测试；漏一个文件就是用户机器上的幽灵 bug。ADR 0001 选择单守护文件换发布确定性。维护性通过 Region 注释与纯函数单测补，而不是先拆。

**Q3：control.token 会不会被别的软件偷走？**  
同用户下任何进程理论上可读 `%LOCALAPPDATA%`。token 的目标是防**误触与脚本乱扫端口**，不是防恶意同用户软件。若威胁模型升级到「防同用户恶意」，需要 OS 级隔离或独立用户，已超出换肤工具范围。

**Q4：为什么 CI 只跑 `npm test`？**  
因为 themes/deps/freshness 不依赖 Codex 进程；doctor、kick、probe 依赖 Store 包与本机 UI。把后者塞进 GitHub ubuntu runner 只会得到永久失败或假跳过。正确分层：云上契约测试，本机行为测试。

**Q5：产品线版本 1.3.25 不涨，但 runtimeId 一直变，用户怎么理解？**  
`1.3.25` 是产品线/营销与兼容叙事；`1.3.25-50fee1` 是一次 publish 产物指纹。doctor 与 `current.json` 认后者。发版说明应写「产品线不变，引擎构建更新」。

**Q6：和官方 Appearance 会不会冲突？**  
可能叠层。皮肤应尽量用可逆 DOM/CSS 注入，并提供暂停/恢复。官方色板与 CDP 背景同时开启时，以实机为准做兼容，而不是宣称互斥锁。

**Q7：能否支持 Linux？**  
非目标。Linux 上 Codex 分发形态、路径、快捷方式与签名假设全变；要做就单独立项与 ADR，不得偷偷塞进 Windows 产品线。

**Q8：Agent 改了 control-plane 如何自证？**  
`npm run test:control` 必须绿；若影响安装用户，还需 publish 后对安装树 `Select-String tokensEqual` 与 doctor fresh。只提交 git 不等于用户已修好。

### 24.2 决策树：接到一个「需求」时

```text
需求进入
  ├─ 是否要求改 asar / 劫持 AUMID / 非 loopback CDP？
  │    └─ 是 → 拒绝并引用 PROJECT 不做表
  ├─ 是否要求 mac 一等公民？
  │    └─ 是 → 拒绝或另立研究仓
  ├─ 是否只改主题资源/文案/文档？
  │    └─ 是 → 走 themes 测试 + 文档链接检查
  ├─ 是否改 packages/runtime？
  │    └─ 是 → 必须计划 publish 与安装验收
  ├─ 是否改 core ↔ runtime 依赖方向？
  │    └─ 是 → 拒绝（除非新 ADR）
  ├─ 是否引入 npm 生产依赖？
  │    └─ 是 → 默认拒绝；要做需供应链评估
  └─ 否则 → 写任务卡（含不做的事）→ 实现 → npm test → 按模块补 doctor/probe
```

### 24.3 决策树：发版是否就绪

```text
代码已合 main？
  ├─ 否 → 先合
  └─ 是 → npm test 绿？
         ├─ 否 → 停
         └─ 是 → 若动 runtime：publish -Version <line>
                → doctor fresh=true？
                → control 标记（若安全相关）在安装树？
                → 可选 probe 表勾选
                → CHANGELOG / 基线行更新
                → 需要分发？ Build-ProductPackage
                → 需要远程？ push（workflow 注意权限）
```

### 24.4 与 Styler「证据门」的映射

| Styler 概念 | 本仓近似物 | 差距 |
|-------------|------------|------|
| Gate：可靠性基础 | soft reattach、kick 降级、state 完整性 | 缺系统化设备报告模板 |
| Gate：包校验 | theme-schema、deps | 缺 package archive 格式 |
| Gate：E2E/截图基线 | probe-session-dom 手工 | 无自动截图对比 |
| Gate：签名 | PAIN #24 文档 | 无 Authenticode |
| Gate：双端生命周期 | 仅 Windows | 有意 |

目标不是抄全 Styler 门，而是把「我们声称支持的 Windows 主路径」每条都有**可出示证据**。

### 24.5 研究局限（诚实声明）

1. 未能在本环境直接 `WebFetch` github.com 页面，元数据以 `gh api` 为准，README 为抽样而非全文法律审阅。  
2. 未对 Styler 源码做逐文件审计，架构判断来自公开 README/ROADMAP/SECURITY/目录。  
3. 未做用户访谈；痛点来自本仓 PAIN 与运行日志经验。  
4. 星标与 fork 数会随时间变化，引用时请重查。  
5. 安装态 runtimeId 以读者机器 doctor 为准，文中样本会过期。  

### 24.6 建议的后续产出物（非本文范围）

- 一页纸《发版证据清单》可打印版  
- `verify-install-matches-repo.ps1`  
- 主题包威胁建模短文（可放 `docs/security/`）  
- 上游视觉 diff 季度回顾  

---

## 25. 案例推演：三次「看起来像需求、其实是边界」的对话

下列对话压缩自真实维护场景，用来训练「先边界、后方案」的肌肉记忆。

### 25.1 「能不能做成自动跟随系统深色模式的动态皮肤？」

**表面需求**：系统一切深色，皮肤自动换一套。  
**边界检查**：可以做「读系统主题并切换 catalog 中的另一套 id」，但这是**产品功能**，不是架构升级；必须仍走 active-theme + kick，不得在渲染进程里驻留第二套轮询脚本造成性能债。  
**推荐实现**：托盘/设置里提供「跟随系统」开关 → launcher 读注册表或 .NET API → `apply --theme` 已有 id → kick。  
**明确不做**：在 injector 内每秒探测系统主题；为跟随系统引入云配置。

### 25.2 「上游 star 很多，我们要不要 rebase 回去？」

**表面需求**：同步社区。  
**边界检查**：rebase/merge 在物理上不可行（零共同历史）。  
**推荐实现**：跑 sync 脚本看 CSS diff；有价值的视觉点人工移植；README 诚实写 fork 关系与差异。  
**明确不做**：为了 star 数字强行对齐目录结构。

### 25.3 「用户希望商店磁贴也能带皮肤」

**表面需求**：入口统一。  
**边界检查**：AUMID 与商店 activation 是 OS 合约，第三方改写即高风险且通常不可行。  
**推荐实现**：强化任务栏钉教育、FastLaunch 体验、裸启时尽量 reattach。  
**明确不做**：劫持、补丁商店包、注册表魔改当默认解。

这三则的共同点是：**拒绝不是无能，而是保护已经验证的成功标准**。成功标准写在 PROJECT 里——皮肤可见、kick 快、单 injector、fresh、可回退——任何需求若破坏其中一条，必须升级为 ADR 讨论，而不是 silent 合入。

---

## 26. 指标建议：什么叫「变好了」

没有指标的架构优化会变成品味之争。建议只盯**可测、少而精**的指标。

| 指标 | 基线思路 | 采集方式 | 目标方向 |
|------|----------|----------|----------|
| kick 延迟 | 历史 45–80ms | 控制面响应 `ms` 字段 | 不回退到秒级 |
| doctor fresh 率 | 发版后应为 true | 发版检查单 | 100% 发版后 |
| 双 injector 事件 | 应为 0 | 进程扫描 / 用户报告 | 保持 0 |
| CI 契约测试 | themes+deps+freshness | Actions | 保持绿 |
| 安装树与仓关键标记一致 | tokensEqual 等 | 校验脚本 | 发版后一致 |
| post-update 需人工介入次数 | soft reattach 后仍失败 | 日志 | 趋降 |
| 文档基线漂移天数 | 手改易旧 | 日历 | 趋降 |
| SmartScreen 客诉 | 定性 | 用户反馈 | 签名后观察 |

**不要**把 star 数、主题包数量、代码行数当核心 KPI——它们不直接服务成功标准。

---

## 28. 综论：我们到底在优化什么

把全文收束成一句可执行的价值主张：

> 在不破坏官方签名、不扩大网络暴露面、不引入第二守护进程的前提下，让 Windows 用户用可预期的入口获得可回退的氛围级皮肤，并让维护者与智能体在清晰边界内持续改动。

这句话里每一个从句都对应一条否决权：

- 「不破坏官方签名」否决 asar 与商店包补丁；  
- 「不扩大网络暴露面」否决非回环调试端口；  
- 「不引入第二守护」否决并行 injector 与历史 heige 常驻；  
- 「可预期的入口」否决默许商店磁贴作为主路径；  
- 「可回退」要求版本树与恢复路径存在；  
- 「氛围级」区分于官方色板导入；  
- 「清晰边界」要求文档与机器门禁同时存在。  

同类项目教给我们的，不是「谁星星多就抄谁的目录」，而是：

1. 上游证明了**内容与安装故事**能打动海量用户；  
2. 样式编辑器类项目证明了**证据门与主题包安全合同**能支撑更复杂产品；  
3. 本仓已经证明了**版本化引擎与热应用控制面**能把换肤从玩具做成可运维运行时。  

三者叠加的最优解，是本仓继续做「运行时与发布」的深井，用文档和导入协议连接内容生态，用证据清单吸收编辑器类项目的质量文化，而不是把自己摊成又一个样样都有一点的二流复刻。

技术债允许存在，但必须**命名、分级、可拒绝**。匿名的「以后重构」不是债，是借口。本文登记的条目都可以变成任务卡；登记之外的大重构默认不受理。

最后，关于「万字调研」的用途：它不是为了陈列在仓库里好看，而是为了在三个月后、换一个智能体会话时，仍然能回答——我们为什么是现在这个形状，以及什么叫变好。若它不能减少错误合并，就应被修订，而不是被供奉。

---

## 30. 收束清单：读完本文后应带走的十条

1. 赛道分三层：终端语法主题、官方色板导入、本机调试协议皮肤；本仓只做第三层。  
2. 上游明星项目证明内容与安装叙事的力量，不证明应当放弃版本化引擎。  
3. 样式编辑器类项目证明证据门与数据仅主题包的价值，不证明应当整仓重写成桌面套件。  
4. 本仓护城河是单守护、版本目录、热应用控制面与诊断聚合，不是星星数量。  
5. 硬边界包括不改安装包、不劫持应用用户模型标识、不开放非回环调试、不恢复双守护。  
6. 与上游不能合并历史，只能镜像资产并人工提升；把合并幻想当任务会空耗。  
7. 技术债必须命名分级；双巨石文件是有意代价，应用测试与分区注释治理而非盲目拆分。  
8. 云上持续集成只适合契约测试；真实注入与诊断留在装有官方应用的本机。  
9. 发版证据至少包括测试绿灯、如改运行时则发布到安装树、诊断新鲜度为真、可选会话探测勾选。  
10. 智能体可以写代码，但边界、证据与否决权必须留在人与架构决策记录。  

若只能记一句：先约束，后生成；先架构，后界面；先验证，后合并。

---

## 31. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-07-21 | 初版：同类对照、本仓优缺点、架构优化 |
| 2026-07-21 | 扩写实现深潜、对照长表、场景、方案库、看板、反模式、问答决策树 |
| 2026-07-21 | 再扩案例、指标、综论与收束清单；汉字近万、含标点阅读单位一万以上 |

*全文完。请以本机诊断与版本指针为准更新文首状态样本；需要对外可见时再写入变更日志。*
