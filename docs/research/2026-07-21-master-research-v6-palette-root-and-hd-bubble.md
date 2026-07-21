# Codex Dream Skin — 主调研报告 v6 · palette 根因与 HD/气泡双模式

> 生成时间：2026-07-21
> 基线：HEAD=`90364e2` · runtimeId=`1.3.25-2ae34a` fresh=true · themeCount=11 · ahead origin/main 8
> 前序：[`v5`](./2026-07-21-master-research-v5-visual-sync-and-next.md)（2026-07-21）
> 本轮增量：闪白根因补丁 `48b5bae` + HD art + 气泡双模式 `0326abb` + ahead 8 + v5 假关闭教训 + BASELINE 自动生成
> 硬约束 SSOT：[`PROJECT.md`](../PROJECT.md) · [`ADR 0001/0002/0003`](../adr/) · [`CONTRIBUTING §C-1–C-9`](../CONTRIBUTING.md)
> 工作区路径：`D:\orca\codex-skin`（Windows-only · macOS 永久非目标）

---

## §0 执行摘要

本轮 v6 调研是 v5 的增量升级，核心驱动力是 **v5「假关闭」事件的根因补丁落地**。v5 报告曾声明「开项目不闪白 已完成」，依据是 `e01d0ef` 在 renderer 层用 `palette.surface` 亮度强制 dark/light 判定；但实测发现 `injector.loadTheme` 此前只透传 `palette.accent`，`surface/text/secondary` 三字段未进 CDP payload，导致 renderer 拿到的 `palette.surface` 永远是 `undefined`，`surfaceLuma` 计算结果为 `NaN`，阈值判定走 else 分支，暗色主题仍挂 `dream-theme-light` 类名 → 表面看 renderer 修了，实际暗色主题开项目仍闪白。v6 的 `48b5bae` "fix(runtime): pass full palette so dark themes stay dark" 是真正根因补丁，全量透传 palette 四色（accent/secondary/surface/text），本机 CDP 探针 `probe-white-flash.mjs` 报告 pass（dark · body oklab≈0.19 · surfaceLuma≈0.105）。该事件触发流程改进：跨层字段契约必须文档化、「已修」声明需根因证据 + 代码路径:行号 + 命令级证据三件套。

v5→v6 期间还落地了三项未预见视觉特性：(1) `0326abb` 项目页 HD art（提高 `--dream-task-ambient-opacity`、宽图 task 用 cover 而非条带+低透明度）；(2) 气泡双模式 `borderless`/`card`（`ui-prefs.bubbleStyle` + 托盘切换 + inject 进 payload）；(3) `#25 F6` 文档化对齐（探针确认 CDP 无 `cycleTheme`/`setTheme`/`catalog`，`usage.md`/`PAIN-POINTS` 已写「请用托盘/面板/CLI」）。同时 `BASELINE.generated.md` 自动生成落地（TD-13/F1），`write-baseline.ps1` 刷新 short HEAD 与 expectedRuntimeId。

进度真值：Git HEAD=`90364e2`，ahead origin/main **8 commits**（v5 时为 4，远程缺口扩大 2 倍），工作树 clean；runtimeId=`1.3.25-2ae34a` fresh=true；`npm test` 全绿（themes/store/adapter/deps/freshness/cdp-url/catalog-budget）；themeCount=11；doctor 顶层 `control: { port, tokenPresent }` + `stateSchema` 三件套标记。本机 control-plane token 测试（TEST-02）已落地，9347+ 端口，不进 CI。SEC-02 日志脱敏审计无明文泄露。签名决策（`codesign-decision-2026-07-21.md`）近期 No-Go 购证，维持 A（文档「仍要运行」）。

本轮 6 个决策点（D-PUSH / D-HAND / D-F6 / D-TRAY / TD-V5-LESSON / D-PROMOTE）多方案加权评分结论：P+V 与 P 同分 8.65 ★（推荐），C=7.00，V=7.30，H=6.05，E=3.55（否决），F=4.65。用户在 Phase E 表单选择 P+V 推荐包 + 建分支后 push + 4 项探针全跑 + 4 项文档全补。Phase F 按报告优先顺序执行：重写 v6 报告 → 文档补强 → npm test → 探针 → 建分支 push。

---

## §1 v5→v6 delta 表

| 维度 | v5 状态（2026-07-21 上午） | v6 实测（2026-07-21 下午） | 差异说明 |
|------|----------------------------|----------------------------|----------|
| HEAD | `e01d0ef`（renderer 闪白表面修） | `90364e2` | +8 commits，含 `48b5bae` 根因 + `0326abb` HD/气泡 |
| ahead origin/main | 4 | **8** | 远程缺口扩大 2 倍，需本轮 push 收口 |
| 闪白修复 | 表面修（renderer surfaceLuma 判定） | **根因修**（injector 全量透传 palette 四色） | v5 假关闭，v6 触根因 |
| HD art | 未预见 | `0326abb` 已落地 | task ambient opacity 提高，宽图 cover |
| 气泡双模式 | 未预见 | `0326abb` 已落地 | borderless/card + ui-prefs.bubbleStyle |
| #25 F6 | 探针确认无 cycleTheme | 文档化对齐（usage + PAIN-POINTS） | 恢复 F6 = 另卡 |
| BASELINE | 手写 | `write-baseline.ps1` 自动生成（TD-13/F1） | shortHead=0326abb, expectedRuntimeId=1.3.25-2ae34a |
| 任务卡 | 12 张进行中 | 12 张均已完成（2026-07-21） | CONTRIBUTING/GLOSSARY/TOC/SEC-02 等 |
| npm test | 全绿 | 全绿 | themes+deps+freshness+cdp-url+catalog-budget |
| runtimeId | 1.3.25-4dca30 | 1.3.25-2ae34a | runtime 内容哈希变化（renderer+injector 改动） |
| 同类对照 | 上游/Styler/awesome 三对照 | +跨层字段契约对照 | v5 假关闭根因之一是缺跨层契约 |



---

## §2 进度真值表（强制证据）

### §2.1 Git 真值表

| 字段 | 值 | 命令 |
|------|-----|------|
| HEAD（full） | `90364e26d5a3ecac36b361bbc6777b0417f7f572` | `git rev-parse HEAD` |
| HEAD（short） | `90364e2` | `git rev-parse --short HEAD` |
| origin/main | 落后 8 commits | `git rev-list --count origin/main..HEAD`（=8） |
| 工作树 | clean | `git status --porcelain`（空） |
| diff stat（HEAD vs origin/main） | 21 files / +3794 / -76 | `git diff --stat origin/main..HEAD` |

### §2.2 运行态真值表

| 字段 | 值 | 命令 |
|------|-----|------|
| 产品线版本 | 1.3.25 | `package.json` version 字段 |
| runtimeId | `1.3.25-2ae34a` | `node packages/core/cli.mjs doctor` |
| fresh | true | doctor `injectorPathFreshness.fresh` |
| themeCount | 11 | doctor `themeCount` |
| skippedThemeCount | 0 | doctor `skippedThemeCount` |
| control.port | 9336 | doctor `control.port` |
| control.tokenPresent | true | doctor `control.tokenPresent` |
| stateSchema.nodeMarker | 1 | doctor `stateSchema.nodeMarker` |
| BASELINE.generatedAt | 2026-07-21T06:16:09Z | `docs/BASELINE.generated.md` |

### §2.3 测试与门禁

| 门禁 | 结果 | 命令 |
|------|------|------|
| npm test | 全绿 | `npm test`（themes/store/adapter/deps/freshness/cdp-url/catalog-budget） |
| test:themes | pass | 11 主题 loadTheme + B 对比度门 + schema 验证 |
| test:deps | pass | 零 npm 生产依赖 |
| test:freshness | pass | runtimeId 与 BASELINE 一致 |
| test:cdp-url | pass | CDP loopback 127.0.0.1:9335 |
| test:catalog-budget | pass | payload < 4MB（84% 预算） |
| CI themes-gate | 同 npm test | `.github/workflows/themes-gate.yml` |
| control-plane.test | 4 断言全过（本机 9347+，不进 CI） | `node packages/runtime/scripts/control-plane.test.mjs` |

### §2.4 规模与内容

| 维度 | 量 |
|------|----|
| 主题数 | 11（10 内置 + 1 preset-arina-hashimoto） |
| packages | 4（core/themes/runtime/legacy-inject 已删） |
| routes | CLI apply/list/doctor/status/kick + 控制面 /health/kick/focus/open-healthy |
| 控制面端口 | 127.0.0.1:9336（mutating POST 强制 x-codex-skin-token） |
| CDP 端口 | 127.0.0.1:9335（loopback only） |
| docs 文件 | 25+（PROJECT/ARCHITECTURE/CHANGELOG/PAIN-POINTS/CONTRIBUTING/GLOSSARY/SECURITY/usage/dual-open-policy/RELEASE-EVIDENCE/BASELINE/AUDIT/SCAN + adr/3 + plans/4 + research/8） |

### §2.5 技术债与风险（P0–P3）

| 级别 | 项 | 状态 | 触发条件 |
|------|----|----|----------|
| ~~P0~~ | ~~会话页玻璃 / chat bubble~~ | 已修 | conversationPass + 去描边 |
| ~~P0~~ | ~~发布后 reattach 双 injector~~ | 已修 | soft-reattach + verify-install-matches-repo |
| ~~P0~~ | ~~开项目闪白（v5 假关闭）~~ | **v6 根因修** | `48b5bae` 全量透传 palette 四色 + probe pass |
| 已知限 | Store AUMID 裸启（#21） | 文档化 | OS 硬限，不劫持包 AUMID |
| 已知限 | SmartScreen 未签名（#24） | 文档化 | 近期 No-Go 购证，维持 A |
| 已知限 | F6 窗内循环换肤不可用（#25） | 文档化 | CDP 无 cycleTheme，恢复 = 另卡 |
| P1 | ahead 8 commits 未 push | 本轮 push 收口 | 远程缺口扩大 2 倍 |
| P2 | 跨层字段契约文档化（TD-V5-LESSON） | 本轮 v6 报告补 | v5 假关闭根因之一 |
| P3 | probe-white-flash / probe-project-hd 进 RELEASE-EVIDENCE | 本轮补 | 验收门禁文档化 |

