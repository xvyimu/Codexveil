# 任务卡清单 · 2026-07-21

> 基线：HEAD 以 `git rev-parse HEAD` 为准 · runtimeId 以 doctor 为准（产品线 `1.3.25`）  
> 来源：外部扫描 [`SCAN-OPTIMIZE-2026-07-20.md`](../SCAN-OPTIMIZE-2026-07-20.md) + 维护落地后剩余项  
> 关联：[`CONTRIBUTING.md`](../CONTRIBUTING.md) · [`adr/`](../adr/) · 维护提示词 [`../prompts/agent-maintain-task-cards-zh.md`](../prompts/agent-maintain-task-cards-zh.md)  
> **收口**：12 张卡均已完成（2026-07-21）；后续可选见 PROJECT §12.2「可选」行。

**已落地勿重复当债**（2026-07-20）：SEC-01 token 强制 · soft-reattach.ps1 · `--state-root` · `test:deps` · 11 主题 loadTheme · G1-B/G3-A/G4-A/G5-C。

---

## P1（高 · 30 天）

### DOC-01 文档 HEAD/runtimeId 对齐

| 字段 | 内容 |
|------|------|
| 目标 | 消除 AUDIT/SCAN 文档与仓库实际的基线漂移 |
| 完成范围 | `docs/AUDIT-2026-07-20.md` §16 追加校准行（HEAD/runtimeId）；`docs/SCAN-OPTIMIZE-2026-07-20.md` 尾部追加修订行；两份顶部加「当前基线校准」段 |
| 不做的事 | 不重写文档主体；不改 §1–§15 原结论 |
| 涉及模块与边界 | 仅 docs/（不改代码） |
| 现有接口/数据结构 | 无 |
| 实现要求 | 遵守 PROJECT §3；路径不涉及 |
| 验收标准 | `git rev-parse HEAD` 与文档声明一致；doctor.runtimeId 与文档声明一致 |
| 验证命令 | `git rev-parse HEAD` · `node packages/core/cli.mjs doctor` |
| 工作量 | S（<2h） |
| 风险 | 无（纯文档） |
| 规划落点 | P1 / 30 天 |
| 状态 | **已完成（2026-07-21）** |

---

### DOC-02 PAIN-POINTS 补 SmartScreen 条目

| 字段 | 内容 |
|------|------|
| 目标 | 用户首次运行 SmartScreen 拦截有文档指引 |
| 完成范围 | `docs/PAIN-POINTS.md` 追加 #24 SmartScreen（现象 + 应对「更多信息 → 仍要运行」+ 长期规划 P3 OV 证书签名）；`docs/usage.md` 交叉引用 |
| 不做的事 | 不承诺立即签名；不写教程；不改 macOS（永久非目标） |
| 涉及模块与边界 | 仅 docs/ |
| 现有接口/数据结构 | 无 |
| 实现要求 | 遵守 PROJECT §3 |
| 验收标准 | PAIN-POINTS.md 含 #24；usage.md 交叉引用 |
| 验证命令 | Grep `SmartScreen` docs/PAIN-POINTS.md（命中） |
| 工作量 | S |
| 风险 | 无 |
| 规划落点 | P1 / 30 天 |
| 状态 | **已完成（2026-07-21）** · PAIN #24 + usage 交叉引用 |

---

### FRAME-01 § 规范草案写入 CONTRIBUTING + 索引

| 字段 | 内容 |
|------|------|
| 目标 | 8 类规范入库，PR 审查有清单可依 |
| 完成范围 | 仓库存在 `docs/CONTRIBUTING.md`（§C-1–C-9 + PR 模板）；`docs/PROJECT.md` / `CLAUDE.md` / `README.md` 链入；可选 `.github/pull_request_template.md` |
| 不做的事 | 不重写 PROJECT.md 主体；不引入 lint 工具链；不改 ADR |
| 涉及模块与边界 | 仅 docs/（+ 可选 .github） |
| 现有接口/数据结构 | 无 |
| 实现要求 | 遵守 PROJECT §3 |
| 验收标准 | CONTRIBUTING 含 §C-1 至 §C-9；PROJECT/CLAUDE/README 含链入 |
| 验证命令 | Grep `模块依赖 PR 必答 7 问` docs/CONTRIBUTING.md（命中） |
| 工作量 | M（0.5–1d） |
| 风险 | 低（纯文档） |
| 规划落点 | P1 / 30 天 |
| 状态 | **已完成（2026-07-21）**：`docs/CONTRIBUTING.md` + PROJECT/CLAUDE/README 链入；维护提示词见 `docs/prompts/agent-maintain-task-cards-zh.md` |

---

## P2（中 · 60 天）

### TEST-02 control-plane token 测试

