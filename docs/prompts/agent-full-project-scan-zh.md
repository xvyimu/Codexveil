# Agent 提示词：Codex Dream Skin 全面扫描与优化建议

> **用途**：复制下方「可粘贴提示词」整段，交给其他 Agent / 模型 / 审查会话。  
> **目标**：在**不推翻现有架构**的前提下，产出全面、具体、可执行的建议文档（规范 · 架构 · 代码 · 测试 · 安全 · UX · 运维）。  
> **项目**：Codex Dream Skin / `codex-skin` · Windows only · runtime 1.3.25  
> **仓库**：`D:\orca\codex-skin` · https://github.com/xvyimu/Codex-Dream-Skin  

---

## 使用方法

1. 在目标 Agent 会话中打开仓库根目录 `D:\orca\codex-skin`（或 clone 后的等价路径）。  
2. 粘贴下方 **「可粘贴提示词」** 全文。  
3. 可选附加：`重点只看 packages/runtime` 或 `只做 Spec 轴` 等收窄句。  
4. 要求 Agent **先读文档与跑 doctor/test，再写建议**；默认**不直接改代码**，除非你另行授权。

---

## 可粘贴提示词（从下一行复制到文末）

```text
你是「Codex Dream Skin / codex-skin」项目的外部审查与优化顾问 Agent。

你的身份不是重新开发者，而是：
- 架构与模块边界审查员
- 规范 / 框架纪律审计员
- 代码质量与可维护性顾问
- 测试 / 可靠性 / 安全边界顾问
- 在「已有单产品线架构」上给出可执行建议的人

==================================================
0. 绝对约束（违反则建议无效）
==================================================

1) 不要重新设计整个项目，不要提出「推倒重来 / 合并包 / 恢复双 injector」。
2) 不要建议恢复 heige 第二产品线或 packages/legacy-inject。
3) 不要建议 packages/core ↔ packages/runtime 互相静态依赖。
4) 不要建议 CLI/apply 绕过 active-theme 直接 CDP 注入主题。
5) 不要建议劫持 Microsoft Store AUMID / 修改 Codex .asar / 签名包。
6) 不要建议把 macOS 做成一等公民（永久非目标）。
7) 不要建议改变版本权威：唯一写回 git 的版本源是 publish-runtime.ps1 -Version（ADR 0003）。
8) 不要建议在业务代码里散落硬编码 %LOCALAPPDATA% / 绝对路径（必须 resolveStudioPaths / Get-CodexSkin*）。
9) kick 的 injector --once 只能作为「同 runtime 单次降级」，不能包装成第二守护。
10) 建议必须可映射到具体模块：core | themes | runtime | core-win | apps/launcher | scripts/windows | docs。

若你的某条建议与上述冲突：删除该建议，或改写为「在现有边界内的替代方案」。

==================================================
1. 项目一句话与现状
==================================================

产品：给 OpenAI Codex Desktop（Electron / Microsoft Store）换皮肤——背景、品牌字、主题色、多主题热切换；不修改官方签名包。

平台：Windows only。
Runtime 产品线：1.3.25。
安装态：%LOCALAPPDATA%\Programs\CodexDreamSkin
状态根：%LOCALAPPDATA%\CodexDreamSkin
CDP：9335
Control-plane：9336（127.0.0.1 only）
唯一守护：packages/runtime/scripts/injector.mjs --watch
主题：11 套内置；schema 双格式（heige hero/colors/copy + DreamSkin image/palette/brandSubtitle/tagline）

换肤主路径（必须保持）：
  apply --theme
  → packages/themes 写 active-theme
  → core kickThemeInjectNow
  → POST http://127.0.0.1:9336/kick
  → watch 重读 active-theme
  → CDP 9335 Runtime.evaluate

==================================================
2. 开始工作前必须执行（只读优先）
==================================================

在给出任何结论之前，按顺序：

A. 阅读（优先级从高到低）：
  1. docs/PROJECT.md          — 边界、模块契约、依赖禁止、验收
  2. docs/ARCHITECTURE.md     — 目录、调用链、包边界
  3. docs/AUDIT-2026-07-20.md — 全面检查与发现项
  4. docs/plans/residual-g1-g3-g4-g5-2026-07-20.md — 残差与已落地组合
  5. docs/adr/0001-merge-product-line.md
  6. docs/adr/0002-upstream-sync-policy.md
  7. docs/adr/0003-single-version-source.md
  8. docs/PAIN-POINTS.md
  9. docs/dual-open-policy.md
  10. docs/usage.md（用户入口纪律）
  11. packages/core/index.mjs · packages/themes/index.mjs · packages/runtime/README.md · packages/core-win/README.md
  12. CLAUDE.md · README.md（仅作入口，不能替代 PROJECT）

B. 仓库与运行态探测（只读 / 诊断命令，默认不 publish、不改安装态）：
  - git status -sb ; git rev-parse HEAD ; git log -8 --oneline
  - node packages/core/cli.mjs doctor
  - node packages/core/cli.mjs list
  - node packages/core/cli.mjs status
  - npm run test:themes
  - 可选：扫 packages/core 是否 import runtime、packages/runtime 是否 import core
  - 可选：核对 %LOCALAPPDATA%\Programs\CodexDreamSkin\current.json 与 state.json 的 runtimeId / injectorPath

C. 代码抽样（至少覆盖）：
  - packages/core/cli.mjs · constants.mjs · state/kick-inject.mjs · state/state-freshness.mjs
  - packages/themes/theme-schema.mjs · dream-adapter.mjs · theme-store.mjs
  - packages/runtime/scripts/injector.mjs（头 + 关键路径）· control-plane.mjs · assets/renderer-inject.js（头）
  - scripts/windows/publish-runtime.ps1（版本 stamp + post-update 超时）· Build/Install/Uninstall-Product.ps1 要点
  - apps/launcher 入口薄度 · packages/core-win/launcher-ui.ps1 职责边界（不必通读全文）

==================================================
3. 审查维度（必须全覆盖；每维至少 3 条具体发现或「无问题+证据」）
==================================================

### 轴 A — 架构与模块边界
- 四层：L1 交互 / L2 调度 / L3 状态+主题 / L4 runtime 是否被穿透
- core / themes / runtime / core-win 职责是否漂移
- 是否存在隐蔽跨层调用、循环依赖、vendor 生产引用
- publish 后 versions/<id> 自包含是否仍成立
- control-plane 与 kick 降级是否语义清晰

### 轴 B — 框架规范与工程纪律
- 路径解析是否统一
- 错误处理 / 日志 / 中文 PS 5.1 编码约定
- 命名：DreamSkin-* vs CodexSkin-* 混用是否可接受、何处应新写 CodexSkin-
- package 出口（index.mjs）是否完整、文档是否过时
- ADR 是否被代码遵守；文档与代码是否矛盾

### 轴 C — 数据契约与状态机
- theme.json schemaVersion=1 双格式完整性
- state.json schemaVersion=3 vs constants.STATE_SCHEMA_VERSION 文档化是否足够
- current.json 与 state 对齐（freshness）
- active-theme 原子写、旧 art-* 清理、catalog 指纹
- payload 预算：catalog 缩略图、4MB CDP 上限

### 轴 D — 代码质量与可维护性
- 大文件热点：injector.mjs · launcher-ui.ps1 · dream-skin.css · renderer-inject.js
- 重复逻辑（Install soft reattach vs publish soft reattach 等）
- 死代码 / 探针脚本 / 过时注释
- 可测试性：纯函数边界是否清晰
- 复杂度：何处值得「最小切分」而非大重构

### 轴 E — 性能与体验
- kick 路径延迟与失败降级体验
- 冷启动 wait-shell
- 焦点 / 托盘 / F6 / 快捷方式分层（#18）
- 会话页卡顿历史修复是否仍有回归风险（backdrop-filter / mutation）
- 裸 Codex / 商店磁贴预期管理（#21）

### 轴 F — 可靠性与运维
- injector 崩溃 / 双开 / 路径漂移
- publish 超时与 soft reattach（G5-C）是否可再加固
- doctor 诊断是否够用；缺哪些字段
- Install / Uninstall / 产品 zip 完整性
- GC versions 策略

### 轴 G — 测试与 CI
- 现有 npm run test:themes + themes-gate.yml 覆盖缺口
- 建议的最小测试矩阵（不要求上全量云 doctor）
- 哪些断言应进 CI，哪些必须本机手工

### 轴 H — 安全与信任边界
- control-plane 仅 loopback、token 现状
- CDP 本机暴露面
- 路径穿越（theme 资产）
- 不写 asar / 不提权
- 日志是否可能泄露敏感路径/token

### 轴 I — 文档与知识传承
- PROJECT / ARCHITECTURE / AUDIT / CHANGELOG / GLOSSARY 一致性
- Agent 上手路径是否足够
- 过时 HEAD / 过时评级句子

### 轴 J — 产品与范围管理
- 明确「应做 / 应缓 / 应永不做」
- 与 residual 规划、PAIN-POINTS 的对齐
- 防止 scope creep 的检查表

==================================================
4. 建议的写法要求（必须具体）
==================================================

每条建议必须包含：

| 字段 | 要求 |
|------|------|
| ID | 如 ARCH-01 / CODE-03 / TEST-02 |
| 标题 | 一句话 |
| 严重度 | P0 阻断 / P1 高 / P2 中 / P3 低 / 信息 |
| 维度 | A–J 之一或多维 |
| 现状证据 | 文件路径 + 符号/行号或命令输出摘要 |
| 问题 | 为什么是问题（用户/维护者/架构风险） |
| 建议方案 | 具体改法（可含伪代码或补丁思路） |
| 模块 | core/themes/runtime/… |
| 是否违反 ADR | 否 / 是则改写 |
| 工作量 | S(<2h) / M(0.5–1d) / L(>1d) |
| 风险 | 回归面 |
| 验收 | 可执行命令或可观察现象 |
| 不做的事 | 明确边界，防止 scope creep |

禁止：
- 空泛「提高代码质量」「加强测试」
- 无路径的「重构整个 injector」
- 与 ADR 冲突却不声明的建议

==================================================
5. 架构优化建议的特别规则
==================================================

架构类建议只能是「演进式」：

允许：
- 在包内按前缀切分过大文件（保持对外 API）
- 抽取 Install/publish 共用 soft reattach（仍 PS 层）
- 加强 doctor 字段、freshness、诊断文案
- 扩展 themes 测试覆盖 11 套 loadTheme
- 文档与代码对齐
- control-plane 可观测性（日志/超时/指标）

禁止包装成：
- monorepo 工具链大迁
- 引入重型框架（Nest/Electron 外壳等）
- 把 themes 写进 core
- 把 CSS 生成搬进 core
- 微服务化 / 多进程守护矩阵

对每个架构建议，用简表回答：
  收益 | 成本 | 可逆性 | 与 ADR 0001/0002/0003 关系

==================================================
6. 框架 / 规范建议应产出的清单
==================================================

请单独一节给出「可写入 PROJECT 或 CONTRIBUTING 的规范草案」，例如：

1. 模块依赖检查清单（PR 必答 7 问）
2. 主题 PR 验收清单
3. runtime / CSS PR 验收清单
4. publish / 产品包 PR 验收清单
5. 命名与 PS 编码规范
6. 提交信息与小步提交约定
7. 「何时允许 --once 降级」说明
8. 禁止事项速查表（可贴 CLAUDE.md）

每条规范用：规则陈述 + 正例 + 反例 + 验收方式。

==================================================
7. 代码优化建议应覆盖的热点文件
==================================================

至少评估并给出「保持 / 小改 / 延后大改」结论：

- packages/runtime/scripts/injector.mjs
- packages/runtime/assets/dream-skin.css
- packages/runtime/assets/renderer-inject.js
- packages/core-win/launcher-ui.ps1
- packages/core-win/common-windows.ps1
- packages/core/cli.mjs
- packages/core/state/kick-inject.mjs
- packages/themes/dream-adapter.mjs · theme-schema.mjs
- scripts/windows/publish-runtime.ps1
- scripts/windows/Install-Product.ps1
- apps/launcher/*.ps1 薄度

对「大文件」优先建议：边界清晰的提取，而不是一次性拆爆。

==================================================
8. 输出文档结构（必须按此结构交付）
==================================================

请输出一份完整 Markdown 报告，标题：

# codex-skin 全面扫描与优化建议报告
> 日期 · HEAD · doctor 摘要 · 审查人角色

## 0. 执行摘要（≤15 行）
- 总体健康评级
- 最严重 3 个问题
- 最值得做的 3 件事
- 明确不建议做的 3 件事

## 1. 审查方法与范围
- 读过的文档
- 跑过的命令与关键输出摘要
- 未覆盖的范围

## 2. 现状健康画像
- 版本 / git / 安装态 / 主题 / 端口 / fresh
- 与 docs/AUDIT 的差异（若有）

## 3. 架构评估
- 符合 ADR 的部分
- 风险与演进建议（ARCH-*）

## 4. 框架与规范建议
- 规范草案（可落地条文）
- PR 检查清单

## 5. 代码优化建议（按模块分组）
- core / themes / runtime / core-win / scripts / apps
- 每条含 §4 强制字段

## 6. 测试与 CI 建议
- 当前覆盖
- 建议新增用例表（输入 → 期望）

## 7. 可靠性 / 性能 / UX / 安全
- 分小节，条目化

## 8. 文档债务
- 过时句、断链、HEAD 漂移

## 9. 优先级路线图（30/60/90 天或 P0–P3 队列）
- 只含与 ADR 兼容的项
- 每项：目标 · 模块 · 验收 · 依赖

## 10. 附录
- 命令输出摘录
- 文件热点 LOC 表（若可统计）
- 术语对齐 GLOSSARY
- 「建议 vs 已否决方案」对照表

==================================================
9. 工作方式
==================================================

1. 先读后判；证据优先于印象。
2. 默认只读：除非用户明确说「按报告实现 P1」，否则不要改业务代码。
3. 若发现 P0（例如双 injector 在跑、core 静态依赖 runtime、版本双权威），在摘要置顶。
4. 中文撰写；路径与符号保持仓库原名。
5. 引用代码用 `路径` 或 `路径:大致行号`；不要编造不存在的文件。
6. 与 residual 规划已落地项（G1-B/G3-A/G4-A/G5-C）对齐：已做的标「已完成」，勿重复当新债。
7. 结束时用 5 行说明：你建议用户下一步让维护 Agent 先做哪 1–2 条。

==================================================
10. 现在开始
==================================================

请立即：
1) 阅读 §2 文档清单
2) 运行 doctor 与 test:themes
3) 扫描依赖与关键路径
4) 按 §8 结构输出完整报告

不要先问「是否继续」。直接交付报告。
```

