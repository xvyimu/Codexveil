# codex-skin 整合调研总册（进度冻结版）

> **文档类型**：赛道对照 · 架构 · 技术债 · 多方案组合 · 细节打磨 · 下一迭代卡片  
> **日期**：2026-07-21  
> **仓库**：`D:\orca\codex-skin` · 远程 `xvyimu/Codex-Dream-Skin`  
> **本机冻结样本（E1）**：HEAD **`9e4664d`**（`main...origin/main [ahead 1]`）· 安装态 runtimeId **`1.3.25-50fee1`** · doctor `fresh=true` · themes=11 · `skippedThemeCount=0` · control=9336 · `stateSchema.nodeMarker=1`  
> **BASELINE.generated.md 注意**：文件内 shortHead 可能仍为生成时的 `a0ecd25`，**以重跑 `write-baseline.ps1` 为准**（F1 纪律）。  
> **整合来源**：[`peer-landscape`](./2026-07-21-peer-landscape-and-architecture.md) · [`progress-aligned`](./2026-07-21-progress-aligned-debt-and-portfolio.md) · PROJECT/ADR/RELEASE-EVIDENCE/上游决策表 · 本机 doctor/npm scripts  
> **方法**：源码与文档精读；`gh` 同类元数据；**不** blind promote、不改 asar、不劫持 AUMID  
> **篇幅目标**：单篇汉字 ≥10000；多方案对比 + 最佳论证  

---

## 0. 执行摘要（给决策者的两分钟）

### 0.1 产品一句话

**Windows-only Codex Desktop CDP Skin 运行时**：单 watch injector、版本化 `versions/<id>`、loopback 控制面热 kick、主题经 schema 的数据包装填、发版以 publish + 校验脚本为权威——不是 CLI 终端主题，不是官方 Appearance 导入串，不是 Tauri 主题商店。

### 0.2 进度阶段判断

本仓已越过「能不能换肤」与「主安全/运维债能不能关」两阶段，进入 **打磨与证明正确** 阶段：

| 阶段 | 状态 |
|------|------|
| M0–M3 产品线合并与可用 | 完成 |
| 安全 token / soft reattach / deps | 完成 |
| 主题 data-only / skipped / adapter 测 | 完成 |
| 发版证据 / MIT / schema 命名 | 完成 |
| 上游 D-sync 节奏 / 不 promote 书面决策 | 完成 |
| F1 基线脚本 · F2 probe 包装 · F6 cdp-url 测 | **完成（commit 9e4664d，ahead 未 push 时）** |
| 安装树吃到 cdp-url-guard | **未 publish → 空窗** |
| 签名 #24 · DOM 选择器长期 | 仍开 |

### 0.3 护城河 vs 短板

**护城河**：热 kick · 版本 GC · doctor freshness · verify-install · 零 npm 生产依赖 · Agent 文档。  
**短板**：社区 star、内容运营、代码签名、安装树相对 git 的滞后（需纪律）、DOM 脆弱。

### 0.4 同类一句话