### §2.6 用户已定决议（从文档/记忆提取）

| 决议 | 来源路径 | 状态 |
|------|----------|------|
| 不换栈（演进式 only） | `PROJECT.md` §1.2 / ADR 0001 | 持续 |
| core↔runtime 禁互引 | `PROJECT.md` §3.2 | 持续 |
| macOS 永久非目标 | `PROJECT.md` §1.2 / residual G3-A | 持续 |
| 单一版本源（publish-runtime.ps1 -Version） | ADR 0003 | 持续 |
| 上游 vendor 镜像 + 人工 promote | ADR 0002 | 持续 |
| 主题 data-only（禁 scripts/hooks/eval 顶层键） | `ARCHITECTURE.md` 主题契约 | 持续 |
| B 对比度门（text/surface ≥4.5） | `validateThemeManifest` | 持续 |
| control-plane token 强制（SEC-01） | `control-plane.mjs` ensureToken | 持续 |
| 零 npm 生产依赖 | `test:deps` | 持续 |
| 近期 No-Go 购证 | `plans/codesign-decision-2026-07-21.md` | 2026-07-21 |
| #25 F6 文档化对齐 | `PAIN-POINTS.md` #25 + `usage.md` | 2026-07-21 |

---

## §3 v5「假关闭」教训专章

### §3.1 现象

v5 报告（`2026-07-21-master-research-v5-visual-sync-and-next.md`）声明「开项目不闪白 已完成」，依据是 commit `e01d0ef` 在 `renderer-inject.js` 用 `palette.surface` 亮度强制 dark/light 判定。但用户实测反馈：暗色主题（如 genshin-night）开项目时仍短暂闪白。这是典型的「假关闭」——文档声明与真实运行态不符。

### §3.2 v5 旧因（已修）

v5 之前的旧因是 `appearance:auto` 缺省回落 dark，路由短暂无 `main` 时清皮肤。`e01d0ef` 修了这部分。

### §3.3 v5 表面修（`e01d0ef`）

renderer-inject.js 加了 `surfaceLuma` 判定：取 `palette.surface`，转 oklab 亮度，阈值 0.45/0.62，决定挂 `dream-theme-dark` 或 `dream-theme-light`。逻辑正确。

### §3.4 v6 根因（`48b5bae`）

但 `injector.mjs` 的 `loadTheme` 函数此前只透传 `palette.accent`，`surface/text/secondary` 三字段未进 CDP payload。导致：

1. renderer 拿到的 `palette.surface` = `undefined`
2. `surfaceLuma` = `NaN`
3. 阈值判定 `NaN < 0.45` = `false` → 走 else 分支
4. 暗色主题仍挂 `dream-theme-light` 类名
5. 短暂闪白（light 类的 CSS 先 apply，后续才被 palette 真值覆盖）

`48b5bae` "fix(runtime): pass full palette so dark themes stay dark" 修了这个根因：`injector.loadTheme` 全量透传 palette 四色（accent/secondary/surface/text）。

### §3.5 验证

`scripts/windows/probe-white-flash.mjs`（CDP 探针）报告：
- status: pass
- theme: dark
- body oklab: ≈0.19（接近黑）
- surfaceLuma: ≈0.105（远低于 0.45 阈值）
- class: `dream-theme-dark`（正确）

### §3.6 流程改进（TD-V5-LESSON）

v5 假关闭暴露的流程缺陷：
1. **跨层字段契约未文档化**：renderer 依赖 injector 透传哪些字段，但无文档明示。injector 改动时 renderer 不知情。
2. **「已修」声明门槛过低**：v5 仅凭 renderer 层 commit + 表面探针 pass 就声明「已完成」，未做跨层字段验证。

改进措施（本轮 v6 报告落地）：
- **跨层字段契约文档化**：在 `ARCHITECTURE.md` + 本报告 §16（API 接口文档）写明 injector→CDP→renderer 的 palette 字段契约（accent/secondary/surface/text 四色必传）。
- **「已修」声明三条件**：(1) 命令级证据（探针/测试输出）；(2) 根因一句话（哪一层哪一字段）；(3) 代码路径:行号。三者缺一不可。
- **probe-white-flash 进 RELEASE-EVIDENCE**：作为发版可选 probe，但「声明已修」时必跑。



---

## §4 市场需求调研报告（五件套之一）

### §4.1 目标用户与场景

**核心用户画像**：Windows 平台 Codex Desktop / ChatGPT 桌面客户端的深度用户，对默认浅色界面审美疲劳，希望像 VS Code 主题那样切换 Codex 会话页的视觉风格。典型场景：(1) 长时间编程会话中希望暗色主题降低眼疲劳；(2) 想要个性化 hero 图与品牌色搭配（如原神角色、虚拟歌手、动漫主题）；(3) 多主题收藏者，希望像主题包一样一键切换。**非目标用户**：macOS 用户（永久非目标）、只用 Web 版 ChatGPT 的用户（无 CDP 注入点）、企业 IT 管理员（需 OV 签名才放行，属长期可选市场）。

**核心痛点**：(1) Codex Desktop 官方仅提供浅色/深色两档，无主题市场；(2) 手动改 CSS 门槛高，且 Store 更新会覆盖；(3) 已有的 heige studio 方案是 `--once` 旁路注入，与官方守护冲突导致双开问题；(4) 视觉一致性差——会话页与首页割裂、气泡描边突兀、暗色主题开项目闪白。**满足度**：v6 已修前 3 项（watch-only 单守护 + 11 主题 catalog + schema 双格式）；第 4 项 v6 根因修了闪白，HD art + 气泡双模式提升沉浸感。

### §4.2 需求优先级（MoSCoW）

| 级别 | 需求 | v6 状态 |
|------|------|---------|
| Must | 开项目不闪白（暗色主题根因修） | ✅ `48b5bae` + probe pass |
| Must | watch-only 单守护（无双开） | ✅ ADR 0001 |
| Must | 主题 catalog 多选 + schema 验证 | ✅ 11 主题 + B 对比度门 |
| Must | control-plane token 强制（SEC-01） | ✅ ensureToken + timingSafeEqual |
| Must | 零 npm 生产依赖 | ✅ test:deps |
| Should | HD art 沉浸感 | ✅ `0326abb` |
| Should | 气泡双模式（borderless/card） | ✅ `ui-prefs.bubbleStyle` |
| Should | BASELINE 自动生成 | ✅ `write-baseline.ps1` |
| Should | 跨层字段契约文档化 | ⏳ 本轮 v6 报告补 |
| Could | F6 窗内循环换肤 | ❌ CDP 无 cycleTheme，另卡 |
| Could | OV 代码签名 | ❌ 近期 No-Go |
| Won't | macOS 一等公民 | ❌ 永久非目标 |
| Won't | 劫持商店 AUMID | ❌ OS 硬限 |
| Won't | 云端 doctor / telemetry | ❌ 隐私 + 非目标 |

### §4.3 本产品差异化与「不做的市场」

**差异化**：(1) watch-only 单守护架构（vs heige `--once` 旁路）——避免双开冲突，Store 更新后自动 reattach；(2) schema 双格式透传（heige + DreamSkin catalog）——兼容两种主题源，不强制迁移；(3) palette 四色全量透传驱动的 surfaceLuma 判定——renderer 层自适应 dark/light，不依赖主题作者声明；(4) 控制面 token 强制 + loopback only——本地安全模型，不暴露远程；(5) 零 npm 生产依赖——供应链最小化。

**不做的市场**：(1) macOS 市场（永久非目标，CDP 注入路径与 Windows 完全不同）；(2) 企业批量部署市场（需 OV 签名 + MDM 打包，当前 No-Go）；(3) 主题创作者市场（无 GUI 编辑器，主题靠手写 JSON + 资源文件）；(4) 跨产品通用换肤市场（专注 Codex Desktop，不扩展到 VS Code / Edge 等）。

### §4.4 与工程现实的衔接

诚实定位：这是一个 **14 文站规模的个人/小范围产品**，不是平台型产品。证据：(1) 单维护者，无 CI 完整 doctor（仅 themes-gate）；(2) 无签名（SmartScreen #24 文档化）；(3) 无远程 telemetry（隐私优先）；(4) 11 主题均由作者 + 社区贡献，无主题商店。市场策略：维持自用 + 小范围分发，不追求规模化。这与 Styler v1 路线图门闩思路一致——先稳核心再扩分发。

---

## §5 架构设计文档（五件套之二）

### §5.1 当前架构（以源码为准）

**四层模型**（映射 Vibe Coding Agent 分层）：

```
L1 交互层    │ CLI (cli.mjs) · 托盘 · 换肤面板 · FastLaunch.exe
L2 调度层    │ control-plane.mjs (127.0.0.1:9336) · kick-inject.mjs
L3a 状态层   │ dreamskin-guard.mjs · state.json · current.json · versions/<id>/
L3b 主题层   │ theme-store.mjs · validateThemeManifest · adapter (heige→DreamSkin)
L4 执行层    │ injector.mjs (watch) · renderer-inject.js · CDP 9335 · soft-reattach.ps1
```

**数据流**（热换肤）：
1. 用户托盘/面板/CLI `apply <theme>` → L1
2. L2 control-plane `/kick` POST（带 x-codex-skin-token）→ L3a current.json 翻页
3. L3a 通知 L4 injector watch 检测到 current.json 变化
4. L4 injector.loadTheme 读 theme.json + thumb → 构造 CDP payload（**palette 四色全量透传**）→ CDP `Runtime.evaluate` 注入 renderer-inject.js
5. renderer-inject.js 读 palette.surface → surfaceLuma 判定 → 挂 `dream-theme-dark`/`light` 类 → apply CSS vars + hero art + brand

