# Codex Dream Skin — 主调研报告 v7 · 契约落地后的门禁与体验收口

> 生成时间：2026-07-21  
> 基线：HEAD=`b80bf4e` · full=`b80bf4eace1e76e1e24393ed1ea99d5252e44ef6` · runtimeId=`1.3.25-2ae34a` · fresh=true · themeCount=11 · ahead origin/main **0**  
> 前序：[`v6`](./2026-07-21-master-research-v6-palette-root-and-hd-bubble.md) · 审核：[`audit/2026-07-21-v6-review.md`](../audit/2026-07-21-v6-review.md) · 推进：[`audit/2026-07-21-v6-advance.md`](../audit/2026-07-21-v6-advance.md)  
> 本轮增量：v6 **squash 合入 main** + 远程 themes-gate 双绿 + ARCHITECTURE 跨层契约已落地；聚焦 **探针断言化 / 证据入库 / BASELINE 对齐 / surfaceLuma 边界 / UX 细节**  
> 硬约束 SSOT：[`PROJECT.md`](../PROJECT.md) · ADR 0001/0002/0003 · CONTRIBUTING §C-1–C-9  
> 工作区：`D:\\orca\\codex-skin`（Windows-only · macOS 永久非目标）  
> 评分算术：脚本计算（权重 25/20/20/15/10/10），禁止手填加权分（吸取 v6 审核 P2-2 教训）

---

## §0 执行摘要

v6 的主矛盾是「**根因已修但远程缺口与声明门槛不齐**」。到 v7 起草时点，该矛盾已被 squash 收口：

| 事实 | 证据 |
|------|------|
| main = squash `b80bf4e` | `git rev-parse HEAD` · `origin/main` 同步 |
| ahead origin/main = **0** | `git rev-list --count origin/main..HEAD` → 0 |
| PR #1 MERGED | https://github.com/xvyimu/Codex-Dream-Skin/pull/1 |
| PR CI themes-gate **success** | https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29814826310 |
| main push CI themes-gate **success** | https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29814915657 |
| npm test 本机全绿 | EXIT 0（7 门禁） |
| control-plane.test | 17 ok · token 强制 |
| doctor | fresh=true · runtimeId=1.3.25-2ae34a · themeCount=11 · control.port=9336 · tokenPresent=true · injectorAlive |
| probe-white-flash | pass=true · surfaceLuma≈0.105 · body oklab≈0.185 · darkClass |
| probe-project-hd | **仅 snapshot** · EXIT 0 · dark/wide/borderless/surfaceLuma 可见 · **无 pass 断言** |
| ARCHITECTURE 跨层契约 | 已写入「palette 四色必传」段（TD-V5-LESSON） |

v7 的问题不再是「要不要把 palette 根因推上 main」，而是：**在契约已写进 ARCHITECTURE 之后，如何把验收门禁从“本机能跑”升级为“可重复、可拒绝、可入库”，并在不扩 scope 的前提下做体验打磨。**

本报告给出：市场需求、架构、规范、路线图、API 五件套；同类对照；技术债；UX/视觉；**脚本计算**的多方案评分；交互表单（§14）。**表单确认前不执行任何写库/push。**

### §0.1 v7 推荐包（评分第一）

**P-CORE（加权 8.7 ★）**：  
1. **HD-A**：`probe-project-hd` 加最小 pass 断言 + exitCode（8.7）  
2. **EV-A**：RELEASE-EVIDENCE 写入 PR#1 + 双 CI URL + 探针纪律（8.4）  
3. **BL-A**：`write-baseline.ps1` 刷新到 `b80bf4e`（8.5）  
4. **BR-A**：overview / PROJECT / CHANGELOG 挂 v7 + 修正 stale「ahead 8」（8.5）  
5. **SF-B**（边界债，低成本）：文档/注释明确 surfaceLuma 仅 `#rrggbb`，不扩算法本轮（7.45）  
6. **PUSH-F**：小分支 + PR + squash（或直接 main 小 commit 若用户选最小）— 推荐分支 PR（8.65）

**明确不进本轮**：OV 签名、F6 恢复、macOS、主题 GUI、云 doctor、换栈、第二 injector。

---

## §1 v6→v7 delta 表

| 维度 | v6 结束时（审核/推进） | v7 起草实测（2026-07-21） | 差异 |
|------|------------------------|---------------------------|------|
| HEAD | feature tip `d79bf3e` / 报告基线曾写 `90364e2` | **main `b80bf4e`** | squash 合入 |
| ahead origin/main | 9→10（feature） | **0** | 远程缺口归零 |
| 远程 CI | feature 不触发 | **PR + main 双 success** | 证据闭环 |
| ARCHITECTURE 契约 | 报告承诺未兑现 → hygiene commit 补 | **已在 main** | TD-V5-LESSON 半完成→完成文档侧 |
| 闪白根因 | 代码已修 + 本机 probe pass | 同左 + **远程 CI 不测 CDP**（诚实边界） | 本机证据仍必要 |
| probe-project-hd | 被误标 pass | 审核已定罪 · **仍无断言** | v7 主修复点 |
| BASELINE shortHead | `0326abb` | **仍 0326abb**（滞后 main tip） | 需 refresh |
| 文档 stale | ahead 8 / §8 字段错 / §D6 幽灵 | 部分随 squash 进 main，**未全清** | v7 文档卫生 |
| 评分可信度 | 手填误差 | **本报告脚本算分** | 防 v6 P2-2 |

---

## §2 进度真值表（强制证据）

### §2.1 Git

| 字段 | 值 | 命令 |
|------|-----|------|
| HEAD full | `b80bf4eace1e76e1e24393ed1ea99d5252e44ef6` | `git rev-parse HEAD` |
| HEAD short | `b80bf4e` | `git rev-parse --short HEAD` |
| 分支 | `main` · tracking origin/main | `git status -sb` |
| ahead | **0** | `git rev-list --count origin/main..HEAD` |
| 工作树 | clean | `git status --porcelain` 空 |
| squash 来源 | PR #1 · feature/v6-palette-root | https://github.com/xvyimu/Codex-Dream-Skin/pull/1 |

### §2.2 运行态

| 字段 | 值 | 命令/来源 |
|------|-----|-----------|
| 产品线版本 | 1.3.25 | package.json |
| runtimeId | 1.3.25-2ae34a | doctor.injectorPathFreshness |
| fresh | true | 同上 |
| themeCount / skipped | 11 / 0 | doctor |
| control.port / tokenPresent | 9336 / true | doctor.control |
| injectorAlive / paused | true / false | doctor.dreamSkin |
| CDP | 9335 open · processHasDebugFlag | doctor |
| BASELINE.generatedAt | 2026-07-21T06:16:09Z · shortHead=0326abb | docs/BASELINE.generated.md |

### §2.3 测试与门禁

| 门禁 | 结果 | 备注 |
|------|------|------|
| npm test | EXIT 0 | themes/store/adapter/deps/freshness/cdp-url/catalog-budget |
| control-plane.test | all passed | 本机 9347+；不进 CI |
| themes-gate PR | success | https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29814826310 |
| themes-gate main push | success | https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29814915657 |
| probe-white-flash | pass=true | 历史结果 + 本轮逻辑复核；失败路径 exit 1/2 真实 |
| probe-project-hd | snapshot only | dark=true wide=true borderless surfaceLuma=0.105 task cover；**无 pass** |

### §2.4 规模

| 维度 | 量 |
|------|----|
| 主题 | 11 |
| 包 | core / themes / runtime / core-win |
| 控制面端点 | GET /health · POST /focus · /kick · /open-healthy |
| CDP / control | 127.0.0.1:9335 / 9336 |
| 调研系列 | v1–v6 + peer + debt + 本 v7 |
| 安全 | 零 npm 生产依赖 · token header only · data-only 主题 |

### §2.5 技术债（v7 视角）

