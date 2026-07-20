# codex-skin 全面扫描与优化建议报告

> **日期**：2026-07-20  
> **HEAD**：`ea229b7`（`main` · 与 `origin/main` 同步）  
> **运行时**：`1.3.25-d14cf4` · `installedFrom: product-package`  
> **doctor 摘要**：`ok` · `injectorAlive` pid 38880 · `fresh=true` · CDP 9335 · control 9336 · 11 themes · active 用户 catalog 齐全  
> **审查人角色**：外部审查与优化顾问 Agent（只读；不改业务代码）  
> **对照基线**：[`AUDIT-2026-07-20.md`](./AUDIT-2026-07-20.md) @ `f373fcb` · residual [`G1-B/G3-A/G4-A/G5-C`](./plans/residual-g1-g3-g4-g5-2026-07-20.md) **已完成**  
> **落地状态（同日后续）**：**SEC-01 · TEST-02 · ARCH-01/03 soft-reattach · SCR-01 · CODE-02 · doctor 字段 · injector `--state-root` · `test:deps` CI** 已实现（见仓库 diff / AUDIT §16）。下列 §0「最严重问题」保留为扫描当时证据；实现以代码为准。

---

## 0. 执行摘要

**总体健康评级：A−（Windows 主路径生产可用）** — 与 AUDIT 综合结论一致；本轮未发现 P0，ADR 0001/0002/0003 均被代码遵守。

**最严重 3 个问题**

1. **SEC-01 / CODE-01（P1）**：`control-plane.mjs` 生成并持久化 `control.token`，但校验块为空——任意本机进程可 POST `/kick` `/focus` `/open-healthy`（仅靠 loopback 边界）。
2. **TEST-01（P1）**：`themes-gate.yml` 只跑 5 组逻辑 / 13 断言；缺 state-freshness、token 语义、theme-store、`writeActiveThemeFromHeige`、依赖边界扫描——G1-B 已完成但其覆盖面仍窄。
3. **ARCH-03 / CODE-02（P2）**：`Install-Product.ps1` 与 `publish-runtime.ps1` 各自内联 soft reattach；行为会漂移，且 soft reattach 启动 watch 时**未**传 `--theme-dir`（见 ARCH-01）。

**最值得做的 3 件事**

1. 收紧或**正式声明** control-plane token 策略（强制 401 **或**删空块 + PROJECT 写明「loopback 即信任边界」）。
2. 扩展 `test:themes` / CI：11 套 `loadTheme` + freshness 纯函数 + 依赖边界 grep 脚本。
3. 抽取 `scripts/windows/soft-reattach.ps1`，统一 Install/publish，并在 reattach 时显式传 `--theme-dir` / 未来的 `--state-root`。

**明确不建议做的 3 件事**

1. 推倒重来 / monorepo 大迁 / 恢复双 injector / heige 第二产品线。  
2. macOS 一等公民 · 劫持 Store AUMID · 改 Codex asar。  
3. 云端全量 doctor/smoke（G1-D 已否决）；批量 `DreamSkin-*` → `CodexSkin-*` 改名。

---

## 1. 审查方法与范围

### 1.1 读过的文档

| 优先级 | 文档 | 用途 |
|--------|------|------|
| 1 | `docs/PROJECT.md` | 边界 · 分层 · 依赖 · 验收 |
| 2 | `docs/ARCHITECTURE.md` | 目录 · 调用链 · state schema |
| 3 | `docs/AUDIT-2026-07-20.md` | 前次全面检查与 hygiene 收口 |
| 4 | `docs/plans/residual-g1-g3-g4-g5-2026-07-20.md` | 残差组合 **Implemented** |
| 5–7 | `docs/adr/0001` · `0002` · `0003` | 合并 · 上游 · 版本源 |
| 8–10 | `PAIN-POINTS.md` · `dual-open-policy.md` · `usage.md` | 痛点与入口纪律 |
| 11–12 | 包 README / `CLAUDE.md` / `README.md` | 入口与命名规约 |

### 1.2 跑过的命令与关键输出

