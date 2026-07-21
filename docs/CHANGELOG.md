# Codex Dream Skin — Changelog

> 由 12 份 `release-1.3.*.md` + `m2-status.md` + `m3-status.md` +
> `optimization-best-path.md` + `ux-improvements.md` + `all-launchers-skinned.md`
> 合并；每版一个小节，从新到旧。

---

## Unreleased — maintenance on 1.3.25 product line（2026-07-20 → 07-21）

> 产品线版本仍为 **1.3.25**；安装态 runtimeId 以 doctor 为准（例 `1.3.25-107b0e`）。下列为扫描落地 + 任务卡收口，**未**改 SKIN_VERSION 产品线号。

### UX（U3 / U4）

- **U3 换肤成功轻反馈**：`Show-CodexSkinApplyFeedback` + `ui-prefs.json`（`applyBalloonEnabled`，默认真）；托盘菜单可关；换肤面板 / 托盘切换 / CLI `apply` 统一尊重开关；托盘切换补 control-plane kick。
- **U4 首次入口提示**：`Show-CodexSkinFirstRunGuide` 文案强化「任务栏 Codex / 勿商店磁贴」；`first-run-shown.flag` 一次性；**不**劫持 AUMID。
- **B 可读性门禁**：`validateThemeManifest` 对 `text`/`surface` 做对比度启发式（≥4.5）；`test:themes` 含低对比拒绝夹具；11 套内置主题实测通过。
- **视觉回归（开项目不闪白）**：`renderer-inject` 用 palette.surface 亮度强制 dark/light；`appearance:auto` 缺省回落 dark；路由短暂无 `main` 时**不清皮肤**。**根因补丁**：`injector.loadTheme` 此前只透传 `palette.accent`，`surface/text/secondary` 未进 CDP payload → surfaceLuma 无效、暗色主题仍挂 `dream-theme-light`；现全量透传四色。本机 CDP 探针 `probe-white-flash.mjs`：**pass**（dark · body oklab≈0.19 · surfaceLuma≈0.105）。
- **项目页高清皮肤**：提高 `--dream-task-ambient-opacity`、降低 task immersive 洗白；宽图 task 用 cover 而非「条带 + 低透明度」，对齐上游展示图沉浸感（编码可读仍靠左侧 gradient）。
- **消息气泡双模式**：`borderless`（默认无边框）/ `card`（圆角卡片描边）；`ui-prefs.bubbleStyle` + 托盘切换 + inject 进 payload。
- **#25 F6**：探针确认无 `cycleTheme`；`usage.md` / `PAIN-POINTS` 对齐「请用托盘/面板/CLI」。
- **调研 v5**：`docs/research/2026-07-21-master-research-v5-visual-sync-and-next.md` + PROJECT 索引。
- **BASELINE**：随 HEAD / 安装 runtime 脚本刷新。

### 安全与控制面

- **SEC-01**：control-plane mutating POST 强制 `x-codex-skin-token`；GET `/health` 免 token；kick-inject / launcher-ui 自动带 token。
- **TEST-02**：`packages/runtime/scripts/control-plane.test.mjs`（本机 9347+；不进 CI）。
- **doctor**：顶层 `control: { port, tokenPresent }` · `stateSchema` 三件套标记。

### 可靠性 / 发布

- **soft-reattach.ps1** 共享；`--theme-dir` + `--state-root`；publish G5-C 超时 fallback。
- **seed art** 动态 fallback（不再钉死已 GC 的旧 runtimeId）。
- **test:deps** + CI themes-gate 第二步。

### 文档与工程纪律

- **CONTRIBUTING.md** §C-1–C-9 · PR 模板 · 任务卡 `docs/plans/task-cards-2026-07-21.md` · 维护 Agent 提示词。
- AUDIT/SCAN 基线校准 · PAIN #24 SmartScreen · GLOSSARY 扩展 · WIN-02 冻结表 · residual G5-C 行号反向链接。
- injector TOC/Region 注释；SKIN_VERSION stamp 注释澄清。

---