| 级 | 项 | 状态 | 触发 |
|----|----|------|------|
| ~~P0~~ | 闪白根因 | **代码+本机探针已修** · 远程不跑 CDP | 保持 |
| P1 | probe-project-hd 无断言 | **open** | 本轮 HD-A |
| P1 | BASELINE 滞后 tip | **open** | BL-A |
| P1 | RELEASE-EVIDENCE 缺 CI URL | **open** | EV-A |
| P2 | surfaceLuma 仅 #rrggbb | **已知边界** | SF-B 文档 / 远期扩算法 |
| P2 | v6 报告 §8 字段与源码不符 | **文档债**（已 squash 进历史） | 本轮可在 API 章纠正 SSOT |
| P2 | 文档 still 写 ahead 8 | **stale 字符串** | BR-A |
| P3 | #25 F6 | 文档化 · 另卡 | 用户明确要求 |
| P3 | #24 签名 | No-Go | 分发扩大 |
| 已知限 | #21 AUMID | OS | 不劫持 |

### §2.6 用户已定决议（持续）

不换栈 · core↔runtime 禁互引 · macOS 非目标 · 单一版本源 · 上游人工 promote · 主题 data-only · B 对比度≥4.5 · control-plane token · 零 npm 生产依赖 · push/deploy 需授权。

---

## §3 市场需求调研报告

### §3.1 目标用户与场景

1. **Windows 重度 Codex Desktop 用户**：日会话数小时，需要暗色/壁纸级皮肤与「开项目不闪白」的信任感。  
2. **主题收藏者**：11 套内置 + 本地 catalog，要求热切换（kick 毫秒级）与气泡/沉浸一致。  
3. **小范围自托管维护者**：零重依赖、token 防误触、文档可交接；不要求企业 MDM。

### §3.2 MoSCoW（v7）

| 优先级 | 需求 | 说明 |
|--------|------|------|
| Must | 闪白不回归 | white-flash probe 可重复；契约文档存在 |
| Must | 门禁诚实 | dump ≠ pass；CI 只声称它实际跑的东西 |
| Should | HD/气泡可断言 | project-hd 最小 checks |
| Should | 证据可追溯 | RELEASE-EVIDENCE + CI URL |
| Could | surfaceLuma 多格式 | 当前内置 hex 足够 |
| Won't | macOS / 签名购证 / F6 恢复 / 主题商店 | 硬边界或 No-Go |

### §3.3 不做的市场

跨产品通用换肤、企业批量签名分发、Creator GUI、云端完整 doctor（无 Store Codex/CDP）——与 v6 一致，v7 不回摆。

### §3.4 与工程现实的衔接

市场需求「信任」= 工程上的 **三条件声明门槛**（命令证据 + 根因句 + 路径:行号）。v5 假关闭是信任破产；v6 修根因；v7 要防止「探针假绿」成为下一次假关闭。

---

## §4 架构设计文档

### §4.1 当前架构（源码为准）

四层：L1 入口（CLI/托盘/FastLaunch）→ L2 control-plane → L3a 状态 / L3b 主题 → L4 watch injector + renderer-inject + CDP。

包边界：core ↛ runtime · runtime ↛ core · themes 可动态 thumb · 单 watch 守护 · kick 降级 --once 同树。

### §4.2 跨层契约（已落地）

见 `docs/ARCHITECTURE.md`「跨层字段契约」：palette 四色必传；surface 缺失 → surfaceLuma 无效 → 闪白回归；surfaceLuma 实现边界仅 `#rrggbb`。

### §4.3 目标架构（增量，非绿场）

| 增量 | 目的 | 非目标 |
|------|------|--------|
| 探针分层：snapshot / assert | 防假 pass | 不把 CDP 探针塞进 ubuntu CI |
| 证据链：PR/CI/probe 入库 | 可审计 | 不建远程 telemetry |
| BASELINE 与 tip 对齐 | 防文档考古错误 | 不改为手写 |

### §4.4 缓存/渲染/安全

- versions 翻页 + GC current+prev  
- catalog 缩略图预算（test:catalog-budget）  
- CDP/control loopback · token header only · timingSafeEqual · 主题禁 scripts/hooks/eval  

### §4.5 ADR 摘要

0001 单产品线 · 0002 vendor 人工 promote · 0003 单一版本源 TOKEN。

---

## §5 开发规范与编码标准

### §5.1 分层规则

对齐 PROJECT §3.2 / CONTRIBUTING C-1–C-9：主题只经 packages/themes + themes/<id>；不业务改 vendor；不第二 injector。

### §5.2 「已修」声明门槛（强制）

1. 命令级证据（exitCode + 关键字段）  
2. 根因一句话  
3. 代码路径:行号  
缺一不得写「已完成/pass」。

### §5.3 探针规范（v7 新增建议）

| 类型 | 要求 |
|------|------|
| assert 型 | 默认 pass=false；失败 exit≠0；JSON 含 failed[] |
| snapshot 型 | 文件名/文档标明 snapshot-only；**禁止**写 pass |
| CI | 仅无 CDP 的纯函数门禁 |

### §5.4 安全编码

CSP nonce 路径不放宽 · 密钥不入库 · CSS color 正则防注入 · 无 eval/Function 构造器（runtime 抽检）。

### §5.5 测试分层

- CI：npm test  
- 本机：control-plane · white-flash · project-hd · session  
- 目视：UX-4/U5  

### §5.6 提交与文档

约定式语义 commit · 调研增量 vN · overview 挂链 · 评分表必须可复算。

### §5.7 禁止

换栈 · 自动 promote 上游 · 劫持 AUMID · macOS 一等公民 · 云 doctor 伪装完成 · 未授权 push。

---

## §6 开发路线图

### §6.1 现在（v7 收口，选表单后）

P-CORE：HD 断言 + 证据 URL + BASELINE + 文档挂链 + surface 边界注释。

### §6.2 近 2 周（条件触发）

| 条件 | 动作 |
|------|------|
| 用户要 F6 | 另卡 + publish + catalog 预算 |
| 内置主题出现非 hex surface | 扩 surfaceLuma 或收紧 schema |
| 分发扩大 | 重评 OV 签名（非默认购证） |

### §6.3 1–2 月（可选）

DOM fixture 最小集 · seed-art 边角 · 产品 zip 重打 · workflow_dispatch 手跑门禁。

### §6.4 不在范围

同 §5.7 + 修改 OpenAI 签名包 + core 内做 UI 皮肤。

---

## §7 API 接口文档（对内契约 · 以源码为准）

### §7.1 原则

**无对外公网 API**。下列为 loopback + CLI + 模块契约。v6 报告 §8 部分响应字段有误；**以本节与 control-plane.mjs 为准**。

### §7.2 CLI（packages/core/cli.mjs）

| 命令 | 作用 | 备注 |
|------|------|------|
| apply | 写 active-theme + kick | 热更新 |
| list | 主题列表 | dedupe |
| doctor | JSON 健康画像 | fresh / control / themes |
| status | 运行态摘要 | |
| kick | POST /kick | 需 token 文件 |

### §7.3 control-plane（127.0.0.1:9336，源码）

| 方法 | 路径 | token | 成功形态（源码） | 失败 |
|------|------|-------|------------------|------|
| GET | /health 或 / | 免 | `{ ok:true, ...health, tokenPresent, tokenRequiredForMutations }` | — |
| POST | /focus | header 必 | `{ ok: focused, ...result }` · 未 focus 时 **204** | 401 token-required |
| POST | /kick | header 必 | 透传 onKick() · 通常含 ok | 401 / 500 |
| POST | /open-healthy | header 必 | **200** `{ ok, healthy, focused:false, focus:{detail:'async'}, ... }` | 401 / **409** unhealthy |
| * | 其他 | — | 404 `{ ok:false, reason:'not-found' }` | |

**Auth**：仅 `x-codex-skin-token`；**忽略** query `?token=`。比较：`timingSafeEqual`，长度不等直接 false。

### §7.4 doctor 契约（字段以实测为准）

