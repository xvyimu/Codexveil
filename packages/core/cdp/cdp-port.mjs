/** @file cdp-port.mjs - CDP 端口探测与自动发现 */
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { DEFAULT_CDP_PORT } from "../constants.mjs";
import {
  isMainDesktopProcessLine,
  listWindowsProcessCommandLines,
  parseCdpPortFromCommandLine,
} from "../discover/process-win.mjs";
import { isValidPort } from "./cdp-helpers.mjs";

const execFileAsync = promisify(execFile);

export async function probeCdpPort(
  port,
  { fetchImpl = globalThis.fetch, timeoutMs = 1500 } = {},
) {
  if (!isValidPort(port)) {
    return { port, open: false, browser: null };
  }
  try {
    const response = await fetchImpl(`http://127.0.0.1:${port}/json/version`, {
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response.ok) return { port, open: false, browser: null };
    const version = await response.json().catch(() => null);
    return { port, open: true, browser: version?.Browser ?? null };
  } catch {
    return { port, open: false, browser: null };
  }
}

// 从正在运行的 Codex 主进程命令行读出真实 CDP 端口。
// 商店版/第三方启动器常用 9335 等非默认端口，写死 9341 会误诊成 port-closed。
export async function discoverActiveCdpPort({
  platform = process.platform,
  preferredPort = DEFAULT_CDP_PORT,
  exec = execFileAsync,
  fetchImpl = globalThis.fetch,
} = {}) {
  const candidates = [];
  if (Number.isInteger(preferredPort)) candidates.push(preferredPort);

  if (platform === "win32") {
    try {
      const lines = await listWindowsProcessCommandLines(exec);
      for (const line of lines) {
        if (!isMainDesktopProcessLine(line)) continue;
        const port = parseCdpPortFromCommandLine(line);
        if (port != null) candidates.push(port);
      }
    } catch {
      // 进程枚举失败时仍尝试 preferredPort
    }
  } else if (platform === "darwin") {
    try {
      const { stdout } = await exec("/bin/ps", ["-axo", "command"]);
      for (const line of stdout.split("\n")) {
        if (!/ChatGPT\.app\/Contents\/MacOS\//.test(line)) continue;
        if (/\s--type=/.test(line)) continue;
        const port = parseCdpPortFromCommandLine(line);
        if (port != null) candidates.push(port);
      }
    } catch {}
  }

  // 常见候选兜底：用户手动起过 9335/9222 时，doctor/apply 不带 --port 也能命中
  for (const fallback of [DEFAULT_CDP_PORT, 9335, 9222]) candidates.push(fallback);

  const tried = new Set();
  for (const port of candidates) {
    if (!isValidPort(port) || tried.has(port)) continue;
    tried.add(port);
    const probe = await probeCdpPort(port, { fetchImpl });
    if (probe.open) {
      return {
        port: probe.port,
        open: true,
        browser: probe.browser,
        source: port === preferredPort ? "preferred" : "discovered",
        candidates: [...tried],
      };
    }
  }

  return {
    port: preferredPort,
    open: false,
    browser: null,
    source: "fallback",
    candidates: [...tried],
  };
}

// 运行态诊断：版本号、进程是否带调试参数、端口是否开放。
// （实现见 discover/codex-app.mjs · runtimeDiagnostics）