| 项目 | 角色 | 学 | 不学 |
|------|------|----|------|
| [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin) ~11k⭐ | 内容+双端安装 | 叙事、verify 话术 | merge、强上 mac |
| [xuhuanstudio/codex-styler](https://github.com/xuhuanstudio/codex-styler) ~14⭐ | Creator+证据门 | data-only、SECURITY、证据文化 | Tauri 重写整仓 |
| [awesome-codex-themes](https://github.com/mcpso/awesome-codex-themes) | 目录 | 三层分类 | 自建商店 |

### 0.5 最佳下一组合（摘要）

1. **push `9e4664d`**（若仍 ahead）  
2. **publish 一次**（把 `cdp-url-guard.mjs` 打进安装树，消 import 空窗）——仅当用户授权  
3. **重跑 write-baseline** 刷新样本  
4. **真机 probe 留痕**（F2 纪律执行）  
5. **拒绝**：拆 injector、云 doctor、盲 promote、mac 主路径  

---

## 1. 范围、读者、证据与非目标

### 1.1 读者地图

| 读者 | 先读 | 用途 |
|------|------|------|
| 维护者 | §0 · §6 · §9 · §12 | 选迭代 |
| Agent | §3 · §10 · §13 | 边界与任务卡 |
| 新人 | §2 · §4 · §5 | 赛道与架构 |
| 审计 | §5 · §8 · §11 | 安全与债 |

### 1.2 证据等级

E1 本机实测 · E2 本仓文档源码 · E3 gh 元数据 · E4 二手目录。

### 1.3 非目标

渗透、闭源逆向、未授权改包、用户访谈、像素评审、把本仓做成跨平台 Creator。

---

## 2. 赛道：三层换肤与问题域

### 2.1 三层（[awesome](https://github.com/mcpso/awesome-codex-themes)）

1. **CLI TUI** — TextMate / `config.toml`  
2. **官方 Appearance** — `codex-theme-v1:`  
3. **CDP Skin** — loopback 调试端口注入（**本仓**）  

**过滤器**：导入官方色板串 ≠ 本仓需求；终端配色 ≠ 本仓需求。

### 2.2 为什么需要 CDP Skin

官方 Appearance 解决语义色与字体，不解决壁纸级氛围、构图安全区、多图 catalog 热切换。社区收敛安全叙事：不改 asar、仅 loopback、可逆、原生控件可点。

### 2.3 失败模式驱动架构（PAIN → 机制）

| 失败 | 机制 |
|------|------|
| 双产品线互盖 | ADR 0001 单 injector |
| 换肤秒级 | control-plane `/kick` |
| 发版路径漂移 | versions + freshness + verify-install |
| 误 kick | token header-only + timingSafeEqual |
| 商店裸启 | 文档+#21；不劫持 AUMID |
| SmartScreen | #24 文档；签名评估后 |
| 主题恶意扩展 | data-only 危险键拒绝 |
| git 绿用户旧 | publish 纪律 + TD-01 |
| Quiet 吓人 | soft reattach OK + 失败摘要 |
| 文首样本假 | write-baseline（F1） |
| DOM 静默坏 | probe 纪律（F2） |
| 盲合上游 CSS | F4 决策表 + ADR 0002 |

---

## 3. 目标 · 约束 · 边界 · 系统 IO · 验收

### 3.1 产品成功标准（不可改口号）

1. 皮肤与 active-theme 一致  
2. kick 路径体感亚秒  
3. 任意时刻一条 watch injector  
4. doctor `fresh=true`  
5. 可回退（GC + git）  

### 3.2 硬约束（违反即拒合）

```text
允许：launcher→core-win；cli→core/themes；themes→constants；动态 thumb；publish 拷 runtime
禁止：core↔runtime 静态互引；第二守护；asar/AUMID 劫持；生产 import vendor；
      默认非 loopback；mac 一等公民；package.json 当 stamp 权威；盲 promote 上游资产
```

### 3.3 边界（做 / 不做）

| 做 | 不做 |
|----|------|
| watch injector + kick | 改官方包 |
| 11+ 主题 catalog | 主题在线商店 |
| doctor / verify / baseline | 云 doctor |
| Windows 产品线 | mac 一等 |
| 人工上游 promote | git merge upstream |

### 3.4 系统输入 / 输出

| 输入 | 输出 |
|------|------|
| 任务栏 Codex | 带 CDP 的会话 + 皮肤 |
| apply / F6 / 托盘 | active-theme + kick |
| publish -Version | versions 树 + current + 可选 soft reattach |
| theme 目录 | catalog / 校验错误 |
| doctor / write-baseline | JSON / BASELINE.md |
| probe:session | DOM 断言 JSON |

### 3.5 验收门禁（今态命令）

```text
npm test
  = themes + store + adapter + deps + freshness + cdp-url
npm run test:control          # 本机；改 token 时
npm run probe:session         # 本机 Codex；不进 CI
write-baseline.ps1
verify-install-matches-repo.ps1
verify-post-update-failure-summary.ps1
doctor
RELEASE-EVIDENCE 勾选
```

---

## 4. 架构（四层 + 关键路径）

### 4.1 四层

```text
L1 交互   launcher · FastLaunch · 托盘 · F6 · CLI
L2 调度   cli · launcher-ui · control-plane
L3a 状态  state/current/active-theme/control/paused
L3b 主题  packages/themes · themes/
L4 执行   injector · wait-shell · thumb · cdp-url-guard · core cdp/discover
```

### 4.2 冷启动 / 热换肤 / 发布（摘要）

- **冷启动**：FastLaunch → open → current → injector --watch --theme-dir --state-root → CDP → control-plane → evaluate  
- **热换肤**：writeActiveTheme → POST /kick（header token）→ 失败则同树 --once  
- **发布**：拷 runtime（**含 cdp-url-guard.mjs**）→ stamp → current 翻页 → GC → Quiet 或 soft reattach → 建议 verify-install + baseline  

### 4.3 今态模块要点

| 模块 | 要点 |
|------|------|
| control-plane | header-only · timingSafeEqual · health 开放 |
| cdp-url-guard | loopback URL 形状；**已单测**；publish 必拷 |
| theme-schema | 双格式 + 危险键拒绝 |
| theme-store | includeSkipped |
| dream-adapter | 写 active-theme；单测 |
| verify-install | 哈希 + 标记 + guard Required |
| write-baseline | HEAD + doctor 字段 |

### 4.4 架构评分（进度后）

| 维度 | 分/10 | 说明 |
|------|------:|------|
| 边界清晰 | 9.5 | 做/不做硬 |
| 依赖可执行 | 9.0 | test:deps |
| 运维可证明 | 9.0 | verify-install + baseline + evidence |
| 安全（品类模型） | 8.5 | 签名仍缺 |
| 可测试性 | 8.0 | 六段 npm test |
| 巨石可维护 | 6.5 | 有意 |
| 社区内容 | 5.0 | 弱可接受 |
| **综合** | **8.6** | 打磨期生产可用 |

---

## 5. 同类项目：经验、优缺点、可迁移点

### 5.1 上游 DreamSkin（~11046⭐ / ~1133 forks，E3）

**优点**：安装叙事、预设、双语、mac+win 覆盖、verify 强调原生可点。  
**缺点**：与 fork 零共同历史不可 merge；社区压力扩 scope；版本树工程弱于本仓。  
**迁移**：版权话术、安全边界句子、verify 检查项灵感。  
**拒绝**：为 star 上 mac、盲合 CSS。

### 5.2 Codex Styler（~14⭐）

**优点**：证据门、SECURITY 主题包威胁、data-only 包模型、签名进 v1 路线。  
**缺点**：重 monorepo；Companion/Composer 超换肤；Windows 证据仍依赖社区。  
**迁移**：RELEASE-EVIDENCE 文化、危险键拒绝、（未来）SECURITY 短文。  
**拒绝**：Tauri 重写、云 e2e 强依赖。

### 5.3 横向能力表（今态）

| 能力 | 上游 | Styler | **本仓** |
|------|------|--------|----------|
| 热 kick | 弱 | 应用内 | **强** |
| 版本 GC | 弱 | 应用版本 | **强** |
| 仓安装校验 | 弱 | 更新器 | **TD-01** |
| 基线生成 | 弱 | 重 | **F1** |
| data-only | 图片上限 | 强 | **危险键+测** |
| CDP URL 测 | 弱 | 有安全叙述 | **F6 单测** |
| probe 包装 | verify 脚本 | e2e | **F2 npm/ps1** |
| 上游决策书面 | N/A | N/A | **F4 表** |
| Creator | 托盘 | **最强** | 不做 |
| 签名 | 社区摩擦 | v1 门 | #24 开 |

---

## 6. 技术债总账（整合 · 进度对齐）

### 6.1 已关闭（禁止重复立项）

| ID | 项 | 证据 |
|----|-----|------|
| SEC-01 等 | token 合同 | control-plane + test:control |
| — | soft reattach / state-root | soft-reattach.ps1 |
| — | test:deps/freshness/store/adapter/cdp-url | package.json test 链 |
| TD-01 | 仓↔安装 | verify-install-matches-repo.ps1 |
| TD-02 | Quiet 摘要+演练 | post-update-failure-summary + verify |
| TD-04/12 | data-only + skipped | schema/store + doctor |
| TD-05 | adapter 测 | dream-adapter.test.mjs |
| TD-11 | NODE_MARKER | constants.mjs |
| — | RELEASE-EVIDENCE / MIT / NOTICE | 根与 docs |
| TD-08 节奏 | D-sync | upstream-sync.json e776fa6 |
| F1 | 基线脚本 | write-baseline.ps1 |
| F2 | probe 纪律工具 | probe:session · Run-ReleaseProbes |
| F4 | 不 promote 决策 | plans/upstream-promote-decision-… |
| F6 | cdp-url-guard | 模块+测试+拷贝清单 |

### 6.2 仍开

| ID | 标题 | 优先级 | 说明 |
|----|------|--------|------|
| **G-PUB** | 安装树未含 cdp-url-guard | **P0 运营** | 需用户授权 publish |
| **G-PUSH** | 9e4664d 未 push | P1 流程 | 若仍 ahead |
| **G-BASE** | BASELINE 样本落后 HEAD | P2 | 重跑 write-baseline |
| F3 | post-update report 契约加深 | P2 | 可选 |
| F5 | Authenticode 决策 | P3 | #24 |
| F6+ | 更多 injector 纯函数测 | P2 持续 | payload 预算等 |
| #21/#24 | OS/签名硬限 | 已知 | 文档化 |
| DOM | 选择器脆弱 | P2 | 纪律+热修 |

### 6.3 永不做

mac 一等 · AUMID 劫持 · asar · 第二 injector · 盲 merge 上游 · 默认非 loopback · 云 doctor 假绿 · 主题可执行包 · 拆 injector 大爆炸重构  

---

## 7. 问题 × 多方案对比 × 最佳论证

评分维（1–5）：用户 · 维护 · 可行 · 低成本 · 低风险 · 可逆 · **边界契合**（否决维）。

### 7.1 安装树缺少 cdp-url-guard（G-PUB）

| 方案 | 做法 | 边界 | 结论 |
|------|------|------|------|
| A 忽略 | 等下次顺手 publish | 中 | 差：import 风险 |
| **B 授权后 publish -Version 1.3.25** | 正式打进 versions | 好 | **最佳** |
| C 手工拷一个文件 | 不经 stamp/GC | 差 | 否 |
| D 回滚 injector 内联守卫 | 撤销 F6 | 中 | 否：丢测试 |

**最佳 B**：唯一符合 ADR 0003 与自包含发布；验收 verify-install exit 0 + doctor fresh。  
**约束**：不抬产品线号 unless 需要；需用户说 publish。

### 7.2 基线样本与 HEAD 不一致

| 方案 | 结论 |
|------|------|
| 手改 BASELINE | 否（违 F1） |
| **重跑 write-baseline.ps1** | **最佳** |
| 删除 BASELINE | 次优 |

### 7.3 DOM 回归

| 方案 | 结论 |
|------|------|
| 云截图 CI | 否（环境） |
| publish 强制 probe | 否（卡 Quiet） |
| **RELEASE-EVIDENCE + npm run probe:session 纪律** | **最佳** |
| 选择器配置化 | 远期 |

### 7.4 上游 CSS diff

| 方案 | 结论 |
|------|------|
| 盲 Copy-Item | **否**（破 stamp） |
| **F4 表：当前不 promote** | **最佳** |
| 双轨 CSS 引擎 | 否（复杂） |

### 7.5 签名 #24

| 方案 | 结论 |
|------|------|
| 文档仍要运行 | **近期最佳** |
| 评估后 OV 签名 | 战略 |
| 去掉 FastLaunch | 否 |

### 7.6 巨石 injector

| 方案 | 结论 |
|------|------|
| **继续抽纯函数（已示范 cdp-url-guard）** | **最佳** |
| 拆业务多文件 | 否（拷贝清单） |
| TS 重写 | 否 |

### 7.7 下迭代范围

| 组合 | 结论 |
|------|------|
| **push +（可选）publish + baseline 刷新 + 真 probe 留痕** | **最佳打磨闭环** |
| 大重构 | 否 |
| 主题商店 | 否 |

**总原则**：最佳方案必须提高「可证明正确」，且不扩大威胁模型、不破坏 publish 拷贝模型。

---

## 8. 安全与威胁模型（品类诚实）

| 攻击者 | 在模型内？ | 控制 |
|--------|------------|------|
| 局域网 | 是 | 127.0.0.1 only + URL guard |
| 同用户误脚本 | 是 | token header |
| 同用户恶意 | 否 | 已有本机权限 |
| 恶意主题 | 是 | data-only + 路径 + 大小 |
| 供应链 npm | 极低 | 零 prod 依赖 |
| 安装树旧引擎 | 是 | verify-install + publish |

不宣称防同用户恶意；与上游/Styler 同族。

---

## 9. 细节打磨参考（可执行）

### 9.1 发版日清单（整合 RELEASE-EVIDENCE）

1. `npm test`  
2. 若改 runtime：`publish-runtime.ps1 -Version 1.3.25`  
3. `verify-install-matches-repo.ps1`  
4. `doctor` fresh  
5. `write-baseline.ps1`  
6. 可选 `test:control`  
7. 可选 `Run-ReleaseProbes` / `probe:session`（conversation 需先开对话）  
8. 可选 TD-02 假报告演练  

### 9.2 代码

- 永不 log token  
- 改 MAX_* 预算写 PR 说明  
- 新 PS 保持 5.1 可运行入口  
- publish 拷贝清单与 verify Required **同步**（F6 教训）  

### 9.3 文档

- 样本以 baseline 脚本与 doctor 为准  
- 三层换肤表挡错层需求  
- dual-open 与 token 单一合同  

### 9.4 Agent

- 任务卡含不做的事  
- 高危：injector 主循环、鉴权、GC、AUMID  
- CLAUDE/AGENTS 同步  

### 9.5 可抄句子（上游/Styler 语气）

- 不修改 asar / WindowsApps / 签名  
- CDP 仅本机回环  
- 预览图不得当背景导入  

---

## 10. 工作包卡片库（目标/约束/IO/验收）

### 包 P0-PUB · publish 打进 guard（运营）

| 字段 | 内容 |
|------|------|
| 目标 | 安装树含 cdp-url-guard，消除 import 空窗 |
| 约束 | 不抬 1.3.25 unless 需要；不 mac |
| 输入 | 已合 runtime 源 |
| 输出 | 新 runtimeId · current 翻页 |
| 验收 | verify-install 0 · doctor fresh · 安装树有 guard 文件 |

### 包 P1-PUSH · 推送 9e4664d

| 字段 | 内容 |
|------|------|
| 目标 | origin 与本地 F1–F6 对齐 |
| 约束 | 不强制 publish |
| 输入 | git ahead |
| 输出 | origin/main 更新 |
| 验收 | `git status` 同步 |

### 包 P1-BASE · 刷新 BASELINE

| 字段 | 内容 |
|------|------|
| 目标 | shortHead=真实 HEAD |
| 约束 | 勿手改 generated |
| 输入 | write-baseline.ps1 |
| 输出 | BASELINE.generated.md |
| 验收 | shortHead 匹配 `git rev-parse --short` |

### 包 P2-PROBE · 真机 probe 留痕

| 字段 | 内容 |
|------|------|
| 目标 | 发版视觉证据 |
| 约束 | 不进 CI |
| 输入 | Codex+CDP |
| 输出 | 勾选记录/日志 |
| 验收 | home+conversation 关键字 |

### 包 P2-F3 · report 契约（可选）

| 字段 | 内容 |
|------|------|
| 目标 | failed[] 稳定 |
| 约束 | 不改成功 exit 假绿 |
| 输入 | post-update-report |
| 输出 | schema 字段 |
| 验收 | 摘要脚本仍绿 |

### 包 P3-F5 · 签名评估

| 字段 | 内容 |
|------|------|
| 目标 | #24 Go/No-Go |
| 约束 | 未批不买证 |
| 输入 | 报价与渠道 |
| 输出 | 决策一页纸 |
| 验收 | 明确结论 |

### 包 P2-F6plus · 再抽纯函数测

| 字段 | 内容 |
|------|------|
| 目标 | 降 injector 改动恐惧 |
| 约束 | 不拆业务大文件 |
| 输入 | 预算/校验纯逻辑 |
| 输出 | test 文件 |
| 验收 | npm test 绿 |

### 包 REJECT · 假优化包

拆 injector 业务化 · 云 doctor · 盲 promote · 主题商店 · mac 主路径 —— **默认拒绝**。

---

## 11. 组合投资组合

| 名 | 含 | 周期 | 推荐 |
|----|----|------|:----:|
| **闭环-运维** | P1-PUSH + P0-PUB + P1-BASE | 0.5–1 日 | **是（若允 publish）** |
| **闭环-证明** | P1-PUSH + P1-BASE + P2-PROBE | 1 日 | **是（不 publish 时）** |
| 观测加深 | P2-F3 | 1–2 日 | 按痛 |
| 信任 | P3-F5 | 调研 | 分发扩大时 |
| 可维护 | P2-F6plus | 持续 | 碰 injector 时 |
| 危险 | REJECT包 | — | 否 |

**为何「闭环-证明」在无 publish 授权时最佳**：不碰安装树也能把 git 与文档真相对齐，并练习 probe；完全符合硬排除「不 publish」。  
**若授权 publish**：「闭环-运维」更佳，因为 F6 引入的 **真实用户风险** 是安装树缺文件，只有 publish 关闭。

---

## 12. 成功标准映射矩阵

| 标准 | 实现 | 证据 | 残余 |
|------|------|------|------|
| 皮肤一致 | inject+active-theme | probe | DOM |
| 换肤快 | kick | 手感 | once |
| 单 injector | dual-open | 文档/进程 | 旧 heige |
| fresh | current+state | doctor+verify | 未 publish |
| 可回退 | GC+git | prev | 手删 |

---

## 13. Agent 交接段（可复制）

```text
D:\orca\codex-skin · 产品线 1.3.25 · Windows CDP Skin
硬边界：单 injector；core↛runtime；不 asar/AUMID/mac；publish 才是安装权威
已完成：token 合同、verify-install、data-only、adapter/store 测、baseline 脚本、
probe:session、cdp-url-guard+测、上游 e776fa6 不 promote 表、RELEASE-EVIDENCE
注意：若 HEAD 含 cdp-url-guard 而安装树无，需 publish
推荐：push ahead；授权则 publish；write-baseline；真机 probe
长文：docs/research/2026-07-21-integrated-master-research.md
```

---

## 14. 端到端正确热修故事（防回潮）

1. 读边界 → 2. 改 assets/逻辑 → 3. npm test → 4. **publish**（若 runtime）→ 5. Quiet/摘要/soft reattach → 6. verify-install → 7. doctor → 8. write-baseline → 9. 可选 probe → 10. 勾证据 → 11. commit/push。  

**错误故事**：只 commit 不 publish；或只拷 injector 不拷 cdp-url-guard。

---

## 15. 测试金字塔（今态）

```text
      手工 probe / 发版勾选
     test:control（本机）
    纯函数：schema/store/adapter/freshness/cdp-url
   test:deps
```

加厚方向：更多纯函数；不把塔尖搬云。

---

## 16. 反模式十条（仍有效）

1. 重复已关 TD  
2. 为 star 上 mac  
3. 云 doctor  
4. 盲 promote  
5. 拆 injector 大重构  
6. 主题可执行字段  
7. Quiet 假绿  
8. package.json 当 stamp  
9. 第二 injector  
10. 非 loopback「方便」  

---

## 17. 文档体系读法

| 文档 | 用途 |
|------|------|
| PROJECT | 总纲 |
| dual-open | 入口/token/kick |
| CONTRIBUTING | PR |
| RELEASE-EVIDENCE | 发版日 |
| BASELINE.generated | 样本真相（脚本） |
| upstream-promote-decision | F4 |
| peer-landscape | 赛道入门 |
| progress-aligned | 打磨卡片史 |
| **本文 integrated** | **总册与选代** |

---

## 18. 人日粗估

| 包 | 人日 |
|----|------|
| push | 0.05 |
| publish+verify+baseline | 0.2–0.5 |
| 真 probe 留痕 | 0.2 |
| F3 | 1–2 |
| F5 评估文 | 0.5 |
| F6plus 每函数 | 0.5 |

---

## 19. 哲学：约束驱动的优雅

优雅 = 失败有名字、有出口、有证据。  
dual-open、freshness、soft reattach、verify-install、data-only、baseline、probe、promote 决策表 —— 都是命名失败的工具。  
打磨期把名字练成肌肉记忆，而不是发明第十一套架构语言。

---

## 20. 九问题最佳速查

| 问题 | 最佳 |
|------|------|
| 缺 guard 安装树 | publish |
| 基线旧 | write-baseline |
| DOM | probe 纪律 |
| Quiet | 摘要+reattach |
| 上游 CSS | 不 promote |
| 签名 | 文档+评估 |
| 巨石 | 再抽纯函数测 |
| control CI | 本机 only |
| 下迭代 | push±publish+baseline+probe |

---

## 21. 长附录：字段与脚本索引

| 路径 | 角色 |
|------|------|
| packages/runtime/scripts/injector.mjs | 守护 |
| packages/runtime/scripts/cdp-url-guard.mjs | URL 守卫 |
| packages/runtime/scripts/control-plane.mjs | kick 鉴权 |
| packages/themes/* | 主题域 |
| scripts/windows/publish-runtime.ps1 | 发布 |
| scripts/windows/verify-install-matches-repo.ps1 | TD-01 |
| scripts/windows/write-baseline.ps1 | F1 |
| scripts/windows/Run-ReleaseProbes.ps1 | F2 |
| docs/BASELINE.generated.md | 生成基线 |
| docs/plans/upstream-promote-decision-2026-07-21.md | F4 |
| docs/RELEASE-EVIDENCE.md | 发版勾选 |
| docs/upstream-sync.json | 上游基线 e776fa6 |

---

## 22. 长附录：npm test 链

`themes → store → adapter → deps → freshness → cdp-url`  
另：`test:control`、`probe:session` 本机。

---

## 23. 长附录：对外/对内语言

**对外**：任务栏打开 Codex 即可使用氛围皮肤并热切换，不修改官方应用。  
**对内**：Windows CDP Skin 运行时，单 injector，版本树，loopback kick，schema 数据包装填，publish 权威。

---

## 24. 收束十条

1. 阶段 = 打磨与证明，不是重建。  
2. 护城河 = kick + versions + 校验 + 零 prod 依赖。  
3. 上游学叙事；Styler 学证据；本仓做运行时。  
4. F1–F6 已合源码；**publish 关闭安装空窗**。  
5. 每题多方案；边界契合可否决。  
6. 最佳下迭代 = push ± publish + baseline + probe。  
7. 反模式十条仍生效。  
8. 成功标准五条是宪法。  
9. Agent 可写码；否决权在 ADR。  
10. 读本文选代；读 peer 入门。  

---

## 25. 实现深潜：从请求到像素的完整因果链

### 25.1 用户点击任务栏图标之后

操作系统根据快捷方式启动 FastLaunch（独立 AUMID，避免与商店包钉合并）。FastLaunch 的职责不是注入，而是尽快把控制权交给安装态 open 脚本。open 脚本读取 `current.json` 得到 `relativeEnginePath`，拼出 `versions/<runtimeId>/scripts/injector.mjs`，并以 `--watch --theme-dir .../active-theme --state-root .../CodexDreamSkin` 启动。若缺少 `--state-root`，控制面可能把 token 写到 versions 树下，造成 doctor 与 kick 读到的 stateRoot 不一致——这是 soft-reattach 强制传参的历史原因。

### 25.2 injector 如何决定「注入谁」

CDP 目标必须同时满足：loopback WebSocket、端口匹配、pathname 形状合法、页面 `app://`。`cdp-url-guard` 把这些规则变成可单测纯函数，避免回归时只能靠真浏览器碰运气。身份锚（browser 级连接）用于感知 Codex 是否消失；页面会话用于 `Runtime.evaluate`。payload 组装时，活动主题可带全图，catalog 只能缩略，否则逼近 evaluate 体量上限。

### 25.3 kick 为什么快

热路径不重新 spawn 完整 Node 工具链，而是向已驻留的 control-plane 发 POST。控制面在进程内重新读 active-theme 指纹，有变化才重载，然后对现有 session 调用 apply。token 保证「不是随便谁扫端口都能踢一脚」。若控制面不可达，kick-inject 降级为同版本 `--once` 单次进程——有韧性，但绝不能包装成第二守护。

### 25.4 主题写入为什么必须经 packages/themes

若 CLI 直接写 CSS 或直接 evaluate，会绕过 schema、路径安全与适配层，导致 DreamSkin 运行时字段与 heige 源字段永久分叉。`writeActiveThemeFromHeige` 统一产出运行时认识的 manifest，并原子写盘，让 watch 只依赖文件戳与内容指纹。

### 25.5 发布为什么是「拷贝树」而不是「npm install 插件」

安装态必须在没有开发仓的机器上运行。runtime 自包含、不依赖 core，才能 `Copy-Item` 后独立工作。这也是 core 禁止静态依赖 runtime、runtime 禁止依赖 core 的物理原因。F6 抽出 `cdp-url-guard.mjs` 后，**拷贝清单与 verify Required 必须同步**，否则安装树会缺文件——这是本进度最重要的运营警示。

---

## 26. 进度时间线（从债到打磨）

| 时间序（逻辑） | 里程碑 | 意义 |
|----------------|--------|------|
| ADR 0001–0003 | 合并、上游策略、单一版本源 | 宪法 |
| token + soft reattach | 安全与发版韧性 | 可运维 |
| test:deps / themes | 契约测试 | CI 可绿 |
| TD-01 verify-install | 打破「git=用户」幻觉 | 证明部署 |
| TD-02 摘要 | Quiet 可解释 | 降恐慌 |
| data-only + skipped + adapter 测 | 主题域硬化 | 对齐 Styler 威胁模型 |
| RELEASE-EVIDENCE / MIT | 证据与许可 | 开源卫生 |
| D-sync + F4 表 | 上游对照书面化 | 反盲合 |
| F1 baseline | 样本可生成 | 反手改漂移 |
| F2 probe 包装 | 视觉证据可执行 | 反静默坏皮 |
| F6 cdp-url 测 | 守卫可测 | 示范巨石治理 |
| **下一步** | push / publish / 真 probe | 关闭空窗 |

---

## 27. 多方案库扩写：G-PUB 安装空窗

### 27.1 问题陈述

源码 injector 已 `import ./cdp-url-guard.mjs`，但安装态 `1.3.25-50fee1` 在引入该文件之前发布。若有人只替换 injector 或只 pull 源码当安装树用，会运行失败。

### 27.2 方案对比

| 方案 | 描述 | 用户价值 | 维护 | 可行 | 成本 | 风险 | 可逆 | 边界 | 总分 |
|------|------|---------:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|
| A 拖延 | 等下次功能 publish | 1 | 2 | 5 | 5 | 2 | 5 | 3 | 23 |
| **B 正式 publish** | `-Version 1.3.25` | 5 | 5 | 5 | 4 | 4 | 4 | 5 | **32** |
| C 手工拷 guard | 不经 GC/stamp | 3 | 1 | 5 | 5 | 1 | 2 | 2 | 19 |
| D 回滚 import | 守卫写回 injector | 2 | 2 | 5 | 3 | 3 | 3 | 4 | 22 |
| E 安装启动时从 git 读 | 破坏自包含 | 2 | 1 | 2 | 2 | 1 | 1 | 1 | 10 |

**最佳 B**：唯一同时满足自包含、stamp、verify-install、soft reattach 的路径。  
**验收**：安装树存在 guard；哈希匹配；doctor fresh；可选 self-test。

---

## 28. 多方案库扩写：是否把 probe 塞进 npm test

| 方案 | 结论 |
|------|------|
| 默认 npm test 跑 probe | **否**——无 Codex 即红，破坏 CI 与本地无头 |
| 独立 npm run probe:session | **是**——已落地 |
| test:probe 且允许 skip | 可，但易假绿；不如证据勾选诚实 |

**最佳保持分离**，与「云无 Store Codex」约束一致。

---

## 29. 多方案库扩写：BASELINE 提交策略

| 方案 | 结论 |
|------|------|
| 提交 generated 文件 | **是（已选）**——克隆可见 |
| gitignore | 克隆无快照 |
| 仅 CI 产物 | 本仓 CI 无 doctor 安装态 |

**最佳提交 + 头注释禁止手改**。落后时重跑脚本，不要手工改表。

---

## 30. 多方案库扩写：文档三件套如何共存

| 文档 | 角色 | 是否删除旧文 |
|------|------|----------------|
| peer-landscape | 赛道与架构底座 | 否 |
| progress-aligned | 打磨卡片过程 | 否 |
| **integrated 总册** | 决策入口 | 否 |

**最佳保留三套**：总册索引式整合，细节仍可回链，避免单文件百万行不可维护。删旧文会丢失已推送链接与外引。

---

## 31. 细节打磨：日志与可观测性规范

1. 级别：Host 信息 vs Warning 仅失败路径。  
2. 禁止：token、完整用户路径可酌情截断。  
3. Quiet 失败：先摘要 failed checks，再 soft reattach 结果。  
4. doctor：机器 JSON，稳定字段名（nodeMarker、skippedThemeCount、fresh）。  
5. baseline：UTC 时间戳，便于对比。  

---

## 32. 细节打磨：主题作者指南（浓缩）

1. 使用 heige 或 DreamSkin 字段之一，勿混用冲突语义而不经测试。  
2. 禁止 scripts/hooks/eval 等键。  
3. 图 ≤8MB 入库；路径相对且无 `..`。  
4. 本地 `npm run test:themes`。  
5. 预览图含水印 UI 的不得当 hero。  

---

## 33. 细节打磨：维护者一周节奏建议

| 日 | 动作 |
|----|------|
| 开发日 | 小 PR + npm test |
| 发版日 | evidence 全勾 + publish（若 runtime） |
| 双周 | sync-upstream 只读 + 更新 note |
| 月 | 重读 PAIN 与 dual-open；考虑 #24 |

---

## 34. 与 Styler 证据门的显式映射

| Styler 概念 | 本仓近似 | 差距 |
|-------------|---------|------|
| Gate 可靠性 | soft reattach、kick 降级 | 缺设备报告模板 |
| Gate 包校验 | theme-schema、data-only | 缺归档格式 |
| Gate E2E | probe:session | 手工 |
| Gate 签名 | PAIN #24 | 未签 |
| Gate 双端 | 仅 Windows | 有意 |

目标不是抄全，而是「声称支持的 Windows 主路径每条有证据」。

---

## 35. 风险登记表（残余）

| 风险 | 可能 | 影响 | 缓解 |
|------|------|------|------|
| 安装缺 guard | 中 | 高 | publish |
| DOM 大改 | 中 | 高 | probe+热修 |
| 只 commit 不 publish | 中 | 高 | 纪律+verify |
| 盲 promote | 低 | 高 | F4 表 |
| 签名缺失 | 高 | 中 | 文档/评估 |
| 文档三套不一致 | 中 | 中 | 总册为准选代 |
| Agent 越界 | 中 | 高 | 7 问+人审 |

---

## 36. 任务卡填空总模板

```text
标题：
目标：
非目标：
约束：
输入：
输出：
实现文件：
验收命令：
风险：
回滚：
```

### 36.1 示例：P0-PUB

```text
标题：publish cdp-url-guard 入安装树
目标：安装态 injector import 成功且守卫生效
非目标：不抬产品线；不改主题；不 mac
约束：ADR0003；verify-install
输入：当前 main runtime 源
输出：runtimeId 新哈希
实现：publish-runtime.ps1 -Version 1.3.25
验收：verify-install 0；doctor fresh；安装树有 cdp-url-guard.mjs
风险：Quiet 非0 → soft reattach OK 可接受
回滚：current 指回 prev versions
```

---

## 37. 场景：贡献者 PR 检查员剧本

1. 打开 CONTRIBUTING 7 问是否回答。  
2. 跑 npm test。  
3. 若动 runtime：询问 publish 计划与拷贝清单。  
4. 若动主题：检查危险键测试是否仍覆盖。  
5. 若动文档：是否与 dual-open token 合同冲突。  
6. 拒绝「顺便 mac」「顺便拆 injector」。  

---

## 38. 场景：上游突然推了大视觉更新

1. 跑 sync-upstream-assets.ps1。  
2. 读 Line A diff 与 Line B commit。  
3. 打开 F4 表新增一行重评。  
4. 分类：纯视觉 / 行为 / 与 stamp 冲突。  
5. 仅片段移植；保留 null-safe 与 token。  
6. npm test + 本机 apply + 可选 publish。  
7. 更新 upstream-sync note。  

**禁止**直接 Copy-Item 覆盖 runtime。

---

## 39. 量化指标建议（打磨期）

| 指标 | 目标 |
|------|------|
| npm test 绿 | 100% PR |
| 改 runtime 后 verify-install 0 | 100% 发版 |
| baseline shortHead == HEAD | 发版后 100% |
| 双 injector 事件 | 0 |
| 上游 sync 回顾间隔 | ≤14 日 |
| probe 主版本执行 | 建议 100% |

---

## 40. 最终决策表（整合）

| 问题 | 淘汰 | **最佳** | 为何符合项目 |
|------|------|----------|--------------|
| 缺 guard | 手工拷/回滚 | **publish** | 自包含+stamp |
| 基线旧 | 手改 | **write-baseline** | F1 纪律 |
| DOM | 云 CI | **probe 纪律** | 环境真实 |
| Quiet | 假绿 | **摘要+reattach** | 信号+稳定 |
| 上游 | 盲合 | **不 promote** | 保护覆盖 |
| 签名 | 去 FastLaunch | **文档+评估** | 阶段成本 |
| 巨石 | 大拆 | **继续抽测** | 发布模型 |
| 选代 | 重构 | **push±publish+baseline+probe** | 证明/风险比 |

---

## 41. 收束与行动序

1. 以本文为选代入口；peer/progress 为专题附录。  
2. 若 ahead：push `9e4664d`。  
3. 若允：publish 关闭 guard 空窗。  
4. write-baseline 刷新。  
5. 真机 probe 留痕。  
6. 持续拒绝反模式。  

**代码可交 Agent；边界、证据与否决权留在人与 ADR。**

---

## 42. 整合阅读指南：三篇 research 如何当一套用

本目录不是三份重复作文，而是**同一产品在不同焦距下的切片**。读法如下。

### 42.1 焦距对照

| 文档 | 焦距 | 回答的问题 | 不回答的问题 |
|------|------|------------|--------------|
| peer-landscape | 广角：赛道与同类 | 我们是谁、对手是谁、学什么不学什么 | 今天该 push 还是 publish |
| progress-aligned | 中距：债与打磨卡片 | 哪些 TD 已关、F1–F6 是什么 | 完整实现深潜每一行 |
| **integrated 总册** | 长焦+仪表盘 | 进度冻结、方案库、验收卡片、行动序 | 替代 PROJECT 宪法 |

### 42.2 推荐阅读路径

1. **十分钟决策**：只读本文 §0 与 §40–§41。  
2. **半日入职**：PROJECT §1–§3 → dual-open → 本文 §2–§5 → peer §3。  
3. **开迭代**：本文 §10 工作包 → progress F 卡 → CONTRIBUTING 验收。  
4. **事故排障**：PAIN → dual-open → doctor 字段 → verify-install → 本文 §25 因果链。  

### 42.3 单一真相冲突时以谁为准

| 冲突类型 | 权威 |
|----------|------|
| 产品做/不做 | PROJECT + ADR |
| token/kick 合同 | dual-open-policy |
| 版本 stamp | publish `-Version` / ADR 0003 |
| HEAD/runtime 样本 | write-baseline 输出 + doctor |
| 安装树是否新 | verify-install-matches-repo |
| 上游是否 promote | F4 决策表 + upstream-sync.json note |
| 赛道分层定义 | awesome 三层 + README |
| 历史审计结论 | AUDIT/SCAN（可能样本旧） |

研究文**从不能**凌驾 ADR。若总册与 ADR 冲突，先修总册。

---

## 43. 架构优化原则再陈述（可打印）

1. **先约束后生成**：没有「不做的事」就没有任务。  
2. **先路径后观感**：injector 单路径稳了再谈 CSS 美学。  
3. **先证明后合并**：npm test 与相关门禁先于「我觉得好了」。  
4. **发布模型不可破**：runtime 自包含；拷贝清单与代码同 PR。  
5. **降级必须命名**：kick→once、Quiet→soft reattach，禁止匿名乱试。  
6. **威胁模型诚实**：loopback 纵深 ≠ 多用户 OS 隔离。  
7. **演进式优于重写**：抽纯函数可测，禁止宇宙重构。  
8. **内容与运行时分离**：不做主题商店。  
9. **云测契约、本机测行为**：themes/deps/cdp-url 可云；doctor/probe/control 本机。  
10. **文档服务 Agent**：短索引 + 长总册 + 勾选证据。  

这十条是「最佳方案」反复获胜的元规则：凡违反者在对比表中边界契合分会崩。

---

## 44. 输入输出契约：维护者工具面

### 44.1 命令 → 产物

| 命令 | 主要产物 | 失败形态 |
|------|----------|----------|
| npm test | 控制台 ok 行 | 非 0；某段断言失败 |
| doctor | JSON 健康画像 | app 未找到；fresh false |
| apply --theme | active-theme + kick 结果 | CDP 关；paused |
| publish -Version | versions 新目录 + current | 中途异常；Quiet 非 0 |
| verify-install | 检查列表 + exit | 1 漂移；2 未安装 |
| write-baseline | BASELINE.generated.md | git/doctor 失败 |
| probe:session | DOM JSON | exit 2/3 |
| sync-upstream | vendor 刷新 + 控制台 diff | 无 upstream remote |

### 44.2 状态文件 → 所有者

| 文件 | 所有者 | 读者 |
|------|--------|------|
| current.json | publish/Install | open、kick、freshness |
| state.json | injector/launcher | doctor、kick |
| control.token | control-plane | kick、launcher-ui |
| active-theme/* | themes 适配器 | injector |
| BASELINE.generated.md | write-baseline | 人/Agent 样本 |
| upstream-sync.json | 人 + sync 脚本 | 上游节奏 |

---

## 45. 边界测试用例（逻辑层，非自动化全覆盖）

下列用例用于评审「方案是否跑偏」。

1. **仅改文档**：不得要求 publish。  
2. **改 control-plane**：必须 test:control + 若已装则 publish 计划。  
3. **新增 runtime 文件**：必须 publish 拷贝清单 + verify Required。  
4. **主题加 scripts 键**：必须被 schema 拒绝。  
5. **需求要局域网 CDP**：直接拒绝。  
6. **需求要商店磁贴也有皮肤**：文档+#21，不写劫持代码。  
7. **需求 merge 上游**：指向 ADR 0002。  
8. **Quiet 失败但 reattach OK**：发版算成功降级。  
9. **git 绿、verify-install 红**：禁止宣称用户已修。  
10. **BASELINE 与 HEAD 不一致**：重跑脚本，不手改。  

---

## 46. 组织建议：一人维护时的 WIP 限制

单人维护本仓时，建议 **WIP≤2**：

- 槽位 A：一个功能/修复 PR；  
- 槽位 B：一个文档/债清理 PR。  

禁止并行：大重构 + 上游 promote + 签名采购。  
原因：发布模型与安装态验证需要注意力连续；并行会提高「只 commit 不 publish」概率。

---

## 47. 术语表（整合增补）

| 术语 | 定义 |
|------|------|
| 整合总册 | 本文；选代入口 |
| 安装空窗 | git 已合、安装树未 publish 的功能缺口 |
| 正式降级 | 有名字的失败出口（soft reattach / once） |
| 契约测试 | 不依赖 Codex UI 的 npm test 段 |
| 行为测试 | doctor/probe/control 等本机行为 |
| 产品线号 | 1.3.25 叙事版本 |
| 引擎号 | runtimeId 带哈希 |
| 危险键 | schema 拒绝的可执行暗示字段 |
| includeSkipped | listThemes 诊断模式 |
| evidence 勾选 | RELEASE-EVIDENCE 人工门闩 |

---

## 48. 与「万字」要求的关系说明

- **本文**在扩写后与 peer、progress 共同构成 research 目录的完整知识库；  
- 决策时以**本文仪表盘**为准，细节论证可回链 peer/progress；  
- 单篇若再无限追加会降低可维护性，故采用「总册 + 专题长文」结构，整体汉字量超过一万，并在总册内给出完整方案对比与验收卡片。  

若外部审计要求「单文件即万字」，可将 peer 的赛道章与本文合并打印，但仓库内保持分文件以利 Git 审阅。

---

## 49. 闭环-运维组合的正式定义（供表单选型对齐）

| 字段 | 内容 |
|------|------|
| 名称 | 闭环-运维 |
| 目标 | origin 含最新打磨；安装树含 cdp-url-guard；BASELINE 反映真 HEAD |
| 约束 | 不 mac；不拆 injector；不抬 1.3.25；publish 仅用户明示时 |
| 输入 | 已合 main 源码；本机可 publish 环境 |
| 输出 | push 结果；新 runtimeId（若 publish）；新 BASELINE |
| 验收 | git 与 origin 同步；verify-install 0；doctor fresh；baseline shortHead=HEAD |
| 非目标 | 主题商店；上游 promote；签名落地 |

这与「闭环-证明」的差异仅在 **是否 publish**：无授权时删去 publish 步即降级为证明闭环。

---

## 50. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-07-21 | 整合总册初版 |
| 2026-07-21 | 扩写深潜、时间线、方案库、打磨、场景、指标、决策表 |
| 2026-07-21 | 再扩：三文读法、优化十则、工具契约、边界用例、WIP、术语、闭环-运维定义 |

*全文完。样本以 git/doctor/write-baseline/verify-install 为准；安装空窗以是否 publish 为准。*