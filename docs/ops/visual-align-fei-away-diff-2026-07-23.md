# 视觉对齐 Fei-Away V2 · 选择器/token 映射 · 2026-07-23

> Plan：`D:\orca\.planning\week-next-2026-07-23\repos\cv-visual-align-v2.md`  
> 对照快照：`D:\orca\.planning\week-next-2026-07-23\upstream-snapshot\`  
> 本仓权威：`packages/runtime/assets/dream-skin.css` · `renderer-inject.js`  
> **默认观感：arina 粉系** · **禁止**整文件替换 · ADR 0006

## 0. 资产规模（快照日）

| 资产 | 本仓 | Fei-Away win 快照 |
|------|------|-------------------|
| `dream-skin.css` | ~675 行 · oklch/`--dream-*` · 根类 `codex-dream-skin` | ~971 行 · rgb/`--ds-*` · 根 `data-dream-skin=active` |
| `renderer-inject.js` | ~815 行 · **4 参** `(css, art, config, catalog)` · F6/cycleTheme | ~687 行 · 单主题 config · 无 catalog F6 |
| 默认 theme | `assets/theme.json` + `themes/preset-arina-hashimoto` · accent `#E8A0BF` | arina 字段齐但公开包偏 Gothic |

## 1. Token 映射表（Fei → 本仓）

| Fei-Away | 本仓 | 映射策略 |
|----------|------|----------|
| `--ds-accent` / `--ds-green` 等硬编码 | `--dream-accent`（主题 palette 写入） | **保留** inject `setProperty(--dream-accent)`；arina 粉 |
| `--ds-bg` / panel / panel-2 | `--dream-canvas` / `--dream-surface` / `--dream-surface-raised` | color-mix(oklab, oklch…, accent) |
| `--ds-text` / `--ds-muted` | `--dream-text` / `--dream-text-muted` | 暗色根类 `dream-theme-dark` 重映射 |
| `--ds-line` | `--dream-line` / `--dream-line-soft` | 同上 |
| `--ds-immersive-edge/mid/far` | `--dream-immersive-*` | 已有；W1 微调不透明阶 |
| `--ds-immersive-sidebar` | `--dream-immersive-sidebar` | 已有 |
| `--ds-immersive-composer` / `-solid` | `--dream-immersive-composer`（+ 本波 solid 变体） | solid → denser color-mix(accent) |
| `--ds-hero-scrim` 多 stop 渐变 | `--dream-hero-shade` + 选择器 gradient | **promote**：多 stop 用 shade token |
| `--ds-focus-x/y` · art-position | `--dream-focus-x/y` · `--dream-art-position` | inject 已写；safe 类 `dream-safe-*` |
| `--dream-skin-art` | `--dream-art` | 命名不同，语义同 |
| `--dream-skin-status` 等文案变量 | `--dream-brand` / `--dream-headline` / 本波 `--dream-status` | 对齐 status 写入；**不**强制 promo UI |
| 根 `data-dream-shell=light` | 类 `dream-theme-light` / `dream-theme-dark` | **不**改成 data-attr 体系 |

## 2. 选择器对照（白名单区域）

### P0 · composer

| 区域 | 本仓选择器 | Fei 倾向 | W1 决策 |
|------|------------|----------|---------|
| 输入岛 | `html.codex-dream-skin .composer-surface-chrome` | blur **16px** · panel 94% | **吸收层次**：背景略抬 + 内高光阴影；**blur 保持 8px**（防 1.3.12 冻窗回潮） |
| 光标/字 | `.ProseMirror` caret `var(--dream-accent)` | 高对比 | **保持** + 确认 color text token |
| wide 沉浸 | `.composer-surface-chrome::before { content:none }` | 同 | 已有，不动 |

### P0 · hero / art 焦点

| 区域 | 本仓 | Fei | W1 决策 |
|------|------|-----|---------|
| home hero 卡 | `.dream-home > … > div:first-child::before` 用 `--dream-hero-shade` 单 stop | `--ds-hero-scrim` 多 stop 90→76→18 | **promote** 多 stop，仍 `var(--dream-hero-shade)` / surface mix |
| safeArea left/right/center/none | `.dream-safe-*` 翻转 gradient | `data-dream-art-safe-*` | 结构已有；增强 center radial |
| body 右半 hero | `body::before` mask 38%→100% | 不同实现 | **不**整段替换；保持 heige 右半策略 |