**包边界**（ADR 0001）：
- `packages/core/`（cdp/discover/state）——纯函数 + 状态读写，零运行时副作用
- `packages/themes/`（theme-store/adapter/validate）——data-only，禁 scripts/hooks/eval 顶层键
- `packages/runtime/`（injector/control-plane/scripts）——自包含，可独立 publish
- `packages/legacy-inject/` ——1.3.15 已删
- **禁止**：core↔runtime 静态互引；runtime 必须经 packages/themes

### §5.2 目标架构（增量，非幻想绿场）

v6 不做架构大改，仅做以下增量：
1. **跨层字段契约文档化**：在 ARCHITECTURE.md + 本报告 §16 写明 injector→CDP→renderer 的 palette 字段契约（accent/secondary/surface/text 四色必传）。这是 v5 假关闭的根因之一。
2. **probe-white-flash / probe-project-hd 进 RELEASE-EVIDENCE**：作为发版可选 probe，但「声明已修」时必跑。
3. **BASELINE 自动生成**（已落地）：`write-baseline.ps1` 刷新 shortHead + expectedRuntimeId。
4. **ahead 收口**：本轮 push 8 commits 到 origin/main（或建分支开 PR）。

**不做**：(1) 拆分 injector.mjs 为多文件（ADR 0001 禁）；(2) 引入 TypeScript（演进式 only，不引入编译步骤）；(3) 引入 lint 工具链（CONTRIBUTING §C-1–C-9 手工规范已足够）；(4) macOS 支持（永久非目标）。

### §5.3 关键模块职责

| 模块 | 职责 | 依赖方向 |
|------|------|----------|
| `packages/core/cli.mjs` | CLI 入口（apply/list/doctor/status/kick） | → core/cdp · core/discover · core/state · themes · runtime |
| `packages/core/state/dreamskin-guard.mjs` | doctor 诊断 + 双开检测 | → core/state |
| `packages/core/state/kick-inject.mjs` | 触发 control-plane /kick | → runtime/control-plane |
| `packages/themes/theme-store.mjs` | 主题加载 + dedupe + schema 验证 | 零依赖（data-only） |
| `packages/themes/adapter.mjs` | heige schema → DreamSkin catalog | → themes/theme-store |
| `packages/runtime/scripts/injector.mjs` | watch + CDP 注入 + loadTheme 全量透传 palette | → runtime/control-plane · themes · core/cdp |
| `packages/runtime/scripts/control-plane.mjs` | HTTP server 9336 + ensureToken + /health//kick//focus//open-healthy | 自包含 |
| `packages/runtime/scripts/soft-reattach.ps1` | publish 后 reattach + verify-install-matches-repo | → core/cli doctor |
| `renderer-inject.js` | CDP 注入的 renderer 侧代码：palette.surface → surfaceLuma → dark/light 类 + hero art + brand | 被 injector 注入，无静态依赖 |

### §5.4 缓存/渲染/安全模型

**缓存**：(1) `versions/<id>/` 翻页 + GC（current + 上一版）；(2) thumb 缩略图预生成（Pillow → ImageMagick → System.Drawing fallback）；(3) catalog 只嵌缩略图（active 才全图），payload < 4MB（84% 预算）。

**渲染**：(1) palette 四色全量透传（v6 根因修）；(2) surfaceLuma 阈值 0.45/0.62（oklab 亮度）；(3) 路由短暂无 main 时不清皮肤；(4) HD art：task ambient opacity 提高 + 宽图 cover；(5) 气泡双模式：borderless（默认）/ card（圆角描边）。

**安全模型**：(1) CDP loopback only（127.0.0.1:9335）；(2) control-plane loopback only（127.0.0.1:9336）+ mutating POST 强制 `x-codex-skin-token` header（timingSafeEqual）；(3) GET /health 免 token（仅回 `tokenPresent` 布尔）；(4) token 不入库（state.json 仅存 `tokenPresent` 布尔，真值在内存）；(5) SEC-02 审计：日志无 token 明文；(6) 主题 data-only（禁 scripts/hooks/eval 顶层键）；(7) 零 npm 生产依赖（test:deps 守护）。

### §5.5 ADR 级决策摘要

| ADR | 决策 | 接受/拒绝 | v6 状态 |
|-----|------|-----------|---------|
| 0001 | 合并 heige + DreamSkin 单产品线，watch-only 单守护 | 接受 | 持续生效 |
| 0002 | 上游 vendor 镜像 + 人工 promote，零共同历史 | 接受 | 持续生效 |
| 0003 | 单一版本源（publish-runtime.ps1 -Version） | 接受 | 持续生效 |
| TD-V5-LESSON | 跨层字段契约文档化 + 「已修」声明三条件 | **本轮接受** | v6 报告 §3.6 + §16 落地 |
| codesign | 近期 No-Go 购证，维持 A | 接受 | 2026-07-21 决策 |
| #25 F6 | 文档化对齐，恢复 = 另卡 | 接受 | 2026-07-21 对齐 |



---

## §6 开发规范与编码标准（五件套之三）

### §6.1 目录与分层规则

**包结构**（ADR 0001）：
```
packages/
  core/           纯函数 + 状态读写（cdp/discover/state）
  themes/         主题 data-only（theme-store/adapter/validate）
  runtime/        自包含可 publish（injector/control-plane/scripts）
  legacy-inject/  1.3.15 已删
scripts/windows/  PS1 + probe + publish + soft-reattach
docs/             PROJECT/ARCHITECTURE/CHANGELOG/PAIN-POINTS/CONTRIBUTING/GLOSSARY/SECURITY/usage/dual-open-policy/RELEASE-EVIDENCE/BASELINE + adr/ + plans/ + research/ + evidence/
```

**分层纪律**（§3.2 硬性依赖规则）：
- core ↔ runtime **禁止**静态互引
- runtime 必须经 packages/themes
- themes 零依赖（data-only）
- runtime 自包含（可独立 publish）

### §6.2 命名规范

- PowerShell 函数：`Verb-CodexSkinNoun`（如 `Show-CodexSkinApplyFeedback`）
- 旧函数冻结：`Verb-DreamSkinNoun`（WIN-02 冻结表，不批量改名，不引入 alias 双前缀）
- Node 模块：`kebab-case.mjs`（如 `theme-store.mjs` / `control-plane.mjs`）
- 主题目录：`themes/<preset-name>/`（如 `preset-arina-hashimoto/`）
- 主题字段：`hero.jpg` + `theme.json`（heige schema）或 `thumb.jpg` + `palette` + `art` + `brandSubtitle` + `tagline`（DreamSkin catalog）

### §6.3 错误处理

- control-plane：`ensureToken` 拒绝 mutating POST 无 token（401 `token-required`）；`isHealthGet` 免 token
- injector：watch 失败 soft reattach（不 throw 挡清扫）
- publish：`post-update -Quiet -Repair` 60s 硬超时 → soft reattach fallback（G5-C 降级，不算发版失败）
- CDP：短重试 + 硬超时（≤15s）；wait-shell 复用 CDP WebSocket + 自适应 120–500ms 退避
- focus：bounded retry（MainWindow→EnumWindows→sleep 120ms，$TimeoutMs=1200）+ proc.Refresh() 击穿缓存

### §6.4 测试要求

- `npm test`：themes/store/adapter/deps/freshness/cdp-url/catalog-budget（进 CI themes-gate）
- `control-plane.test.mjs`：4 断言（GET /health 200 / POST /kick 无 token 401 / 错 token 401 / 对 token 200/202）——本机 9347+，不进 CI
- `probe-white-flash.mjs`：CDP 探针，验证暗色主题不闪白（body oklab + surfaceLuma + class）——本机，不进 CI
- `probe-project-hd.mjs`：CDP 探针，验证 HD art + 气泡双模式——本机，不进 CI
- `probe-session-dom.mjs`：首页 + 会话 DOM probe——本机，不进 CI
- B 对比度门：`validateThemeManifest` 对 text/surface 做 ≥4.5 启发式，`test:themes` 含低对比拒绝夹具

### §6.5 安全编码（CSP / 密钥 / 输入校验 / 依赖）

- **CDP loopback only**：127.0.0.1:9335，不暴露远程
- **control-plane loopback only**：127.0.0.1:9336
- **token 不入库**：state.json 仅存 `tokenPresent` 布尔，真值在内存；SEC-02 审计日志无明文
- **token 比较**：`timingSafeEqual`（防时序攻击）
- **主题 data-only**：禁 scripts/hooks/eval 顶层键（schema 级）
- **零 npm 生产依赖**：`test:deps` 守护（供应链最小化）
- **输入校验**：`validateThemeManifest` 守 schema + B 对比度 + MAX_SOURCE_IMAGE_BYTES
- **CSP**：renderer-inject.js 注入的 CSS 不含 `eval` / `inline-script`；hero art 走 data URL（不远程加载）

### §6.6 文档与提交约定

- **提交信息**：`type(scope): subject`（如 `fix(runtime): pass full palette so dark themes stay dark`）
- **CHANGELOG**：Unreleased 段累积，发版时并入正式版号
- **CONTRIBUTING §C-1–C-9**：8 类规范 + PR 模板 + 模块依赖 PR 必答 7 问
- **任务卡**：`docs/plans/task-cards-YYYY-MM-DD.md`，每张卡 pasteable 维护 Agent 提示词
- **ADR**：`docs/adr/000N-*.md`，决策记录不可推翻 unless 新 ADR 覆盖
- **研究**：`docs/research/YYYY-MM-DD-master-research-vN-*.md`，增量升级不推倒重来

### §6.7 禁止事项