- **v6 调研**：[`research/2026-07-21-master-research-v6-palette-root-and-hd-bubble`](./research/2026-07-21-master-research-v6-palette-root-and-hd-bubble.md)（闪白根因补丁 `48b5bae` 全量透传 palette 四色 + HD art + 气泡双模式 `0326abb` + v5 假关闭教训 + BASELINE）+ [overview.md](./overview.md) 挂链 + PROJECT 索引。
- **v6 合入**：PR #1 squash → main `b80bf4e`；themes-gate PR/main 双 success（仅 `npm test`）。
- **v7 门禁收口**：[`research/2026-07-21-master-research-v7-gate-hygiene-and-ux`](./research/2026-07-21-master-research-v7-gate-hygiene-and-ux.md) · `probe-project-hd.mjs` 改为断言型（`pass`/`failed`/exit 1·2，镜像 white-flash）· RELEASE-EVIDENCE 记 CI URL · BASELINE 刷新 · overview/PROJECT 索引 · `surfaceLuma` 仅 `#rrggbb` 边界（ARCHITECTURE 已述）。

---

## 1.3.25 — multi-theme catalog + shortcut UX · 1.3.25-4dca30

### 主题 catalog（11 bundled）

- **preset 入库**：`themes/preset-arina-hashimoto/`（hero.jpg + heige schema + copy/art/palette），`import-themes` 覆盖默认 DreamSkin 主题。
- **schema 双格式透传**：`loadTheme` / `validateThemeManifest` 同时接受 heige（`hero`/`colors`/`copy`）与 DreamSkin catalog（`image`/`palette`/`brandSubtitle`/`tagline`/`art`），避免从用户 catalog 再 `apply` 时冲空 palette。
- **adapter 圆整**：`heigeManifestToDreamSkin` 保留 statusText / project* / art / 完整 palette；`import` 写 `thumb` 字段时跟真实文件名（`thumb.jpg` 或 `thumb.webp`）。
- **内置 10 套补 copy/art**：每套有 tagline + 构图 focus，不再全是空 tagline + 通用默认 art。
- **runtime assets theme.json**：默认 preset 补 palette，与 bundled 源一致。
- 验证：`import-themes` 11/0 · `list` 11 · apply genshin-night / preset 二次 round-trip palette 非空 · kick ~55–79ms · doctor fresh · published `1.3.25-4dca30`。

### 快捷方式与入口纪律（PAIN #18 / #20 / #21）

- **`install-ux-shortcuts.ps1` 唯一源**：日常 = Codex / ChatGPT / Codex 换肤；工具只进开始菜单 **Codex 工具**（皮肤修复 · 商店更新后修复 · 使用说明）；桌面不再放修复类入口。
- **清理误导项**：重复 `Codex Skin.lnk`、旧「Codex Skin 高级」、散落的管理/回归顶层项、名称含 heige / Codex Studio 的残留 lnk。
- **`refresh-shortcuts.ps1`** 改为转发到 install-ux（避免两套布局打架）。
- **#21 文档化**：商店磁贴/包 AUMID 裸启为 OS 硬限；`usage.md` + `dual-open-policy.md` 写清「只用任务栏钉」；FastLaunch AUMID=`CodexDreamSkin.FastLaunch`。
- **#20**：仓内 heige 入口已清；ux 扫删 heige/Studio lnk；Programs 独立 heige 目录仍须用户手卸。

### 产品包（终端用户分发）

- **`Build-ProductPackage.ps1`** → `dist/CodexDreamSkin-<ver>-win-x64.zip`（含 11 主题 + runtime + CLI + FastLaunch + `launch-switch-theme.vbs` + usage 文档）。
- **`Install.ps1` / `Uninstall.ps1`**：写 `Programs\CodexDreamSkin` + 导入主题 + 快捷方式；安装后 **soft reattach** 已运行 injector 到新 runtime + versions GC（current+上一版）；卸载清理 #18 全套入口（Codex/ChatGPT/换肤/Codex 工具/Startup），默认可保留用户 catalog。
- **版本权威（ADR 0003）**：`-Version` 或已 stamp runtime token / package-meta / payload `VERSION`；**禁止**硬编码默认；只 stamp **payload/install-tree**，git tree 写回仍只走 `publish-runtime.ps1`。
- **runtimeId**：内容哈希 6 位（injector+renderer+VERSION），同包可复现。
- 验收：Install exit 0 · doctor fresh · package CLI apply · STRUCTURAL_PASS。