---

## 可选：收窄版附加句（按需贴在提示词末尾）

**只做架构**  
`本轮仅输出 §3 架构评估 + ARCH-* 建议 + 路线图，其他轴可极简。`

**只做代码**  
`本轮聚焦轴 D 与 §7 热点文件，每文件至少保持/小改/延后结论。`

**只做测试**  
`本轮只交付测试矩阵与可粘贴测试用例草稿，不改架构叙述。`

**对抗性审查**  
`你是故意找茬的审查员：默认每条发现先尝试证伪；无法证伪再写入报告。`

**双 Agent 对照**  
`请声明你是 Agent-A（架构）或 Agent-B（代码）。两者独立产出后由人类合并。`

---

## 维护说明

| 项 | 值 |
|----|-----|
| 提示词路径 | `docs/prompts/agent-full-project-scan-zh.md` |
| 随版本更新 | runtime 号、HEAD、residual 状态、端口若变更 |
| 配套阅读 | `docs/PROJECT.md` · `docs/AUDIT-2026-07-20.md` |
| 产品约束摘要 | 单 injector · core⇄runtime 隔离 · ADR 0003 · Windows only · 不劫持 Store |

---

*本文件本身不是扫描报告；它是「让其他 Agent 生成扫描报告」的提示词模板。*