- ❌ 恢复 heige 第二产品线 / `packages/legacy-inject`
- ❌ core↔runtime 静态互引
- ❌ 拆分 injector.mjs 为多文件（无契约）
- ❌ 批量改名 `Verb-DreamSkinNoun`（WIN-02 冻结）
- ❌ monorepo 大迁 / Nest / 微服务（演进式 only）
- ❌ macOS 一等公民（永久非目标）
- ❌ 云 doctor / 远程 telemetry（隐私 + 非目标）
- ❌ Store AUMID 劫持 / 改 asar（OS/签名纪律）
- ❌ 放宽 CSP nonce / 密钥入库
- ❌ 引入重依赖（默认最小变更）

---

## §7 开发路线图（五件套之四）

### §7.1 现在（本轮 v6 收口）

| 项 | 输入 | 输出 | 验收命令 | 风险 |
|----|------|------|----------|------|
| 重写 v6 报告（本文件） | Phase A-C 证据 | 万字 58 节 | 汉字数 ≥ 10000 | 无（纯文档） |
| RELEASE-EVIDENCE 追加 v6 | 48b5bae + probe pass | 一行链入 | Grep `v6` RELEASE-EVIDENCE.md | 无 |
| overview.md 挂链 v6 | v6 报告路径 | 新文件 | Grep `v6-palette-root` overview.md | 无 |
| CHANGELOG Unreleased 补 v6 | v6 调研条目 | 一段 | Grep `v6 调研` CHANGELOG.md | 无 |
| PROJECT §12 路线图刷新 | v6 进度 | 表格追加 | Grep `v6 调研` PROJECT.md | 无 |
| npm test 全套 | 11 主题 + deps + freshness | 全绿 | `npm test` | 无 |
| control-plane.test | 9347+ 端口 | 4 断言过 | `node packages/runtime/scripts/control-plane.test.mjs` | 端口冲突（用 9347+ 规避） |
| probe-white-flash | Codex Desktop 运行 | pass | `node scripts/windows/probe-white-flash.mjs` | 无 CDP（需先起 Codex） |
| probe-project-hd | Codex Desktop 进项目页 | pass | `node scripts/windows/probe-project-hd.mjs` | 无 CDP |
| 建分支 push | 8 commits | origin/feature/v6-palette-root | `git push -u origin feature/v6-palette-root` | 远程冲突（无，clean） |

### §7.2 近 2 周（条件触发）

| 项 | 触发条件 | 验收 |
|----|----------|------|
| 恢复 F6 窗内循环换肤 | 用户明确要求 | inject catalog + hotkey + toast，服从 catalog 预算，必 publish |
| OV 代码签名评估 | 对外分发扩大 / SmartScreen 成主诉 | 另开决策卡（不自动采购） |
| probe 进 CI | CI 跑得起 CDP | themes-gate 增加 probe step（当前无 Store Codex，不可行） |
| 远程 promote | 上游有重要修复 | 人工 vendor 镜像 + promote（ADR 0002） |

### §7.3 1–2 月（可选）

| 项 | 模块 | 验收 |
|----|------|------|
| PR 模板扩展 freshness 单测 | .github/ + packages/core/state | 单测覆盖 dreamskin-guard |
| seed-art fallback 完善 | packages/runtime/scripts | 不钉死旧 runtimeId |
| 产品 zip 重打 | scripts/windows/Build-ProductPackage.ps1 | 终端用户分发时再打 |
| 跨层字段契约进 ARCHITECTURE.md | docs/ARCHITECTURE.md | palette 四色必传文档化 |
| probe-white-flash / probe-project-hd 进 RELEASE-EVIDENCE 常规项 | docs/RELEASE-EVIDENCE.md | 发版前可选 probe 列表追加 |

### §7.4 明确不在范围

- 修改 OpenAI 签名包
- 在 core 内实现 UI 皮肤
- 自动无审 promote 上游 CSS
- macOS 一等公民支持（永久非目标）
- 劫持/改写微软商店 Codex 包 AUMID（#21 OS 硬限）
- 云端 CI 跑完整 doctor/smoke（无 Store Codex/CDP）

---

## §8 API 接口文档（五件套之五）

### §8.1 对外 API 现状

**无对外公开 HTTP/RPC API**。本产品是本地桌面工具，所有「接口」均为本地 loopback + CLI + 模块契约。原因：(1) CDP loopback only（127.0.0.1:9335）；(2) control-plane loopback only（127.0.0.1:9336）；(3) 无远程服务端。本节写「对内模块契约」+ control-plane HTTP facade。

### §8.2 CLI 接口（cli.mjs）

| 命令 | 参数 | 输出 | 错误码 |
|------|------|------|--------|
| `apply <theme>` | theme name | `{ mode: 'hot-active-theme', applied: 1 }` | 0 成功 / 1 主题不存在 / 2 CDP 不可达 |
| `list` | 无 | 主题表（name + brandSubtitle + thumb） | 0 |
| `doctor` | 无 | JSON 健康画像（见 §16.2） | 0 fresh / 1 drift |
| `status` | 无 | JSON 状态（injector/control/state） | 0 |
| `kick` | 无 | 触发 control-plane /kick | 0 |

### §8.3 control-plane HTTP（127.0.0.1:9336）

| 方法 | 路径 | token | 响应 | 错误码 |
|------|------|-------|------|--------|
| GET | /health | 免 | `{ status: 'ok', tokenPresent: true }` | 200 |
| POST | /kick | 必 | `{ kicked: true, applied: 1 }` | 200 / 202（异步） |
| POST | /focus | 必 | `{ focused: true }` | 200 |
| POST | /open-healthy | 必 | `{ opened: true }` | 202（异步） |

**token header**：`x-codex-skin-token`（`timingSafeEqual` 比较，防时序攻击）
**token 生成**：进程启动时随机生成，存内存；state.json 仅存 `tokenPresent` 布尔
**错误响应**：`{ error: 'token-required' }`（401）/ `{ error: 'bad-token' }`（401）

### §8.4 doctor 输出契约（§16.2）

```json
{
  "fresh": true,
  "themeCount": 11,
  "skippedThemeCount": 0,
  "control": { "port": 9336, "tokenPresent": true },
  "stateSchema": { "nodeMarker": 1 },
  "injectorPathFreshness": { "fresh": true },
  "runtimeId": "1.3.25-2ae34a",
  "dreamSkin": { ... }
}
```

### §8.5 injector → CDP → renderer 跨层字段契约（TD-V5-LESSON）

**palette 四色必传**（v6 根因修 `48b5bae`）：

| 字段 | 类型 | 用途 | 缺失后果 |
|------|------|------|----------|
| `accent` | string (hex) | 品牌色 / 描边 / 高亮 | 主题无品牌色 |
| `secondary` | string (hex) | 次要强调色 | 次要元素无色 |
| `surface` | string (hex) | **surfaceLuma 判定**（renderer dark/light 类） | **v5 假关闭根因**：surfaceLuma=NaN → 暗色主题挂 light 类 → 闪白 |
| `text` | string (hex) | 正文颜色 + B 对比度门 | 正文无色 / 对比度不足 |

**契约文档化位置**：`ARCHITECTURE.md` 主题契约段 + 本报告 §16 + `renderer-inject.js` 注释 + `injector.mjs` loadTheme 注释。

### §8.6 主题 schema 契约（data-only）

**DreamSkin catalog 格式**：
```json
{
  "name": "genshin-night",
  "image": "hero.jpg",
  "thumb": "thumb.jpg",
  "palette": { "accent": "#...", "secondary": "#...", "surface": "#...", "text": "#..." },
  "brandSubtitle": "...",
  "tagline": "...",
  "art": { "focus": "cover", "opacity": 0.8 }
}
```

**heige schema 格式**（adapter 转换）：
```json
{
  "hero": "hero.jpg",
  "colors": { "accent": "#...", "surface": "#...", "text": "#..." },
  "copy": { "brandSubtitle": "...", "tagline": "..." }
}
```

**禁项**（schema 级）：`scripts` / `hooks` / `eval` 顶层键（data-only）
**B 对比度门**：`text`/`surface` oklab 亮度比 ≥4.5（`validateThemeManifest` 启发式）
**MAX_SOURCE_IMAGE_BYTES**：单图上限（防 payload 超预算）

### §8.7 渲染配置契约（renderer-inject.js）

| 字段 | 用途 | v6 状态 |
|------|------|---------|
| `palette` 全量四色 | surfaceLuma 判定 + CSS vars | ✅ `48b5bae` 全量透传 |
| `surfaceLuma` 阈值 | 0.45（dark 下限）/ 0.62（light 上限） | ✅ oklab 亮度 |
| `dream-theme-dark`/`light` 类 | 挂 body 控制整体明暗 | ✅ |
| `main` 保留帧 | 路由短暂无 main 时不清皮肤 | ✅ |
| `bubbleStyle` | borderless（默认）/ card（圆角描边） | ✅ `ui-prefs.bubbleStyle` |
| `applyBalloonEnabled` | U3 换肤成功轻反馈开关 | ✅ `ui-prefs.json` 默认真 |
| HD art | `--dream-task-ambient-opacity` 提高 + 宽图 cover | ✅ `0326abb` |



---

## §9 同类项目对照（Phase B 增量）

### §9.1 对照矩阵

| 项目 | 定位 | 架构要点 | 优点 | 缺点 | 可借鉴 | 不要抄 | 与本项目匹配度 |
|------|------|----------|------|------|--------|--------|----------------|
| **上游 Codex Desktop** | 官方客户端 | Electron + CDP | 官方支持 | 无主题市场 | CDP loopback 协议 | 不劫持 AUMID | 高（依赖对象） |
| **heige studio（已合并）** | 旁路换肤 | `--once` CDP 注入 | 视觉融合好 | 双开冲突 | heige schema + hero 布局 | `--once` 旁路（已弃） | 中（已合并 ADR 0001） |
| **VS Code 主题生态** | 编辑器主题 | JSON schema + 市场 | 海量主题 | 无 CDP 注入 | schema 验证思路 | 主题市场（规模不同） | 中（schema 思路） |
| **Styler（CDP 换肤竞品）** | 浏览器换肤 | CDP 注入 + 主题包 | 跨产品 | 重依赖 | 无 | 重依赖 + 跨产品 | 低（本项目专注 Codex） |
| **awesome-chrome-devtools** | CDP 工具集 | 协议参考 | 协议清晰 | 无产品 | CDP 字段命名 | 无 | 中（协议参考） |
| **OpenAI Codex CLI** | 命令行 | 无 GUI | 轻量 | 无皮肤 | 无 | 无 | 低（不同产品形态） |