| 命令 | 结果摘要 |
|------|----------|
| `git status -sb` / `rev-parse` / `log -8` | clean vs origin；仅 `?? docs/prompts/`；HEAD `ea229b7` |
| `node packages/core/cli.mjs doctor` | `diagnosis=ok` · fresh · pid 38880 · 11 themes · CDP 9335 |
| `list` | 11 套 · schemaVersion=1 · palette/art 齐全 · source=user |
| `status` | active-injector · browserId 在 |
| `npm run test:themes` | **all passed**（13 ok 行） |
| 依赖扫描 | `packages/core` 无 → runtime 静态 import；`runtime` 无 → core；`themes` 仅动态 `thumb.mjs` |
| 安装态 | `current.json` → `1.3.25-d14cf4`；`control.port=9336`；`control.token` 长度 32 |

### 1.3 未覆盖的范围

- 未重跑 kick 计时 / smoke / publish / Install  
- 未通读 `launcher-ui.ps1` 1059 行全文、`dream-skin.css` 全文件  
- 未读 `apps/native/CodexFastLaunch.cs` 源、`Build/Uninstall` 全文  
- 未做 computer-use 像素走查、渗透级安全审计  
- 未验证 GitHub Actions 云端实际跑通（workflow 文件存在）

---

## 2. 现状健康画像

| 项 | 现值 | 备注 |
|----|------|------|
| 产品线版本 | `1.3.25` | `package.json` 元数据；stamp 权威仍是 publish |
| git | `ea229b7` on `main` | AUDIT 基线 `f373fcb` 之后已落地 residual + Release 链接 |
| 安装 runtimeId | `1.3.25-d14cf4` | product-package |
| SKIN_VERSION_TOKEN（仓内） | `"1.3.25"` | 已 stamp（非 `__SKIN_VERSION__`） |
| 主题 | 11 | 与 PROJECT 附录 B 一致 |
| CDP / CP | 9335 / 9336 | portOpen · control.port 在 |
| fresh | true | expected/actual injector 路径一致 |
| residual | G1-B G3-A G4-A G5-C | **已完成** · 勿当新债 |
| 未提交 | `docs/prompts/` | 扫描提示词模板（本会话产物） |

**与 AUDIT 的差异**

| 点 | AUDIT (`f373fcb`) | 本轮 (`ea229b7`) |
|----|-------------------|------------------|
| residual G1/G3–G5 | 规划中 / 有意保留叙述混杂 | **已实现**；AUDIT §9.3 已改「已做」 |
| CI 评级 B−「仍无 PR CI」 | 过时句 | 现有 `themes-gate.yml`；评级应升为 **B / B+**（仍无 doctor CI） |
| Codex 包 | `26.715.4045.0` | doctor 主路径 `26.715.7063.0`（多候选并存） |
| launcher-ui LOC | ~850（G6） | **实测 1059**；README 仍写 850 |
| 本轮新增关注 | — | token 空校验 · soft reattach 缺 theme-dir · seed art 硬编码 1.2.1 |

---

## 3. 架构评估

### 3.1 符合 ADR 的部分

| ADR | 证据 |
|-----|------|
| **0001** 单产品线 | 单 watch injector；无 legacy-inject；heige 经 `dream-adapter` 归一；`dual-open-policy` 钉死入口 |
| **0002** 上游 | `vendor/dreamskin` 只读；生产路径无 import vendor |
| **0003** 版本源 | 仅 `publish-runtime.ps1 -Version` 写 git token；Build/Install 只 stamp 包/安装树 |

**四层边界**：L1 launcher → L2 cli/control-plane → L3 state+themes → L4 runtime 主路径清晰；CLI apply 不直连 CDP evaluate。

**payload 预算**（`injector.mjs:17-23`）：4MB evaluate · catalog ≤8 · 总 ≤1.6MB · 单条 ≤96KB — 清晰可测。

### 3.2 风险与演进建议（ARCH-*）

#### ARCH-01 — soft reattach / 默认 themeDir 导致 stateRoot 猜测脆弱