### 残差加固（G1-B / G3-A / G4-A / G5-C · 规划落地）

- **G1-B CI**：`.github/workflows/themes-gate.yml` 在 push/PR 跑 `npm run test:themes`（轻量；**不是**云端 doctor）。
- **G3-A**：文档钉死 **Windows only**；macOS 永久非目标。
- **G4-A**：#21 预期管理加强（usage / dual-open：不劫持商店 AUMID；成功标准=会用任务栏钉）。
- **G5-C**：`publish-runtime.ps1` 对 `post-update -Quiet -Repair` **60s 硬超时**；超时/非零退出 → 与 Install 同语义的 **soft reattach** fallback。
- 规划全文：`docs/plans/residual-g1-g3-g4-g5-2026-07-20.md`。

## 1.3.24 — wait-shell cold-start + tray native focus + UTF-8 console

- **wait-shell.mjs**: reuse CDP WebSocket across polls; adaptive 120–500ms backoff; default deadline 45s (was 90s hard); structural pass without requiring sidebar. Ready-session bench ~76ms.
- **open Wait-CodexShell**: passes timeoutMs; seeds wait-shell.mjs from runtime if missing.
- **tray focus native** (1cbed78): in-process WinFocus6 / CodexFastLaunch instead of PS open script (~40–300ms).
- **UTF-8 console** (a9d09eb): chcp 65001 + OutputEncoding on entry scripts.
- **publish auto-reattach** (941757b): post-update reattaches on runtime drift before smoke.


## 1.3.18 — heige 融合视觉 · 1.3.18-118f81
**基线**：扩展 1.3.15；把观感改回 heige studio + 原项目那样（右半 hero 图 + 左上品牌字），底部输入区收敛为 heige 单框。（1.3.16 = 单一版本源落地，1.3.17 = 融合视觉首版，均为过渡。）

- **修复断掉的图通道**：injector 之前把 `__DREAM_ART_JSON__` 硬写 `"null"`，renderer 又没读 catalog，导致 `--dream-art` 恒空、根本没背景图。改为把 active 主题 art 以 data URL 经 `__DREAM_ART_JSON__` 回填，`__DREAM_THEME_JSON__` 传完整 theme config。
- **右半 hero 布局**（heige 风格）：`body::before` 固定层 `right center / cover`，左三分之一渐隐 mask，人物清晰、内容区在左。
- **左上品牌字**：renderer 把 active 主题 `brandSubtitle`/`tagline` 经 `--dream-brand`/`--dream-headline`（JSON.stringify 保证 CSS 字符串安全）暴露；`body::after` 品牌名（绑 `--dream-accent`）、`#root::after` tagline。空 tagline 不渲染。`dream-has-art/brand/headline` class 控制显隐。
- **每套主题自己的 accent**：品牌字/描边/高亮绑 `--dream-accent`（miku 蓝绿、火影橙…），不硬套单一配色。
- **底部输入区改回 heige 单框**：删除 Fei-Away 的 `dream-home-utility` 双层拼框（项目选择栏 `18px 18px 0 0` + composer `0 0 18px 18px`）；composer 恢复单岛 `border-radius: 22px`、0.96 不透明、8px blur、accent 描边；utility 栏透明化（选择器仍可点，不再画成第二个框）。
- injector loadTheme 加 `brandSubtitle`（兜底=主题名）/`tagline`；cleanup 清理新增 class/var。
- 验证：doctor OK · verify pass（version 1.3.18）· smoke SMOKE_PASS · kick applied=1/sessions=1 · live 探针确认 hero 图铺上、品牌字生效、accent=主题色、composer 单框 22px/0.96。

## 1.3.15 — 收敛注入路径 · 1.3.15-4b1f91
**基线**：扩展 1.3.14。

