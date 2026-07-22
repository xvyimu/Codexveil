# Injector 模块拆分 · 方案 SSOT · 2026-07-22

> **角色**：cv-1 = 方案 SSOT（只维护本文件与验收；**不**与 cv-2 抢写实现）  
> **实现**：cv-2 · **测试**：cv-3  
> **总控**：`D:\orca\docs\refactor-coord-2026-07-22.md` §3.2  
> **依据**：ADR 0004 D4 · 协调模块一已验收

## 0. 目标 / 非目标

| 做 | 不做 |
|----|------|
| 从 `packages/runtime/scripts/injector.mjs` 抽出 `theme-load.mjs` + `payload-builder.mjs` | 第二 watch / injector |
| publish 白名单同步新文件 | runtime 装 Zod/contracts 运行时依赖 |
| 离线回归测钉死 fingerprint / loadTheme / catalog 语义 | 合并 injector loadTheme 与 `packages/themes` loadTheme |
| 每步 commit；行为零可见变化 | 本切片接线 `computeSkinStamp` 决策（仍 prep） |

## 1. 目标布局

```text
packages/runtime/scripts/
  injector.mjs           # 编排 CDP/watch/kick/CLI
  theme-load.mjs         # NEW
  payload-builder.mjs    # NEW
  stamp.mjs              # 已有；本切片不改变 inject 决策
  theme-catalog-budget.mjs
  cdp-url-guard.mjs
  image-metadata.mjs
```

| 模块 | 迁出 | 对外语义 |
|------|------|----------|
| `theme-load.mjs` | `loadTheme` / `loadCatalogMember` / `loadThemeCatalog` / `readCatalogSourceStamp` / `readThemeSourceStamp` / 校验 helpers / `THEME_CHOICES` / palette CSS 循环 | 同参同返；缺 palette 键**不**填默认（≠ themes 包） |
| `payload-builder.mjs` | `loadPayload` / `imageDataUrl` / `earlyPayloadFor` | placeholder 替换 + fingerprint 合成不变；依赖 theme-load **单向** |
| `injector.mjs` | import 上两者；CdpSession/watch/kick/main 分支不改 | CLI / kick JSON / 异常 message 不变 |

依赖方向：`payload-builder` → `theme-load` → (`theme-catalog-budget` | `image-metadata`)；**禁止** core ↔ runtime 新边。

## 2. 文件清单

| 路径 | 动作 | 谁 |
|------|------|-----|
| `packages/runtime/scripts/theme-load.mjs` | 新增 | cv-2 S2 |
| `packages/runtime/scripts/payload-builder.mjs` | 新增 | cv-2 S3 |
| `packages/runtime/scripts/theme-load.test.mjs` | 新增 | cv-3 优先 / cv-2 可先红测 |
| `packages/runtime/scripts/payload-builder.test.mjs` | 新增 | cv-3 / cv-2 S3 |
| `packages/runtime/scripts/injector.mjs` | 搬迁 + import + TOC | cv-2 |
| `scripts/windows/publish-runtime.ps1` | 白名单 +2 | cv-2 S4 |
| `package.json` | `test:theme-load` / `test:payload-builder` → `test:unit` | cv-2 S4 |

## 3. 步骤（实现师 cv-2）

| 步 | 内容 | 验证 | commit 建议 |
|----|------|------|-------------|
| **S1**（可与测并行） | 红测 / fixture：合法 4 色；非法 color throw；image 越界；sourceStamp 形状；catalog thumb 优先 | `node …/theme-load.test.mjs` | `test(runtime): theme-load regression fixtures` |
| **S2** | 新增 `theme-load.mjs`；injector import；**逐行搬**无分支改写 | 测绿 + `node --check` | `refactor(runtime): extract theme-load from injector` |
| **S3** | `payload-builder.mjs` + 测：同输入同 fingerprint；bubbleStyle 变 → fingerprint 变；`earlyPayloadFor` 含 revision | 测绿 + check | `refactor(runtime): extract payload-builder from injector` |
| **S4** | publish 白名单（`Copy-Item` 与 `cdp-url-guard` 同级）+ package.json scripts | `rg` 白名单含新文件 | `chore(publish): ship theme-load and payload-builder modules` |
| **S5** | `npm test` 全量；可选本机 doctor | exit 0；写总结 | 总结可 docs 一句或 commit body |

## 4. 行为契约（硬 · 测试师对照）

1. **两套 loadTheme 不可混**：injector 侧 CSS color 子集；缺 `surface` **不**默认填充（TD-V5）。  
2. **Kick 热路径**仍用 `sourceStamp`（mtime/size），**不**改用 `computeSkinStamp`。  
3. Kick 响应字段：`ok/mode/applied/sessions/fingerprint/ms/errors/note`。  
4. `loadPayload`：四个 `__DREAM_*_JSON__`；`ui-prefs.json` bubbleStyle；fingerprint = themeFp + catalogFp + bubbleStyle。  
5. 异常 message 字符串尽量逐字保留（禁止为“整洁”改文案）。  
6. **Publish**：漏拷 = 安装态 `ERR_MODULE_NOT_FOUND` — S4 必做。

## 5. 测试矩阵（cv-3）

| 用例 | 期望 |
|------|------|
| palette 四色合法 | 写入 theme.palette |
| 非法 color | throw 含 `palette.` |
| image 绝对路径 / 越界 `..` | throw |
| 有 thumb.* | catalog member 走 thumb |
| 无 thumb 且 art 超 budget | null |
| loadPayload 稳定输入 | fingerprint 相等 |
| 改 bubbleStyle | fingerprint 变 |
| earlyPayloadFor | 含 generation/revision 字面量 |
| `npm test` / `test:deps` | 全绿；无 core↔runtime 新边 |

**不强求本切片**：真 CDP apply（doctor/probe 仍人工）。

## 6. 风险与回滚

| 风险 | 缓解 |
|------|------|
| publish 漏拷 | S4 白名单；总结勾选 |
| `root`/`here` 路径错 | payload 显式 assets/runtime 根，语义对齐原 `path.join(root,"assets")` |
| 循环依赖 | 单向 import only |
| 误并 themes.loadTheme | 禁止 |

回滚：逐步 `git revert`；安装态 re-publish 旧 runtimeId。

## 7. DoD

- [ ] `npm test` exit 0（含新测）  
- [ ] `injector.mjs` 行数下降（目标量级 ≤~1100，以实测为准）  
- [ ] publish 白名单含 `theme-load.mjs` + `payload-builder.mjs`  
- [ ] fingerprint / loadTheme 有离线测  
- [ ] 无 core ↔ runtime 新边  
- [ ] 每步独立 commit；总结：变更清单 / 验证 / 残留风险  

## 8. Backlog（另 PR，勿塞进本切片）

1. stamp shadow log  
2. Reconciler `shouldInject` 真接线  
3. CdpSession 外提  
4. Vitest 迁移 `*.test.mjs`

## 9. 槽位纪律

- **cv-1**：只改本 SSOT / 答疑 / 验收对照；**禁止**并行大改 injector。  
- **cv-2**：严格 S1–S5；diff 除搬迁外无业务分支。  
- **cv-3**：测与边界；实现完成后全量跑；契约冲突以本文件为准，回写 cv-1 修订。

---

**修订记录**

| 日期 | 说明 |
|------|------|
| 2026-07-22 | 初版：模块一验收后落盘 SSOT |
