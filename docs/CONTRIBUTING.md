# Codex Dream Skin 贡献规范

> 适用范围：所有 PR、所有包（core / themes / runtime / core-win / apps/launcher / scripts/windows / docs / apps/native）  
> 基线：HEAD 以 `git rev-parse HEAD` 为准 · runtime 产品线 `1.3.25` · 本机安装态以 doctor `runtimeId` 为准（文档撰写时 `1.3.25-107b0e`）  
> 关联：[`PROJECT.md`](./PROJECT.md) §3 依赖规则 · [`adr/0001`](./adr/0001-merge-product-line.md) · [`adr/0003`](./adr/0003-single-version-source.md) · [`adr/0006`](./adr/0006-independent-product-line.md) · [`PAIN-POINTS.md`](./PAIN-POINTS.md) · 任务卡 [`plans/task-cards-2026-07-21.md`](./plans/task-cards-2026-07-21.md)

---

## 附录 C-1：模块依赖 PR 必答 7 问

**规则**：任何涉及 `packages/*` 或 `scripts/windows/*` 的 PR，必须在 PR 描述中回答以下 7 问。缺答阻塞 merge。

| # | 问题 | 答错信号 |
|---|------|---------|
| 1 | 改了哪个包？ | 答「多个」却无重构理由 |
| 2 | 新增静态 import？ | 答有但未列双向 |
| 3 | 是否 core↔runtime 互引？ | 答是（立即否决，违反 ADR 0001） |
| 4 | 是否新增注入旁路？ | 答是（违反绝对约束：CLI/apply 不得绕过 active-theme 直连 CDP 注入主题） |
| 5 | 路径解析走 `resolveStudioPaths` / `Get-CodexSkin*`？ | 答否且业务代码散落 `$env:LOCALAPPDATA` |
| 6 | 是否改 active-theme 写入？ | 答是但未同步 runtime watch 逻辑 |
| 7 | 是否改版本源？ | 答是但走 `package.json` 而非 `publish-runtime.ps1 -Version`（违反 ADR 0003） |

**正例**：

```text
1. packages/runtime（仅 injector.mjs 注释）
2. 无新增静态 import
3. 否
4. 否
5. 不涉及路径
6. 否
7. 否
```

**反例**：「改了 runtime，测试通过」（7 问全缺）

**验收**：PR 描述含 7 问 checklist；`npm run test:deps` 本机绿。

---

## 附录 C-2：主题 PR 验收

**规则**：新增/修改主题必须满足：

- [ ] 主题目录在 `themes/<id>/`（源）或用户 catalog；`theme.json` / manifest 为双格式之一（heige `hero/colors/copy` 或 DreamSkin `image/palette/brandSubtitle/tagline`）
- [ ] `npm run test:themes` 通过（含新主题 `loadTheme('<id>')` 若已纳入 bundled 循环）
- [ ] 用户 catalog 侧 `source` 语义正确（user vs bundled）
- [ ] 资产路径无 `..` / 绝对路径（`normalizeAssetPath` 会拒）
- [ ] 若含图片，导入侧 `MAX_SOURCE_IMAGE_BYTES`（theme-store，8MB）内
- [ ] `node packages/core/cli.mjs list` 含新主题且 `schemaVersion=1`
- [ ] `node packages/core/cli.mjs apply --theme <id>` 后 doctor `fresh=true`（可选但推荐）
- [ ] **可读性（UX-3 / B 门禁）**——机器 + 目视：
  - [ ] `npm run test:themes`：`text`/`surface` 对比度启发式 ≥ **4.5**（`assertReadableTextSurface`；非全站 WCAG 承诺）
  - [ ] `text` 与 `surface` / 页面底可辨，长文可读
  - [ ] `muted`/次要色不「融进」背景
  - [ ] accent 上的字/图标有足够对比（参考 `--dream-accent-ink`；accent 本身不做硬失败）
  - [ ] 亮色主题与暗色意图自洽（若提供 dark）
  - [ ] hero/`art` 焦点不压住 composer 输入区（`focusX`/`focusY`）
  - [ ] **无**危险顶层键（`scripts`/`hooks`/…）；调色走 palette + [design-tokens.md](./design-tokens.md)

**正例**：`themes/dream-aurora/theme.json` + `test:themes` 绿 + list 命中 + 可读性勾选。

**反例**：主题目录塞进 `packages/runtime/assets/`；test 未覆盖新 id；灰字灰底「有氛围但不可读」。

