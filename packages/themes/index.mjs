/**
 * @file packages/themes/index.mjs
 * @description 主题 schema / 目录库 / DreamSkin 适配写入
 *
 * 数据落点（安装态）：
 * - active-theme  → %LOCALAPPDATA%\CodexDreamSkin\active-theme
 * - catalog       → %LOCALAPPDATA%\CodexDreamSkin\themes\<id>
 *
 * heige 源主题（开发仓 themes/）通过 dream-adapter 转成 DreamSkin 可热加载格式。
 */
export { loadTheme, validateThemeManifest } from "./theme-schema.mjs";
export { createSingleImageTheme, listThemes } from "./theme-store.mjs";
export {
  heigeManifestToDreamSkin,
  importAllBundledThemes,
  importHeigeThemeToCatalog,
  touchThemesCatalog,
  writeActiveThemeFromHeige,
} from "./dream-adapter.mjs";
