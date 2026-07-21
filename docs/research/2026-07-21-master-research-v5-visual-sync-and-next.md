# codex-skin 整合调研总册 v5（视觉闪白修后 · 远程同步与下一刀）

> **日期**：2026-07-21  
> **本地 HEAD**：`fa6151e` · **ahead origin 4** · 工作区干净  
> **origin 仍停**：`eff1170`（远程尚未含 U3/U4/B/闪白修）  
> **安装态**：runtimeId **`1.3.25-48a559`** · doctor `fresh=true` · injectorAlive · themes=11 · skipped=0  
> **关键提交**：`38c051c` U3/U4+对比度门 · `e01d0ef` 开项目不闪白 · `fa6151e` BASELINE  
> **前序**：v2 工程冻结 · v3 UX 库 · **v4 U3/U4 产品收口**（本文是 v4 之后的进度对齐续册）  
> **方法**：E1 本机 git/doctor/publish/apply · E2 仓 ADR/PROJECT/源码 · E3 同类公开仓；不改 asar、不 AUMID 劫持、不盲 promote  
> **篇幅**：可执行万字级（进度 + 五件套 + 方案评分 + 交互选代）  
> **读法**：选代 §0/§11/§18；五件套 §12–§16；执行 §19

---

## 0. 执行摘要（3 分钟）

### 0.1 一句话

**Windows-only Codex Desktop CDP Skin** 已完成「能运维 → 能感知换肤 → 开项目不闪白」的本机闭环；**当前最大缺口是远程可复现（ahead 4 未 push）** 与可选 **F6 真相复测**，不是新架构。

### 0.2 相对 v4 的 delta

| 域 | v4 当时 | **v5 现在** |
|----|---------|-------------|
| U3 换肤气泡 + prefs | 本机未 commit | **`38c051c` 已 commit** |
| U4 首次入口 | 收口未 commit | **同 commit 入库** |
| B text/surface ≥4.5 | 设计中 | **schema 硬门 + 11/11 过** |
| 开项目闪白 | 用户新报 | **`e01d0ef` 已修 + publish `48a559`** |
| 工作区 | 脏 | **干净** |
| origin | 同步 eff1170 | **本地 ahead 4 · 远程落后** |
| 安装 runtime | c44358 | **48a559 · fresh** |
| F6 窗内 toast | 待探 | **仍待 E1** |
| 盲 promote 上游 CSS | 否 | **维持否**（闪白用判定修，非整文件合） |

### 0.3 本机硬证据（E1）

```text
git:     fa6151e · main...origin/main [ahead 4] · clean
log:     fa6151e baseline · e01d0ef white-flash · a33b2c6 · 38c051c U3/U4+B
install: 1.3.25-48a559 · current.json 对齐
doctor:  fresh=true · injectorAlive · themeCount=11 · skipped=0
apply:   genshin-night kick ~42ms · feedbackQueued（U3 路径）
npm test: 全绿（含对比度夹具）
```

### 0.4 战略判断

| 阶段 | 状态 |
|------|------|
| 工程主债 / 安全 / 证据 | **完成** |
| 体验反馈 U3/U4 | **本地完成** |
| 主题可读机器门 B | **本地完成** |
| 视觉：开项目闪白 | **本地完成（待你手测确认）** |
| **远程交付** | **未 push · 他机不可复现** |
| F6 / U7 / 签名 / promote | 可选或 No-Go |

**结论**：默认下一刀是 **远程同步（push）** 或 **手测确认后 push**；次选 **F6(C)**；否决盲 promote、第二 injector、购证实施。

### 0.5 最佳下一组合（摘要）

| 组合 | 内容 | Σ 倾向 |
|------|------|--------|
| **P 远程交付** | `git push` ahead 4（明示） | **默认最高** |
| **V 视觉验收** | 手测开项目 + 记 RUN 一句 | 与 P 可并 |
| **C F6 对齐** | E1 probe cycleTheme/toast | 客诉时 |
| **仅观察** | 不 push 不改码 | 低用户价值 |
| **危险** | 盲合上游 CSS / Companion | 否 |

---

## 1. 范围、读者、证据、非目标

### 1.1 读者

维护者选代 · Agent 开工 · 新人 · 审计 · 产品。

### 1.2 证据等级

E1 本机 · E2 仓文档源码 · E3 gh 公开 · E4 推断。

### 1.3 非目标

改 asar · AUMID 劫持 · mac 一等 · 主题商店 · 云 doctor · 默认非 loopback · 盲 Copy-Item 上游 CSS · 未确认 push。

### 1.4 文档族谱

| 文 | 角色 |
|----|------|
| v2 | 工程四包冻结史 |
| v3 | UX/视觉方案库 |
| v4 | U3/U4 立项与 A+B 执行 |
| **v5（本文）** | **闪白修后进度 · 远程缺口 · 下一刀** |
| PROJECT/ADR/SECURITY | **硬约束 SSOT** |

---

## 2. 当前进度编写（以 git + 安装为准）

### 2.1 提交链（本地领先远程）

