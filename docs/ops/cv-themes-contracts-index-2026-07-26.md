# 主题契约索引（2026-07-26）

## 范围

本仓主题系统涉及 `packages/themes` + `packages/contracts` + `themes/` 资源目录 + `packages/runtime/assets/` 注入 CSS/JS。**不改 asar** 是硬边界。

## 主题数据流

```text
themes/<id>/theme.json           # 源主题清单（heige 格式）
      ↓ dream-adapter 转换
packages/themes/dream-adapter    # 转 DreamSkin 格式写入安装态
      ↓
%LOCALAPPDATA%\CodexDreamSkin\active-theme\   # 当前生效主题
%LOCALAPPDATA%\CodexDreamSkin\themes\<id>\     # catalog（缩略图 + 控制 payload）
      ↓
packages/runtime/assets/dream-skin.css         # 注入 CSS（CSS 变量）
packages/runtime/assets/renderer-inject.js     # 页面桥（brand/art/tagline）
```

## 模块职责

| 模块 | 职责 | 非职责 |
|------|------|--------|
| `packages/themes/theme-schema.mjs` | 校验 `theme.json` schema、`normalizeColors` 四色落盘 | 不写 CDP、不启动进程 |
| `packages/themes/theme-store.mjs` | catalog 列表、`createSingleImageTheme`、图片校验 | 不写 active-theme |
| `packages/themes/dream-adapter.mjs` | `writeActiveThemeFromHeige`、`importAllBundledThemes`、`importHeigeThemeToCatalog` | 不注入 CSS |
| `packages/contracts/` | TS 契约：`parsePaletteWithSurface`、`isCssColor`、`CSS_COLOR_RE` | 不进 `versions/`（开发平面） |
| `packages/runtime/assets/` | 注入端 CSS/JS 资源 | 不写主题 schema |
| `themes/` | 内置主题源（arina-only） | 不含运行时逻辑 |

## 主题 schema（`theme.json`）

### 字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `schemaVersion` | `number` | 是 | 当前 `1` |
| `id` | `string` | 是 | `^[a-z0-9]+(?:-[a-z0-9]+)*$` |
| `name` | `string` | 是 | 显示名 |
| `palette.accent` | `string` | 是 | `#RRGGBB` 六位 |
| `palette.secondary` | `string` | 是 | `#RRGGBB` 六位 |
| `palette.surface` | `string` | 是 | `#RRGGBB` 六位 |
| `palette.text` | `string` | 是 | `#RRGGBB` 六位 |
| `art.focusX` | `number` | 是 | 构图焦点 |
| `art.focusY` | `number` | 是 | 构图焦点 |
| `art.safeArea` | `string` | 是 | `"left"` / `"right"` |
| `art.taskMode` | `string` | 是 | `"ambient"` / `"focus"` |
| `brandSubtitle` | `string` | 否 | 左上品牌字 |
| `tagline` | `string` | 否 | 空串不渲染 |
| `image` | `string` | 是 | 相对主题目录的图片文件名 |
| `hero` | `string` | 是（新格式） | 主视觉文件名 |

### 默认值

```js
{
  palette: { accent: "#4BC2E0", secondary: "#AD7ED5", surface: "#FAFAFF", text: "#122C60" },
  art: { focusX: 0.72, focusY: 0.45, safeArea: "left", taskMode: "ambient" }
}
```

### 安全限制

- 顶层禁止键（大小写不敏感）：`scripts`, `hooks`, `eval`, `executable`, `commands`, `main`, `bin`
- 图片扩展：`.png`, `.jpg`, `.jpeg`, `.webp`
- 源图上限：8MB（`MAX_SOURCE_IMAGE_BYTES`）
- 注入 payload 上限：~4MB（CDP evaluate）；catalog 只嵌缩略图

## 四色契约（themes ↔ contracts 对齐）

| 层 | 职责 | 正则 |
|----|------|------|
| `packages/themes` `normalizeColors` | 落盘 `#RRGGBB` | 硬编码 `HEX_COLOR = /^#[0-9A-F]{6}$/i` |
| `packages/contracts` `parsePaletteWithSurface` | 校验跨层 payload | `CSS_COLOR_RE`（更宽，兼容 `rgb`/`oklch`） |
| `packages/runtime/assets/renderer-inject.js` | 注入 CSS 变量 | `cssColor` 正则与 contracts 同源 |
| 对齐 | `npm run test:themes-contracts` | 把 `normalizeColors` 输出喂进 `parsePaletteWithSurface` |

## Catalog 操作

### 内置主题（仓内）

现行唯一内置：`preset-arina-hashimoto`（`themes/preset-arina-hashimoto/`）。
CLI `DEFAULT_THEME_ID` = `"preset-arina-hashimoto"`。
历史 11 套 ID 仅存 git 历史；扩内置须 ADR。

### 用户 catalog

安装态：`%LOCALAPPDATA%\CodexDreamSkin\themes\<id>`

| 操作 | 命令 | 路径 |
|------|------|------|
| 导入所有内置 | `node packages/core/cli.mjs import-themes` | admin/import-themes |
| 用户自建 | `createSingleImageTheme` | store/mjs |
| 列表 | `cli.mjs list` | theme-store.mjs → `listThemes()` |

### apply / kick 流程

```
cli apply --theme <id>
  → themes.writeActiveThemeFromHeige(id, themeRoot)
  → 更新 active-theme 文件戳
  → core.kickThemeInjectNow → POST http://127.0.0.1:9336/kick (x-codex-skin-token)
  → watch 重 apply（~45ms）
  → kick 未命中时降级 spawn 路径（应少见）
```

## 不改 asar 边界

| 操作 | 允许 | 禁止 |
|------|------|------|
| 读 active-theme | ✅ | — |
| 写 active-theme | ✅（经 themes 模块） | — |
| 读 catalog | ✅ | — |
| 注入 CSS/JS via CDP | ✅ | — |
| 修改 Codex Desktop `.asar` | ❌ | **永远禁止** |
| 修改 Codex 安装包 | ❌ | **永远禁止** |
| 直接写 Codex DOM 外 | ❌ | 不破坏官方签名 |

## 相关测试

| 命令 | 覆盖 |
|------|------|
| `npm run test:themes` | theme-schema + dream-adapter + theme-store 单元 |
| `npm run test:themes-contracts` | 四色对齐（`normalizeColors` → `parsePaletteWithSurface`） |
| `npm run test:contracts` | contracts 包自身 |
| `npm run test:store` | theme-store 单元 |
| `npm run test:adapter` | dream-adapter 单元 |
| `npm run test:freshness` | 安装态新鲜度 |
| `npm run test:catalog-budget` | catalog 缩略图预算 |
| `npm run test:deps` | core↔runtime 静态互引 |
| `npm test` | 全部单元 + contracts |

---

*本索引维护于 2026-07-26。`packages/themes/*.mjs` 为 SSOT。*