| 字段 | 内容 |
|------|------|
| 目标 | SEC-01 token 强制有测试守护 |
| 完成范围 | 新增 `packages/runtime/scripts/control-plane.test.mjs`，4 条断言：1) GET /health 免 token 200；2) POST /kick 无 token 401 `token-required`；3) POST /kick 错 token 401；4) POST /kick 对 token 200/202 |
| 不做的事 | 不进 CI（需起服务）；不测 CDP 9335 真实注入；不改 control-plane.mjs 主体（除非发现 bug） |
| 涉及模块与边界 | 仅 packages/runtime/scripts/（新增 test 文件） |
| 现有接口/数据结构 | `control-plane.mjs` ensureToken / isHealthGet / CONTROL_TOKEN_HEADER |
| 实现要求 | 测试用 9347+ 端口段；token 持久化到 tmp stateRoot；不引入新依赖 |
| 验收标准 | `node packages/runtime/scripts/control-plane.test.mjs` 4 条断言全过；`npm test` 仍绿 |
| 验证命令 | 同上 |
| 工作量 | M |
| 风险 | 中（端口冲突，用 9347+ 规避） |
| 规划落点 | P2 / 60 天 |
| 状态 | **已完成（2026-07-21）** · `control-plane.test.mjs`（本机跑，不进 CI） |

---

### DOC-03 GLOSSARY 术语覆盖扩展

| 字段 | 内容 |
|------|------|
| 目标 | 术语覆盖齐全、可点源文件 |
| 完成范围 | `docs/GLOSSARY.md` 扩展：soft reattach · control.token / x-codex-skin-token · resolveStudioPaths · Get-CodexSkin* · Verb-DreamSkinNoun 冻结 · Verb-CodexSkinNoun · schema 三件套 · FastLaunch · dual-open-policy · dreamskin-guard · test:deps 等；每条一句话 + 源文件路径 |
| 不做的事 | 不写教程；不改源码注释 |
| 涉及模块与边界 | 仅 docs/ |
| 现有接口/数据结构 | 无 |
| 实现要求 | 遵守 PROJECT §3 |
| 验收标准 | 关键术语齐全；与 ARCHITECTURE/CONTRIBUTING 一致 |
| 验证命令 | 人工对照 CONTRIBUTING §C-9 + ARCHITECTURE 控制面段 |
| 工作量 | S |
| 风险 | 无 |
| 规划落点 | P2 / 60 天 |
| 状态 | **已完成（2026-07-21）** |

---

### CODE-01 injector.mjs TOC 注释

| 字段 | 内容 |
|------|------|
| 目标 | 1300+ 行单文件可读性提升 |
| 完成范围 | `packages/runtime/scripts/injector.mjs` 顶部 TOC + 区域 `// === Region: xxx ===` 分隔（常量 / stateRoot / theme 加载 / watch / CDP / control-plane / signal / payload） |
| 不做的事 | 不拆分为多文件（ADR 0001）；不引入 ts/jsdoc 工具链；不改逻辑 |
| 涉及模块与边界 | 仅 packages/runtime/scripts/injector.mjs（仅注释） |
| 现有接口/数据结构 | 无（仅注释） |
| 实现要求 | 行号用 Grep 实际定位，禁止编造 |
| 验收标准 | 顶部含 TOC；`npm test` 绿；doctor `fresh=true` |
| 验证命令 | `node packages/core/cli.mjs doctor` · `npm test` |
| 工作量 | S |
| 风险 | 无（仅注释） |
| 规划落点 | P2 / 60 天 |
| 状态 | **已完成（2026-07-21）** · TOC + Region markers（仅注释） |

---

## P3（低 · 90 天）

### WIN-02 common-windows.ps1 冻结表写入 README

| 字段 | 内容 |
|------|------|
| 目标 | 旧 `Verb-DreamSkinNoun` 函数冻结表文档化 |
| 完成范围 | `README.md`「已知债务」段声明冻结表 + 新增函数用 `Verb-CodexSkinNoun`；链 CONTRIBUTING §C-5 |
| 不做的事 | 不批量改名；不引入 alias 双前缀 |
| 涉及模块与边界 | 仅 README.md（不改 common-windows.ps1） |
| 验收标准 | README 含冻结表声明 |
| 验证命令 | Grep `Verb-DreamSkinNoun` README.md（命中） |
| 工作量 | S |
| 风险 | 无 |
| 规划落点 | P3 / 90 天 |
| 状态 | **已完成（2026-07-21）** · README 已知债务段 |

---

### SEC-02 日志脱敏审计

| 字段 | 内容 |
|------|------|
| 目标 | 确认 control.token 未写入日志明文 |
| 完成范围 | Grep 日志写入路径周边；若有明文则 `redactToken`；无泄露则 PAIN-POINTS 记「SEC-02 已审计」 |
| 不做的事 | 不改 token 生成算法；不引入 vault；不改 control-plane 主体逻辑 |
| 涉及模块与边界 | runtime / core-win（仅日志写入点） |
| 验收标准 | 日志周边无 token 明文；或 redact + 测试 |
| 验证命令 | Grep + doctor |
| 工作量 | S |
| 风险 | 低 |
| 规划落点 | P3 / 90 天 |
| 状态 | **已完成（2026-07-21）** · 无明文泄露；PAIN-POINTS 记 SEC-02 |