| 字段 | 内容 |
|------|------|
| 严重度 | **P2** |
| 维度 | A · C · F |
| 现状证据 | `injector.mjs:39` 默认 `themeDir=path.join(root,"assets")`；`injector.mjs:1128-1130` `stateRootGuess = path.dirname(resolve(themeDir))` 传入 control-plane。日常 open 传 `%LOCALAPPDATA%\CodexDreamSkin\active-theme` 时 dirname=stateRoot **正确**。但 `publish-runtime.ps1:311-314` soft reattach 仅 `--watch --port 9335 [--browser-id]`，**无** `--theme-dir` → themeDir 落在 `versions/<id>/assets` → stateRootGuess=`versions/<id>` |
| 问题 | control.token / control.port / state.controlPort 可能写到 versions 树；kick 靠端口扫描仍可能工作，但 doctor/文件面不一致、多 runtime 残留 token |
| 建议方案 | ① soft reattach 增加 `--theme-dir (Join-Path $StateRoot 'active-theme')`；② 中期给 injector 增加显式 `--state-root`（优先于 guess） |
| 模块 | runtime · scripts/windows |
| 是否违反 ADR | 否 |
| 工作量 | **S** |
| 风险 | 低；改 PS 参数列表 + 可选 parseArgs |
| 验收 | soft reattach 后 `control.port` 仍在 stateRoot；`doctor` fresh；kick 200 |
| 不做的事 | 不在 runtime 静态依赖 core 的 `resolveStudioPaths` |

**简表**：收益=安装/发版一致性 | 成本=S | 可逆=高 | ADR=无冲突  

#### ARCH-02 — control-plane 内直读 `LOCALAPPDATA`

| 字段 | 内容 |
|------|------|
| 严重度 | **P2** |
| 维度 | A · B |
| 现状证据 | `control-plane.mjs:26-28` `stateRootDefault()`；`:72-75` focus 脚本路径硬拼 `Programs\CodexDreamSkin` |
| 问题 | 与「业务代码走统一路径解析」纪律冲突；runtime 自包含下不能 import core，但应**由 injector 注入 stateRoot/focusScriptPath**（接口已支持 `opts.stateRoot` / `focusScriptPath`） |
| 建议方案 | 启动时强制传入 stateRoot；`stateRootDefault` 仅 fallback + 注释「dev only」；focus 路径由 launcher 侧或 state 提供 |
| 模块 | runtime |
| 是否违反 ADR | 否（强化 self-contained 注入） |
| 工作量 | **S** |
| 风险 | 低 |
| 验收 | 单测/手工：自定义 stateRoot 时 token/port 落点正确 |
| 不做的事 | 不让 runtime import `packages/core` |

**简表**：收益=路径纪律 | 成本=S | 可逆=高 | ADR=强化 0001 自包含  

#### ARCH-03 — Install vs publish soft reattach 重复

| 字段 | 内容 |
|------|------|
| 严重度 | **P2** |
| 维度 | A · D · F |
| 现状证据 | `publish-runtime.ps1:275-332` `Invoke-CodexSkinSoftReattach`；Install-Product 内联同类逻辑（停旧 node injector → 起 watch → patch state） |
| 问题 | 双份实现；ARCH-01 的 theme-dir 漏洞会只修一边 |
| 建议方案 | 抽 `scripts/windows/soft-reattach.ps1`，两处 dot-source；一并修 theme-dir / 可选 state-root |
| 模块 | scripts/windows |
| 是否违反 ADR | 否 |
| 工作量 | **M** |
| 风险 | 中（PS 路径与杀进程面） |
| 验收 | publish 超时路径 + Install 路径均 doctor fresh |
| 不做的事 | 不改成第二 node 守护服务 |

**简表**：收益=单一真相 | 成本=M | 可逆=中 | ADR=无冲突  

#### ARCH-04 — GC 策略 Install vs publish 细微差

| 字段 | 内容 |
|------|------|
| 严重度 | **P3** |
| 维度 | A · F |
| 现状证据 | publish GC：current + bak 指向 + 兜底；Install 更简（current + 最新非当前） |
| 问题 | 极端目录布局下保留集不一致 |
| 建议方案 | 与 ARCH-03 同文件抽 `Invoke-CodexSkinVersionsGc` |
| 模块 | scripts/windows |
| 工作量 | **S** |
| 验收 | 3+ versions 夹具下两边保留集相同 |
| 不做的事 | 不把 GC 放进 injector |