### P1 · 侧栏

| 区域 | 本仓 | Fei | W1 决策 |
|------|------|-----|---------|
| `aside.app-shell-left-panel` | 实色 `--dream-sidebar` · `backdrop-filter: none` | 竖向 panel→bg 渐变 · 圆角右 | **promote** 轻竖向 color-mix 渐变 + 右 inset 线；**仍无 blur** |
| wide immersive 侧栏 | linear immersive-sidebar→edge | 同构 | 已有，微调 token 可选 |

### P1 · 首页卡片 / raised

| 区域 | 本仓 | Fei | W1 决策 |
|------|------|-----|---------|
| suggestions | `.group/home-suggestions button` surface-raised | glass + accent 图标 | **promote** raised 混入更多 accent（粉系）；hover 仍 accent-soft |

### P2 · 沉浸会话 / 文案

| 区域 | 状态 |
|------|------|
| immersive edge/mid/far | 已有 token；本波不加重会话 blur |
| brand/tagline 节点 | inject 已写 `--dream-brand` / `--dream-headline`；CSS 故意 `content:none` 防挡对话 |
| statusText | Fei 有 `--dream-skin-status`；本波 inject **补** `--dream-status`（无强制 UI 广告） |

## 3. Inject 对照（最小视觉）

| 能力 | 本仓 | Fei | W1 |
|------|------|-----|-----|
| 签名 | `(cssText, artDataUrl, rawConfig, themeCatalog)` | 单主题 | **禁止**改签名 |
| F6 / cycleTheme / setTheme | 有 | 无 | **保留** |
| catalog 预算 8 | 有 | 无 | **保留** |
| palette → CSS vars | accent/secondary/text/art | `--dream-skin-*` 命名 | 保持 `--dream-*` |
| statusText | 主题有字段，inject 未写 CSS var | 有 | **补写** `--dream-status` |
| promoUrl | 无强制 UI | 字段可能存在 | **不**引入强制 promo |

## 4. Promote 黑名单（再确认）

- 整文件 `cp` css/inject  
- Gothic 为 default active  
- 删除 `dream-theme-dark` / oklch 根 token  
- 会话气泡全局 blur 恢复到 Fei 7–14px  
- composer blur 16px  
- vendor / asar / publish

## 5. arina 粉系锚点

| 字段 | 值 |
|------|-----|
| theme id | `preset-arina-hashimoto` |
| accent | `#E8A0BF` |
| secondary | `#C9A0DC` |
| surface / text | `#1A1218` / `#FFF0F5` |
| art focus | 0.72 / 0.45 · safeArea `left` · taskMode `ambient` |
| runtime 模板 | `packages/runtime/assets/theme.json` **= arina** |

> 注：`packages/core/constants.mjs` 的 `DEFAULT_THEME_ID = miku-488137` 是 CLI/空库回退 id，**不是** runtime 装机模板默认；产品装机模板与本波视觉默认仍为 arina。

## 6. W1 实施清单（enact）

| ID | 动作 | 文件 |
|----|------|------|
| CV-V-DIFF | 本文 | `docs/ops/visual-align-fei-away-diff-2026-07-23.md` |
| CV-V-CSS | 白名单 promote | `packages/runtime/assets/dream-skin.css` |
| CV-V-INJ | status 变量 + 注释 | `packages/runtime/assets/renderer-inject.js` |
| CV-V-THEME | 无改默认 id | arina 已齐 |
| CV-V-DOC | stack-matrix + design-tokens 补一行 | `docs/ops/*` · `docs/design-tokens.md` |
| CV-V-VER | npm test · verify-payload | 报告 exit code |

## 7. 修订

| 日期 | 说明 |
|------|------|
| 2026-07-23 | W1 DIFF 表初版 + 与 enact 同步 |