**验收**：`npm run test:themes` 绿；`node packages/core/cli.mjs list` 含新主题；可读性清单已勾或 PR 附图。

---

## 附录 C-3：runtime/CSS PR 验收

**规则**：

- [ ] `packages/runtime/scripts/injector.mjs` 改动需本机 `node packages/core/cli.mjs doctor` + `npm test` 双绿
- [ ] `packages/runtime/assets/renderer-inject.js` 改动需手测 `apply --theme` → CDP 9335 evaluate 链路
- [ ] `packages/runtime/assets/dream-skin.css` 改动需手测 backdrop 历史回归（PAIN-POINTS #21 OS 硬限语境下的视觉回归）
- [ ] 任何 payload 预算常量改动（`MAX_ART_BYTES` / `DEFAULT_PAYLOAD_BUDGET_BYTES` / `MAX_THEME_CATALOG_BYTES` / `MAX_CATALOG_MEMBER_BYTES`）需在 PR 描述说明理由
- [ ] 改动 `SKIN_VERSION_TOKEN` 字面量必须经 `publish-runtime.ps1 -Version`，禁止手改源文件 token
- [ ] **发版纪律**：改 `packages/runtime/**` 后必须 `pwsh scripts/windows/publish-runtime.ps1 -Version <line>` 才能进入 `%LOCALAPPDATA%\Programs\CodexDreamSkin\versions\<runtimeId>\`（源树改动不会自动进安装树）

**正例**：CSS 改动 PR 附 before/after 说明 + doctor 输出。

**反例**：CSS 改动 PR 仅「美化」无验证；手改 `SKIN_VERSION_TOKEN = "1.3.26"`。

**验收**：doctor `fresh=true`；`apply --theme <id>` 后 CDP 注入成功。安装树 `control-plane.mjs` 含 `timingSafeEqual` 且 mutating 路由 header-only（`x-codex-skin-token`）；`node packages/core/cli.mjs doctor` → `injectorPathFreshness.fresh=true`。

**仓 ↔ 安装树（TD-01）**：publish 后建议跑：

```powershell
pwsh -NoProfile -File scripts\windows\verify-install-matches-repo.ps1 -RepoRoot D:\orca\codex-skin
```

- exit `0`：关键文件 hash + control-plane 安全标记对齐  
- exit `1`：漂移（先 publish 再复跑）  
- exit `2`：本机未安装 / 无 `current.json`  
- `-Json`：机器可读报告  

发版证据一页纸（维护者勾选）：[RELEASE-EVIDENCE.md](./RELEASE-EVIDENCE.md)。  
发版前建议再跑：`pwsh -NoProfile -File scripts/windows/write-baseline.ps1`（刷新 `docs/BASELINE.generated.md`，便于对照 HEAD / expectedRuntimeId）。

---

## 附录 C-4：publish/产品包 PR 验收

**规则**：

- [ ] `scripts/windows/publish-runtime.ps1` 改动需用 `-Version` 参数本机 dry-run / 实跑
- [ ] `scripts/windows/Build-ProductPackage.ps1` / `Install-Product.ps1` 改动需本机安装态验证
- [ ] 任何版本源改动必须只走 `publish-runtime.ps1 -Version`（ADR 0003）
- [ ] 改 `packages/runtime/**` 后必须跑 `publish-runtime.ps1 -Version <line>` 才能进安装树；验收安装树 control-plane 含 `timingSafeEqual` / header-only（`x-codex-skin-token`）+ doctor `fresh=true` + 建议 `verify-install-matches-repo.ps1` exit 0
- [ ] `soft-reattach.ps1` 改动需同时验证 publish + Install 两条调用链，且传 `--theme-dir` + `--state-root`
- [ ] G5-C 超时逻辑（publish 尾部 `WaitForExit` + soft reattach fallback）改动需验证超时与非零退出两条路径；Quiet exit=2 后 soft reattach **成功**应见 `soft reattach OK`（非吓人 Warning）
- [ ] seed art fallback 不得钉死已 GC 的旧 runtimeId；优先 repo `packages/runtime/assets` + 动态扫 `versions/*/assets`

**正例**：publish 改动 PR 附 `node packages/core/cli.mjs doctor` 输出含新 runtimeId。

**反例**：在 `package.json` 直接改 `version` 字段当作 stamp 权威。

**验收**：`publish-runtime.ps1 -Version <x.y.z>` 后 doctor `expectedRuntimeId` 对齐；Install 路径 soft reattach 后 `fresh=true`。完整勾选见 [RELEASE-EVIDENCE.md](./RELEASE-EVIDENCE.md)。建议同步 `write-baseline.ps1` 刷新生成基线。

---

## 附录 C-5：命名与 PS 编码

**规则**：

- 新增 PowerShell 函数用 `Verb-CodexSkinNoun` 前缀
- `packages/core-win/common-windows.ps1` 旧 `Verb-DreamSkinNoun`（30+ 个，如 `Enter-DreamSkinOperationLock` / `Get-DreamSkinNodeRuntime` / `Get-DreamSkinCodexInstall`）**冻结，不可重命名**（见任务卡 WIN-02）
- 新增 .mjs 模块用 camelCase 导出
- 路径解析统一走 `resolveStudioPaths`（`packages/core/constants.mjs`）/ `Get-CodexSkin*`（core-win），禁止业务代码散落 `$env:LOCALAPPDATA` 硬编码
- scripts 解析层（launcher 入口拼 stateRoot）按 PROJECT §3.2 允许，但不得复制到业务算法
- PS 入口 UTF-8 / chcp 65001 bootstrap（PAIN-POINTS #22）

**正例**：

```powershell
function Get-CodexSkinStateRoot { ... }
function Invoke-CodexSkinControl { ... }
```

**反例**：

```powershell
function Get-DreamSkinNewThing { ... }  # 新函数禁用 DreamSkin 前缀
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'  # 业务代码散落
```

**验收**：

- 新增函数 Grep `DreamSkin` 在 `git diff` 范围内 0 命中（冻结表改名除外：禁止）
- Grep `$env:LOCALAPPDATA` 仅在 scripts 解析层 / constants 路径解析允许

---

## 附录 C-6：小步提交约定

**规则**：

- 单次 commit 优先 ≤300 行改动（大重构拆 stack）
- 重构与功能改动分提交
- commit message 第一行 imperative + standalone：
  - 正：`Add dream-aurora theme` · `Enforce control-plane token (SEC-01)`
  - 反：`Fix bug` · `Phase 1` · `Adding ...` · `修了几个问题`
- body 说明 what + why，链接 ADR / PAIN-POINTS / 任务卡 ID
- 禁止「一把梭重构」

**正例**：

```text
Add control-plane token test (SEC-01 regression guard)