#### ARCH-05 — themes → runtime `thumb.mjs` 动态依赖

| 字段 | 内容 |
|------|------|
| 严重度 | **P3 信息** |
| 维度 | A · C |
| 现状证据 | `dream-adapter.mjs:196` 动态 import；Install 需 copy thumb 到 cli 树 |
| 问题 | 隐性契约；改 thumb 接口 themes 无编译期保护 |
| 建议方案 | themes README + CI 探测 `import('../runtime/scripts/thumb.mjs')` 可解析 |
| 模块 | themes · docs · CI |
| 工作量 | **S** |
| 是否违反 ADR | 否（动态已允许） |

---

## 4. 框架与规范建议

### 4.1 模块依赖检查清单（PR 必答 7 问）

**规则**：改 `packages/{core,runtime,themes}` 的 PR 描述必须回答：

1. core 是否新增对 runtime 的静态 import？  
2. runtime 是否新增对 core/themes 的静态 import？  
3. themes 是否新增**静态**对 runtime 的 import？（动态仅 thumb 例外）  
4. 是否硬编码 `%LOCALAPPDATA%` 而非 `resolveStudioPaths` / `Get-CodexSkin*`？（scripts 解析层除外）  
5. 是否新增常驻守护 / 第二 injector？  
6. 是否绕过 active-theme 直接 CDP 注入主题？  
7. 是否改动版本 stamp 权威（非 publish `-Version`）？

**正例**：themes 只改 schema + `npm run test:themes`。  
**反例**：core 里 `import '../runtime/scripts/injector.mjs'` 并 evaluate。  
**验收**：CI 或 pre-push 脚本 `node scripts/check-deps.mjs`（可后续加）exit 0。

### 4.2 主题 PR 验收清单

- [ ] `themes/<id>/theme.json` schemaVersion=1 · id kebab  
- [ ] hero/image 相对路径 · 无 `..` · png/jpg/webp  
- [ ] `npm run test:themes`  
- [ ] `cli list` 可见（import 后）  
- [ ] （可选）`apply --theme <id>` + doctor  

### 4.3 runtime / CSS PR 验收清单

- [ ] `injector.mjs --self-test`（若有）或本地 verify  
- [ ] payload 预算注释未破（catalog 仍缩略图）  
- [ ] 不 import core  
- [ ] 会话敏感选择器改动需说明是否触及 backdrop-filter / mutation 历史修复  

### 4.4 publish / 产品包 PR 验收清单

- [ ] 不引入硬编码默认版本 return  
- [ ] soft reattach 走共享函数  
- [ ] seed art 不依赖已 GC 的 runtimeId  
- [ ] Build 不写 git tree；publish 才 stamp 源  

### 4.5 命名与 PS 编码规范

**规则陈述**：新函数 `CodexSkin-*`；`DreamSkin-*` 冻结不扩；PS 入口 UTF-8 BOM；JSON 无 BOM。  
**正例**：`Get-CodexSkinControlPort`。  
**反例**：新加 `Get-DreamSkinFoo`。  
**验收**：core-win README 附录冻结表（见 WIN-02）。

### 4.6 提交信息与小步提交

**规则**：一个维度一个 commit；首行 ≤72；body 写「为什么」。  
**正例**：`fix(control-plane): enforce or document token gate`。  
**反例**：`update everything`。

### 4.7 何时允许 `--once` 降级

**规则**（与 `dual-open-policy.md` 对齐）：仅 control-plane 不可达时，spawn **同 current runtime** 的 `--once` 单次 apply；CLI 不暴露开关；禁止 cron/`--watch` 第二守护。  
**验收**：`grep -rn "injector.mjs.*--once" apps scripts packages` 仅 kick 路径。

### 4.8 禁止事项速查表（可贴 CLAUDE.md）

| 禁止 | 检查 |
|------|------|
| core↔runtime 静态互引 | grep import |
| 第二守护 | 进程列表 / 文档 |
| 改 asar / AUMID 劫持 | review |
| macOS 一等公民 | review |
| 业务散落绝对路径 | grep LOCALAPPDATA in packages（允许 constants 解析层） |
| publish 外写版本权威 | review |
| 批量 DreamSkin 改名 | review |