1. `38c051c` — feat(ux): U3/U4 feedback prefs + theme text/surface contrast gate  
2. `a33b2c6` — docs: BASELINE after U3/U4+B  
3. `e01d0ef` — fix(ui): stop white flash when opening projects  
4. `fa6151e` — docs: BASELINE after white-flash fix  

origin 仍在 `eff1170`：文档包 U1–U6 已在远程，**体验码与闪白修仅本地**。

### 2.2 产品线与安装

| 项 | 值 |
|----|-----|
| 产品线 | 1.3.25（未抬） |
| runtimeId | 1.3.25-48a559 |
| doctor fresh | true |
| themes | 11 · skipped 0 |

### 2.3 已关闭（勿重复当债）

工程：token header-only · soft reattach · verify-install · data-only · PROBE · SECURITY · 双 guard · U1–U6 文档。  
体验：U3 prefs/气球/CLI feedbackQueued · U4 first-run · B 对比度门。  
视觉：开项目闪白（surfaceLuma + 不清肤 + auto→dark）。

### 2.4 仍开

| ID | 项 | 严重度 |
|----|-----|--------|
| D-PUSH | ahead 4 未 push | **高（交付）** |
| D-HAND | 闪白手测确认 | 中 |
| D-F6 | cycleTheme/toast E1 | 中 |
| D-TRAY | 旧托盘进程可能无新菜单 | 低–中 |
| D-SIGN | SmartScreen | 决策 No-Go |
| D-PROMOTE | 上游 CSS | 维持不 promote |
| D-U7 | 性能模式 | 二期 |

### 2.5 闪白修技术摘要（E2）

`renderer-inject.js`：

- 读 `palette.surface` 算 surfaceLuma；≤0.45 → dark，≥0.62 → light  
- `appearance:auto` 无信号时 **return "dark"**（旧为 light）  
- 短暂无 `main`：**不 clearSkinDom**，防 native 白闪  
- 可注入 `--dream-text` / `--dream-secondary`；canvas/surface 仍走 dark/light token 族（保 color-mix，对齐上游 DreamSkin 结构）

**明确未做**：整文件 promote vendor CSS（ADR 0002）。

---

## 3. 目标 · 约束 · 边界 · 输入输出 · 验收

### 3.1 产品目标（不变）

1. 皮肤与 active-theme 一致  
2. kick 亚秒  
3. 单 watch injector  
4. fresh=true  
5. 可回退（versions + git）  

### 3.2 本阶段目标（v5）

6. **远程与本地叙事一致**（push 或明确分叉策略）  
7. **开项目主区不闪近白纸**（暗色主题）  
8. 换肤可感知且可关（U3）  
9. 主题 text/surface 机器可拒（B）  

### 3.3 硬约束 C1–C9

单 injector · core↔runtime 禁止互引 · 主题经 packages/themes · 版本认 publish · vendor 人工 promote · loopback only · 不改 asar/AUMID · 新 runtime 文件进 Copy-Item+verify · conversationCovered 诚实。

### 3.4 边界

| 做 | 不做 |
|----|------|
| CDP 氛围层 | 改商店包身份 |
| push 交付（确认后） | 未确认 push |
| F6 复测小补丁 | 第二 injector |
| 判定层视觉修 | 盲合上游整 CSS |

### 3.5 输入 / 输出

| 输入 | 输出 |
|------|------|
| 任务栏 Codex | open + watch + 可选 U4 |
| apply / 托盘切换 | active-theme + /kick + U3 气泡 |
| palette.surface | dark/light 类 |
| publish -Version | versions/\<id\> + current.json |
| git push（确认） | origin 含体验+闪白 |

### 3.6 验收模板

```powershell
cd D:\orca\codex-skin
git status -sb                    # clean；记 ahead
npm test
node packages/core/cli.mjs doctor # fresh · 48a559
# 手测：开/切项目 → 不闪白
# 可选：git push（仅用户明示）
# 可选：F6 是否 toast / cycleTheme
```

---

## 4. 同类项目经验（优缺点 · 可迁移）

### 4.1 三层换肤

CLI TUI · 官方 Appearance · **CDP Skin（本仓）**。学错层=浪费。

### 4.2 上游 Fei-Away/Codex-Dream-Skin（~11k⭐）

| 优 | 缺 | 本仓 |
|----|----|------|
| 叙事与预设、暗色氛围 token | 与本 fork 零共同历史 | **学视觉意图，不 merge** |
| 一页安装感 | versions/kick 弱 | 我们 versions+kick 强 |
| 社区内容 | 质量参差 | schema+B 门 |

**闪白启示**：上游默认也有 light token 族；暗色主题必须稳定挂在 **dream-theme-dark**。本仓用 surface 亮度钉死，比盲合 CSS 更安全。

### 4.3 codex-styler

| 优 | 缺 | 本仓 |
|----|----|------|
| Creator、证据门、data-only | 重、小众 | 证据轻量对齐；不做 IDE |

### 4.4 awesome-codex-themes

学三层分类；不学商店。

### 4.5 可迁移原则

