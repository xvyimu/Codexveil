/**
 * @file codex-app.mjs
 * @description Codex Desktop 发现与运行态诊断（编排层）
 *
 * 子模块：path-utils / process-win / cdp-port
 * 对外 API 保持不变。
 */
import { execFile } from "node:child_process";
import { access } from "node:fs/promises";
import { homedir } from "node:os";
import { posix, win32 } from "node:path";
import { promisify } from "node:util";

import { DEFAULT_CDP_PORT } from "../constants.mjs";
import { discoverActiveCdpPort, probeCdpPort } from "../cdp/cdp-port.mjs";
import { firstExisting, uniquePaths } from "./path-utils.mjs";
import {
  discoverMsixInstallLocations,
  isDesktopAppExe,
  isMainDesktopProcessLine,
  listWindowsProcessCommandLines,
  listWindowsProcessExecutablePaths,
  parseCdpPortFromCommandLine,
  scoreDesktopExe,
} from "./process-win.mjs";

export { discoverActiveCdpPort, probeCdpPort } from "../cdp/cdp-port.mjs";

const execFileAsync = promisify(execFile);

// uniquePorts lives once near classifyInjection (from original file body)

export function codexAppCandidates({
  platform = process.platform,
  env = process.env,
  home = homedir(),
  extra = [],
} = {}) {
  if (platform === "win32") {
    const localAppData = env.LOCALAPPDATA ?? win32.join(home, "AppData", "Local");
    const programFiles = env.ProgramFiles ?? "C:\\Program Files";
    const programFiles64 = env.ProgramW6432 ?? programFiles;
    // 注意：Local\Programs\OpenAI\Codex\bin 是 CLI，不是 Desktop，不进候选
    const staticCandidates = [
      win32.join(localAppData, "Programs", "ChatGPT", "ChatGPT.exe"),
      win32.join(localAppData, "Programs", "Codex", "Codex.exe"),
      win32.join(localAppData, "ChatGPT", "ChatGPT.exe"),
      win32.join(localAppData, "Codex", "Codex.exe"),
      win32.join(programFiles, "ChatGPT", "ChatGPT.exe"),
      win32.join(programFiles, "Codex", "Codex.exe"),
      win32.join(programFiles64, "ChatGPT", "ChatGPT.exe"),
      win32.join(programFiles64, "Codex", "Codex.exe"),
    ];
    return uniquePaths([...extra, ...staticCandidates]);
  }
  // 无管理员权限时 macOS 标准安装位是 ~/Applications，必须一并探测
  return uniquePaths([
    ...extra,
    "/Applications/ChatGPT.app",
    posix.join(home, "Applications", "ChatGPT.app"),
  ]);
}

export function bundledNodeCandidates(appPath, { platform = process.platform } = {}) {
  if (platform === "win32") {
    // MSIX 包内路径：...\OpenAI.Codex_x\app\ChatGPT.exe → resources 在 app 目录下
    // 独立安装：...\Codex\Codex.exe → resources 同级
    const appDir = win32.dirname(appPath);
    return [
      win32.join(appDir, "resources", "cua_node", "node.exe"),
      win32.join(appDir, "resources", "cua_node", "bin", "node.exe"),
    ];
  }
  return [posix.join(appPath, "Contents", "Resources", "cua_node", "bin", "node")];
}


