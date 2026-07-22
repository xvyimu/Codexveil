# Design tokens（codex-skin 视觉变量）

> **权威实现**：`packages/runtime/assets/dream-skin.css`（`:root.codex-dream-skin`）  
> **注入**：`packages/runtime/assets/renderer-inject.js` 将主题 `palette` / `art` 写入部分变量  
> **原则**：默认 **S1 克制工具向**（可读优先）；主题用 palette 表达个性，避免在选择器里硬编码颜色绕过 token  
> **相关**：[`CONTRIBUTING.md`](./CONTRIBUTING.md) 主题可读性清单 · 调研 v3 UX 章 · 上游 promote 决策（勿盲合 CSS）

本文档供主题作者与改 CSS 的维护者使用。改 token 语义后请同步本文。

---

## 1. 使用方式

1. 全局皮肤类：`html`/`root` 带 `codex-dream-skin`。  
2. 暗色：再加 `dream-theme-dark`（由注入层按主题/系统策略切换）。  
3. 主题 JSON 的 `palette.accent|secondary|surface|text`（或 heige `colors`）映射到 accent 等；**不要**在 theme 里放 `scripts`/`hooks`（schema 拒绝）。  
4. 业务 CSS 优先 `var(--dream-*)`，禁止散落 `#rrggbb` 除非注释说明例外。

---

## 2. 核心色板（Light 默认）

| Token | 角色 | 调色建议 |
|-------|------|----------|
| `--dream-accent` | 品牌主色；大量 `color-mix` 的源 | 主题 `palette.accent`；避免极低彩度导致「没皮肤」 |
| `--dream-accent-ink` | 落在 accent 上的字/图标 | 与 accent 强对比 |
| `--dream-text` | 主正文 | 相对 surface/canvas 高对比 |
| `--dream-text-muted` | 次要说明 | 弱于 text，但不可接近背景消失 |
| `--dream-canvas` | 页面大地色 | 略偏 accent 的中性底 |
| `--dream-surface` | 主面板 | 层级介于 canvas 与 raised |
| `--dream-surface-raised` | 浮起面板/卡片 | 略亮于 surface |
| `--dream-sidebar` | 左栏 | 与主区可区分 |
| `--dream-line` / `--dream-line-soft` | 分割线 | 低对比线，勿抢正文 |
| `--dream-accent-soft` / `--dream-accent-hover` | 悬停/浅强调 | 交互态 |

实现上 canvas/surface/sidebar 多由 **accent 与中性 oklch 的 color-mix** 生成，故改 accent 会「整板跟着变」。

---

## 3. 暗色（`.dream-theme-dark`）

同一套 token 名，重映射为冷灰底 + 高亮 text（oklch 蓝色相偏置）。  
验收：暗色下 text/muted 仍可读；accent 按钮字用 `--dream-accent-ink` 或等价对比。

---

## 4. 氛围与沉浸

| Token | 角色 | 注意 |
|-------|------|------|
| `--dream-art-position` | hero 焦点（如 `72% 45%`） | 勿让焦点盖住 composer |
| `--dream-hero-shade` | 图上遮罩 | 保字可读 |
| `--dream-ambient-opacity` | 氛围强度 | 性能敏感；默认约 0.18–0.22 |
| `--dream-shadow` | 浮起阴影 | 克制 |
| `--dream-immersive-edge/mid/far` | 沉浸渐变 | 会话页慎加重 |
| `--dream-immersive-sidebar` / `--dream-task-immersive-*` | 任务/侧栏沉浸 | 与 taskMode 相关 |
| `--dream-immersive-composer` | 输入区混合 | 保持输入对比 |
| `--dream-immersive-composer-solid` | 宽图会话搜索/输入实底 | V2 桥接；略浓于 composer，仍 oklch mix |
| `--dream-composer-fill` / `--dream-composer-edge` | home composer 岛填充/描边 | V2；blur 仍 8px |
| `--dream-status` | 主题 statusText（可选 CSS 消费） | inject 写入；无强制 UI |
| `--dream-immersive-line` | 沉浸分割 | |

**性能**：侧栏实现使用 `backdrop-filter: none`（历史去 blur）。新增大面积 blur 需发版 probe + 弱机手测，默认不恢复全局 blur。

---

## 5. 字体

`body`：`"Segoe UI Variable Text", "Segoe UI", "Microsoft YaHei UI", system-ui, sans-serif`。  
主题一般不改字体栈；若改须中西文回退完整。

---

## 6. 动效

按钮等过渡约 **180ms**，`cubic-bezier(.22, 1, .36, 1)`。  
禁止无限循环装饰动画抢 CPU。新动效 ≤200ms 交互反馈为默认。

---

## 7. 主题 JSON ↔ token 映射（概念）

| 主题字段 | 影响 |
|----------|------|
| `palette.accent` / `colors.accent` | `--dream-accent` 及 mix 链 |
| `palette.text` / `colors.text` | 倾向主文本 |
| `palette.surface` / `colors.surface` | 表面倾向 |
| `palette.secondary` | 次强调（视注入实现） |
| `art.focusX/focusY` | 构图安全区 → art-position 类 |
| `brandSubtitle` / `tagline` | 品牌字（空 tagline 不渲染） |

具体写入以 `renderer-inject.js` 为准；改映射须 publish + conversation/home probe。

---

## 8. 改 CSS 的验收最低集

1. `npm test`  
2. 若改 `packages/runtime/**`：`publish-runtime.ps1 -Version 1.3.25` + `verify-install-matches-repo.ps1`  
3. `doctor` fresh  
4. `Run-ReleaseProbes.ps1`（会话场景须 `conversationCovered=true`）  
5. 目视：侧栏、composer、会话气泡正文  

---

## 9. 禁止

- 主题包可执行字段（schema 已拒）  
- 盲 `Copy-Item` 上游 CSS 覆盖本地 token/stamp（见 upstream-promote-decision）  
- 为氛围牺牲正文对比  
- 非 loopback / 第二 injector「方便调样式」  

---

## 10. 修订

| 日期 | 说明 |
|------|------|
| 2026-07-23 | W1 V2：composer-fill/edge · immersive-composer-solid · status（见 `docs/ops/visual-align-fei-away-diff-2026-07-23.md`） |
| 2026-07-21 | U1 初版：从 dream-skin.css 提炼 token 表与门禁 |