- 删除 `packages/legacy-inject/`（原 heige `--once` CDP 旁路 · 4 mjs · 785 LOC）。
- `cli.mjs` 移除 `--once` / `--force-dual-open` / `--prefer-stored` 分支；`apply` 只保留 hot-active-theme + 控制面 /kick 一条路径。
- 移除 `status` 里的 `heigeWindows` 字段与 `pause` 里的 heige DOM 兜底清理（reader-side 已无 heige CSS）。
- 页面注入唯一路径：watch injector；`dreamskin-guard.mjs` 保留为 doctor 诊断，不再做 dual-open 拦截。
- 上游 renderer-inject.js 兼容：`artDataUrl=null`（catalog 通道）时不炸。
- `SKIN_VERSION` / renderer `dreamVersion` / `installed:true version:` 三处统一为 `1.3.15`。
- 验证：`doctor` OK · `apply` mode=hot-active-theme · smoke SMOKE_PASS · post-update 8/8 PASS。

## 1.3.14 — repo 架构重构 · 1.3.14-198361
**基线**：扩展 1.3.13；无功能变更，只做 repo 层清理与拆包。

- 删除 17 份一次性 fix 脚本（`scripts/windows/_*.py` `_*.out` `_verify-136.ps1` `_trace-switch.ps1`）与遗留 `.bak`。
- 删除空目录 `apps/tray/` 与无引用的 `vendor/heige/`（2 文件）。
- 25 份 docs 合并为 6 份：`ARCHITECTURE.md` · `CHANGELOG.md` · `PAIN-POINTS.md` · `usage.md` · `dual-open-policy.md` · `adr-0001-merge-product-line.md`。
- `packages/inject/` 改名 `packages/legacy-inject/`（明示"heige 遗留 · 仅 --once 调试"）；cli.mjs import 路径同步。
- `packages/core/` 按子目录归拢：
  - `cdp/` — cdp-client · cdp-helpers · cdp-port · cdp-session · cdp-targets
  - `discover/` — codex-app · path-utils · process-win
  - `state/` — dreamskin-guard · kick-inject · state-freshness
- 补 `packages/core-win/README.md` 与 `packages/runtime/README.md`，说明包边界与命名规约。
- `SKIN_VERSION` 与 renderer `dreamVersion` 对齐到 `1.3.14`。
- 验证：doctor OK · list 11 · kick 200/2ms · publish 后 check-and-fix exit=0。

## 1.3.13 — deeper freeze / jank mitigation · 1.3.13-f4bf1a
**基线**：扩展 1.3.12。

- 更严格的会话页玻璃退让：在 chat 检测到高频 mutation 时短暂停 backdrop-filter。
- watch injector 增加 payload 变更节流，避免相同指纹重复 evaluate。
- 冻结应急路径：托盘「暂停皮肤 30s + kick」双击可救。
- 验证：ChatGPT 进程 `Responding=True`，smoke **PASS**。

## 1.3.12 — freeze / jank fix · 1.3.12-0f7c2f
- 症状：会话切换/连击后 Codex 会短暂 UI 冻结。
- 根因：CSS mutation observer 触发无限重试 apply，叠加 backdrop-filter 卡帧。
- 修：observer 节流 400ms · CSS 移除高开销 backdrop（header）· 缩小选择器覆盖面。
- 应急：暂停皮肤 30s → 状态恢复后 kick。

## 1.3.11 — controlPort / fix timeout / report freshness / version align · 1.3.11-c83c04
- `state.controlPort` 正确写入并保留（normalize 不再覆盖）。
- `check-and-fix` CDP 短重试 + 硬超时（≤15s）。
- publish 后自动跑 quiet post-update 更新报告。
- SKIN_VERSION / renderer version 对齐 install version。
- 遗留：会话页 probe（需手动进对话）· 原生 focus helper · post-update publish race。

## 1.3.10 — focus hard-fix from deep UX scan · 1.3.10-*
- 根因：PS 5.1 `Add-Type` C# 不支持 discard `out _`，`Focus-CodexSkinWindow` 编译失败，EnumWindows 整条链废。
- 修：命名 out 变量 · 进程评分优先 `Chrome_WidgetWin_1` + Codex/ChatGPT 标题。
- 部署：`lib\launcher-ui.ps1` 同步 install。