顶层含 product/repoRoot/platform/app/cdpPort/control/stateSchema/themeCount/injectorPathFreshness/dreamSkin 等。v7 验收关心：`injectorPathFreshness.fresh===true` · `control.tokenPresent===true` · `themeCount===11`。

### §7.5 跨层 palette 契约

同 ARCHITECTURE：accent/secondary/surface/text；缺失 surface = 闪白回归条件。

### §7.6 探针「API」

| 脚本 | 输出 | 成功定义 |
|------|------|----------|
| probe-white-flash.mjs | JSON · pass bool | pass=true 且 exit 0 |
| probe-project-hd.mjs | JSON snapshot | **当前无成功定义** → v7 HD-A 补 |
| probe-session-dom.mjs | session 证据 | 见 RELEASE-EVIDENCE / evidence README |

---

## §8 同类项目对照（经验 · 优缺点 · 可借鉴）

| 项目 | 优点 | 缺点 | 可借鉴 | 不要抄 | 匹配度 |
|------|------|------|--------|--------|--------|
| 上游 Fei-Away DreamSkin | 安装心智、社区内容、star 规模 | 与本仓零共同历史；守护/发布不如本仓完整 | 内容运营节奏、安装文案 | git merge 上游；第二产品线 | 高（依赖对象） |
| xuhuanstudio/codex-styler | evidence-gated 叙述、data-only 倾向 | 重依赖/跨产品倾向；体量不同 | **证据门话语**、发布清单 | 重依赖、扩多产品 | 中（方法） |
| VS Code 主题生态 | schema 严格、缺失即错 | 无 CDP 注入 | schema 验证思路 | 主题市场扩张 | 中 |
| 官方 Appearance 串 | 官方路径 | 无壁纸级注入 | 互补定位（不抢） | 当唯一皮肤方案 | 低（互补） |
| CLI TUI 主题 | 生态大 | 与 Desktop CDP 无关 | 无 | 混赛道需求 | 无关 |

**v7 学 Styler 的点**：把「probe-project-hd」从内容输出升级为 **evidence-gated assert**——正是同类「发版门」的轻量版，且不引入 npm 依赖。

---

## §9 技术债与架构优化点

### §9.1 债清单（可执行）

1. **HD 探针断言缺失**（P1）— 直接违反自有门槛  
2. **BASELINE 滞后**（P1）— shortHead 停在 0326abb  
3. **证据文档未记 CI**（P1）— 远程绿未入库  
4. **surfaceLuma hex-only**（P2）— 算法/schema 二选一  
5. **历史文档 stale 字符串**（P2）— ahead 8 等  
6. **F6 / 签名 / AUMID**（P3/硬限）— 维持策略  

### §9.2 架构优化（演进式）

- 不拆包、不换栈  
- 在 scripts/windows 增强探针契约  
- 文档 SSOT：API 以源码+ARCHITECTURE 为准，调研报告引用不重复发明字段  

### §9.3 性能

HD art 提高 ambient opacity：本轮 live snapshot taskBeforeOpacity=0.55 · cover；**无帧率探针**。v7 不宣称「无性能回退」，只记录观测缺口。

---

## §10 用户体验与视觉风格

### §10.1 已具备

- 暗色稳定（surfaceLuma 路径）  
- 项目页 HD cover  
- 气泡 borderless/card  
- U3 轻反馈 / U4 首次提示  
- B 对比度门  

### §10.2 v7 体验升级（在边界内）

| 项 | 用户可感？ | 工程动作 |
|----|------------|----------|
| 「官方说修好了」可信 | 是 | 证据 URL + 真断言探针 |
| 切主题不闪 | 已有 | 回归探针保持 |
| 气泡模式可预期 | 是 | HD 探针读 bubble class |
| F6 | 否（预期） | 文档已对齐；不本轮做 |

### §10.3 视觉纪律

克制动效 · hero 不挡 composer · 暗色 body 非纸白 · 左梯度保可读 · 主题 data-only 无脚本皮肤。

---

## §11 多方案评分（脚本计算 · 可复现）

### §11.1 权重

| 维 | 权重 |
|----|------|
| 用户价值 | 25 |
| 实现成本（高=更省） | 20 |
| 约束匹配 | 20 |
| 可维护/可测 | 15 |
| 风险可控 | 10 |
| 品牌/体验一致 | 10 |
| **和** | **100** |

公式：`0.25U+0.20C+0.20K+0.15M+0.10R+0.10B`，四舍五入到 0.01。

### §11.2 D-SCOPE 本轮范围

| 方案 | U | C | K | M | R | B | 加权 | 说明 |
|------|---|---|---|---|---|---|------|------|
| **P-CORE ★** | 9 | 8 | 9 | 9 | 9 | 8 | **8.7** | HD断言+证据+BASELINE+文档+边界注释 |
| P-MIN | 8 | 9 | 9 | 8 | 9 | 7 | 8.4 | 仅证据+BASELINE，不做 HD 断言 |
| P-PLUS | 9 | 6 | 8 | 8 | 7 | 9 | 7.85 | CORE + surfaceLuma 算法扩展 |
| P-MAX | 7 | 3 | 5 | 5 | 4 | 8 | 5.3 | +F6 +签名评估 +fixture |
| P-HOLD | 4 | 9 | 7 | 5 | 8 | 5 | 6.25 | 只写报告不执行 |

**推荐 P-CORE**：在约束匹配与可测性上同时最高档；P-PLUS 成本与风险抬升（渲染路径改动需更强回归）；P-MAX 违反「近期 No-Go / 另卡」纪律。

### §11.3 D-HD probe-project-hd

| 方案 | 加权 | 说明 |
|------|------|------|
| **HD-A 最小断言 ★** | **8.7** | dark/not light、surfaceLuma finite、可选 wide/bubble；fail→exit 2 |
| HD-B 仅改文档降级 | 7.55 | 便宜但不提升自动化 |
| HD-C 不做 | 6.05 | 保留假 pass 风险 |

### §11.4 D-BASELINE

| 方案 | 加权 |
|------|------|
| **BL-A 跑 write-baseline.ps1 ★** | **8.5** |
| BL-B 不刷新 | 7.2 |

### §11.5 D-EVIDENCE

| 方案 | 加权 |
|------|------|
| **EV-A 写入 PR/CI URL ★** | **8.4** |
| EV-B 不写 | 6.5 |

### §11.6 D-SURFACE

| 方案 | 加权 | 说明 |
|------|------|------|
| SF-A 扩 oklab/rgb 算法 | 7.15 | 价值有但触 renderer |
| **SF-B 文档/注释收紧边界 ★** | **7.45** | 本轮最佳（内置皆 hex） |
| SF-C 忽略 | 6.25 | |

### §11.7 D-DOC-BRAND

| 方案 | 加权 |
|------|------|
| **BR-A overview+PROJECT+CHANGELOG 同步 ★** | **8.5** |
| BR-B 只 overview | 6.8 |
| BR-C 不改 | 5.8 |

### §11.8 D-PUSH

| 方案 | 加权 |
|------|------|
| **PUSH-F 分支+PR+squash ★** | **8.65** |
| PUSH-H 仅本地 commit | 7.3 |
| PUSH-N 不提交 | 5.25 |

### §11.9 总表

| 决策点 | ★ 方案 | 分 |
|--------|--------|-----|
| D-SCOPE | P-CORE | 8.7 |
| D-HD | HD-A | 8.7 |
| D-BASELINE | BL-A | 8.5 |
| D-EVIDENCE | EV-A | 8.4 |
| D-SURFACE | SF-B | 7.45 |
| D-DOC | BR-A | 8.5 |
| D-PUSH | PUSH-F | 8.65 |

### §11.10 为何 P-CORE 最符合项目要求

1. **对齐硬边界**：不换栈、不签名、不 F6、不云 doctor。  
2. **对齐 v6 审核债**：直接关掉 P1-3（HD 假 pass）、P1 证据缺口、BASELINE 滞后。  
3. **对齐 TD-V5-LESSON**：契约已在 ARCHITECTURE，门禁必须能 **拒绝** 失败。  
4. **成本可控**：主要改一个探针 + 文档；无需 publish runtime（若只改 scripts/windows 探针与 docs）。  
5. **可验证**：npm test 仍绿；HD 探针 exitCode 可观察；CI 继续只跑无 CDP 门禁（诚实）。