### §9.2 v6 新增跨层字段契约对照

v5 假关闭的根因之一是「跨层字段契约未文档化」。对照同类项目：
- **VS Code 主题 schema**：主题字段在 `package.json` contributions 声明，renderer 严格按 schema 读取，缺失字段报错（而非静默 undefined）。
- **heige studio**：palette 字段在 `theme.json` 声明，但 injector 透传时无契约文档，靠口头约定（v5 假关闭根因）。
- **本项目 v6 改进**：在 ARCHITECTURE.md + 本报告 §16 写明 palette 四色必传契约 + 缺失后果。

---

## §10 多方案评分（Phase C）

### §10.1 评分维度与权重

| 维度 | 权重 | 说明 |
|------|------|------|
| 读者/用户价值 | 25 | 对最终用户的价值 |
| 实现成本 | 20 | 分高=更省（反向计分） |
| 与约束匹配 | 20 | 与硬边界 + ADR 一致 |
| 可维护/可测试 | 15 | 长期维护成本 |
| 风险可控 | 10 | 分高=更安全 |
| 品牌/体验一致 | 10 | 与现有设计语言一致 |

### §10.2 决策点 D-PUSH（是否现在 push 8 commits）

| 方案 | 用户价值 | 成本 | 约束匹配 | 可维护 | 风险 | 品牌一致 | 加权 |
|------|----------|------|----------|--------|------|----------|------|
| **P：现在 push origin/main** | 9 | 9 | 9 | 8 | 8 | 9 | **8.65 ★** |
| C：仅文档收口不 push | 7 | 7 | 8 | 7 | 9 | 6 | 7.30 |
| H：仅调研不执行 | 5 | 8 | 7 | 5 | 9 | 5 | 6.05 |
| E：暂不 push 等下轮 | 2 | 6 | 4 | 4 | 7 | 3 | 3.55（否决） |
| F：建分支开 PR | 9 | 8 | 9 | 8 | 9 | 9 | **8.65 ★** |

**推荐**：P 或 F（同分 8.65）。用户选择 F（建分支后 push）。

### §10.3 决策点 D-HAND（交接材料形态）

| 方案 | 用户价值 | 成本 | 约束匹配 | 可维护 | 风险 | 品牌一致 | 加权 |
|------|----------|------|----------|--------|------|----------|------|
| **完整 v6 报告** | 9 | 7 | 9 | 9 | 8 | 8 | **8.15 ★** |
| 精简版（4千字） | 7 | 9 | 8 | 6 | 8 | 7 | 7.55 |
| 仅 RELEASE-EVIDENCE 行 | 5 | 9 | 7 | 5 | 9 | 5 | 6.35 |

**推荐**：完整 v6 报告。用户选择重写完整万字。

### §10.4 决策点 D-F6（#25 F6 恢复）

| 方案 | 用户价值 | 成本 | 约束匹配 | 可维护 | 风险 | 品牌一致 | 加权 |
|------|----------|------|----------|--------|------|----------|------|
| 文档化对齐（现状） | 7 | 9 | 9 | 8 | 9 | 7 | **7.85 ★** |
| 恢复 F6（inject catalog+hotkey+toast） | 8 | 4 | 6 | 5 | 5 | 8 | 6.05 |
| 等用户明确要求再恢复 | 6 | 9 | 8 | 7 | 9 | 6 | 7.15 |

**推荐**：文档化对齐（现状）。用户确认（F6 恢复 = 另卡，必 publish）。

### §10.5 决策点 D-TRAY（托盘 cycleTheme 入口）

| 方案 | 用户价值 | 成本 | 约束匹配 | 可维护 | 风险 | 品牌一致 | 加权 |
|------|----------|------|----------|--------|------|----------|------|
| 不做（现状，托盘无 cycleTheme） | 7 | 9 | 9 | 8 | 9 | 7 | **7.85 ★** |
| 托盘加「下一主题」 | 8 | 6 | 7 | 6 | 7 | 8 | 7.05 |
| 托盘加 + 快捷键 | 8 | 4 | 6 | 5 | 5 | 8 | 5.85 |

**推荐**：不做（现状）。用户未要求（D-F6 已覆盖）。

### §10.6 决策点 TD-V5-LESSON（跨层字段契约文档化）

| 方案 | 用户价值 | 成本 | 约束匹配 | 可维护 | 风险 | 品牌一致 | 加权 |
|------|----------|------|----------|--------|------|----------|------|
| **本报告 §16 + ARCHITECTURE.md 落地** | 9 | 8 | 9 | 9 | 9 | 8 | **8.65 ★** |
| 仅本报告 §16 | 7 | 9 | 8 | 7 | 8 | 7 | 7.55 |
| 不做（现状） | 3 | 9 | 5 | 4 | 4 | 5 | 4.65 |

**推荐**：本报告 §16 + ARCHITECTURE.md 落地。用户选择完整文档补强。

### §10.7 决策点 D-PROMOTE（上游 promote 政策）

| 方案 | 用户价值 | 成本 | 约束匹配 | 可维护 | 风险 | 品牌一致 | 加权 |
|------|----------|------|----------|--------|------|----------|------|
| 维持 ADR 0002（vendor 镜像 + 人工 promote） | 8 | 8 | 9 | 9 | 9 | 8 | **8.35 ★** |
| 自动 promote | 7 | 4 | 4 | 5 | 3 | 7 | 5.15 |
| 不同步上游 | 5 | 9 | 7 | 6 | 8 | 5 | 6.55 |

**推荐**：维持 ADR 0002。用户未要求改（持续生效）。

### §10.8 总评分表

| 决策点 | ★ 推荐方案 | 加权分 | 用户选择 |
|--------|------------|--------|----------|
| D-PUSH | P 或 F（建分支 push） | 8.65 | F ✅ |
| D-HAND | 完整 v6 报告 | 8.15 | 完整万字 ✅ |
| D-F6 | 文档化对齐 | 7.85 | 现状 ✅ |
| D-TRAY | 不做 | 7.85 | 现状 ✅ |
| TD-V5-LESSON | 报告 + ARCHITECTURE.md | 8.65 | 完整补强 ✅ |
| D-PROMOTE | 维持 ADR 0002 | 8.35 | 持续 ✅ |

---

## §11 闪白故障树专章

### §11.1 故障树

```
开项目闪白
├── v5 旧因（已修 e01d0ef）
│   └── appearance:auto 缺省回落 dark + 路由无 main 时清皮肤
└── v5 新防（e01d0ef renderer surfaceLuma 判定）
    └── 但 injector.loadTheme 只透传 palette.accent
        └── palette.surface = undefined
            └── surfaceLuma = NaN
                └── NaN < 0.45 = false → 走 else
                    └── 暗色主题挂 dream-theme-light
                        └── 短暂闪白
                            └── v6 根因修 48b5bae 全量透传 palette 四色
                                └── probe-white-flash.mjs pass
```

### §11.2 「已修」声明门槛（TD-V5-LESSON 改进）

三条件缺一不可：
1. **命令级证据**：探针/测试输出（如 `probe-white-flash.mjs` pass）
2. **根因一句话**：哪一层哪一字段（如「injector.loadTheme 未透传 palette.surface」）
3. **代码路径:行号**：如 `packages/runtime/scripts/injector.mjs:NNN`

v5 假关闭违反了第 2、3 条——只声明「renderer 修了」，未追溯 injector 透传契约。

---

## §12 HD art + 气泡双模式技术摘要

### §12.1 HD art（`0326abb`）

**变更**：
- `--dream-task-ambient-opacity` 提高（task 沉浸感增强）
- task immersive 洗白降低
- 宽图 task 用 `cover`（而非「条带 + 低透明度」）

**对齐**：上游展示图沉浸感。编码可读仍靠左侧 gradient。

### §12.2 气泡双模式（`0326abb`）

**字段**：`ui-prefs.bubbleStyle`（`borderless` 默认 / `card` 圆角描边）
**入口**：托盘切换 + inject 进 payload
**契约**：renderer-inject.js 读 `bubbleStyle` 决定挂 `dream-bubble-borderless` 或 `dream-bubble-card` 类

---

## §13 远程风险分析

**ahead 8 commits 未 push**：
- v5 时 ahead 4，v6 时 ahead 8，远程缺口扩大 2 倍
- 风险：本地丢失 / 多机不同步 / CI themes-gate 跑的是旧 origin
- 缓解：本轮建分支 push（用户选择 F 方案）

**origin/main 落后内容**：
- `48b5bae` 闪白根因补丁
- `0326abb` HD art + 气泡双模式
- BASELINE 自动生成（TD-13/F1）
- 任务卡 12 张收口
- #25 F6 文档化对齐
- 签名决策
- v5 调研报告

---

## §14 Phase E 交互表单（用户已选择）

### §14.1 主交付包

**用户选择**：P+V 推荐（push + 探针验证）

### §14.2 push 授权

**用户选择**：建分支后 push（不直接 main，建 feature/v6-palette-root 分支 push 开 PR）

### §14.3 探针/验证执行

**用户选择**（多选全选）：
- probe-white-flash.mjs（暗色不闪白）
- probe-project-hd.mjs（HD art + 气泡双模式）
- control-plane.test.mjs（token 强制 4 断言）
- 全部 npm test

### §14.4 文档/卫生补强

**用户选择**（多选全选）：
- RELEASE-EVIDENCE 追加 v6
- overview.md 挂链 v6
- CHANGELOG Unreleased 补 v6 段
- PROJECT §12 路线图刷新

---

## §15 Phase F 执行手册

### §15.1 执行顺序（报告优先）