## 1.3.9 — UX iteration (focus / bare / tip / DOM probe) · 1.3.9-c08338
- **A · Focus**：EnumWindows 主路径 + AppActivate fallback。
- **B · Bare Codex**：托盘首项「★ 用皮肤重启 Codex」，气泡多行 + 明确路径。
- **C · Cold-start tip**：phase 状态机（start / slow-path / shell-wait / launch-cdp / inject-start / healthy-focus / control-hit / ready / focus-miss / bare-codex / failed / first-run / user-feedback），≥8s 追加"仍在等待"。
- **D · DOM probe**：新增 `scripts/windows/probe-session-dom.mjs`（首页 + 会话）。

## 1.3.7 — session selectors + F6 thumb coverage · 1.3.7-509f0a
- N09 自适应会话选择器（composer / user / assistant / approval 各支持多种候选）。
- Shell 判定放宽：composer **或** sidebar **或** main 存在即可。
- F6 缩略图覆盖：`thumb.mjs` 全套主题预生成，payload 减重。

## 1.3.6 — T1–T3 UX (focus / bare poll / Chinese feedback / tray) · 1.3.6-58b376
- 焦点用户手势链路 + bare Codex 轮询发现 + 中文反馈气泡 + 托盘条目重排。
- 已知：VBS 保持 ASCII；中文 UI 走 PS feedback helper。

## 1.3.5 — UX visibility & recovery (S1–S3) · 1.3.5-6920f6
- 建立控制面 `/health` `/kick` `/focus` `/open-healthy` 快路径。
- 气泡节流 45–60s（避免连点刷屏）。

## 1.3.4 — hard-bottleneck fixes · 1.3.4-db4479
- payload 减重：catalog 只嵌缩略图，active 才全图。
- thumb 生成链：Pillow → ImageMagick → System.Drawing（有则用，无跳过）。
- 遗留：后台 helper focus 仍受 Windows 前台规则限制；WebP 全 thumbs 需 magick。

## 1.3.3 — pain-point fixes · 1.3.3-554d87
- `cli list` 去重（bundled + user store 合并计数）。
- `kick-theme-now` 面板直接调 node（去掉中间 PS）。
- `versions/` GC：保留 current + 上一版。

## 1.3.2 — Codex Store update compatibility · 1.3.2-9a68fa
- 目标：Store 侧 Codex/ChatGPT 更新后无需重装皮肤。
- adaptive wait-shell 复制到 `stateRoot`。
- `post-update-regression.ps1` / `kick-theme-now.ps1` 落地到 programRoot。
- 已知限制：Store 磁贴 / AUMID / 第三方 Codex-X launcher 仍可能裸启。

## 1.3.1 — 模块化发布 · 1.3.1-5293ef
- PowerShell 共享库 `launcher-ui.ps1` 落地 + apps/launcher 全部薄化。
- Node 核心拆分：core / themes / inject / runtime 四包，每包 `index.mjs` 出口。
- 安装布局：`programRoot\lib\` 存放共享库；publish 同步 lib + 入口脚本。
- 验证：ParseFile 全部 PARSE_OK · doctor OK · apply hot-active-theme OK。

---

## 里程碑历史（合并 m2/m3 状态）

| 里程碑 | runtime | 说明 |
|---|---|---|
| M0 停双开 | — | dreamskin-guard 检测 DreamSkin，拒绝 heige studio 二次启动 |
| M1 建仓 + 迁内核 | — | heige + DreamSkin 合并进单仓 |
| M2 多主题接入守护 | 1.3.0 | active-theme 热切换验证通过 |
| M3 托盘 / F6 / 归档 / 回归 | 1.3.0 | SMOKE_PASS + POST_UPDATE_PASS |
| 模块化 + 安静启动 | 1.3.1 | launcher-ui + 包 index 出口 |
| runtime 1.3.2 – 1.3.13 | 见上 | 详见各版 |

---

## UX 改进类（原 ux-improvements / optimization-best-path 摘要）

- 快捷方式全部皮肤化（wscript 静默启动），Codex / ChatGPT / 换肤 / 修复 / 管理 5 条入口。
- 换肤面板 200ms debounce + optimistic UI 高亮。
- 控制面 `/kick` 45ms 主路径；spawn 是 fallback。
- 托盘条目：暂停皮肤 · 换肤… · 保存主题 · 修复 · 帮助（保存主题在锁定态不可用）。

---

## 参考

- 痛点合集：`PAIN-POINTS.md`
- 架构：`ARCHITECTURE.md`
- 使用：`usage.md`