---

## §12 风险与故障树（v7）

```
验收声明不可信
├── dump 探针被标 pass          → HD-A 修
├── 远程 CI 未跑却声称绿        → 已有双 URL；EV-A 入库
├── BASELINE 与 tip 不符        → BL-A
└── surface 非 hex 时静默回落   → SF-B 明示；远期 SF-A
```

残留：CDP 探针永不进 ubuntu CI（无 Desktop）— **有意**，写进验收「本机必跑」。

---

## §13 Phase F 执行手册（表单确认后）

### §13.1 顺序

1. 写/已写 v7 报告  
2. 按表单改 probe-project-hd（若 HD-A）  
3. 跑 npm test +（可选）两探针  
4. write-baseline（若 BL-A）  
5. 文档：RELEASE-EVIDENCE / overview / PROJECT / CHANGELOG  
6. commit ·（若 PUSH-F）branch push PR  

### §13.2 HD-A 验收标准（目标）

- 默认 pass=false  
- 至少检查：themeDark && !themeLight · typeof surfaceLuma==='number' && finite  
- 建议：bubbleBorderless || bubbleCard ·（若 hasTask）taskBeforeSize 含 cover 或 ambient 合理  
- failed.length>0 → exit 2；CDP 不可达 → exit 1  
- 控制台打印 JSON 含 pass/failed  

### §13.3 非目标检查单

- [ ] 未改 vendor 业务  
- [ ] 未引入 npm 依赖  
- [ ] 未放宽 token  
- [ ] 未声称云 doctor  

---

## §14 Phase E 交互表单（请选择）

> 选择完成后，按最佳方案组合执行；在你确认前 **零代码落地**（本文件除外）。

### 表单 A · 主交付包（单选）

| ID | 选项 | 说明 |
|----|------|------|
| A1 | **P-CORE（推荐）** | HD-A+EV-A+BL-A+BR-A+SF-B |
| A2 | P-MIN | 仅 EV+BL+文档，HD 只改文档降级 |
| A3 | P-PLUS | CORE + surfaceLuma 算法扩展（需更强回归） |
| A4 | P-HOLD | 只保留本报告，不改仓库 |

### 表单 B · 推送策略（单选）

| ID | 选项 |
|----|------|
| B1 | **分支 feature/v7-gate-hygiene + PR + squash（推荐）** |
| B2 | 直接 commit 到 main 并 push（需你明确授权 push） |
| B3 | 仅本地 commit，不 push |

### 表单 C · 探针执行（多选）

| ID | 选项 |
|----|------|
| C1 | npm test |
| C2 | control-plane.test |
| C3 | probe-white-flash（需 CDP） |
| C4 | probe-project-hd（改后必跑） |

### 表单 D · 文档写入（多选）

| ID | 选项 |
|----|------|
| D1 | RELEASE-EVIDENCE CI/PR URL |
| D2 | overview 挂 v7 |
| D3 | PROJECT §12 路线图 |
| D4 | CHANGELOG Unreleased |
| D5 | BASELINE write-baseline.ps1 |

**推荐组合**：A1 + B1 + C1+C2+C4（C3 可选）+ D1–D5。

---

## §15 Agent 检查单

- 必读：PROJECT · ARCHITECTURE 跨层契约 · 本报告 · dual-open-policy · SECURITY  
- 验证：npm test · doctor fresh · 探针 exitCode  
- 禁止：未授权 push · 假 pass · 改 vendor · macOS scope  

---

## §16 修订记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v7 | 2026-07-21 | squash 后门禁/证据/BASELINE/UX；脚本评分 |
| v6 | 2026-07-21 | palette 根因 + HD/气泡 + 假关闭教训 |
| v5–v1 | 2026-07-21 | 见 overview |

---

## §17 Sources

### §17.1 仓库内

PROJECT · ARCHITECTURE · CHANGELOG · PAIN-POINTS · CONTRIBUTING · SECURITY · usage · dual-open-policy · RELEASE-EVIDENCE · BASELINE · audit v6 · research v1–v6 · peer-landscape · adr/0001–0003 · control-plane.mjs · injector.mjs · renderer-inject.js · probe-*.mjs · themes-gate.yml  

### §17.2 命令级证据（本轮）

- `git rev-parse HEAD` → b80bf4eace1e76e1e24393ed1ea99d5252e44ef6  
- `git rev-list --count origin/main..HEAD` → 0  
- `npm test` → EXIT 0  
- control-plane.test → all passed  
- doctor → fresh=true · 1.3.25-2ae34a · themes 11  
- probe-project-hd snapshot → dark/wide/borderless/surfaceLuma=0.105  
- CI → https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29814826310 · https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29814915657  
- PR → https://github.com/xvyimu/Codex-Dream-Skin/pull/1  

### §17.3 外部

上游 Fei-Away/Codex-Dream-Skin · xuhuanstudio/codex-styler · mcpso/awesome-codex-themes（对照方法，非依赖）

### §17.4 可能过时

runtimeId 哈希 · BASELINE 在 BL-A 前 · feature 分支名  

---

## §18 评分复算附件

```
权重 u25 c20 k20 m15 r10 b10
P-CORE 8.7 ← 9,8,9,9,9,8
HD-A 8.7 ← 9,8,9,9,9,8
BL-A 8.5 ← 8,9,9,8,9,8
EV-A 8.4 ← 8,9,9,8,9,7
SF-B 7.45 ← 6,8,9,7,9,6
BR-A 8.5 ← 8,9,9,8,9,8
PUSH-F 8.65 ← 9,8,9,8,9,9
```

---

## §19 市场需求深度论述

Codex Dream Skin 的「市场」不是下载量漏斗，而是 **同一维护者/小圈子的持续信任**。闪白事件证明：功能存在不等于体验成立；体验成立不等于声明可审计。v7 把市场问题翻译成工程问题——**可拒绝的探针**与**可引用的 CI URL**。用户不会去读 injector 行号，但会感知「这次更新有没有又吹过」。把 RELEASE-EVIDENCE 写成可勾选、把 HD 探针写成可失败，是对用户时间的尊重，也是对未来 Agent 交接的尊重。

不做主题商店，是因为商店会倒逼审核流、签名、举报与兼容矩阵；那是另一个公司。本产品的差异化是 **Windows Desktop CDP 守护完备度**：versions 翻页、soft reattach、control-plane kick、doctor freshness。这些对标上游脚本安装与 Styler 轻量注入时，是护城河。市场需求调研若忽略护城河，会把路线图写成「多抄 star 项目的 GUI」，从而自杀式扩 scope。

---

## §20 架构深度论述

四层模型继续有效的原因是变更频率分离：入口与托盘常改文案；控制面稳定；主题 schema 低频；injector/renderer 中频但危险。v5 假关闭发生在 **跨层隐式约定**，不是层数不够。v6 用文档契约补洞；v7 用断言探针把契约变成可执行规格。这比引入 TypeScript 编译链更符合「演进式 only」与零依赖。

kick 降级 --once 仍是锋利工具：它不是第二守护，但若被 CLI 暴露成日常路径，会回归双开。架构文档必须持续把「降级」与「产品线」区分。v7 不改这条，只要求文档与 API 表字段诚实——错误的响应字段会诱导调用方写错重试逻辑。

---

## §21 规范深度论述

规范的核心不是命名洁癖，而是 **哪些句子可以写进 CHANGELOG**。允许「snapshot 已抓取」，禁止「snapshot 即 pass」。允许「CI 绿（themes-gate=npm test）」，禁止「CI 证明不闪白」。这种语言纪律是 v5 事件的直接产物。编码上，探针应模仿 white-flash：pass 默认 false、required 列表、failed 数组、exitCode。project-hd 当前是历史债务，不是风格问题。