Cover 4 paths: GET /health 200, POST /kick no-token 401,
wrong-token 401, correct-token 200. Run on 9347+ to avoid
conflict with active daemon. Not added to CI (needs server).

Refs: docs/CONTRIBUTING.md §C-1, task TEST-02
```

**反例**：`fix: 修了几个问题` · `wip` · `.`

**验收**：`git log --oneline -10` 第一行均 informative；大 diff 有拆分说明。

---

## 附录 C-7：何时允许 `--once` 降级

**规则**：

- `injector.mjs --once` 仅作为「同 runtime 单次降级」，**不能包装成第二守护**
- 触发条件：control-plane 不可达（端口扫描失败 / token 丢失等）且走 `kickThemeInjectNow` 内置降级
- `--once` 执行后必须退出，不可 watch
- `packages/core/state/kick-inject.mjs` 优先 control-plane，失败再 spawn `--once` 是**唯一允许路径**
- 禁止 cron 定时跑 `--once` 作为「保活」
- CLI 不暴露用户开关包装第二产品线

**正例**：control-plane 不可达，`kickThemeInjectNow` 自动 spawn 同树 `--once` 单次注入后退出。

**反例**：

- cron 每分钟跑 `node injector.mjs --once`（第二守护）
- 包装 `--once` 为 Windows Service 常驻
- `apply --theme` 直接调 `--once` 绕过 active-theme

**验收**：Grep `--once` 仅在 kick 路径、injector 参数定义、文档中出现；无第二守护包装脚本。详见 [`dual-open-policy.md`](./dual-open-policy.md)。

---

## 附录 C-8：禁止事项速查表

| # | 禁止 | 理由 | ADR |
|---|------|------|-----|
| 1 | 恢复 heige 第二产品线 / `packages/legacy-inject` | ADR 0001 已合并 | 0001 |
| 2 | core↔runtime 静态 import 互引 | 边界纪律 | 0001 |
| 3 | CLI/apply 绕过 active-theme 直接 CDP 注入 | 主路径纪律 | — |
| 4 | 劫持 Microsoft Store AUMID / 修改 Codex .asar | 官方签名包纪律 | — |
| 5 | 把 macOS 做成一等公民 | 永久非目标 | — |
| 6 | 在 `package.json` 直接改 version 作为 stamp 权威 | ADR 0003 单一版本源 | 0003 |
| 7 | 业务代码散落 `$env:LOCALAPPDATA` 硬编码 | 路径集中纪律 | — |
| 8 | 包装 `--once` 为第二守护 | 单守护纪律 | — |
| 9 | 批量重命名 `Verb-DreamSkinNoun` 为 `Verb-CodexSkinNoun` | WIN-02 冻结表 | — |
| 10 | 为「好看」拆分 `injector.mjs` 为多文件（无 publish copy 清单同步） | 单文件单守护 + 发布契约 | 0001 |
| 11 | 引入 monorepo 大迁 / Nest / 微服务 | 架构演进式 only | — |
| 12 | 把 themes 或 CSS 生成塞进 core | 边界纪律 | — |
| 13 | 云 doctor / 远程 telemetry | 隐私 + 非目标 | — |
| 14 | 手改 `SKIN_VERSION_TOKEN` 字面量（不经 publish） | ADR 0003 | 0003 |
| 15 | 恢复双 injector | ADR 0001 单守护 | 0001 |

**验收**：PR 审查时逐条对照；命中任一立即否决。

---

## 附录 C-9：schema 版本三件套语义

| 常量 / 字段 | 类型 | 当前值 | 语义 | 位置 |
|------------|------|--------|------|------|
| `STATE_SCHEMA_NODE_MARKER` | 契约常量 | 1 | Node 侧 docs/export 标记（**非 on-disk 写出**） | `packages/core/constants.mjs` |
| `STATE_SCHEMA_VERSION` | 弃用别名 | = `STATE_SCHEMA_NODE_MARKER` | 兼容旧 import；新代码用 `STATE_SCHEMA_NODE_MARKER` | `packages/core/constants.mjs` |
| `THEME_SCHEMA_VERSION` | 契约常量 | 1 | theme.json / catalog manifest schema 版本 | `packages/core/constants.mjs` |
| `state.json.schemaVersion` | on-disk 写出 | 3 | stateRoot\state.json 实际写出版本 | 运行时 / launcher-ui |
| `current.json.schemaVersion` | on-disk 写出 | 1 | 安装态程序根\current.json 实际写出版本 | 运行时生成 |

**规则**：升级 `STATE_SCHEMA_NODE_MARKER` 必须同步迁移 `state.json.schemaVersion` 读写；`THEME_SCHEMA_VERSION` 升级必须同步 `theme-schema.test.mjs`。禁止把 `STATE_SCHEMA_NODE_MARKER`（或弃用别名 `STATE_SCHEMA_VERSION`）当作 on-disk 写出版本（见 constants 注释与 ARCHITECTURE）。

---

## PR 模板（建议加入 `.github/pull_request_template.md`）

```markdown
## 改动摘要
<!-- 一句话 -->