---

## 5. 代码优化建议（按模块）

### 5.1 core

#### CORE-01 — `STATE_SCHEMA_VERSION=1` 与磁盘 write=3

| 字段 | 内容 |
|------|------|
| 严重度 | **P3**（A8 已注释，仍易误导） |
| 维度 | B · C · I |
| 证据 | `constants.mjs:15-21`；ARCHITECTURE 写 launcher-ui schemaVersion=3 |
| 问题 | 新人把常量当写出版本 |
| 建议 | doctor 输出 `stateSchema: { accept:[1,3], write:3 }`；常量改名或 JSDoc 再加「not on-disk write」徽章 |
| 模块 | core · docs |
| 工作量 | **S** |
| 验收 | doctor JSON 含字段 |
| 不做 | 强行把常量改为 3 并拒读旧文件 |

### 5.2 themes

#### THEME-01 — 源图 8MB vs injector art 16MB

| 字段 | 内容 |
|------|------|
| 严重度 | **P3 信息** |
| 维度 | C · D |
| 证据 | `theme-store.mjs:7` 8MB；`injector.mjs:17` 16MB |
| 问题 | 上限语义不同（导入 UX vs art 硬顶）易误解 |
| 建议 | 两边交叉注释；保持 8MB 导入限制（CDP 超时） |
| 工作量 | **S** |

#### THEME-02 — `listThemes` source 用路径正则

| 字段 | 内容 |
|------|------|
| 严重度 | **P3** |
| 维度 | B · D |
| 证据 | theme-store 以 `CodexDreamSkin.../themes` 判 user |
| 建议 | caller 传 `source: 'user'|'bundled'`，正则仅 fallback |
| 工作量 | **S** |

#### THEME-03 — 测试只 load 1 个 bundled 主题

| 字段 | 内容 |
|------|------|
| 严重度 | **P2** |
| 维度 | G |
| 证据 | `theme-schema.test.mjs` 仅 `genshin-night` + temp dream |
| 建议 | 循环 `themes/*` 全部 `loadTheme`（G1-C 轻量升级） |
| 工作量 | **S** |
| 验收 | `npm run test:themes` 覆盖 11 套 |

### 5.3 runtime

#### CODE-01 / SEC-01 — token 校验空块

| 字段 | 内容 |
|------|------|
| 严重度 | **P1** |
| 维度 | D · H |
| 证据 | `control-plane.mjs:162-165` 空 if；token 文件存在（本机 32 hex） |
| 问题 | 安全错觉；本机任意进程可 kick/focus |
| 建议 | **推荐 A**：不匹配则 401；kick-inject 读 `control.token` 带 `x-codex-skin-token`；token 缺失时兼容旧行为并 log。**备选 B**：删除空块 + PROJECT 明确 loopback 信任模型 |
| 模块 | runtime · core/kick-inject · docs |
| 工作量 | **S–M** |
| 风险 | 中（漏带 token 会破热切换） |
| 验收 | 无 token → 401；有 token → 200；apply 仍 ok |
| 不做 | mTLS / 非 loopback 暴露 |

#### CODE-02 — `writeControlPort` 非原子写 state.json

| 字段 | 内容 |
|------|------|
| 严重度 | **P2** |
| 维度 | C · F |
| 证据 | `control-plane.mjs:53-60` 直接 `writeFile` |
| 建议 | tmp + rename（对齐 dream-adapter atomicWriteJson） |
| 工作量 | **S** |
| 验收 | 写入中 kill 后文件仍合法 JSON |

#### CODE-03 — injector 单文件 1402 LOC

| 字段 | 内容 |
|------|------|
| 严重度 | **P3** |
| 维度 | D |
| 建议 | 延后：抽 `cdp-session.mjs` / `theme-loader.mjs`；更新 publish copy 列表 |
| 结论 | **延后大改**（见 §10.3） |

### 5.4 core-win

#### WIN-01 — README LOC 漂移（850→1059，644→658）

| 严重度 | **P3** · 维度 I · 工作量 **S** |
| 建议 | 更新 README；G6「保持不切」结论可保留，但阈值说明改为 1059 |