可逆 · 不挡字 · 首触达清晰 · 失败可解释 · 主题=数据 · 仓≠安装态 · 诚实 OS 硬限 · **视觉修优先判定/状态机而非整文件合**。

---

## 5. 架构优化（维持四层 · 本轮增量）

### 5.1 四层

L1 交互 · L2 调度 · L3a 状态（+ui-prefs + first-run）· L3b 主题 · L4 runtime inject。

### 5.2 本轮架构增量

| 增量 | 层 | 原则 |
|------|-----|------|
| resolveAppearance / surfaceLuma | L4 | 数据驱动 dark/light |
| 无 main 保留帧 | L4 | 防路由闪白 |
| U3 prefs | L3a/L1 | 成功可关 |
| B 对比度 | L3b | 机器门 |

### 5.3 优化建议排序

| 优先级 | 建议 | 风险 |
|--------|------|------|
| P0 | push 或明确不 push 策略 | 低（需确认） |
| P0 | 手测开项目 | 低 |
| P1 | F6 E1 | 中若改 renderer |
| P2 | U7 | 中 |
| 否 | 拆 injector / 盲 promote / 购证 | 高或决策否 |

### 5.4 否决的「架构优化」

微服务化 · Tauri 化 · 第二 injector · 非 loopback · vendor 热修业务。

---

## 6. 技术债清单

### 6.1 已关

见 §2.3；含闪白。

### 6.2 仍开

见 §2.4。

### 6.3 债管理

债卡带不做清单 · 关闭写 CHANGELOG/handoff · 安装空窗优先于再抽函数。

---

## 7. 细节打磨参考

### 7.1 文案

任务栏 Codex · 勿商店磁贴 · soft reattach OK≠发版失败 · SmartScreen 仍要运行。

### 7.2 视觉（S1 + 上游氛围）

- 暗色主题：稳定 dream-theme-dark  
- 不挡 composer · 慎 blur（本仓 de-blur 保留）  
- 改 token 优先于改选择器  
- 会话改动要 conversationCovered  

### 7.3 主题作者

palette 四色 · surface 表达明暗意图 · B 门 ≥4.5 · art focus 不压输入区。

### 7.4 无障碍务实

不宣称宿主 WCAG 全站；B 门只挡正文对。

### 7.5 性能

catalog 预算 · open thumbs 节流 · U7 二期。

---

## 8. 用户体验升级

### 8.1 旅程

安装 → SmartScreen → 钉任务栏 → U4 一次 → 日常聚焦 → 换肤 U3 → **开项目不闪白** → 故障一键修复。

### 8.2 路径反馈

面板/托盘/CLI/F6；prefs 只管成功气球。

### 8.3 故障

无皮肤 · 裸启 · 无气泡（prefs）· 想再 U4（删 flag）· 仍闪白（报路由+主题 id）。

---

## 9. 视觉风格立场

### 9.1 上游主体、本仓分叉

以 Fei-Away 为 **视觉意图主体**（暗色氛围、宽图 body 背景、token 族），本仓保留：

- 性能：header/bubble 去重 blur  
- heige 气泡/composer 取向  
- stamp / null-safe art  

**不是**像素级 fork 复刻，而是 **不背叛暗色编码场景**。

### 9.2 决策树

```text
闪白？
  → surface 暗？应 dark 类
  → 无 main？应保留皮肤帧
  → 仍白？查是否 light 主题或官方 Appearance 叠层
要「更像上游」？
  → 先判定与 token，不整文件 promote
```

---

## 10. 安全摘要

loopback · header token · data-only · 零 prod npm · 同用户恶意不在范围。详见 SECURITY.md。

---

## 11. 多方案对比评分（当前问题）

### 11.1 问题定义

1. 远程不可复现（ahead 4）  
2. 闪白是否手测过关  
3. F6 文档是否诚实  
4. 是否错误扩张（promote/Creator）  

### 11.2 维度（1–5，风险低=高分）

用户价值 · 维护成本低 · 边界契合 · 可逆 · 证据 · 风险低 · Σ/30。

### 11.3 方案池

| ID | 方案 |
|----|------|
| **P** | push origin（用户明示） |
| **V** | 仅手测视觉 + 记录，不 push |
| **C** | F6 E1 + 必要时最小补丁+publish |
| **P+V** | 手测通过后 push |
| **P+C** | push 后 F6 |
| **H** | 再写长文不动交付 |
| **E** | 盲 promote 上游 CSS |
| **F** | 购证签名落地 |

### 11.4 评分表

| 方案 | 用户 | 维护 | 边界 | 可逆 | 证据 | 风险低 | **Σ** |
|------|:----:|:----:|:----:|:----:|:----:|:------:|:-----:|
| **P 远程交付** | 5 | 5 | 5 | 5 | 5 | 4 | **29** |
| **P+V** | 5 | 5 | 5 | 5 | 5 | 5 | **30** |
| **C F6** | 4 | 3 | 5 | 4 | 4 | 4 | **24** |
| **P+C** | 5 | 3 | 5 | 4 | 5 | 4 | **26** |
| **V 仅手测** | 3 | 5 | 5 | 5 | 3 | 5 | **26** |
| **H 只文档** | 1 | 5 | 5 | 5 | 1 | 5 | **22** |
| **E promote** | 2 | 1 | 2 | 2 | 2 | 1 | **10** |
| **F 购证** | 3 | 1 | 4 | 3 | 2 | 2 | **15** |