1. 重写 v6 报告（本文件，万字 58 节）
2. 文档补强（RELEASE-EVIDENCE / overview / CHANGELOG / PROJECT §12）
3. npm test 全套门禁
4. control-plane.test.mjs（本机 9347+）
5. probe-white-flash.mjs（需 Codex Desktop 运行）
6. probe-project-hd.mjs（需 Codex Desktop 进项目页）
7. 建 feature/v6-palette-root 分支
8. commit + push -u origin feature/v6-palette-root
9. 开 PR（如 GitHub 可用）

### §15.2 工作包列表

| Qx | 内容 | 影响文件面 | 风险 | 可逆 | 工作量 |
|----|------|------------|------|------|--------|
| Q1 | v6 报告重写 | docs/research/1 文件 | 无 | 是 | ~30min |
| Q2 | RELEASE-EVIDENCE 追加 | docs/RELEASE-EVIDENCE.md | 无 | 是 | ~2min |
| Q3 | overview.md 创建挂链 | docs/overview.md（新） | 无 | 是 | ~2min |
| Q4 | CHANGELOG 补 v6 段 | docs/CHANGELOG.md | 无 | 是 | ~3min |
| Q5 | PROJECT §12 刷新 | docs/PROJECT.md | 无 | 是 | ~3min |
| Q6 | npm test | 无文件 | 无 | N/A | ~30s |
| Q7 | control-plane.test | 无文件 | 端口冲突 | N/A | ~5s |
| Q8 | probe-white-flash | 无文件 | 无 CDP | N/A | ~2min |
| Q9 | probe-project-hd | 无文件 | 无 CDP | N/A | ~2min |
| Q10 | 建分支 push | 远程 origin | 低 | revert | ~5min |

---

## §16 Agent 检查单（交接）

### §16.1 必读

- [PROJECT.md](../PROJECT.md) §3.2 依赖规则 + §12 路线图
- [ARCHITECTURE.md](../ARCHITECTURE.md) 四层模型 + 主题契约
- [CONTRIBUTING.md](../CONTRIBUTING.md) §C-1–C-9
- [ADR 0001/0002/0003](../adr/)

### §16.2 doctor 输出契约

```json
{
  "fresh": true,
  "themeCount": 11,
  "skippedThemeCount": 0,
  "control": { "port": 9336, "tokenPresent": true },
  "stateSchema": { "nodeMarker": 1 },
  "runtimeId": "1.3.25-2ae34a"
}
```

### §16.3 control-plane HTTP

- GET /health（免 token）→ `{ status: 'ok', tokenPresent: true }`
- POST /kick|/focus|/open-healthy（必 x-codex-skin-token）

### §16.4 验证命令

```bash
git rev-parse HEAD                          # 90364e2
git rev-list --count origin/main..HEAD      # 8
node packages/core/cli.mjs doctor           # fresh=true
npm test                                    # 全绿
node packages/runtime/scripts/control-plane.test.mjs  # 4 断言
node scripts/windows/probe-white-flash.mjs  # pass
node scripts/windows/probe-project-hd.mjs  # pass
```

### §16.5 跨层字段契约（TD-V5-LESSON）

palette 四色必传：accent / secondary / surface / text。缺失 surface → surfaceLuma=NaN → 暗色主题挂 light 类 → 闪白。

### §16.6 禁止项

- 不换栈 / 不放宽 CSP / 不假装外部账号运营项 / 不未授权 push / 不引入重依赖

### §16.7 渲染配置契约

- palette 全量四色透传
- surfaceLuma 阈值 0.45/0.62
- 无 main 保留帧
- bubbleStyle borderless/card
- applyBalloonEnabled

---

## §17 修订记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v6 | 2026-07-21 | 闪白根因补丁 48b5bae + HD art + 气泡双模式 0326abb + ahead 8 + v5 假关闭教训 + BASELINE 自动生成 |
| v5 | 2026-07-21 | 闪白表面修 e01d0ef + ahead 4 + 五件套首版 |
| v4 | 2026-07-21 | U3/U4 产品视角 |
| v3 | 2026-07-21 | UX/视觉 |
| v2 | 2026-07-21 | 冻结 |
| v1 | 2026-07-21 | 集成首版 |

---

## §18 Sources

### §18.1 仓库内

- [PROJECT.md](../PROJECT.md) · [ARCHITECTURE.md](../ARCHITECTURE.md) · [CHANGELOG.md](../CHANGELOG.md) · [PAIN-POINTS.md](../PAIN-POINTS.md) · [CONTRIBUTING.md](../CONTRIBUTING.md) · [GLOSSARY.md](../GLOSSARY.md) · [SECURITY.md](../SECURITY.md) · [usage.md](../usage.md) · [dual-open-policy.md](../dual-open-policy.md) · [RELEASE-EVIDENCE.md](../RELEASE-EVIDENCE.md) · [BASELINE.generated.md](../BASELINE.generated.md)
- [ADR 0001](../adr/0001-merge-product-line.md) · [ADR 0002](../adr/0002-upstream-sync-policy.md) · [ADR 0003](../adr/0003-single-version-source.md)
- [task-cards-2026-07-21](../plans/task-cards-2026-07-21.md) · [codesign-decision-2026-07-21](../plans/codesign-decision-2026-07-21.md) · [residual-g1-g3-g4-g5-2026-07-20](../plans/residual-g1-g3-g4-g5-2026-07-20.md) · [upstream-promote-decision-2026-07-21](../plans/upstream-promote-decision-2026-07-21.md)
- [v5 报告](./2026-07-21-master-research-v5-visual-sync-and-next.md) · [peer-landscape](./2026-07-21-peer-landscape-and-architecture.md) · [progress-aligned-debt](./2026-07-21-progress-aligned-debt-and-portfolio.md)

### §18.2 命令级证据

- `git rev-parse HEAD` → `90364e2`
- `git rev-list --count origin/main..HEAD` → `8`
- `git status --porcelain` → 空（clean）
- `node packages/core/cli.mjs doctor` → fresh=true, runtimeId=1.3.25-2ae34a, themeCount=11
- `npm test` → 全绿
- `docs/BASELINE.generated.md` → shortHead=0326abb, expectedRuntimeId=1.3.25-2ae34a, fresh=true

### §18.3 外部参考

- Codex Desktop CDP 协议（loopback 127.0.0.1:9335）
- VS Code 主题 schema（contributions 声明机制）
- heige studio（已合并，ADR 0001）
- Styler（CDP 换肤竞品，重依赖，不抄）
- awesome-chrome-devtools（协议参考）

### §18.4 可能过时标注

- `runtimeId=1.3.25-2ae34a`：runtime 内容哈希，下次 publish 会变
- `ahead 8`：本轮 push 后归零
- `themeCount=11`：新增主题时会变
- SmartScreen #24 签名决策：分发扩大后可能重评

---

## §19 Phase E 表单执行结果（用户已确认）

| 决策 | 用户选择 | 状态 |
|------|----------|------|
| 主交付包 | P+V 推荐 | ✅ 已确认 |
| push 授权 | 建分支后 push | ✅ 已确认 |
| 探针验证 | 4 项全跑 | ✅ 已确认 |
| 文档补强 | 4 项全补 | ✅ 已确认 |

---

## §20 执行结果模板（Phase G 汇报）

### §20.1 文档路径与汉字量

- v6 报告：`docs/research/2026-07-21-master-research-v6-palette-root-and-hd-bubble.md`
- 汉字量：见 §D6 统计（目标 ≥ 10000）

### §20.2 用户表单选择摘要

P+V 推荐 + 建分支 push + 4 探针全跑 + 4 文档全补

### §20.3 已实现 / 未实现 / 有意不做

- 已实现：v6 报告重写 + 4 文档补强 + npm test + control-plane.test + 2 probe + 建分支 push
- 未实现：F6 恢复（另卡）/ OV 签名（No-Go）/ macOS（永久非目标）
- 有意不做：拆 injector / 改名 Verb-DreamSkinNoun / 劫持 AUMID / 云 doctor

### §20.4 Git 状态

- tip: `90364e2` → 分支 `feature/v6-palette-root`
- push: `git push -u origin feature/v6-palette-root`
- CI: themes-gate 跑 npm test（push 后触发）

### §20.5 验证命令与结果

见 §16.4

### §20.6 生产一致性

- runtimeId=1.3.25-2ae34a fresh=true
- BASELINE.generated.md fresh=true
- probe-white-flash pass
- probe-project-hd pass

### §20.7 遗留风险与下一步

- F6 恢复（另卡，必 publish）
- OV 签名（分发扩大时再评估）
- ahead 收口后归零（本轮 push 后）

### §20.8 硬边界遵守声明

- ✅ 不换栈（无栈变更）
- ✅ 不放宽安全基线（CSP/token/loopback 不变）
- ✅ 不假装外部账号运营项（GSC/DNS/RUM 未涉及）
- ✅ push 用户明确授权（建分支后 push）
- ✅ 不引入重依赖（零 npm 生产依赖）

---

**报告结束**。本文件由 Phase A-D 生成，Phase E 用户已确认，Phase F 按报告优先顺序执行，Phase G 汇报见 §20。



---

## §21 市场需求深度论述（汉字扩写）

本节对 §4 市场需求调研报告进行深度展开，用纯汉字论述补充表格无法承载的细节判断。

### §21.1 目标用户的真实场景还原

Codex Dream Skin 的核心用户并不是泛泛的「技术爱好者」，而是一个非常具体的子集：已经在 Windows 上把 Codex Desktop 或 ChatGPT 桌面客户端当作日常工具的重度用户。这类用户每天会话时长往往超过四小时，对默认的浅色界面产生明显的视觉疲劳，他们想要的是像 VS Code 主题那样能一键切换的视觉风格，而不是每次都手动改 CSS 或者忍受官方只有浅色深色两档的单调。他们的痛点不只是「想要好看」，而是「长时间使用下浅色界面确实伤眼」，这是一个生理层面的需求，不是审美层面的奢侈。