#### WIN-02 — DreamSkin/CodexSkin 混用

| 严重度 | **P3 信息** · 已文档化可接受 |
| 建议 | README 冻结老名清单；新 API 只用 CodexSkin |

### 5.5 scripts/windows

#### SCR-01 — seed art fallback 钉死 `1.2.1-c1ad5a79ddf5`

| 字段 | 内容 |
|------|------|
| 严重度 | **P2** |
| 维度 | B · F |
| 证据 | `publish-runtime.ps1:54` |
| 问题 | GC 后 fallback 失效 → 首启 theme store 可能失败 |
| 建议 | 扫 `versions/*/assets/dream-reference.jpg` 最新；或保证 repo `packages/runtime/assets` 始终有种子图（优先） |
| 工作量 | **S** |
| 验收 | 无 1.2.1 目录时 publish 仍有 seed |

#### SCR-02 — CodexFastLaunch.exe 未签名

| 严重度 | **P2** · 维度 H · UX |
| 建议 | 文档化 SmartScreen 预期（C）或后续签名（A/B）；**不**改 asar |
| 工作量 | S（文档）/ M+（签名） |

### 5.6 apps/launcher

#### APP-01 — 入口体量

| 文件 | LOC | 评价 |
|------|----:|------|
| open-codex-dream-skin.ps1 | 378 | 可接受编排厚度 |
| switch-theme-ui.ps1 | 438 | UI 脚本，非「算法进 launcher」违规 |
| start-dream-skin.ps1 | 275 | 偏历史入口，保持 |
| post-update-regression.ps1 | 271 | 工具层 OK |
| check-and-fix.ps1 | 249 | OK |
| 其余 | ≤110 | 薄 |

**结论**：**保持**；业务仍应沉在 core-win / themes，不在此堆 schema。

---

## 6. 测试与 CI 建议

### 6.1 当前覆盖

| 项 | 状态 |
|----|------|
| `theme-schema.test.mjs` | 双格式 validate · path escape · 1 bundled load · 1 dream temp |
| `themes-gate.yml` | ubuntu · Node 20 · **仅** `npm run test:themes`（**G1-B 已完成**） |
| doctor/smoke/verify | **本机 only**（有意） |

### 6.2 建议新增用例

| ID | 输入 | 期望 | CI? |
|----|------|------|-----|
| TEST-02 | 全部 `themes/*` loadTheme | 11 ok | 是 |
| TEST-03 | freshness：runtimeId 不一致 | fresh=false | 是 |
| TEST-04 | 模拟 core 文件含 `from '../runtime'` | check-deps fail | 是 |
| TEST-05 | token 强制模式：无 header POST /kick | 401 | 是（mock server） |
| TEST-06 | writeActiveThemeFromHeige 后 art 清理 | 旧 art 不残留 | 本机/临时可是 |
| TEST-07 | listThemes dedupe | user 覆盖 bundled | 是 |
| TEST-08 | publish seed 无 1.2.1 | 仍有 dream-reference | 本机 |

### 6.3 原则

保持 G1-B 精神：**云端零 Codex/CDP**；扩的是纯 Node 断言，不是 windows-latest doctor。

---

## 7. 可靠性 / 性能 / UX / 安全

### 7.1 可靠性

| ID | 级 | 说明 |
|----|:--:|------|
| RELI-01 | — | **已完成 G5-C**：`WaitForExit(60s)` + soft reattach |
| RELI-02 | — | 端口扫描 9336–9346 / kick 多端口 fallback 健康 |
| RELI-03 | P2 | doctor 未暴露 `controlToken` / `controlPortFile` 路径（配合 ARCH-01 排障） |
| RELI-04 | P2 | soft reattach 未带 theme-dir（ARCH-01） |
| RELI-05 | — | BrowserIdentityAnchor 身份漂移退出 — 保持 |

### 7.2 性能

| ID | 级 | 说明 |
|----|:--:|------|
| PERF-01 | — | kick 主路径 HTTP 进程内 apply — 设计正确 |
| PERF-02 | — | `/open-healthy` 异步 focus — 保持 |
| PERF-03 | 信息 | CSS `color-mix` / 历史 backdrop 禁用点 — 回归风险低但改 CSS 需小心 |
| PERF-04 | — | catalog 预算 — 保持 |