export async function runtimeDiagnostics({
  platform = process.platform,
  appPath = "/Applications/ChatGPT.app",
  port = DEFAULT_CDP_PORT,
  exec = execFileAsync,
  fetchImpl = globalThis.fetch,
  autoDiscoverPort = true,
} = {}) {
  const result = {
    appVersion: null,
    processRunning: false,
    processHasDebugFlag: false,
    processDebugPorts: [],
    requestedPort: port,
    activePort: port,
    portOpen: false,
    portBrowser: null,
    portSource: "requested",
  };

  if (platform === "darwin") {
    try {
      const { stdout } = await exec("/usr/bin/defaults", [
        "read",
        posix.join(appPath, "Contents", "Info"),
        "CFBundleShortVersionString",
      ]);
      result.appVersion = stdout.trim() || null;
    } catch {}
    try {
      const { stdout } = await exec("/bin/ps", ["-axo", "command"]);
      const mainPrefix = posix.join(appPath, "Contents", "MacOS") + "/";
      const mains = stdout
        .split("\n")
        .filter((line) => line.startsWith(mainPrefix) && !/\s--type=/.test(line));
      result.processRunning = mains.length > 0;
      result.processHasDebugFlag = mains.some((line) => line.includes("--remote-debugging-port"));
      result.processDebugPorts = uniquePorts(
        mains.map((line) => parseCdpPortFromCommandLine(line)).filter((value) => value != null),
      );
    } catch {}
  }

  if (platform === "win32") {
    try {
      const lines = await listWindowsProcessCommandLines(exec);
      const mains = lines.filter(isMainDesktopProcessLine);
      // processRunning 只看 Desktop 主进程；CLI 的 codex.exe 不算
      result.processRunning = mains.length > 0;
      result.processHasDebugFlag = mains.some((line) => line.includes("--remote-debugging-port"));
      result.processDebugPorts = uniquePorts(
        mains.map((line) => parseCdpPortFromCommandLine(line)).filter((value) => value != null),
      );
    } catch {}
  }

  let probe = await probeCdpPort(port, { fetchImpl });
  if (!probe.open && autoDiscoverPort) {
    const discovered = await discoverActiveCdpPort({
      platform,
      preferredPort: port,
      exec,
      fetchImpl,
    });
    if (discovered.open) {
      probe = {
        port: discovered.port,
        open: true,
        browser: discovered.browser,
      };
      result.portSource = discovered.source;
    }
  }

  result.activePort = probe.port;
  result.portOpen = probe.open;
  result.portBrowser = probe.browser;
  return result;
}

function uniquePorts(ports) {
  return [...new Set(ports)];
}

export function classifyInjection(diag) {
  if (diag.portOpen) {
    if (
      Number.isInteger(diag.requestedPort) &&
      Number.isInteger(diag.activePort) &&
      diag.requestedPort !== diag.activePort
    ) {
      return `ok：端口开放（请求 ${diag.requestedPort}，实际活跃 ${diag.activePort}），可直接注入`;
    }
    return "ok：端口开放，可直接注入";
  }
  if (diag.processRunning && diag.processHasDebugFlag) {
    const ports = Array.isArray(diag.processDebugPorts) && diag.processDebugPorts.length
      ? `；进程声明端口：${diag.processDebugPorts.join(", ")}`
      : "";
    return `flag-present-port-closed：进程已带调试参数但端口未开放${ports}，当前版本可能禁用了调试端口，或端口与默认值不一致，请附本 JSON 开 Issue`;
  }
  if (diag.processRunning) {
    return "running-no-flag：实例未带调试参数（可能被旧实例接管或参数被丢弃），请完全退出 Codex 后重跑 apply.command";
  }
  return "not-running：Codex 未在运行";
}

export async function discoverCodex({
  platform = process.platform,
  env = process.env,
  home = homedir(),
  exists = (path) => access(path).then(() => true, () => false),
  exec = execFileAsync,
} = {}) {
  const dynamic = [];

  if (platform === "win32") {
    // 优先级：用户指定 > 运行中的 Desktop 主进程 > MSIX 安装位 > 静态候选
    // CLI（Programs\OpenAI\Codex\bin）绝不进候选，否则会盖住商店版真身。
    if (env.HEIGE_CODEX_APP) dynamic.push(env.HEIGE_CODEX_APP);
    dynamic.push(...(await listWindowsProcessExecutablePaths(exec)));
    dynamic.push(...(await discoverMsixInstallLocations({ env, home, exec, exists })));
  }

  const candidates = codexAppCandidates({ platform, env, home, extra: dynamic }).filter(
    (path) => platform !== "win32" || isDesktopAppExe(path) || scoreDesktopExe(path) === 0,
  );
  // static 候选 score 可能为 0（路径尚未确认是否存在），保留；负分路径直接丢掉
  const ranked = candidates
    .filter((path) => scoreDesktopExe(path) >= 0 || !String(path).toLowerCase().includes("openai\\codex\\bin"))
    .sort((left, right) => scoreDesktopExe(right) - scoreDesktopExe(left));
  const ordered = ranked.length ? ranked : candidates;

  const app = await firstExisting(ordered, exists);
  const nodeCandidates = app ? bundledNodeCandidates(app, { platform }) : [];
  const bundledNode = app ? await firstExisting(nodeCandidates, exists) : null;
  return {
    platform,
    app: app ?? ordered[0] ?? candidates[0],
    appFound: app !== null,
    candidates: ordered,
    bundledNode: bundledNode ?? nodeCandidates[0] ?? null,
    bundledNodeFound: bundledNode !== null,
  };
}
