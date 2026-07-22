# W1 · Codexveil 架构/栈升级报告 · Claude

| 字段 | 值 |
|------|-----|
| **波次** | portfolio-arch-upgrade-2026h2 · **W1** |
| **产品** | Codexveil（GitHub `xvyimu/Codexveil`） |
| **工作树** | `C:\Users\yuanjia\orca\workspaces\Codexveil\w1-cv-claude` |
| **分支** | `xvyimu/w1-cv-claude` |
| **开工 HEAD** | `4f218c93d98249f91a3d5c7d795f02182c407cdc` |
| **Agent** | solo Claude · 2026-07-23 |
| **对照 plan** | `week-next/…/cv-visual-align-v2.md` · `prompts/w1-cv.md` · `repos/cv.md` |

---

## 1. 交付摘要

| # | 题单项 | 结果 |
|---|--------|------|
| 1 | `docs/ops/stack-matrix-2026-07.md` | **已落盘**（Node/pnpm/runtime/contracts 当前→目标→本波） |
| 2 | 视觉 V2 映射表 | **已落盘** `docs/ops/visual-align-fei-away-diff-2026-07-23.md` |
| 3 | 白名单 CSS promote → `dream-skin.css` | **已做**（composer/sidebar/hero/raised；blur 仍 8px） |
| 4 | inject 最小视觉 | **已做**（`--dream-status` + ROOT_PROPERTIES；**保留** F6/catalog 四参） |
| 5 | 默认 arina 粉系 | **仍默认**（`packages/runtime/assets/theme.json` id `preset-arina-hashimoto` · accent `#E8A0BF`） |
| 6 | `npm test` | **exit 0** |
| 7 | `verify-publish-runtime-payload.ps1` | **exit 0** |
| 8 | 真 publish / push main | **未做**（禁止） |

---

## 2. 栈矩阵要点

详见 [`stack-matrix-2026-07.md`](./stack-matrix-2026-07.md)。

| 项 | 当前 | 本波 |
|----|------|------|
| engines | `node >=20` | 不硬升（装机旁路） |
| CI Node | themes-gate **22** | 已钉（本波确认文档化） |
| packageManager | `pnpm@11.5.0` | 已对齐组合 |
| contracts | 开发态包 | **不扩 API**（W2） |
| runtime 线 | `1.3.25` | 无真 publish |

---

## 3. 视觉 V2 改动（可审）

### 3.1 CSS（`packages/runtime/assets/dream-skin.css`）

| 区域 | 变更 | 拒绝（黑名单） |
|------|------|----------------|
| token | 增 `--dream-composer-fill/edge`、`--dream-immersive-composer-solid`；略抬 hero-shade / composer 混 accent | 不删 oklch 根 token |
| 侧栏 | 竖向 color-mix 渐变 + 右线；**backdrop none** | 不恢复全局 blur |
| hero scrim | 多 stop gradient（Fei hero-scrim 语义） | 不整段换 body::before heige 策略 |
| suggestions | raised 混 accent 6%（粉链） | 不用 Gothic 金 |
| composer | fill/edge token + 内高光；**blur 8px** | **不** promote Fei 16px blur |
| 会话搜索条 | solid composer 变体 | 不加重气泡 blur |

### 3.2 Inject（`packages/runtime/assets/renderer-inject.js`）

- `normalizeConfig` 读取 `statusText`  
- `applyProfile` 写 `--dream-status`  
- `ROOT_PROPERTIES` 含 `--dream-status`（cleanup 可清）  
- **未改**：IIFE 四参、`setTheme`/`cycleTheme`/F6、`MAX_CATALOG_ENTRIES=8`、catalog 预算路径  

### 3.3 Theme

- 未改默认 id；arina `theme.json` / runtime 模板仍粉系  
- 未引入 Fei `promoUrl` 强制 UI  

### 3.4 Docs

- `docs/design-tokens.md` 补 V2 token 行 + 修订表  

---

## 4. 验证证据

### 4.1 自动

```text
npm test
→ npm_test_exit=0
  (themes / themes-contracts / store / adapter / deps / freshness /
   cdp-url / catalog-budget / stamp / theme-load / probe-kit / contracts)

pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1
→ verify_payload_exit=0
  VERIFY OK publish runtime payload closed
  (theme-load + control-plane + required ESM graph)
```

### 4.2 手测 H1–H7

| # | 项 | 状态 |
|---|-----|------|
| H1–H7 | 装态 arina 真机 | **未跑**（本波 **无** publish 授权；装态仍旧 tip 时 CSS 不进机） |
| 说明 | 合入后 **另** 人 gate publish + 装态烟测 | 见 plan §6 / §7 |

建议合入后清单（人）：

1. publish-runtime（人 gate）→ doctor fresh  
2. H1 粉系 · H2 侧栏层次 · H3 composer 对比 · H4 hero 不压输入 · H5 F6 · H6 kick · H7 暗色  

---

## 5. 明确不做（本波遵守）

| 禁止 | 遵守 |
|------|------|
| push / 合 main | 是 |
| 真 publish-runtime | 是 |
| vendor 整树 / upstream remote | 是 |
| 默认改 Gothic | 是 |
| V3 整文件替换 css/inject | 是 |
| asar / 换前端框架 | 是 |
| contracts 大扩 / injector 模块图下一刀 | 留给 W2 |

---

## 6. 风险与残留

| 风险 | 缓解 / 残留 |
|------|-------------|
| Codex DOM 与选择器漂移 | 选择器沿用本仓 class；真机 probe 在 publish 后 |
| blur 回潮 | composer **固定 8px**；侧栏/header 仍 none |
| inject 破坏 F6 | 未触 cycle/setTheme；`npm test` catalog 门仍绿 |
| 装态与 tip 差一版 | **人 gate publish** 后才有 H1–H7 真证 |
| CLI `DEFAULT_THEME_ID=miku-488137` | 空库回退 id，**非** runtime 模板默认；文档已注明；不在 W1 改常量 |

---

## 7. 产出路径

| 路径 | 角色 |
|------|------|
| `docs/ops/stack-matrix-2026-07.md` | 栈矩阵 |
| `docs/ops/visual-align-fei-away-diff-2026-07-23.md` | 选择器/token 映射 |
| `docs/ops/w1-arch-upgrade-codexveil-claude.md` | 本报告 |
| `docs/design-tokens.md` | token 文档增量 |
| `packages/runtime/assets/dream-skin.css` | 视觉权威 CSS |
| `packages/runtime/assets/renderer-inject.js` | 注入权威（最小 diff） |

---

## 8. 建议下一刀（W2 / 人）

1. 人审 diff → merge feature 分支（非本 agent）  
2. 人 gate `publish-runtime` + H1–H7  
3. W2：contracts 公共 API 扩一圈 · injector 模块图强制 · 主题质量门  

**状态：** W1 enact **完成**（自动门绿 · 装态手测待 publish gate）。
