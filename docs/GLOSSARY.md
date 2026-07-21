# 术语表（Glossary）

Codex Dream Skin / codex-skin 项目的领域术语。按字母/拼音归类，随讨论增补。

## 产品线

| 术语 | 定义 |
|---|---|
| **DreamSkin** | 原 Windows 皮肤产品（启动器 + watch 守护）。本项目继承其安装态布局 `%LOCALAPPDATA%\Programs\CodexDreamSkin`。 |
| **heige** | 原多主题引擎（theme schema / store / 一次性 CDP 注入）。M1 合并进本仓 `packages/`；其 `--once` 旁路已于 1.3.15 删除。 |
| **upstream / Fei-Away** | GitHub 上游 `Fei-Away/Codex-Dream-Skin`。本仓曾是其 fork，已脱离 fork 网络；`main` 已重构覆盖，零共同历史。 |
| **本仓** | `xvyimu/Codexveil`（原 `Codex-Dream-Skin`）。`origin` remote，`main` 为重构主线。 |

## 运行时 / 注入

| 术语 | 定义 |
|---|---|
| **watch injector** | 常驻进程 `packages/runtime/scripts/injector.mjs --watch`，监听 CDP 目标并持续注入皮肤。唯一注入路径（1.3.15 起）。 |
| **control-plane** | injector 内的 loopback HTTP 面（`control-plane.mjs`），暴露 `/health` `/kick` `/focus` `/open-healthy`；端口写入 `control.port` 与 `state.controlPort`。 |
| **kick** | 通过 control-plane `POST /kick` 让 watch 立刻重新 apply active-theme（~45ms），替代 spawn 独立进程。 |
| **CDP** | Chrome DevTools Protocol。Codex(Electron) 以调试端口（默认 9335）暴露，injector 通过它注入 CSS/JS。 |
| **browserId** | CDP 目标浏览器身份；state.json 记录，用于校验注入对的是当前 Codex。 |
| **active-theme** | `%LOCALAPPDATA%\CodexDreamSkin\active-theme\`，当前皮肤；改文件戳即触发 watch 热更新。 |
| **catalog** | 多主题库 `%LOCALAPPDATA%\CodexDreamSkin\themes\`，供 F6/托盘切换；只嵌缩略图以控 payload。 |
| **payload** | 注入进页面的 JSON（CSS + renderer + catalog）。有 ~4MB 预算（CDP evaluate 上限）。 |
| **paused** | `%LOCALAPPDATA%\CodexDreamSkin\paused` 文件；存在则 watch 跳过注入（暂停皮肤）。 |

## 版本 / 发布

| 术语 | 定义 |
|---|---|
| **SKIN_VERSION** | runtime 报告的皮肤版本；1.3.16 起由单一版本源派生（见 ADR 0003）。 |
| **SKIN_VERSION_TOKEN** | 源文件里的占位符 `"__SKIN_VERSION__"`；publish 时被 `-Version` 替换，未替换则 `SKIN_VERSION="dev"`。 |
| **dreamVersion** | renderer 写在 `<style data-dream-version>` 上的标记；不同则重写 style，用于让 live 会话拾取新 CSS。1.3.16 起引用 SKIN_VERSION。 |
| **runtimeId** | `<version>-<hash>`，如 `1.3.16-6257d5`；`versions/<runtimeId>/` 目录名 + `current.json.runtimeId`。 |
| **current.json** | `programRoot\current.json`，指针：当前 runtimeId + relativeEnginePath（**schemaVersion: 1**）。 |
| **state.json schema** | 安装态运行状态。**现行写出为 schemaVersion 3**（launcher-ui）；读路径接受 1..3。与 `constants.STATE_SCHEMA_NODE_MARKER`（Node 文档标记，非写出版本；旧名 `STATE_SCHEMA_VERSION`）无关。 |
| **kick 降级 `--once`** | 控制面不可达时，同 runtime 的 `injector --once` **单次** apply；非第二守护、非 heige 旁路。 |
| **publish** | `scripts/windows/publish-runtime.ps1 -Version X`：拷 runtime 到 `versions/<id>/`、stamp 版本、翻 current.json、GC 旧版、刷快捷方式。 |
| **promote** | 把 `vendor/dreamskin/assets` 的上游资产择优搬进 `packages/runtime/assets`（人工，见 ADR 0002）。 |
| **package.json version** | npm 元数据，与 runtime 产品线对齐（如 `1.3.25`）；**不是** ADR 0003 stamp 权威。 |

## 上游同步（ADR 0002）

| 术语 | 定义 |
|---|---|
| **vendor 镜像** | `vendor/dreamskin/`，上游只读快照；sync 脚本刷新，作为 promote 的中转层。 |
| **视觉资产线** | 文件级吸收：`upstream/windows/assets` → vendor → promote → runtime。 |
| **PS 修复线** | 只自动**发现**上游 `windows/scripts/**` 的 commit，人工判断+手动移植（结构已分叉，不能盲搬）。 |
| **lastSyncedUpstreamSha** | `docs/upstream-sync.json` 里的基线；`git log <sha>..upstream/main` 的下界。初始 `fd6a118`。 |

## 校验 / 工具

| 术语 | 定义 |
|---|---|
| **verify** | `injector.mjs --verify`：检查页面注入是否成功，含 `version === expectedVersion`、stylePresent、chromePresent 等。 |
| **smoke** | `smoke-dream-skin.ps1`：产品线冒烟（runtime/active-theme/CDP/verify/payload/probe）；输出 SMOKE_PASS/FAIL。 |
| **check-and-fix** | `check-and-fix.ps1`：健康检查 + 必要时 reattach/normalize state，快路径下 ~3-5s。 |
| **post-update** | `post-update-regression.ps1`：Codex Store 更新后回归；publish 尾部自动跑刷新报告。 |
| **session-dom probe** | `probe-session-dom.mjs`：在首页/会话页探针 DOM 标记，验证皮肤实锤到位。 |
| **install-ux-shortcuts** | 用户可见快捷方式唯一源：日常 Codex/ChatGPT/换肤 + 开始菜单「Codex 工具」。 |
| **CodexFastLaunch** | 原生 winexe 任务栏入口；AUMID=`CodexDreamSkin.FastLaunch`，避免归组回商店包。见 `apps/native/CodexFastLaunch`。 |
| **商店磁贴裸启** | 用户点微软商店 Codex 磁贴时无 CDP → 无皮肤；OS 硬限，见 PAIN #21。 |
| **soft reattach** | 杀旧 watch injector → 用 current `versions/<id>` 启新 `--watch`（带 `--theme-dir` + `--state-root`）→ 补 state。共享实现：`scripts/windows/soft-reattach.ps1`；publish / Install 调用。 |
| **control.token** | stateRoot 下 32 hex 文件；control-plane 启动时 `ensureToken` 生成/复用。见 `packages/runtime/scripts/control-plane.mjs`。 |
| **x-codex-skin-token** | 控制面 mutating POST 鉴权头（仅 header；query 不放行）；`CONTROL_TOKEN_HEADER`。GET `/health` 免 token。见 SEC-01 / dual-open-policy。 |
| **resolveStudioPaths** | `packages/core/constants.mjs` 统一解析 installRoot / dreamStateRoot / 主题路径；业务代码禁止散落硬编码 `%LOCALAPPDATA%`。 |
| **Get-CodexSkin\*** | core-win 路径/控制面函数族前缀（新 API）；如 `Get-CodexSkinControlToken`、`Invoke-CodexSkinControl`。见 `packages/core-win/launcher-ui.ps1`。 |
| **Verb-DreamSkinNoun** | 历史 PS 函数前缀（`common-windows.ps1` 30+ 个）；**冻结不可批量改名**（WIN-02）。 |
| **Verb-CodexSkinNoun** | 新增 PS 函数命名格式；见 `docs/CONTRIBUTING.md` §C-5。 |
| **schema 三件套** | `STATE_SCHEMA_NODE_MARKER=1`（Node 契约，非写出；旧名 `STATE_SCHEMA_VERSION`）· `THEME_SCHEMA_VERSION=1` · on-disk `state.json.schemaVersion=3` / `current.json.schemaVersion=1`。见 CONTRIBUTING §C-9。 |
| **dual-open-policy** | 入口纪律：任务栏 Codex vs 商店磁贴；kick 主路径 + `--once` 单次降级。见 `docs/dual-open-policy.md`。 |
| **dreamskin-guard** | `packages/core/state/dreamskin-guard.mjs`：诊断 injectorAlive / controlPort / controlTokenPresent 等（非第二守护）。 |
| **test:deps** | `scripts/check-package-deps.mjs` + `npm run test:deps`：禁止 core↔runtime 静态互引；CI themes-gate 第二步。 |
| **stateRoot** | `%LOCALAPPDATA%\CodexDreamSkin`：state.json · active-theme · control.port · control.token · themes catalog。 |
| **托盘 / F6** | 系统托盘换肤与窗口内 F6 循环；catalog 缩略图注入。见 launcher-ui / renderer-inject。 |