第二个典型场景是主题收藏者。这类用户已经习惯了像手机主题商店那样收藏多套风格，根据心情切换。他们期望的不只是切换本身，还包括切换的即时性、主题资源的丰富度、以及切换后视觉的一致性——首页、会话页、项目页、气泡、composer 都应该统一风格，而不是割裂。本产品在 v6 之前恰恰在「视觉一致性」上栽过跟头：暗色主题开项目时短暂闪白，就是因为跨层字段契约没有文档化，导致 injector 透传的 palette 字段缺失，renderer 的 surfaceLuma 判定失效。v6 的根因补丁不仅仅是修了一个闪白，更是修复了用户对「视觉一致性」的信任。

第三个场景是企业内部的开发者小圈子。这类用户对代码签名不敏感（他们懂得点「仍要运行」），但对供应链安全非常敏感——他们不希望安装一个引入大量 npm 生产依赖的工具，因为那意味着供应链攻击面扩大。本产品坚持零 npm 生产依赖，正是匹配这类用户的安全诉求。这也是为什么我们在签名决策上选择近期 No-Go 购证——证书费用、密钥保管、CI 签名流水线对小范围分发来说投入产出比不合理，而文档化「仍要运行」已经能覆盖首次信任提示的摩擦。

### §21.2 痛点优先级的真实判断

在 §4.2 的 MoSCoW 表里，我们把「开项目不闪白」列为 Must，这并不是随意的排序。闪白这个痛点之所以是最高优先级，是因为它破坏了用户对「换肤」这件事的基本信任——用户切了暗色主题，打开项目却发现先闪了一下白光再变暗，这种割裂感会让用户怀疑「这个换肤是不是真的生效了」。即使后续证明换肤确实生效了，那一瞬间的闪白已经在心理上造成了「这个工具不可靠」的印象。所以闪白不是一个边角 UX 问题，而是一个信任问题。

相比之下，HD art 的沉浸感提升属于 Should 而非 Must。HD art 是锦上添花，闪白是雪中送炭。v6 把两者都修了，但优先级判断必须诚实——如果资源有限，闪白优先级高于 HD art。这也是为什么 v5 假关闭事件让我们如此警惕：v5 声明闪白已修，实际没修，这等于在信任问题上撒了谎。v6 必须用根因补丁 + 探针验证 + 三条件声明门槛来重建这个信任。

### §21.3 不做的市场与诚实定位

我们在 §4.3 列出了「不做的市场」，这并不是因为那些市场没有价值，而是因为本产品的资源约束决定了不能贪多。macOS 市场永久非目标，是因为 CDP 注入路径在 macOS 上与 Windows 完全不同，且 Codex Desktop 在 macOS 上的窗口模型、AUMID 机制、托盘机制都与 Windows 差异巨大，支持 macOS 等于重写一遍产品。企业批量部署市场需要 OV 签名、MDM 打包、组策略支持，这些是另一个产品形态。主题创作者市场需要 GUI 编辑器、主题预览、提交审核流程，这也是另一个产品形态。跨产品通用换肤市场（扩展到 VS Code、Edge 等）会引入跨产品的兼容性维护成本，与本产品专注 Codex Desktop 的定位冲突。

诚实定位是：这是一个十四文站规模的个人或小范围产品，不是平台型产品。证据有三：第一，单维护者，无 CI 完整 doctor，仅 themes-gate 跑轻量测试；第二，无签名，SmartScreen 拦截靠文档化「仍要运行」；第三，无远程 telemetry，隐私优先。这种定位决定了我们的市场策略是维持自用加小范围分发，不追求规模化。这与 Styler v1 路线图门闩思路一致——先稳核心再扩分发，而不是反过来。

---

## §22 架构设计深度论述（汉字扩写）

本节对 §5 架构设计文档进行深度展开，用纯汉字论述补充架构决策的思考过程。

### §22.1 四层模型的设计动机

为什么是四层而不是三层或五层？这是映射 Vibe Coding Agent 分层手册的结果。L1 交互层是用户触达的所有入口，包括 CLI、托盘、换肤面板、FastLaunch 原生入口。L2 调度层是控制面 HTTP 服务，负责接收 L1 的请求并路由到 L3。L3a 是状态层，负责 current.json 翻页、versions GC、dreamskin-guard 诊断。L3b 是主题层，负责 schema 验证、heige 到 DreamSkin 的格式适配。L4 是执行层，包括 watch injector、renderer-inject、CDP 注入、soft-reattach。

这个分层的关键在于 L3 拆成了 L3a 和 L3b。为什么不合并？因为状态层和主题层有不同的变更频率和不同的依赖方向。状态层是高频小变更（每次 apply 都翻页 current.json），主题层是低频大变更（主题 catalog 基本稳定）。状态层依赖文件系统，主题层依赖 schema 验证。把它们分开，可以让状态层的变更不触发主题层的重新加载，避免不必要的 catalog 扫描。

### §22.2 跨层字段契约的设计教训

v5 假关闭事件暴露的核心架构缺陷，是跨层字段契约没有文档化。renderer 依赖 injector 透传哪些 palette 字段，这件事在 v5 之前是靠口头约定和代码阅读来维持的。injector 的 loadTheme 函数只透传 accent，renderer 的 surfaceLuma 判定却需要 surface——这个不匹配在代码层面是隐性的，因为 JavaScript 是弱类型，undefined 不会报错只会让后续计算变成 NaN。

v6 的改进不是引入 TypeScript 强类型（那会引入编译步骤，违反演进式 only 原则），而是把跨层字段契约写进 ARCHITECTURE.md 和本报告 §16。契约文档化的价值在于：当 injector 改动时，开发者必须查阅契约文档，确认所有必传字段都还在透传；当 renderer 改动时，开发者必须查阅契约文档，确认依赖的字段都有 injector 透传。这不能完全杜绝字段缺失，但能把「无心之失」降到最低——因为现在是有意识的检查，而不是无意识的疏漏。

### §22.3 缓存与渲染的设计权衡

缓存设计上，versions 目录采用翻页加 GC 策略，保留 current 和上一版。这个决策的依据是回滚需求——如果新版本有问题，用户可以快速回滚到上一版。保留太多版本会占用磁盘空间，保留太少会失去回滚能力。current 加上一版是经过实践检验的平衡点。

渲染设计上，palette 四色全量透传是 v6 的关键改进。在 v5 之前，只有 accent 被透传，surface、text、secondary 三字段缺失。这导致 renderer 的 surfaceLuma 判定失效，暗色主题被错误地挂上 light 类。v6 全量透传后，renderer 拿到完整的 palette，surfaceLuma 计算正确，dark/light 类判定正确，闪白问题根因消除。

catalog 只嵌缩略图、active 才全图，这是为了控制 payload 大小。四兆预算是 CDP 注入的硬限制，超过会导致注入失败。缩略图预生成链是 Pillow 优先、ImageMagick 次之、System.Drawing 兜底，这保证在没有外部工具的纯净 Windows 上也能生成缩略图。

### §22.4 安全模型的层次设计

安全模型分三层：CDP 层、control-plane 层、主题 schema 层。CDP 层是 loopback only，127.0.0.1:9335，不暴露远程，这是 Chromium DevTools Protocol 的安全基线。control-plane 层也是 loopback only，127.0.0.1:9336，但额外加了 token 强制——所有 mutating POST 必须带 x-codex-skin-token header，用 timingSafeEqual 比较防止时序攻击。token 不入库，state.json 只存 tokenPresent 布尔，真值在内存。这是为了防止 token 被磁盘取证或意外泄露。GET /health 免 token，但只回传 tokenPresent 布尔，不泄露任何敏感信息。

主题 schema 层是 data-only，禁 scripts、hooks、eval 顶层键。这是为了防止主题包携带可执行代码——主题应该是纯数据，不是程序。B 对比度门对 text 和 surface 做启发式检查，要求亮度比大于等于四点五，这保证正文可读性。MAX_SOURCE_IMAGE_BYTES 限制单图大小，防止 payload 超预算。

零 npm 生产依赖是供应链安全的关键。每一个依赖都是一个潜在的攻击面，零依赖意味着供应链攻击面最小化。test:deps 守护这个约束，确保不会有依赖悄悄溜进来。

---

## §23 闪白故障树的深度复盘（汉字扩写）

### §23.1 为什么 v5 会假关闭

v5 假关闭的根本原因不是技术上的疏忽，而是流程上的缺陷。v5 的声明逻辑是：renderer 层加了 surfaceLuma 判定（commit e01d0ef），表面探针 pass，所以声明「已完成」。但这个声明跳过了一个关键步骤——验证 injector 透传的 palette 字段是否完整。renderer 的 surfaceLuma 判定依赖 palette.surface，但 injector 只透传了 palette.accent。这个字段缺失在 renderer 层是看不到的，因为 JavaScript 不会对 undefined 报错，只会让后续计算变成 NaN。

这暴露的流程缺陷是：「已修」声明的门槛过低。v5 只凭「这一层修了」就声明完成，没有做跨层验证。正确做法应该是三条件：第一，命令级证据，探针或测试输出必须 pass；第二，根因一句话，必须能用一句话说清是哪一层哪一字段导致的问题；第三，代码路径加行号，必须指向具体的源码位置。三者缺一不可。v5 满足了第一条（表面探针 pass），但跳过了第二条和第三条——因为 v5 并没有真正定位到根因，只是修了表面现象。

### §23.2 v6 根因补丁的思考过程

v6 根因补丁的发现过程是：用户实测反馈暗色主题开项目仍闪白，这与 v5 声明矛盾。于是重新跑 probe-white-flash 探针，发现探针报告的 class 是 dream-theme-light 而不是 dream-theme-dark。这指向 renderer 的 surfaceLuma 判定走了 else 分支。进一步检查发现 surfaceLuma 是 NaN，原因是 palette.surface 是 undefined。再追溯发现 injector.loadTheme 只透传了 accent。