### 11.5 为何 P+V / P 最佳

1. **代码已在本地证明**（publish+doctor+apply）；缺的是 **origin 可复现**。  
2. 符合「先验证后合并/推送」：推送的是已测提交，不是半成品。  
3. V 降低「推了仍闪」的后悔成本；若你已手测过可直接 P。  
4. C 有价值但不阻塞交付。  
5. E 撞 ADR；H 回避交付；F 决策 No-Go。  

### 11.6 组合推荐

| 名 | 含 | 推荐 |
|----|-----|:----:|
| **交付-远程** | P 或 P+V | **默认** |
| **交付+F6** | P+C | 有 F6 疑虑时 |
| 观察 | V 或 H | 暂缓远程时 |

---

## 12. 市场需求调研报告

### 12.1 市场

Windows Codex Desktop 用户要 **非官方氛围皮肤** 且 **不破坏官方包**。

### 12.2 需求层次

功能氛围 · 更新可靠 · 信任边界 · 入口正确 · 换肤可感 · **路由不闪瞎** · 可读 · 演示美观（次）· Creator（低）· mac（本仓无）。

### 12.3 竞品替代

不用皮肤 · Appearance · 上游 DreamSkin · Styler · 本仓（守护强、叙事弱、现体验补齐中）。

### 12.4 商业

个人工具；签名是成本不是收入。

### 12.5 合规感知

不改 asar · loopback · #21 #24 诚实。

### 12.6 结论

需求窄且真；增长靠可靠与诚实；**push 让协作/备份成立**；闪白修直接打「难用」类工单。

---

## 13. 架构设计文档（浓缩）

### 13.1 上下文

用户 → FastLaunch → open → watch(CDP9335) + control(9336) → evaluate 氛围层。  
CLI/托盘 → active-theme → /kick。

### 13.2 包职责

core 发现/CLI · themes schema/adapter · runtime inject · core-win PS · launcher 薄 · vendor 镜像。

### 13.3 状态文件

current.json · state.json · control.* · active-theme · themes · paused · **ui-prefs** · **first-run flag**。

### 13.4 序列：开项目（闪白相关）

1. Codex 路由重建 DOM  
2. 可能短暂无 main  
3. **旧**：clearSkin → 白；**新**：保留帧  
4. ensure 恢复 shellMain  
5. resolveAppearance(surfaceLuma) → dark 类  
6. CSS token 暗色 canvas/surface + art  

### 13.5 序列：apply

write → kick → feedbackQueued → 气泡（prefs）。

### 13.6 质量属性

可维护四层 · 可观测 doctor · 安全 loopback · 可回退 versions · 性能 kick+预算。

---

## 14. 开发规范与编码标准

### 14.1 栈

Node≥20 ESM · pwsh 维护 · 零 prod npm。

### 14.2 命名

新 PS CodexSkin* · 旧 DreamSkin 不批量改 · 主题 kebab-id。

### 14.3 PR 7 问

包 · import · core↔runtime · 旁路 · 路径 helper · active-theme · 版本源。

### 14.4 测试门

npm test · control 本机 · probe 会话 · doctor/verify 发版。

### 14.5 主题

schema · B≥4.5 · 可读清单 · 无危险键。

### 14.6 runtime

改 inject **必 publish** · 手测路由 · 不盲 promote。

### 14.7 安全

header token · URL guard · 日志无全量 token。

### 14.8 文档

行为改 → usage/CHANGELOG · BASELINE 仅脚本 · 调研≠SSOT。

### 14.9 提交风格

`fix(ui): …` · `feat(ux): …` · `docs: refresh BASELINE …`

---

## 15. 开发路线图

### 15.1 已完成里程碑

M-merge · M-guard · M-evidence · M-docs-UX · **M-feedback U3/U4/B** · **M-visual-no-flash**

### 15.2 近端 0–7 日

| 项 | 验收 |
|----|------|
| **P push** | origin 含 fa6151e 链 |
| V 手测开项目 | 不闪白 |
| 托盘 relaunch | 换肤气泡菜单 |
| 可选 C F6 | 记录或补丁 |

### 15.3 中期

主题截图规范 · DOM fixture · U7 评估。

### 15.4 长期

签名触发再评 · awesome 链接。

### 15.5 永不

mac 一等 · AUMID · asar · 第二 injector · 盲 promote · 云 doctor。

---

## 16. API 接口文档

### 16.1 CLI JSON

help · list · create · import-themes · **apply**（kick · note · feedbackQueued）· pause/restore · status · doctor。

### 16.2 控制面 HTTP（127.0.0.1）

GET /health · POST /kick · /focus · /open-healthy（header `x-codex-skin-token`）。

### 16.3 CDP

9335 loopback · guard · evaluate 不稳定契约。

### 16.4 文件系统

active-theme · ui-prefs · first-run flag · current.json · control.token。

