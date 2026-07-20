# 术语表（Glossary）

Codex Dream Skin / codex-skin 项目的领域术语。按字母/拼音归类，随讨论增补。

## 产品线

| 术语 | 定义 |
|---|---|
| **DreamSkin** | 原 Windows 皮肤产品（启动器 + watch 守护）。本项目继承其安装态布局 `%LOCALAPPDATA%\Programs\CodexDreamSkin`。 |
| **heige** | 原多主题引擎（theme schema / store / 一次性 CDP 注入）。M1 合并进本仓 `packages/`；其 `--once` 旁路已于 1.3.15 删除。 |
| **upstream / Fei-Away** | GitHub 上游 `Fei-Away/Codex-Dream-Skin`。本仓是其 fork，但 `main` 已重构覆盖，零共同历史。 |
| **fork（本仓）** | `xvyimu/Codex-Dream-Skin`。`origin` remote，`main` 为重构主线。 |

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
| **state.json schema** | 安装态运行状态。**现行写出为 schemaVersion 3**（launcher-ui）；读路径接受 1..3。与 `constants.STATE_SCHEMA_VERSION`（Node 文档标记，非写出版本）无关。 |
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
| **CodexFastLaunch** | 原生 winexe 任务栏入口；AUMID=`CodexDreamSkin.FastLaunch`，避免归组回商店包。 |
| **商店磁贴裸启** | 用户点微软商店 Codex 磁贴时无 CDP → 无皮肤；OS 硬限，见 PAIN #21。 |