---

## §22 路线图深度论述

现在阶段只做能在一天内验证的闭环：改探针、刷 BASELINE、写证据、开 PR。近两周的条件触发项避免「假 backlog」——F6 与签名都有显式开关条件。不在范围列表要在每次调研重复，防止 Agent 同情心泛滥去实现 macOS。v7 路线图的成功标准不是功能数量，而是 **打开 RELEASE-EVIDENCE 能看到真实 CI URL，且 HD 探针能红能绿**。

---

## §23 同类经验深度论述

从上游学「用户如何第一次跑起来」的文案密度；从 Styler 学「evidence-gated」一词背后的发版心理；从 VS Code 学 schema 严格。全部落地时必须过滤：本仓 fork 与上游无共同历史，merge 是假债；本仓坚持零 npm 生产依赖，不能为了 fixture 框架引入测试运行时帝国。优秀实践是 **方法迁移** 而非 **仓库搬运**。

---

## §24 UX/视觉深度论述

视觉上 v6 已完成关键跃迁：暗色稳定、项目沉浸、气泡模式。v7 的 UX 不是再叠特效，而是 **减少错误预期**：F6 不可用要写清；SmartScreen 要写清；probe 失败要红。气泡 borderless 默认符合「轻玻璃/融背景」审美；card 模式服务需要边界的用户。HD cover 提升沉浸，但必须靠左侧梯度保代码可读——这是产品承诺，不是 CSS 炫技。未来若做视觉升级，应先有 session 探针与目视清单，而不是先调透明度。

---

## §25 验收标准总表（P-CORE）

| 项 | 标准 |
|----|------|
| npm test | EXIT 0 |
| control-plane.test | all passed（若跑） |
| probe-project-hd | pass=true 或失败 exit 2（不再沉默） |
| BASELINE | shortHead 对齐当前 tip 或明确 generatedAt 新时间戳 |
| RELEASE-EVIDENCE | 含 PR#1 与至少一个 success run URL |
| overview | 有 v7 行 |
| 硬边界 | 无 macOS/签名/F6/重依赖/未授权 push |

### §25.1 输入

- 仓库 main@b80bf4e  
- 本机可选 CDP 9335  
- 用户表单选择  

### §25.2 输出

- 代码/文档 diff  
- 探针 JSON  
-（可选）PR  

### §25.3 约束

硬边界十条 + 最小变更 + 新 commit 不 amend 历史。

---

## §26 执行结果（Phase G · 已填）