---

### CODE-03 cli.mjs doctor 顶层 control 字段

| 字段 | 内容 |
|------|------|
| 目标 | doctor 顶层 summary 暴露 control 摘要 |
| 完成范围 | `packages/core/cli.mjs` doctor 顶层加 `control: { port, tokenPresent }`（从 dreamskin 子对象提取） |
| 不做的事 | 不改 dreamskin-guard 主体；不破坏现有字段（仅追加） |
| 涉及模块与边界 | 仅 packages/core/cli.mjs |
| 验收标准 | doctor 顶层含 control 字段且与 dreamSkin 一致 |
| 验证命令 | `node packages/core/cli.mjs doctor` |
| 工作量 | S |
| 风险 | 低 |
| 规划落点 | P3 / 90 天 |
| 状态 | **已完成（2026-07-21）** · doctor 顶层 `control: { port, tokenPresent }` |

---

### CODE-04 theme-store.mjs dedupe 注释

| 字段 | 内容 |
|------|------|
| 目标 | listThemes dedupe 逻辑加注释 |
| 完成范围 | `packages/themes/theme-store.mjs` dedupe + 形状守卫 + `MAX_SOURCE_IMAGE_BYTES` 注释 |
| 不做的事 | 不改 dedupe 逻辑 |
| 涉及模块与边界 | 仅 packages/themes/theme-store.mjs（仅注释） |
| 验收标准 | `npm run test:themes` 仍绿 |
| 验证命令 | `npm run test:themes` |
| 工作量 | S |
| 风险 | 无 |
| 规划落点 | P3 / 90 天 |
| 状态 | **已完成（2026-07-21）** · 仅注释 |

---

### CODE-05 renderer-inject.js stamp 注释追加

| 字段 | 内容 |
|------|------|
| 目标 | 消除 SKIN_VERSION_TOKEN 注释与 repo 源已 stamp 的矛盾 |
| 完成范围 | `renderer-inject.js` 与 `injector.mjs` 注释追加：repo 源在 publish 后也被 stamp；dev 检测仅对未 publish working copy 生效 |
| 不做的事 | 不改 stamp 机制；不改 token 字面量 |
| 涉及模块与边界 | 仅注释 |
| 验收标准 | 注释更新；doctor `fresh=true` |
| 验证命令 | doctor · npm test |
| 工作量 | S |
| 风险 | 无 |
| 规划落点 | P3 / 90 天 |
| 状态 | **已完成（2026-07-21）** · 仅注释 |

---

### CODE-06 publish-runtime.ps1 G5-C 反向链接

| 字段 | 内容 |
|------|------|
| 目标 | residual 文档反向链入 publish-runtime.ps1 行号 |
| 完成范围 | `docs/plans/residual-g1-g3-g4-g5-2026-07-20.md` G5-C 追加「已落地：publish-runtime.ps1 行号 + soft-reattach」 |
| 不做的事 | 不改 publish-runtime.ps1；不重写 residual 主体 |
| 涉及模块与边界 | 仅 docs/plans/residual-… |
| 验收标准 | residual G5-C 含行号反向链接（Grep 实际行号） |
| 验证命令 | Grep residual 文档 |
| 工作量 | S |
| 风险 | 无 |
| 规划落点 | P3 / 90 天 |
| 状态 | **已完成（2026-07-21）** · residual 实现落点表含 L294/L305/L314+ |

---

## 永不做（对照表）

| 项 | 理由 | ADR |
|----|------|-----|
| 恢复 heige 第二产品线 / `packages/legacy-inject` | ADR 0001 已合并 | 0001 |
| core↔runtime 静态互引 | 边界纪律 | 0001 |
| 拆分 injector.mjs 为多文件（无契约） | 单守护 | 0001 |
| 批量改名 Verb-DreamSkinNoun | WIN-02 冻结 | — |
| monorepo 大迁 / Nest / 微服务 | 演进式 only | — |
| macOS 一等公民 | 永久非目标 | — |
| 云 doctor / 远程 telemetry | 隐私 + 非目标 | — |
| Store AUMID 劫持 / 改 asar | OS/签名纪律 | — |

---

## 建议执行顺序

1. **30 天**：DOC-01 → DOC-02 → FRAME-01（纯文档，零风险）  
2. **60 天**：TEST-02 → DOC-03 → CODE-01  
3. **90 天**：WIN-02 → SEC-02 → CODE-03/04/05/06（可并行小改）

每张卡的 pasteable 维护 Agent 提示词见 [`../prompts/agent-maintain-task-cards-zh.md`](../prompts/agent-maintain-task-cards-zh.md)。
