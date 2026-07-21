/**
 * @file dreamskin-guard.mjs
 * @description 检测 DreamSkin 是否仍管日常入口（只做诊断，不做拦截）。
 * summary: not-installed | paused | active-injector | installed-idle
 * apply（hot-active-theme）默认写 active-theme + kick 控制面；本模块给
 * doctor/CLI 输出运行时状态，方便判断是否已装/是否 paused/是否有 injector。
 */
import { join } from "node:path";
import { resolveStudioPaths } from "../constants.mjs";
import { isValidPort } from "../cdp/cdp-helpers.mjs";
import { isProcessAlive, pathExists, readJsonFile, readTextTrim } from "./state-io.mjs";

/**
 * 检测本机 CodexDreamSkin 运行时状态（doctor 诊断用）。
 */
export async function detectDreamSkinRuntime({
  stateRoot = resolveStudioPaths().dreamStateRoot,
  env = process.env,
} = {}) {
  const root = env.CODEX_DREAM_SKIN_STATE ?? stateRoot;
  const statePath = join(root, "state.json");
  const pauseFile = join(root, "paused");
  const activeTheme = join(root, "active-theme", "theme.json");
  const themesLock = join(root, "themes", "themes.locked");

  const controlPortFile = join(root, "control.port");
  const controlTokenFile = join(root, "control.token");
  const result = {
    stateRoot: root,
    statePath,
    present: false,
    paused: false,
    locked: false,
    injectorAlive: false,
    injectorPid: null,
    port: null,
    browserId: null,
    activeThemePresent: false,
    controlPortFile,
    controlTokenFile,
    controlPort: null,
    controlTokenPresent: false,
    summary: "not-installed",
  };

  const [hasState, hasPause, hasActive, hasLock, hasPortFile, hasTokenFile] = await Promise.all([
    pathExists(statePath),
    pathExists(pauseFile),
    pathExists(activeTheme),
    pathExists(themesLock),
    pathExists(controlPortFile),
    pathExists(controlTokenFile),
  ]);
  if (!hasState && !hasActive) return result;

  result.present = true;
  result.paused = hasPause;
  result.locked = hasLock;
  result.activeThemePresent = hasActive;
  result.controlTokenPresent = hasTokenFile;

  if (hasPortFile) {
    try {
      const n = Number(await readTextTrim(controlPortFile));
      if (isValidPort(n)) result.controlPort = n;
    } catch {
      // ignore
    }
  }

  if (hasState) {
    try {
      const state = await readJsonFile(statePath);
      result.injectorPid = Number.isInteger(state?.injectorPid) ? state.injectorPid : null;
      result.port = Number.isInteger(state?.port) ? state.port : null;
      result.browserId = typeof state?.browserId === "string" ? state.browserId : null;
      result.injectorAlive = isProcessAlive(result.injectorPid);
      if (result.controlPort == null && isValidPort(state?.controlPort)) {
        result.controlPort = state.controlPort;
      }
    } catch {
      // 坏 state 仍视为「本机装过 DreamSkin」
    }
  }

  if (result.paused) {
    result.summary = "paused";
  } else if (result.injectorAlive) {
    result.summary = "active-injector";
  } else if (result.present) {
    result.summary = "installed-idle";
  }
  return result;
}

export function dualOpenBlockedMessage(dream) {
  const portText = dream.port ? `CDP ${dream.port}` : "CDP 9335";
  return [
    "检测到 CodexDreamSkin 仍是本机日常皮肤入口。",
    `状态：${dream.summary}${dream.injectorPid ? `（injectorPid=${dream.injectorPid}）` : ""}；${portText}。`,
    "日常请用开始菜单 / 任务栏「Codex」（Dream Skin 启动器）。",
    `DreamSkin 数据目录：${dream.stateRoot}`,
  ].join("\n");
}

export function shouldBlockApplyForDreamSkin(dream, { force = false } = {}) {
  if (force) return false;
  if (!dream?.present) return false;
  if (dream.paused) return false;
  // injector 活着，或 active-theme 存在且未 pause：都视为日常产品线在管
  return dream.injectorAlive || dream.activeThemePresent;
}