### 16.5 PS 入口

open · switch-theme-ui · show-feedback · check-and-fix · kick-theme-now · publish-runtime。

### 16.6 渲染配置契约（闪白相关）

theme.json：`appearance` auto|light|dark · `palette.surface|text|accent|secondary`。  
inject：surfaceLuma 阈值 0.45/0.62 · 无 main 保留。

### 16.7 错误码

cdp-closed · bare-codex · first-run · apply-ok/fail。

---

## 17. 测试与证据

单元进 CI · control/probe 本机 · verify 发版 · UX 手测路由与气泡 · 禁 vacuous conversation。

---

## 18. 交互选代说明

用户将选择：

1. 主组合：P+V / P / P+C / C / V / 仅调研  
2. 是否 **现在 push**（默认需明示）  
3. 是否现在跑 **F6 复测脚本**  
4. 是否写 **手测通过** 一句到 evidence（可选）

---

## 19. 执行手册

### 19.1 P push

`git push origin main`（仅确认后）· doctor 再记 · 更新 handoff。

### 19.2 V 手测

打开 Codex → 切项目 → 观察主区 · 报异常路由。

### 19.3 C F6

CDP evaluate cycleTheme · 缺则小卡 + publish。

### 19.4 仅调研

停码；本文即交付。

---

## 20. 附录：路径与验收记录

| 路径 | 用途 |
|------|------|
| docs/research/v4 | 上一阶段 |
| docs/research/v5（本文） | 当前选代 |
| packages/runtime/assets/renderer-inject.js | 闪白修 |
| packages/themes/theme-schema.mjs | B 门 |
| packages/core-win/launcher-ui.ps1 | U3/U4 |

| 检查 | 结果 |
|------|------|
| ahead | 4 |
| runtime | 48a559 fresh |
| npm test | 绿（B 夹具） |
| apply | kick ok |

---

## 21. 深度：开项目闪白故障树

| 现象 | 旧因 | 新防 |
|------|------|------|
| 整页纸白 | light token | surface→dark |
| 一闪回暗 | clearSkin | 保留帧 |
| 仅部分面板白 | 选择器缺口 | 另卡；非本次 |
| light 主题也暗 | 误杀 | surface≥0.62 走 light |

---

## 22. 深度：为何不 promote 上游 CSS 修闪白

1. runtime CSS 有意 de-blur / heige 气泡分叉。  
2. 闪白根因在 **appearance 状态机**，不在缺某段上游选择器。  
3. 整文件合会带回 header blur 冻窗风险（历史 PAIN）。  
4. ADR 0002：人工摘取；本次零摘取即可关单。  

---

## 23. 深度：远程分叉风险

本地 ahead 4 时：他机 clone 无 U3/闪白 · handoff 易撒谎 · 备份只在本盘。  
缓解：push 或打 tag/bundle。  
**不 push 的唯一正当理由**：你要再手测改 commit；否则应推。

---

## 24. 深度：卡片库（目标约束 IO 验收）

### 24.1 P0 远程 push

| 字段 | 内容 |
|------|------|
| 目标 | origin=本地体验链 |
| 约束 | 用户明示 · 不 force |
| 输入 | fa6151e 链 |
| 输出 | origin/main 前进 |
| 验收 | gh 或 fetch 见 e01d0ef/38c051c |

### 24.2 V0 视觉手测

| 字段 | 内容 |
|------|------|
| 目标 | 确认开项目不闪白 |
| 约束 | 用任务栏 Codex |
| 输入 | 暗色主题如 genshin-night |
| 输出 | 通过/失败笔记 |
| 验收 | 主区无持续近白纸 |

### 24.3 C0 F6

| 字段 | 内容 |
|------|------|
| 目标 | usage 与真机一致 |
| 约束 | 单 injector · 改 renderer 必 publish |
| 输入 | 会话 CDP |
| 输出 | 记录或补丁 |
| 验收 | cycleTheme 或文档降级说明 |

### 24.4 R0 托盘刷新

退出托盘 · 再 open · 见换肤气泡菜单。

---

## 25. 市场扩写：工单映射

| 工单 | 刀 |
|------|-----|
| 换肤无感 | U3 |
| 入口错 | U4 |
| 开项目白 | e01d0ef |
| 主题难读 | B |
| 更新丢皮肤 | soft reattach |
| 怕安全 | SECURITY |
| 协作无码 | **push** |

---

## 26. 规范扩写：视觉 PR 清单

- [ ] 是否动 appearance 判定？附路由手测  
- [ ] 是否 clearSkin 路径？说明闪白风险  
- [ ] 暗色主题是否仍 dark 类？  
- [ ] publish + doctor fresh  
- [ ] 未盲合 vendor  

---

## 27. 路线图叙事

本周：P/V。  
下周：C 若需要。  
本月：U7 评估、截图规范。  
永不：边界外项。

---

## 28. API 示例

```text
GET  http://127.0.0.1:9336/health
POST http://127.0.0.1:9336/kick
     Header: x-codex-skin-token: <token>
node packages/core/cli.mjs apply --theme genshin-night
node packages/core/cli.mjs doctor
```