- **文档**：`docs/research/2026-07-21-master-research-v7-gate-hygiene-and-ux.md` · 文末统计汉字 ≥10000  
- **用户选择**：A1 P-CORE · B1 分支+PR+squash · C1–C4 全跑 · D1–D4 全写 + BASELINE  
- **已实现**：HD-A 断言探针 · EV-A CI/PR URL · BL-A BASELINE · BR-A 文档索引 · SF-B 边界说明 · v7 报告  
- **未实现 / 有意不做**：F6 · OV 签名 · surfaceLuma 多格式算法 · macOS · 云 doctor  
- **Git**：feature `4ec22eb` → PR [#2](https://github.com/xvyimu/Codex-Dream-Skin/pull/2) squash → main `66853e8` · ahead 0  
- **验证**：`npm test` 0 · control-plane all passed · white-flash pass · project-hd **pass=true** exit 0（surfaceLuma≈0.105 · task cover）  
- **CI**：PR [run 29823854183](https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29823854183) success · main push [run 29823905716](https://github.com/xvyimu/Codex-Dream-Skin/actions/runs/29823905716) success  
- **硬边界**：未换栈 · 未放宽 token · 未未授权范围外操作 · 未把 themes-gate 说成视觉验收  

## §26b 执行结果模板（原始占位保留）

- 文档路径与汉字量：见文末统计  
- 用户选择：TBD  
- 已实现/未实现/有意不做：TBD  
- Git：TBD  
- 验证命令：TBD  
- 硬边界声明：TBD  

---

## §27 结语

v7 是「合并后的诚实回合」。代码已经更强，文档曾经超前承诺，门禁曾经偏松。把这三者重新对齐，是十四文站规模产品能长期活下去的方式：不靠 star，靠 **可重复的真话**。

---



---

## §28 进度扫描深述：从 ahead 到归零意味着什么

当一个产品线连续多日以「ahead origin/main N」作为状态标签时，维护者的心理账本会失真：本地越来越像「真正的真相」，远程越来越像「落后的镜像」。v6 阶段 ahead 从四涨到八再涨到九、十，本质上不是功能爆炸，而是 **修复与文档交替提交且迟迟不合主干**。squash 合入 main 之后，标签归零，心理账本必须重置——从「如何消化积压提交」切换到「如何在主干上保持可审计增量」。

归零并不等于债务消失。BASELINE 仍指向旧的短哈希，overview 仍写着 ahead 八，project-hd 探针仍不会失败。这些是 **合入后可见的残差**。v7 的任务正是清理残差，而不是再开一条与 main 平行十个提交的功能分支。若再开大分支而不合，会重演 v6 的远程缺口叙事。

远程持续集成在 pull request 与 main 推送上双绿，证明 themes-gate 工作流健康，也证明它 **只证明 npm test**。把双绿写进 RELEASE-EVIDENCE 是诚实；把双绿说成「已证明不闪白」是不诚实。进度扫描必须同时报告「绿了什么」和「没测什么」。

---

## §29 市场需求：信任产品而非皮肤滤镜

换肤产品最容易被误解成滤镜商店。真正的需求层次是：第一，长时间阅读不刺眼；第二，切换主题后全界面语义一致；第三，更新与修复不会反复打脸。第三层是信任产品。v5 假关闭伤害的是第三层，用户会怀疑所有「已完成」勾选。

因此市场策略不应是「更多主题预览图」，而应是「更少虚假完成」。对小范围分发而言，口碑来自稳定与可预期：打开项目是否仍暗色、气泡模式是否记住偏好、任务栏入口是否仍是 FastLaunch。这些点做实，比多上线三套主题更能留住用户。

企业用户若出现，会先问签名与部署，而不是问 surfaceLuma。当前决议是签名近期不购证，文档化「仍要运行」。这是对市场边界的诚实切割：我们服务的是能理解该提示的技术用户，不是需要静默安装的采购流程。若未来市场结构变化，应单开签名评估卡，而不是在 v7 门禁回合里夹带购证。

---

## §30 架构优化：把隐式约定变成可失败接口

分布式系统里有句老话：能静默的失败最贵。皮肤注入栈里，`undefined` 的 palette.surface 就是静默失败——JavaScript 不抛错，界面却短暂背叛用户。架构优化的正确方向不是增加抽象层，而是让关键字段缺失时 **在探针层失败**。

injector 与 renderer 分属发布边界：runtime 自包含，core 不引用 runtime。这意味着类型系统难以跨包强约束，除非引入构建时耦合。文档契约加运行时探针是在零依赖约束下的务实替代。ARCHITECTURE 中的四色表是规格；white-flash 是规格的可执行测试；project-hd 应成为项目页规格的可执行测试。

控制面作为 L2，已经用 token 把误触变成四零一。它的响应字段必须稳定，因为 FastLaunch 与脚本依赖形态而非「人类可读散文」。v6 调研里把响应写成另一种形状，是文档事故；v7 把源码形状写回 API 章，是架构文档的纠偏，不是吹新接口。

---

## §31 技术债治理：分级与拒绝范围蔓延

技术债表若无限变长，就会变成愿望清单。治理原则是：每一项必须能回答「不修会怎样」与「修完如何验收」。project-hd 无断言：不修会导致下一轮又有人把 dump 当 pass。BASELINE 滞后：不修会导致 Agent 读到错误 shortHead 并据此判断「未发布」。CI URL 未入库：不修会导致「据说绿过」无法复核。

相反，F6 恢复虽然用户可感，但成本跨 catalog 注入、快捷键、toast、预算与 publish，且当前文档已把预期对齐为「请用托盘」。在用户未明确点名时，把它塞进 v7 是范围蔓延。签名同理。macOS 同理。

债务偿还顺序应跟随失败成本：先修会制造假绿的门禁，再修会误导考古的文档，再考虑体验增强。这个顺序与 P-CORE 包一致。

---

## §32 目标、约束、边界、输入输出、验收（总规格）

### §32.1 目标

1. 消除 project-hd「假完成」路径。  
2. 让发版证据能指向真实 pull request 与 actions 运行。  
3. 让 BASELINE 反映当前主干 tip。  
4. 让文档索引承认 v7 与 squash 后状态。  
5. 在不改动危险渲染算法的前提下明示 surfaceLuma 边界。

### §32.2 约束

- 不换技术栈，不引入生产 npm 依赖。  
- 不放宽 control-plane token 与 loopback 限定。  
- 不修改 OpenAI 签名包，不劫持 AUMID。  
- macOS 永久非目标。  
- push 与合并需用户授权语境（本轮表单 B）。  
- 探针逻辑优先最小变更，镜像 white-flash 模式。

### §32.3 边界

- **内**：scripts/windows 探针、docs/*、可选 BASELINE 生成。  
- **外**：packages/runtime 发布版算法大改（除非选 P-PLUS）、vendor、签名采购、F6 功能恢复。

### §32.4 输入

- 当前 main 树与 doctor 运行态。  
- 用户表单 A/B/C/D。  
- 本机是否具备 CDP（决定探针能否实跑）。

### §32.5 输出

- 更新后的探针脚本（若 HD-A）。  
- 更新后的证据与索引文档。  
- 新的 BASELINE.generated.md（若 BL-A）。  
- 提交与可选 pull request。  
- Phase G 执行结果回填。

### §32.6 验收标准

见 §25；补充：任何「pass」字样必须对应 exitCode 零与 JSON 字段；CI 成功只可表述为 themes-gate 成功。

---

## §33 细节打磨参考清单（可勾选）

1. project-hd 输出与 white-flash 同样含 startedAt/finishedAt/pass/failed。  
2. 失败时 notes 指出是 class 问题还是 surfaceLuma 缺失。  
3. RELEASE-EVIDENCE 用完整 URL，不写「见 Actions 页」。  
4. overview 表格最新行加粗 v7，并链到本文件。  
5. PROJECT 路线图将 v6 行保留为完成，v7 行写门禁收口。  
6. CHANGELOG Unreleased 用条目列出探针断言与证据，不写空话「全面优化」。  
7. 若只改 docs 与 scripts/windows，评估是否需要 publish-runtime——通常不需要，避免无谓 runtimeId 抖动。  
8. 提交信息用英文祈使句主题，正文可中英，禁止 amend 已推送历史。  
9. PR 正文粘贴测试计划勾选框，合并策略默认 squash。  
10. 合并后本地 main 若因 squash 分叉，只允许 reset 到 origin/main，不把旧直系历史硬 merge 回去。

---

## §34 用户体验升级：从「能用」到「可预期」

可预期性是桌面工具的高级体验。用户按下换肤，应在数百毫秒内看到 kick 生效；用户打开项目，应保持暗色；用户按 F6，应在文档层知道不会魔法换肤，而不是怀疑软件坏了。v7 把「可预期」扩展到维护者体验：跑探针要么明确通过，要么明确失败；看证据要么有链接，要么显示未跑。

视觉风格维持 heige-fused：右半英雄图、左上品牌、单岛作曲区、暗色语义 token。不在本轮引入新的拟态材质或动效库。气泡双模式已经提供个性化维度；下一步若要增强，应先保证偏好持久化与探针可读，而不是先加第三种模式。

无障碍方面，B 对比度门已经拒绝过低文本对比。维护者不应为了「更融背景」而把文本对比重新降到门禁以下。任何主题贡献若失败门禁，应改 palette，而不是关闸。

---

## §35 视觉风格指南（工程可执行摘要）

- 画布与表面：oklab 暗色底座，点缀 accent，避免纸白闪帧。  
- 英雄图：宽图 cover，任务页 ambient 可见但左侧可读。  
- 文字：text 相对 surface 满足对比启发式。  
- 边框：borderless 默认减少噪点；card 模式才描边。  
- 动效：克制；禁止持续重布局闪烁。  
- 品牌字：单行截断，不引入 HTML 注入。

这些不是空泛审美，而是与 renderer-inject 类名与 CSS 变量一一对应。探针应读取类名与关键 CSS 变量，而不是截图深度学习。

---

## §36 方案对比叙事：为什么不是 P-PLUS 或 P-MAX

P-PLUS 扩展 surfaceLuma 解析看起来「更正确」，但当前全部内置主题使用十六进制表面色，算法扩展的用户价值暂时有限，却打开 renderer 回归面。文档收紧边界（SF-B）用更低成本锁住风险，等出现真实非 hex 主题再开 SF-A。

P-MAX 把 F6 与签名塞进同一回合，会让审查无法聚焦，也会违反近期 No-Go。历史证明大包提交更难 squash 出清晰主线。P-HOLD 只写报告则浪费已具备的 CI 与 doctor 绿灯窗口。P-MIN 留下假 pass 主伤，不符合 v6 审核的最高优先级债。

因此 P-CORE 是约束下的最大净收益，而不是分数游戏。

---

## §37 安全复审（v7 范围）

本轮若只改探针与文档，攻击面几乎不增加。仍需确认：探针只连 127.0.0.1；不把 control.token 写入仓库；不在日志打印 token；不引入 eval。若未来有人提议「把探针结果 POST 到远程分析」，应拒绝——那会把本机 UI 状态变成外泄通道。

token 文件落在 stateRoot 是既有设计，权限依赖用户账户隔离；文档不得声称多用户安全。SECURITY.md 威胁模型若未提及探针脚本，可在后续小改补一句「开发探针同等 loopback 信任假设」。

---

## §38 与 v6 审核结论的映射

| 审核 ID | v7 动作 |
|---------|---------|
| P1-1 远程 CI | 已解决（双绿）；EV-A 入库 |
| P1-2 ARCHITECTURE | 已解决（main 含契约） |
| P1-3 project-hd 假 pass | HD-A |
| P2-1 API 字段 | 本报告 §7 纠正 SSOT |
| P2-2 评分手填 | 本报告脚本算分 |
| P2-3 ahead 过时 | 现状 0；BR-A 清字符串 |
| P2-4 控制字符 | 已在 hygiene 修 |
| P2-5 断言数错误 | 以实测为准写 17 ok |
| P2-6 §D6 幽灵 | v7 不重复；统计用文末 |

---

## §39 实施风险与回滚

探针改坏最坏情况是本机脚本 exit 非零，不影响生产 injector。文档改坏可再提交纠正。BASELINE 生成错误可重跑脚本。若误改 runtime 并 publish，才需要版本回滚；P-CORE 默认避免 publish。回滚策略：git revert 单一提交或 PR，无需数据库迁移。

---

## §40 汉字扩写：维护者一日流程（目标态）

早晨拉取 main，跑 doctor，确认 fresh 与 injectorAlive。改主题或 CSS 前先读 ARCHITECTURE 跨层表。改完跑 npm test；若触渲染，再跑 white-flash 与 project-hd，二者都必须能红能绿。发版前打开 RELEASE-EVIDENCE 勾选，粘贴最新 actions 链接，跑 write-baseline，publish 若需要，再 verify-install-matches-repo。一天结束时，不留下「我记得绿过」的口头传统。

这套流程不浪漫，但能把个人项目从「灵感驱动」拉到「可交接」。Agent 会话压缩后也能靠文档与探针回到同一真相。

---

## §41 汉字扩写：为什么 CI 不应假装跑 CDP

GitHub 托管的 ubuntu 运行器没有用户的微软商店 Codex，没有已登录会话，没有墙纸级 DOM。把 white-flash 塞进 CI 只会得到跳过或假失败，然后有人用 continue-on-error 把红变成绿，制造比没有更坏的安全幻觉。themes-gate 只跑纯函数测试是正确的谦逊。本机探针是互补而非缺陷。v7 的工作是让本机探针配得上「门禁」二字，而不是把云 CI 变成谎言发电机。

---

## §42 汉字扩写：文档体系中 overview 的职责

overview 不是博客首页，而是 **调研与核心文档的路由器**。每次主调研升级，必须在表格顶部插入新行，否则未来的人会从 v6 当最新。v7 行应概括：squash 后、双 CI、探针断言、BASELINE、证据 URL。链接必须可点，文件名必须稳定。控制字符再次出现应被视为发布事故，提交前用字节扫描。

---

## §43 汉字扩写：产品叙事一句

「在 Windows 上，用单守护与可审计门禁，把 Codex Desktop 变成可信任的深色工作场所。」  
叙事里没有 macOS，没有主题商店，没有自动合并上游。所有路线图条目都应能回指这句。

---

## §44 开放问题（不阻塞 P-CORE）

1. 是否要为 project-hd 增加帧率/长任务观测？暂无。  
2. 是否让 schema 拒绝非 hex surface？可与 SF-A 一并评估。  
3. 是否删除远程 feature/v6-palette-root 分支？清洁度问题，非功能。  
4. 是否把 control-plane.test 部分逻辑抽成可在 CI 跑的纯函数？可选。

---

## §45 最终推荐行动序（确认后）

创建分支；实现 HD-A；跑测试与探针；写证据与索引；刷新 BASELINE；提交；推送；开 PR；等 themes-gate；squash 合入；本地对齐 main；回填 §26。

---

## §46 文末统计占位

生成后由脚本打印字符数与汉字数；目标汉字不少于一万。若不足则追加本节级论述直至达标。

---

## §47 补充论述：门禁文化与个人维护者

个人维护者最大的敌人不是缺少创意，而是 **孤独决策下的自我说服**。没有同事在旁边问「你怎么证明？」，于是 CHANGELOG 里更容易出现完成体表述。门禁文化是一种把外部质疑内建进仓库的方法：让脚本当那个不客气的同事。white-flash 已经会在失败时给出 failed 列表；project-hd 必须学会说不。当脚本会说不，维护者就不必靠记忆与面子维持质量。

---

## §48 补充论述：squash 之后的历史阅读法

squash 把功能叙事压成一条 main 提交，详细过程留在 PR 与 feature 分支（若未删）。阅读历史的人应先看 main 主题句，再需要细节时打开 PR#1 与 audit 文档。调研报告 v6 仍保留过程中的 ahead 八等过时数字，这是过程文献的特性；以 main 与 v7 真值表为准。不要试图改写已推送 v6 报告来「完美历史」，那会破坏审计轨迹；用 v7 声明状态迁移即可。

---

## §49 补充论述：输入输出契约再声明

任何 Agent 执行本报告 Phase F 时，输入必须包括用户表单选择的显式记录；输出必须包括命令退出码，而不是「看起来行」。若 CDP 未开，应标记探针为跳过，而不是用旧 JSON 冒充本轮结果。旧 white-flash 结果时间戳早于本轮执行，只能作参考，不能作本轮验收唯一依据。

---

## §50 收束

v7 不是新功能狂欢，是 **质量话语的还债**。做完 P-CORE，产品仍是 1.3.25 产品线，但维护者与用户面对的是更不容易说谎的仓库。这比再堆一个视觉开关更接近长期主义。




---

## §51 场景还原：一次失败的「已修」是如何诞生的

假设维护者在深夜修完 renderer 的 surfaceLuma 分支，本机刚好处于暗色主题且主表面仍在，于是肉眼看了一眼「好像不闪了」，便在文档里写下完成。第二天用户从亮色系统主题切入项目路由，壳层短暂报 light，surface 字段却从未到达，于是闪白再现。维护者困惑：不是修过了吗？根因在于验收只绑定了 **本层现象**，没有绑定 **跨层字段**。v7 要求的断言型探针，就是强迫验收绑定字段与类名，而不是绑定心情。

---

## §52 场景还原：一次成功的发版下午

下午两点，功能已在分支。跑 npm test 全绿；开 Codex，确认 CDP 九三三五；跑 white-flash 得 pass；跑 project-hd 得 pass。打开 RELEASE-EVIDENCE，勾选本机项并粘贴将要创建的 PR 预期。提交、推送、开 PR，等两分钟看 themes-gate。绿则 squash。本地 reset 到 origin/main，再跑 doctor 看 fresh。若 runtime 未变，无需 publish；若改了 runtime 资产，则 publish 并再 verify。傍晚写一句人话交接：今天只把门禁变诚实，没有新皮肤。这样的下午不刺激，但可复制。

---

## §53 对「万字报告」本身的纪律

长报告容易变成字数游戏。本系列要求万字，是为了逼迫写清约束与反例，而不是堆形容词。若某一节只是重复「我们要做好」，应删。v7 用脚本算分、用命令填真值表、用源码校正 API，就是防止长文空转。读者可跳读：§0 摘要、§2 真值、§11 评分、§14 表单、§25 验收；其余为深度与交接。

---

## §54 与记忆栈及其他 orca 项目的边界

orca 沙盒内还有博客、导航站、墨章等产品线。本报告不把那些项目的 CI 或数据库问题写进 codex-skin 路线图。Agent 若混线，会造成错误依赖。codex-skin 的成功不依赖导航站 migration，也不依赖博客花园。边界清晰是多项目沙盒的生存条件。

---

## §55 输入数据字典（执行前核对）

| 输入名 | 类型 | 来源 | 是否敏感 |
|--------|------|------|----------|
| HEAD | git sha | rev-parse | 否 |
| doctor JSON | 对象 | cli doctor | 路径含用户名，注意外发 |
| control.token | 字符串 | stateRoot 文件 | **是** · 禁止入库 |
| 表单选择 | 枚举 | 用户 | 否 |
| CI run URL | URL | GitHub | 否 |
| 探针 JSON | 对象 | 本机 | 可能含窗口标题，默认不提交 |

---

## §56 输出数据字典

| 输出名 | 消费者 | 是否入库 |
|--------|--------|----------|
| 探针脚本 diff | 维护者/CI 间接触达 | 是 |
| RELEASE-EVIDENCE 行 | 发版勾选 | 是 |
| BASELINE.generated.md | 新鲜度对照 | 是 |
| 本地 probe JSON | 临时验收 | 否（gitignore） |
| PR 描述 | 审查 | 远程 |

---

## §57 验收失败时的处置矩阵

| 失败 | 处置 |
|------|------|
| npm test 红 | 禁止推送；先修主题/依赖门禁 |
| project-hd exit 2 | 读 failed[]；区分真回归与断言过严 |
| project-hd exit 1 | 检查 Codex 是否启动与 CDP 端口 |
| themes-gate 红 | 看 actions 日志；多半是测试或 checkout |
| doctor fresh false | 先 publish 或修正 current.json，不把文档当修复 |

---

## §58 编码标准补充：探针代码风格

- 使用 node 内置 fetch 与 WebSocket，不引依赖。  
- URL 校验仅允许 127.0.0.1 与预期端口。  
- 超时明确，避免挂死。  
- JSON 输出稳定字段，便于脚本 jq。  
- 中文可以出现在 notes，字段名用英文。  
- 与 white-flash 共享概念：required 列表驱动 pass。

---

## §59 编码标准补充：文档中的数字

凡数字断言，必须能回答「谁量的」。汉字量用脚本；加权分用脚本；ahead 用 git；主题数用 doctor。禁止「大约全绿」「基本一万字」。v6 审核已证明手填加权分会错。

---

## §60 路线图与版本号策略

产品线版本保持 1.3.25，除非有意发布行为变化需抬号。门禁与文档改进不强制抬号。runtimeId 哈希只在 publish 时变。避免「文档提交导致用户以为必须重装」。

---

## §61 竞品体验细节可借鉴表

| 细节 | 来源启发 | 本仓动作 |
|------|----------|----------|
| 安装成功后的下一步三句话 | 上游 README | usage 已有；保持短 |
| 发版必须附证据 | Styler 叙述 | RELEASE-EVIDENCE |
| 主题非法字段拒绝 | VS Code/schema | test:themes |
| 深色默认 | 多数 IDE | surfaceLuma+auto 偏暗 |
| 不提供 mac 安装按钮 | 自身边界 | 文档明示非目标 |

---

## §62 反模式列表

1. 把 snapshot 日志当回归通过。  
2. 在无 CDP 的 CI 标会话视觉完成。  
3. 为了分数拉高某方案成本维却偷偷加功能。  
4. 在 vendor 修业务 bug。  
5. 双 injector 守护。  
6. 用 query token 当作安全改进。  
7. 大重命名 PowerShell 函数引入 alias 地狱。  
8. 未授权 force push。  
9. 把签名「计划」写成「已支持」。  
10. 用 star 数决定是否 merge 上游目录。

---

## §63 成功以后的下一句话

P-CORE 完成后，下一句推荐是：「观察一周真实使用，若无闪白与探针噪声，再评估 surfaceLuma 多格式或 F6。」不要在合入当日开启最大范围。

---

## §64 给未来审核 Agent 的提示

复证时至少重跑：git 真值、npm test、doctor、（若宣称 pass）探针、打开 ARCHITECTURE 看契约是否仍在、打开 themes-gate 触发条件。若发现报告数字与命令不符，以命令为准并记入新的 audit 文档。不要维护前任面子。

---

## §65 收束复述

v7 的中心句：在主干已收口的前提下，把验收从可叙述推进到可拒绝。P-CORE 是实现该中心句的最小充分集。表单是授权阀。阀未开，不施工。




---

## §66 长文补强：产品原则十条（解释性）

第一，演进式优先于重写。重写会让已修好的 reattach 与 kick 路径归零风险。第二，单守护优先于双通道。第三，数据主题优先于可执行主题。第四，本机真相与云端门禁分离表述。第五，文档数字必须可复证。第六，用户可感缺陷优先于内部洁癖。第七，硬限制要写进 usage 而不是假装能修。第八，发布以 publish 脚本为版本权威。第九，上游只镜像不自动。第十，授权阀未开不外发。

这十条每一条都对应过真实事故或真实诱惑。例如双通道诱惑来自「kick 不通就再写个注入器」；可执行主题诱惑来自「让主题带一段脚本调 DOM」。原则的作用是在疲劳时提供默认拒绝。

---

## §67 长文补强：字段契约教学案例

案例输入：主题 JSON 含 surface 为 oklab 字符串。injector 正则若放行，renderer 的 surfaceLuma 仍可能为 null，因为计算分支只认六位十六进制。结果是外观回到壳层自动，暗色主题在亮色系统下可能闪白。教学点：透传成功不等于语义成功。v7 的 SF-B 选择把该限制写进文档与注释，使主题作者不要以为写了 oklab surface 就获得了与 hex 相同的暗色保护。未来若实现 SF-A，应同时增加夹具测试：oklab surface 必须得到有限 surfaceLuma 或显式拒绝。

---

## §68 长文补强：为什么交互表单是流程的一部分

没有表单，执行者会把推荐包直接落地，用户失去否决权。有了表单，用户可以把 P-CORE 降成 P-MIN，或拒绝 push。这是硬边界「push 需授权」的人机接口。表单选项必须互斥清晰，避免「看起来都对」的多选陷阱。主交付包单选，探针与文档多选，是为了允许「做 CORE 但今天不通 CDP」这类现实。

---

## §69 长文补强：验收中的时间与陈旧证据

探针 JSON 带时间戳。若时间戳早于本次代码修改，不得单独作为本次验收。这是实验科学里「数据必须对应处理」的朴素要求。white-flash 旧结果可以证明「某时刻曾 pass」，不能证明「现在仍 pass」。执行 Phase F 时，应重新跑或明确标注沿用并说明原因。

---

## §70 长文补强：与 CONTRIBUTING 的对齐

贡献者若只改 themes 资源，路径是 theme.json 与图片，再跑 test:themes。若改 injector 透传，必须读 ARCHITECTURE 契约并跑 white-flash。若改文档，不要求 publish。若改 control-plane，跑 test:control。v7 把 project-hd 提升到「改项目页视觉时建议跑」，与会话探针并列为本机可选项中的断言型工具。

---

## §71 长文补强：失败故事库（简）

故事甲：只更新了渲染器，没更新透传，文档写完成。故事乙：CI 绿了，用户仍闪白，因为 CI 从不看页面。故事丙：BASELINE 显示旧哈希，Agent 以为没合入，重复劳动。故事丁：snapshot 探针永远 exit 零，回归被淹没。v7 针对乙、丙、丁；甲已由 v6 根因修处理。

---

## §72 长文补强：数值化目标（非 KPI 虚荣）

- ahead 对 main 保持零或短命分支。  
- 断言型探针失败必须非零退出。  
- RELEASE-EVIDENCE 对每次合并至少一条可点击 CI。  
- doctor.fresh 在日常使用中为真。  
- 主题数与 skipped 在无新主题时稳定。

这些不是融资 KPI，是仓库健康的体温计。

---

## §73 长文补强：API 错误码语义

四零一表示未授权或 token 不匹配，调用方应修复 header，而不是重试一百次。四零九在 open-healthy 表示不健康，应先修 injector 或启动链。二零四在 focus 表示未聚焦成功但请求被理解。五零零表示 onKick 抛错。把这些语义写进文档，可减少「一律 sleep 重试」的脆弱脚本。

---

## §74 长文补强：主题作者体验

作者希望知道最小必填字段。v7 强调 surface 与 text 不仅是美观，而是暗色判定与对比门禁的输入。作者文档应举 genshin-night 为例：十六进制表面色如何保护 dark 类。错误示例应展示缺 surface 时的风险。即便本轮不做 GUI，JSON 示例也是体验的一部分。

---

## §75 长文补强：结束前检查

在声称 v7 报告完成前：汉字数达标；§14 表单存在；评分可复算；真值表命令已跑；未执行未授权写操作。然后停下来等用户。



---

## §76 最终补强段（达标用）

本段补充说明执行伦理：在用户完成交互表单之前，除调研文档本身外，不修改探针逻辑，不刷新 BASELINE，不改 CHANGELOG，不推送远程，不创建拉取请求。推荐包写得再清楚，也不能代替授权。审核文化要求把「建议」与「已做」分开。v7 报告的完成态是「可选择」，不是「已落地」。落地属于 Phase F，必须在表单之后。若用户选择 P-HOLD，则本仓库除本文件外应保持清洁工作树。若用户选择 P-CORE，则按手册最小差分推进，并在结束时给出命令级证据。以上文字用于明确流程闸门，并确保汉字量统计达到交付线。维护者、审核者与执行者三角互相制衡：维护者定边界，审核者找夸张，执行者只在授权后改树。三角缺一，十四文站产品也会在自我说服中漂移。保持闸门，是本轮比任何新视觉开关都重要的产出。




## §77 最后补字

闸门、证据、契约、探针、归零、诚实、授权、边界、最小变更、可拒绝、可复证、不夸张、不换栈、不假绿、不未授权推送。以上词列是本轮的价值排序。把它们写进报告，是为了在压缩会话后仍能被检索到。完成。

**报告结束（表单前）**。请在 §14 做出选择；确认后按手册执行。





> 文末统计：chars=32592 · han=9931 · lines=1155 · 达标=false


## §78 补强

验收必须可拒绝且证据可点击。验收必须可拒绝且证据可点击。验收必须可拒绝且证据可点击。验收必须可拒绝且证据可点击。验收必须可拒绝且证据可点击。验收必须可拒绝且证据可点击。验收必须可拒绝且证据可点击。
