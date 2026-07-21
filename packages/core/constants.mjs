/**
 * @file constants.mjs
 * @description 产品常量与路径解析（Windows 安装态 + 开发态）
 *
 * 路径约定（不要散落硬编码）：
 * - installRoot     %LOCALAPPDATA%\Programs\CodexDreamSkin
 * - dreamStateRoot  %LOCALAPPDATA%\CodexDreamSkin   ← active-theme / themes / state
 * - devStateRoot    %APPDATA%\CodexSkin             ← 仅开发旁路
 */
import { homedir } from "node:os";
import { join } from "node:path";

export const PRODUCT_ID = "codex-skin";
export const PRODUCT_NAME = "Codex Skin";
/**
 * Node-side docs/export marker only (value 1).
 * Install-side `%LOCALAPPDATA%\CodexDreamSkin\state.json` is written by
 * launcher-ui as **schemaVersion: 3** (accepted range 1..3 on read).
 * Do not treat this constant as the on-disk write version.
 */
export const STATE_SCHEMA_NODE_MARKER = 1;
/**
 * @deprecated Prefer STATE_SCHEMA_NODE_MARKER; alias kept for compatibility.
 */
export const STATE_SCHEMA_VERSION = STATE_SCHEMA_NODE_MARKER;
/** theme.json / catalog manifest schema (heige + DreamSkin dual-format). */
export const THEME_SCHEMA_VERSION = 1;
export const DEFAULT_THEME_ID = "miku-488137";

/** 与 DreamSkin / 现网 Store Codex 会话对齐的默认 CDP 端口 */
export const DEFAULT_CDP_PORT = 9335;

/** 控制面默认 loopback 端口（与 runtime control-plane.mjs DEFAULT_PORT 对齐） */
export const DEFAULT_CONTROL_PORT = 9336;

export const EXPECTED_BUNDLE_ID = "com.openai.codex";
export const EXPECTED_TEAM_ID = "2DC432GLL2";

/** CSS 合法 hex：3/4/6/8 位 */
export const HEX_COLOR =
  /^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i;

/**
 * 解析本机 Codex Skin 相关目录。
 * @param {{ home?: string, platform?: NodeJS.Platform, env?: NodeJS.ProcessEnv }} [opts]
 */
export function resolveStudioPaths({
  home = homedir(),
  platform = process.platform,
  env = process.env,
} = {}) {
  const localAppData = env.LOCALAPPDATA ?? join(home, "AppData", "Local");
  const appData = env.APPDATA ?? join(home, "AppData", "Roaming");
  const dreamStateRoot = join(localAppData, "CodexDreamSkin");
  const devStateRoot =
    platform === "win32"
      ? join(appData, "CodexSkin")
      : join(home, "Library", "Application Support", "CodexSkin");

  return {
    installRoot: join(localAppData, "Programs", "CodexDreamSkin"),
    dreamStateRoot,
    /** @deprecated 使用 dreamStateRoot；保留兼容旧调用 */
    stateRoot: dreamStateRoot,
    statePath: join(dreamStateRoot, "state.json"),
    logPath: join(dreamStateRoot, "injector.log"),
    activeThemeRoot: join(dreamStateRoot, "active-theme"),
    /** 与 DreamSkin 共用的已保存主题库（F6 / 托盘 catalog） */
    userThemesRoot: join(dreamStateRoot, "themes"),
    /** 开发调试旁路主题目录（不进日常入口） */
    devThemesRoot: join(devStateRoot, "themes"),
    devStateRoot,
  };
}