### 7.3 UX

| ID | 级 | 说明 |
|----|:--:|------|
| UX-01 | — | **G4-A 已完成**：#21 文档化，不劫持 |
| UX-02 | — | #18 快捷方式分层 — 已落地 |
| UX-03 | 信息 | FastLaunch 未签名可能 SmartScreen（SCR-02） |
| UX-04 | — | 用户错误映射 / 气泡节流 — 保持 |

### 7.4 安全

| ID | 级 | 说明 |
|----|:--:|------|
| SEC-01 | **P1** | token 未强制（CODE-01） |
| SEC-02 | — | CDP URL loopback 校验严格 — 保持 |
| SEC-03 | — | theme path `..` 拒绝 + realpath — 测试覆盖 |
| SEC-04 | P2 | 未签名 native exe |
| SEC-05 | P3 | `/health` 回传 themeDir 全路径 — 可降敏 |
| SEC-06 | — | node Authenticode OpenJS 校验（common-windows）— 优秀 |
| SEC-07 | — | tray 拒绝 `-Command` 注入 — 保持 |
| SEC-08 | — | CP bind 127.0.0.1 only — 保持 |

---

## 8. 文档债务

| ID | 位置 | 问题 | 修复 |
|----|------|------|------|
| DOCS-01 | AUDIT 头 HEAD `f373fcb` | 与 `ea229b7` 漂移 | 文末「后续修订」表 |
| DOCS-02 | AUDIT §0 CI 评级 B− | 「仍无 PR CI」过时 | 改为 B/B+ 并注 G1-B |
| DOCS-03 | core-win README LOC | 850/644 过时 | 1059/658 |
| DOCS-04 | PROJECT §13 体量 | injector ~1450 · launcher-ui ~850 | 对齐实测 |
| DOCS-05 | PROJECT / dual-open | token 策略未写死 | 随 SEC-01 落地 |
| DOCS-06 | `docs/prompts/` | 未入库 | 可选 commit 提示词模板 |
| DOCS-07 | AUDIT 安装 Codex 包号 | 4045 vs 现 7063 | 快照注明「以 doctor 为准」 |

---

## 9. 优先级路线图

### P0
（无）

### P1（建议本周）

| ID | 目标 | 模块 | 验收 | 依赖 |
|----|------|------|------|------|
| SEC-01 | token 强制 **或** 正式声明占位 | runtime · kick-inject · docs | 401 或 PROJECT 段落 | 无 |
| TEST-02/04 | 11 主题 loadTheme + deps grep | themes · CI | CI 绿 | 无 |

### P2（30 天）

| ID | 目标 | 模块 | 验收 | 依赖 |
|----|------|------|------|------|
| ARCH-01+03 | soft-reattach 共享 + theme-dir | scripts | publish/Install doctor fresh | 无 |
| CODE-02 | 原子写 state controlPort | runtime | 中断不损坏 | 无 |
| SCR-01 | seed art 动态/仓内保证 | scripts | 无 1.2.1 也可 | 无 |
| RELI-03 | doctor token/port 字段 | core | doctor JSON | ARCH-01 |
| ARCH-02 | CP 少用 LOCALAPPDATA | runtime | 注入 stateRoot | ARCH-01 |
| FRAME | §4 清单写入 PROJECT 附录 | docs | 文档存在 | 无 |
| SCR-02 | SmartScreen 预期文档 | docs | PAIN 一条 | 无 |

### P3（60–90 天）

| ID | 目标 |
|----|------|
| CODE-03 | injector 按边界切分 |
| WIN-01/02 | README LOC + 冻结表 |
| ARCH-04/05 | GC 统一 · thumb 契约文档 |
| THEME-01/02 · CORE-01 · DOCS-* | 注释与债务 |
| APP 保持 | 不主动拆 launcher |

### 永不做

见 §0 与 ADR / residual 否决：双 injector · heige 旁路 · asar/AUMID · mac 一等 · 云 doctor · 批量改名 · monorepo 重写。

---

## 10. 附录

### 10.1 命令输出摘录