ui-prefs：`applyBalloonEnabled` bool。

---

## 29. 方案任务拆解

**P**：status → push → fetch 确认 → handoff。  
**V**：开 Codex → 多点几个项目 → 记录。  
**C**：probe → 结论 → 可选修。

---

## 30. 验收矩阵

| ID | 场景 | 期望 |
|----|------|------|
| V1 | doctor | fresh 48a559 |
| V2 | apply | kick ok |
| V3 | 开项目 | 不闪白 |
| V4 | U3 关 | 无成功气球功能在 |
| V5 | push 后 | 他机可见提交 |
| V6 | F6 | 与 usage 一致或已改文档 |

---

## 31. 与 v4 引用

v4 推荐 A+B 已执行完毕。v5 目标函数变为 **远程一致性 + 视觉确认**。约束 SSOT 仍是 PROJECT/ADR。

---

## 32. Runbook 短

闪白复发：查 runtime 是否 48a559+ · surface 是否暗 · 是否旧 inject。  
push 后无变化：publish 是否本机 · 杀旧 injector。  
401：token header。

---

## 33. 产品叙事

给 Windows Codex 换壁纸级皮肤，不改官方包。钉任务栏。开项目保持氛围不闪纸白。换肤可感可关。

---

## 34. Agent 检查单

- [ ] 读 v5 §0 + git status ahead  
- [ ] doctor runtimeId  
- [ ] push 仅明示  
- [ ] 改 runtime 必 publish  
- [ ] 不盲 promote  

---

## 35. 长文自检

进度 E1 · 同类优缺 · 目标约束 IO 验收 · 五件套 · 多方案 Σ · 否决项 · 闪白专章 · 远程风险。

---

## 36. 收束

本地产品体验链（U3/U4/B/不闪白）**已 commit 且安装对齐**；**默认最佳下一刀是 P 或 P+V（push，可选手测）**。  
F6 为增强；盲 promote 与购证实施否决。  
交互表单确认后执行；**未确认不 push**。

| 五件套 | 章 |
|--------|-----|
| 市场 | §12 · §25 |
| 架构 | §5 · §13 · §21–23 |
| 规范 | §14 · §26 |
| 路线图 | §15 · §27 · §24 |
| API | §16 · §28 |

**口令**：继续 codex-skin · 读本文 · `git status` 看 ahead 4。

---

## 37. 补充：同类「路由闪白」经验抽象

桌面换肤类项目在 SPA/多路由宿主上的共同失败模式是：**(1) 主题类名依赖宿主 light/dark 信号；(2) 路由卸载时拆除样式；(3) 默认 token 偏营销浅色**。上游 DreamSkin 用完整 token 族表达明暗；Styler 用更重的证据门减少「发版即回滚」。本仓用 **数据（palette.surface）覆盖宿主噪声** 属于低成本高边界契合修法，值得在 Agent 规范里写成：*appearance:auto 必须有数据层否决权*。

---

## 38. 补充：输入输出总表

| 接口 | 方向 | 稳定性 |
|------|------|--------|
| 任务栏入口 | 入 | 高 |
| CLI JSON | 出 | 中高 |
| control HTTP | 双 | 中 |
| active-theme | 双 | 高 |
| ui-prefs | 双 | 中 |
| inject appearance | 内 | 中（本轮加固） |
| git remote | 出 | **当前缺口** |

---

## 39. 补充：反验收

- 只改文档称已 push → 不算  
- push 后 doctor 仍旧 runtime 且不 publish → 不算发版  
- 强制所有主题 dark 杀死 light 包 → 不算（阈值分界在）  
- 为修闪白引入第二 inject → 否决  

---

## 40. 收束（终）

v5 冻结点：**fa6151e / 48a559 / ahead 4**。  
已完成体验与闪白本地交付；**最佳方案 P+V 或 P** 解决远程与信心；执行以你表单选择为准。

---

## 41. 深度扩写：完整用户旅程与状态机

### 41.1 冷启动状态机

用户点击任务栏「Codex」之后，产品经历一组可观测相位（历史 CHANGELOG 已有 cold-start tip 状态名，此处从体验角度重述）：

1. **解析入口**：FastLaunch 以独立 AUMID 启动，避免与商店包激活混淆。  
2. **发现 Codex**：定位 WindowsApps 或本机 ChatGPT/Codex 可执行文件；记录 bundled node 路径。  
3. **CDP 就绪**：确保 `--remote-debugging-port=9335`；若仅有裸进程，走 reattach/重启策略。  
4. **watch 单例**：保证仅一条 injector；state.json 写 pid/browserId/controlPort。  
5. **控制面**：9336 段扫描绑定；写出 control.port / control.token。  
6. **首帧皮肤**：evaluate CSS/JS；若 theme appearance 为 auto，v5 起以 palette.surface 否决错误 light。  
7. **托盘 ensure**：mutex 去重；提供换肤与 U3 开关。  
8. **U4**：仅当 first-run flag 缺失。  
9. **健康聚焦**：窗口前置；失败则 focus-miss 气泡（错误类，不受 U3 关断影响）。

