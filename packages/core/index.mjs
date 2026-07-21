/**
 * @file packages/core/index.mjs
 * @description Codex Skin 核心模块出口（发现 / 诊断 / 常量 / 双开守卫）
 *
 * 子目录布局：
 * - constants.mjs      产品常量 + resolveStudioPaths
 * - cdp/               Chrome DevTools Protocol 客户端 + 目标筛选 + 端口探测
 * - discover/          Codex 桌面 app 发现 + 进程扫描 + 路径工具
 * - state/             DreamSkin 状态守卫 · kick 调用 · injector 新鲜度 · state-io
 *
 * 边界：
 * - 本包不直接写 active-theme（主题写入在 packages/themes）
 * - 本包不做页面 CSS 注入（在 packages/runtime watch injector）
 * - 日常启动仍走 PowerShell launcher（apps/launcher + packages/core-win）
 * - state-io 仅包内共享，不向 runtime 导出（保持 runtime 自包含）
 */
export {
  DEFAULT_CDP_PORT,
  DEFAULT_CONTROL_PORT,
  DEFAULT_THEME_ID,
  HEX_COLOR,
  PRODUCT_ID,
  PRODUCT_NAME,
  STATE_SCHEMA_NODE_MARKER,
  STATE_SCHEMA_VERSION,
  THEME_SCHEMA_VERSION,
  resolveStudioPaths,
} from "./constants.mjs";

export {
  classifyInjection,
  codexAppCandidates,
  discoverActiveCdpPort,
  discoverCodex,
  probeCdpPort,
  runtimeDiagnostics,
} from "./discover/codex-app.mjs";

export {
  detectDreamSkinRuntime,
  dualOpenBlockedMessage,
  shouldBlockApplyForDreamSkin,
} from "./state/dreamskin-guard.mjs";

export {
  CdpSession,
  fetchRendererTargets,
  filterRendererTargets,
  waitForRendererTargets,
} from "./cdp/cdp-client.mjs";

export {
  formatKickResultNote,
  kickThemeInjectNow,
} from "./state/kick-inject.mjs";

export { inspectInjectorPathFreshness } from "./state/state-freshness.mjs";