```text
HEAD ea229b7 · main...origin/main · ?? docs/prompts/
doctor: ok · fresh · pid 38880 · runtime 1.3.25-d14cf4 · themes 11 · cdp 9335
test:themes: all passed (13 ok lines)
control.port: 9336 · control.token: present (32 hex)
core→runtime static imports: none
runtime→core static imports: none
themes→runtime: dynamic thumb.mjs only
```

### 10.2 文件热点 LOC

| 文件 | LOC |
|------|----:|
| packages/runtime/scripts/injector.mjs | 1402 |
| packages/core-win/launcher-ui.ps1 | 1059 |
| packages/core-win/common-windows.ps1 | 658 |
| packages/runtime/assets/dream-skin.css | 630 |
| packages/runtime/assets/renderer-inject.js | 479 |
| scripts/windows/Install-Product.ps1 | 445 |
| scripts/windows/publish-runtime.ps1 | 368 |
| packages/core/state/kick-inject.mjs | 276 |
| packages/core/cli.mjs | 267 |
| packages/runtime/scripts/control-plane.mjs | 257 |
| packages/themes/dream-adapter.mjs | 225 |
| packages/themes/theme-schema.mjs | 219 |

### 10.3 热点文件结论（保持 / 小改 / 延后大改）

| 文件 | 结论 |
|------|------|
| injector.mjs | **延后大改**（先修 stateRoot/theme-dir 调用方） |
| dream-skin.css | **保持** |
| renderer-inject.js | **小改**可选（analyzeArt 可测性） |
| launcher-ui.ps1 | **延后大改**（先更 README） |
| common-windows.ps1 | **保持** |
| cli.mjs | **保持** |
| kick-inject.mjs | **小改**（随 token 带 header） |
| dream-adapter / theme-schema | **保持** + 测试扩展 |
| publish-runtime.ps1 | **小改**（seed · 抽 reattach） |
| Install-Product.ps1 | **小改**（共用 reattach） |
| apps/launcher/* | **保持** |

### 10.4 术语对齐 GLOSSARY

active-theme · runtimeId · SKIN_VERSION_TOKEN · kick · soft reattach · catalog · identityAnchor — 与 ARCHITECTURE/PROJECT 一致；**token 语义**待 SEC-01 写入。

### 10.5 建议 vs 已否决

| 建议 | 否决替代 | 原因 |
|------|----------|------|
| 强制/声明 token | 上 mTLS | 过重 |
| 扩 themes CI | 云 doctor | G1-D 不可行 |
| 抽 soft-reattach.ps1 | 常驻服务 | ADR 0001 |
| 切 injector | Nest/微服务 | §5 禁止 |
| 文档 #21 | AUMID 劫持 | OS 硬限 |
| CodexSkin 新 API | 批量改名 | 安装态稳定 |

### 10.6 已完成残差（勿重复当债）

| ID | 状态 |
|----|------|
| G1-B themes-gate.yml | **已完成**（本报告仅建议**扩展**用例） |
| G3-A Windows-only | **已完成** |
| G4-A #21 文档 | **已完成** |
| G5-C 60s + soft reattach | **已完成**（本报告修 **theme-dir 缺口**） |
| AUDIT §12 hygiene A1–A8 | **已完成** |

---

## 结尾：建议维护 Agent 下一步（5 行）

1. **先做 SEC-01**：二选一落地 token（强制 + kick 带 header，或删空块 + PROJECT 信任模型），避免安全错觉。  
2. **并行 TEST-02**：`themes/*` 全量 `loadTheme` 进 `test:themes`（&lt;2h，CI 立刻增值）。  
3. **再做 ARCH-03+01**：共享 soft-reattach 并传 `--theme-dir`，堵住 publish 超时 fallback 的 state 落点问题。  
4. **SCR-01** 去掉 `1.2.1-…` 硬编码 fallback。  
5. **不要**开 injector 大拆或 mac/AUMID/云 doctor；文档 HEAD 漂移可随上述 PR 顺手改。

---

*本报告只读扫描交付；未修改业务注入路径。提示词模板见 `docs/prompts/agent-full-project-scan-zh.md`（若未提交则为本地 untracked）。*