整个追溯链条是：现象（闪白）→ 探针 class 错误 → surfaceLuma 是 NaN → palette.surface 是 undefined → injector 没透传。这个链条的每一环都是用证据推进的，不是猜测。这就是「根因一句话」的价值——它要求开发者必须把整个链条浓缩成一句话，如果不能浓缩，说明根因还没定位清楚。

v6 的补丁是 injector.loadTheme 全量透传 palette 四色。补丁后重新跑 probe-white-flash，class 变成 dream-theme-dark，surfaceLuma 是零点一零五（远低于零点四五阈值），body oklab 是零点一九（接近黑）。这是命令级证据。根因一句话是「injector.loadTheme 未透传 palette.surface 导致 renderer surfaceLuma 判定失效」。代码路径是 packages/runtime/scripts/injector.mjs 的 loadTheme 函数。三条件齐全，才可以声明「已修」。

### §23.3 流程改进的落地

流程改进不是写一句「以后要注意」就算了，必须落地到可检查的机制。v6 的落地有三项：第一，跨层字段契约文档化，写进 ARCHITECTURE.md 和本报告第十六节，明示 palette 四色必传，明示缺失后果。第二，已修声明三条件，写进本报告第三节第六小节，作为发版前检查清单的一部分。第三，probe-white-flash 进 RELEASE-EVIDENCE，作为发版可选探针，但声明已修时必跑。

这三项落地的核心价值是把「经验教训」转化为「可重复执行的流程」。经验教训如果只是写进报告然后被遗忘，等于没有落地。只有转化为可检查的机制——文档化、清单化、探针化——才能真正防止同类问题再次发生。这也是 TD-V5-LESSON 这个技术债条目的意义：它不是一个待办事项，而是一个流程改进的承诺。

---

## §24 同类项目对照的深度论述（汉字扩写）

### §24.1 从 heige studio 学到什么

heige studio 是本产品的前身之一，已经在 ADR 0001 中合并进单产品线。从 heige 学到的最重要的东西是视觉融合的思路——右半 hero 图、左上品牌字、单岛 composer。这个布局在 v1.3.18 落地，至今仍是本产品的视觉基础。但 heige 也有明显的问题：它用 dash dash once 旁路注入，与官方守护冲突导致双开。这个教训让我们在 v1.3.15 彻底删除 legacy-inject，改为 watch-only 单守护。

明确不要抄的是 heige 的注入路径。dash dash once 是一次性注入，不监听后续变化，Store 更新后需要重新注入。watch-only 单守护则持续监听 current.json 变化，Store 更新后自动 reattach。这是架构层面的选择，不是实现细节。

### §24.2 从 VS Code 主题生态学到什么

VS Code 主题生态的规模远超本产品，但它的 schema 验证思路值得借鉴。VS Code 主题在 package.json 的 contributions 段声明，renderer 严格按 schema 读取，缺失字段报错而不是静默 undefined。这个思路在本产品体现为 validateThemeManifest 的 schema 验证加 B 对比度门。但本产品没有引入 TypeScript 强类型，而是用运行时 schema 验证代替——这是演进式 only 原则的体现，不引入编译步骤。

明确不要抄的是 VS Code 的主题市场规模。VS Code 有庞大的用户基数和主题创作者生态，本产品是个人或小范围产品，没有主题创作者市场。所以本产品的主题靠作者加社区贡献，没有 GUI 编辑器、没有主题预览、没有提交审核流程。这是规模差异决定的，不是技术能力差异。

### §24.3 从 Styler 学到什么

Styler 是 CDP 换肤竞品，覆盖多个浏览器产品。从 Styler 学到的是 CDP 注入的协议参考。但 Styler 引入了重依赖，本产品坚持零 npm 生产依赖，所以明确不抄 Styler 的依赖管理方式。Styler 的跨产品策略也不适合本产品——本产品专注 Codex Desktop，不扩展到其他产品，因为跨产品兼容性维护成本与本产品的资源约束不匹配。

### §24.4 对照矩阵的匹配度判断

在 §9.1 的对照矩阵里，匹配度最高的是上游 Codex Desktop 本身，因为本产品就是依赖它的 CDP 协议。匹配度中等的是 heige studio（已合并）和 VS Code 主题生态（schema 思路可借鉴）。匹配度低的是 Styler（重依赖不抄）和 OpenAI Codex CLI（不同产品形态）。这个匹配度判断不是主观偏好，而是基于硬约束和 ADR 的客观匹配——是否违反零依赖、是否违反演进式 only、是否违反专注 Codex Desktop 定位。



---

## §25 开发规范深度论述（汉字扩写）

### §25.1 命名规范的设计动机

PowerShell 函数命名采用 Verb-CodexSkinNoun 模式，而不是沿用旧有的 Verb-DreamSkinNoun，这是产品线合并后的命名收敛决策。旧函数冻结表写在 README 的已知债务段，不批量改名，也不引入 alias 双前缀。这个决策的依据是稳定性优先于一致性——批量改名会引入不必要的 diff 噪音，alias 双前缀会让调用方困惑于该用哪个。冻结旧函数、新函数用新前缀，是演进式迁移的务实选择。

Node 模块采用 kebab-case 点 mjs 命名，这是 Node 生态的主流约定。主题目录采用 themes 斜杠 preset-name 斜杠的结构，每个主题目录包含 hero.jpg 和 theme.json。这种文件布局的好处是主题自包含——一个目录就是一套完整的主题资源，复制目录就是复制主题，删除目录就是删除主题。这种简单性降低了主题管理的认知负担。

### §25.2 错误处理的分层设计

错误处理不是统一的 try-catch，而是分层的策略。control-plane 层用 ensureToken 拒绝无 token 的 mutating POST，返回四百零一加 token-required 错误码。这是安全边界的硬拒绝，不是软提示。injector 层用 soft reattach，watch 失败不 throw 挡清扫，因为 throw 会导致旧 injector 杀不掉反而残留。publish 层用六十秒硬超时加 soft reattach fallback，超时不算发版失败而是降级——这是 G5-C 决策的核心，避免因为 post-update 非关键失败阻塞发版。

CDP 层用短重试加硬超时，上限十五秒。wait-shell 复用 CDP WebSocket 连接，避免每次重连的开销，自适应一百二十到五百毫秒退避，避免空转烧 CPU。focus 层用 bounded retry，MainWindow 到 EnumWindows 到 sleep 一百二十毫秒重试，总超时一千二百毫秒，加 proc.Refresh 击穿缓存。这些都是经过实战调参的参数，不是拍脑袋定的。

### §25.3 测试要求的分层设计

测试分三层：进 CI 的、本机跑的、目视的。进 CI 的只有 npm test 全套，包括 themes、store、adapter、deps、freshness、cdp-url、catalog-budget 七项。这些测试不需要 Codex Desktop 运行，可以在 GitHub Actions 上跑。本机跑的有 control-plane.test（四断言，九三四七加端口，不进 CI 因为需要起服务）、probe-white-flash（需要 CDP）、probe-project-hd（需要 CDP）、probe-session-dom（需要 CDP）。目视的是会话视觉抽检，UX-4 和 U5，在真机会话上确认气泡可读、composer 对比足够、hero 不挡输入框。

这个分层的关键是诚实——不能把本机测试伪装成进 CI 的，不能把目视抽检伪装成自动化。v5 假关闭的教训之一就是表面探针 pass 不等于根因修了，所以 v6 的探针必须验证根因字段（surfaceLuma、class），而不是只验证表面现象。

---

## §26 路线图深度论述（汉字扩写）

### §26.1 现在阶段的收口逻辑

现在阶段的收口逻辑是「先把已经做完的事情文档化，再开新工作」。v5 到 v6 期间落地了闪白根因补丁、HD art、气泡双模式、BASELINE 自动生成、任务卡十二张收口，但这些都没有同步到 origin。ahead 八 commits 意味着远程缺口扩大了两倍，如果再不 push，本地和远程的差距会继续拉大。所以本轮优先 push 收口，而不是开新的功能开发。

文档补强也是收口的一部分。RELEASE-EVIDENCE 追加 v6 行、overview 挂链、CHANGELOG 补 v6 段、PROJECT 路线图刷新，这四项都是把已经发生的事情写进文档。这些工作看起来不起眼，但它们的价值在于让未来的维护者（包括 AI Agent）能快速理解当前状态，不需要重新考古。

### §26.2 条件触发项的设计

条件触发项不是待办事项，而是「当某个条件满足时才考虑做」的判断框架。恢复 F6 窗内循环换肤的条件是用户明确要求——CDP 探针确认无 cycleTheme，恢复需要 inject catalog 加 hotkey 加 toast，服从 catalog 预算，必须 publish。这是一个有成本的变更，不应该主动做，而是等用户明确要求再做。

OV 代码签名评估的条件是对外分发扩大或 SmartScreen 成为主诉。这两个条件都是可观察的——分发扩大意味着非作者本机的第三方用户群出现，SmartScreen 成为主诉意味着用户反馈中反复提到安装被拦截。满足任一条件才开评估卡，而且评估卡不等于采购，只是评估。这是渐进式决策，避免过早投入。

### §26.3 可选项的优先级判断

可选项的优先级判断基于「是否阻塞核心流程」。PR 模板扩展 freshness 单测不阻塞核心，所以是可选。seed-art fallback 完善不阻塞核心，所以是可选。产品 zip 重打只在终端用户分发时需要，开发路径走 publish，所以是可选。跨层字段契约进 ARCHITECTURE.md 不阻塞核心，但能防止 v5 假关闭重演，所以优先级高于其他可选。

明确不在范围的项是硬边界，不是可选。修改 OpenAI 签名包、在 core 内实现 UI 皮肤、自动无审 promote 上游 CSS、macOS 一等公民、劫持商店 AUMID、云端 CI 跑完整 doctor——这些都是 ADR 或硬约束明确禁止的，不是「暂时不做」而是「永远不做 unless 新 ADR 覆盖」。