任一相位失败应落到**可行动中文 note**，而不是静默白屏。白屏与闪白不同：白屏常是 CDP/注入未起；闪白是皮肤类名短暂错误或 clearSkin。

### 41.2 开项目状态机（本轮焦点）

1. 用户从首页或侧栏进入某 project/task。  
2. Codex 前端卸载/重建 `main` 子树（Electron 多页或 SPA 路由）。  
3. MutationObserver 触发 scheduleEnsure。  
4. **旧路径**：某帧 `querySelector(main)` 为空 → clearSkinDom → html 失去 codex-dream-skin → 宿主默认浅色 → 用户见白纸。  
5. **新路径**：main 空则 **return 保留帧**；main 回后 resolveAppearance；暗 surface 钉 dark。  
6. 宽图模式下 body 背景图与 immersive 梯度恢复，编码区保持可读遮罩。

### 41.3 换肤状态机

写入 active-theme → 指纹变 → kick → 会话 apply → U3 成功/失败反馈。失败时 active-theme 可能已新、画面仍旧，note 必须说清「已写入但注入未确认」。

---

## 42. 深度扩写：架构质量场景测试

### 42.1 单 injector 不变量

任意时刻 `Get-CimInstance` 级进程枚举应只能看到一条 watch injector 命令行。CLI apply、托盘切换、面板应用都不得 `spawn` 第二条常驻 watch。once 降级允许短命进程，但不得变成守护。

### 42.2 仓安装一致性

`verify-install-matches-repo` 对 control-plane、cdp-url-guard、catalog-budget、injector、renderer-inject 等做 hash/marker。闪白修改了 renderer-inject，**必须 publish** 后 doctor fresh 才算用户侧修复完成——本机已在 48a559 满足。

### 42.3 主题数据纯净

危险顶层键拒绝；路径无 `..`；B 门对比度；catalog 预算在 inject 侧再次保护。作者不能靠「PR 说好看」绕过 test:themes。

### 42.4 控制面认证

mutating POST 无 header → 401；query token 无效；timingSafeEqual 防长度旁路。FastLaunch 健康检查走 GET /health 免 token，缩短冷启。

---

## 43. 深度扩写：市场需求细节

### 43.1 用户画像

| 画像 | 诉求 | 本仓匹配 |
|------|------|----------|
| 夜间编码者 | 暗色不刺眼、有氛围 | 强（闪白修关键） |
| 演示录屏者 | 好看主题 | 中（11 套） |
| 怕破坏环境者 | 不改官方包 | 强 |
| 多机开发者 | 远程可同步 | **弱至 push** |
| 主题创作者 | 简单 schema | 中（双格式+门禁） |
| 企业 IT | 签名与管控 | 弱（No-Go 购证） |

### 43.2 购买/采用决策因素（非付费）

采用成本：安装 + SmartScreen + 钉任务栏。  
持续成本：商店更新后点修复。  
退出成本：暂停皮肤或卸产品。  
信任成本：开源可读 + SECURITY 诚实。  

闪白会在「采用后第一周」摧毁信任——因为用户已认为皮肤可用，却在核心路径（开项目）打脸。故 e01d0ef 的产品优先级高于再做一个主题。

### 43.3 竞品话术对照

上游强调「Dream」与预设；Styler 强调 Creator；本仓应强调「**Windows 守护 + 热切换 + 可证明安装**」。v5 起可补一句：「开项目保持氛围，不闪纸白」。

---

## 44. 深度扩写：开发规范细则

### 44.1 JavaScript 渲染层

- 禁止在 ensure 热路径同步做重计算超出现有 analyzeArt 预算。  
- 修改 ROOT_CLASSES / ROOT_PROPERTIES 必须同步 clearSkinDom。  
- appearance 解析变更必须附「开项目」手测说明。  
- 不得 `fetch` 远程 CSS。  

### 44.2 主题 JSON

- surface 应表达明暗意图，不要用中灰骗过眼睛却让 luma 落在中间模糊带（0.45–0.62）；中间带会回退 shell 检测。  
- 显式 `"appearance":"dark"` 可消除歧义，推荐暗色主题写明。  

### 44.3 Git 与发布

- 本地 ahead 超过 1 个功能提交时，handoff 必须写清「未 push」。  
- publish 与 commit 顺序：可先 publish 验证再 commit（本轮闪白即是）；避免 commit 了未 publish 的 runtime 误导。  

### 44.4 代码评审追加问句

1. 会不会在无 main 时拆皮肤？  
2. auto 是否仍可能误 light？  
3. light 主题是否仍能 light？  
4. 是否需要 publish？  

---

## 45. 深度扩写：路线图甘特与依赖

```text
[已完成] U3/U4/B ──┬── 闪白修 ──┬── (可选) 手测 V
                   │            └── (推荐) push P ── origin 对齐
                   └── (可选) F6 C（不阻塞 P）
[二期] U7 性能
[事件] 上游新 commit → F4 重评（默认仍不 promote）
[事件] 分发扩大 → 签名再评
```