## 模块依赖 7 问（§C-1）
- [ ] 1. 改了哪个包？
- [ ] 2. 新增静态 import？
- [ ] 3. core↔runtime 互引？（否）
- [ ] 4. 新增注入旁路？（否）
- [ ] 5. 路径走 resolveStudioPaths / Get-CodexSkin*？
- [ ] 6. 改 active-theme 写入？
- [ ] 7. 改版本源？（否，仅 publish-runtime.ps1 -Version）

## 验收对照（勾选适用项）
- [ ] §C-2 主题 PR（test:themes + list + apply）
- [ ] §C-3 runtime/CSS PR（doctor + apply 手测）
- [ ] §C-4 publish/产品包 PR（-Version + 安装态）
- [ ] §C-5 命名（新增函数 Verb-CodexSkinNoun）
- [ ] §C-6 小步提交（imperative message）
- [ ] §C-8 禁止事项速查表（15 条全否）

## 验证命令
```
node packages/core/cli.mjs doctor
npm test
```

## 关联
- ADR：
- PAIN-POINTS：
- 任务卡 ID：
```

---

## 相关

- 任务卡清单：[`plans/task-cards-2026-07-21.md`](./plans/task-cards-2026-07-21.md)
- 维护 Agent 提示词：[`prompts/agent-maintain-task-cards-zh.md`](./prompts/agent-maintain-task-cards-zh.md)
- 外部扫描提示词：[`prompts/agent-full-project-scan-zh.md`](./prompts/agent-full-project-scan-zh.md)