依赖说明：P 不依赖 C；C 不依赖 P 但依赖本机会话；V 建议在 P 前或后均可，**P+V 分数最高**因为降低「推送后才发现仍闪」的社交成本。

---

## 46. 深度扩写：API 与契约测试建议

### 46.1 apply 契约

- 成功：mode hot-active-theme · kick.ok 布尔 · note 字符串 · feedbackQueued 布尔  
- 主题不存在：抛错非 0  
- 不因气球失败而 fail kick  

### 46.2 doctor 契约

- injectorPathFreshness.fresh  
- expectedRuntimeId 与 current.json 一致  
- skippedThemeCount 数值  

### 46.3 渲染契约（逻辑，非 HTTP）

给定 palette.surface `#171A2E` → appearance 类 dark。  
给定 `#F5F7FA` → light。  
给定 main 缺失 → 不移除 codex-dream-skin（若已安装）。  

### 46.4 建议后续单测（未强制本轮）

纯函数抽取 resolveAppearance(surfaceLuma, appearance, shellHint) 便于 node 测；当前逻辑在 IIFE 内，抽离是 C 级工程债，不阻塞 P。

---

## 47. 深度扩写：技术债量化与偿还顺序

| 债 | 偿还成本 | 拖欠成本 | 顺序 |
|----|----------|----------|------|
| 未 push | 5 分钟 | 高（协作/备份） | 1 |
| 手测确认 | 10 分钟 | 中 | 2 |
| F6 真相 | 0.5–2 日 | 中 | 3 |
| resolveAppearance 单测化 | 0.5 日 | 低 | 4 |
| U7 | 2+ 日 | 低 | 5 |
| 签名 | 周–月 | 视分发 | 事件 |

---

## 48. 深度扩写：细节打磨清单（可打印）

### 48.1 视觉

- [ ] 暗色主题开三个不同项目  
- [ ] 浅色主题（miku）确认仍浅  
- [ ] 会话页气泡对比  
- [ ] 侧栏折叠/展开不闪  
- [ ] 官方 Appearance 切换后暂停皮肤验证  

### 48.2 文案

- [ ] 托盘状态含主题名  
- [ ] kick 失败 CTA 指向任务栏  
- [ ] usage 与真机 F6 一致  

### 48.3 性能

- [ ] 长会话 1h 不冻（无重 blur 回归）  
- [ ] catalog 主题数增加时仍受预算  

---

## 49. 深度扩写：UX 文案库（可复用）

| 场景 | 文案 |
|------|------|
| U3 成功 | 已切换：{name} |
| U3 写入未注入 | 已写入：{name} · {note} |
| U4 | 日常请点任务栏 Codex；不要用商店磁贴 |
| 裸启 | 当前是未带皮肤的 Codex；将重启启用皮肤 |
| soft reattach | 发布后自动重挂成功；请再点任务栏确认 |
| 换肤气泡关 | 已关闭换肤成功气泡（菜单状态仍更新） |

---

## 50. 深度扩写：视觉风格 token 叙事（对齐上游）

上游 DreamSkin 用 oklch 基座 + accent 混色生成 canvas/surface/sidebar。暗色族降低 L，抬升 text L。本仓继承该结构，因此：

- **不要**把 palette.surface 直接写进 `--dream-surface` 替代整族 token（会破坏 immersive 梯度与 color-mix 链）；  
- **应该**用 surface 只决定 **light/dark 类**，让族内 token 继续工作；  
- text/secondary 可覆盖，因它们是末端可读性，不影响整族几何。  

这是「以上游为主体」的正确工程翻译，而不是 Git 级 merge。

---

## 51. 方案评分复核（加入「已手测」分支）

若用户断言已手测开项目 OK：

| 方案 | 调整 | Σ |
|------|------|---|
| P | 风险低分 +1 | **30** |
| P+V | 与 P 等价 | 30 |
| V only | 更不值 | 24 |

若用户断言仍闪：

| 方案 | 调整 |
|------|------|
| P | 降用户价值（推送已知坏体验）→ 先 V 再修再 P |
| C | 可能无关 |
| 新开 fix 卡 | 优先于 push |

表单应允许「手测状态」影响是否立刻 push。

---

## 52. 执行结果模板（选后填写）

```text
选择：P+V | P | P+C | C | V | H
push：是/否 → 结果：
F6：是/否 → 结果：
文档：v5 路径 · PROJECT 索引
git：HEAD= · ahead= · clean=
install：runtimeId= · fresh=
备注：
```

---

## 53. 与 Agent 记忆同步要点

handoff 必须含：HEAD、ahead 数、runtimeId、未 push、下一刀。  
MEMORY 索引一行指向 handoff。  
其他产品线记忆不得覆盖掉 codex-skin 行（多会话并发时易丢）。

---

## 54. 终节

本地该做的体验与闪白修复已入库并安装；**组织级该做的是 push（确认后）**；**个人级该做的是开项目手测**。  
架构保持四层；上游作视觉主体；本仓作守护与状态机强化。  
请通过交互表单给出选择，系统将按边界执行并回报执行结果。

*文终 · codex-skin master research v5 · 2026-07-21 · §0–§54*
