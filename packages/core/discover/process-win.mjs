/** @file process-win.mjs - Windows 进程/MSIX 探测（Desktop vs CLI） */
import { execFile } from "node:child_process";
import { access, readdir } from "node:fs/promises";
import { homedir } from "node:os";
import { win32 } from "node:path";
import { promisify } from "node:util";
import { isValidPort } from "../cdp/cdp-helpers.mjs";
import { uniquePaths } from "./path-utils.mjs";

const execFileAsync = promisify(execFile);
const CDP_PORT_FLAG = /--remote-debugging-port(?:=|\s+)(\d{4,5})\b/i;

export function parseCdpPortFromCommandLine(commandLine) {
  if (typeof commandLine !== "string" || !commandLine.trim()) return null;
  const match = commandLine.match(CDP_PORT_FLAG);
  if (!match) return null;
  const port = Number(match[1]);
  if (!isValidPort(port)) return null;
  return port;
}

export function isMainDesktopProcessLine(line) {
  if (typeof line !== "string" || !line.trim()) return false;
  // 排除 renderer/gpu/utility 子进程：它们也会带 --remote-debugging-port，但不是主入口
  if (/\s--type=/.test(line)) return false;
  // CLI / app-server 不是 Desktop，不算「桌面端在跑」
  if (/\\programs\\openai\\codex\\bin\\/i.test(line)) return false;
  if (/\\resources\\codex(?:-code-mode-host)?\.exe/i.test(line)) return false;
  // Desktop 主入口：ChatGPT.exe，或 MSIX/独立安装目录下的 Codex.exe（不含 resources）
  if (/chatgpt\.exe/i.test(line)) return true;
  if (/windowsapps\\openai\.codex[^\\]*\\app\\codex\.exe/i.test(line)) return true;
  if (/\\(?:chatgpt|codex)\\codex\.exe/i.test(line) && !/\\resources\\/i.test(line)) return true;
  return false;
}

export async function listWindowsProcessCommandLines(exec) {
  const { stdout } = await exec("powershell", [
    "-NoProfile",
    "-Command",
    "Get-CimInstance Win32_Process -Filter \"Name='ChatGPT.exe' or Name='Codex.exe'\" | Select-Object -ExpandProperty CommandLine",
  ]);
  return stdout.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
}

export async function listWindowsProcessExecutablePaths(exec) {
  try {
    // 只收桌面主进程路径：排除 renderer 子进程、CLI bin、resources 里的 app-server。
    const { stdout } = await exec("powershell", [
      "-NoProfile",
      "-Command",
      "Get-CimInstance Win32_Process -Filter \"Name='ChatGPT.exe' or Name='Codex.exe'\" | Where-Object { $_.ExecutablePath -and $_.CommandLine -and $_.CommandLine -notmatch '\\s--type=' } | Select-Object -ExpandProperty ExecutablePath",
    ]);
    const paths = uniquePaths(
      stdout
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line && /\.exe$/i.test(line) && isDesktopAppExe(line)),
    );
    return paths.sort((left, right) => scoreDesktopExe(right) - scoreDesktopExe(left));
  } catch {
    return [];
  }
}

export function isDesktopAppExe(path) {
  return scoreDesktopExe(path) > 0;
}

export function scoreDesktopExe(path) {
  const lowered = String(path).toLowerCase().replaceAll("/", "\\");
  // CLI / app-server 永远不当成 Desktop
  if (lowered.includes("\\programs\\openai\\codex\\bin\\")) return -100;
  if (lowered.includes("\\resources\\codex.exe")) return -100;
  if (lowered.includes("\\resources\\codex-code-mode-host.exe")) return -100;
  if (lowered.endsWith("\\codex-code-mode-host.exe")) return -100;

  let score = 0;
  if (lowered.endsWith("\\chatgpt.exe")) score += 50;
  if (lowered.includes("\\app\\chatgpt.exe") || lowered.includes("\\app\\codex.exe")) score += 40;
  if (lowered.includes("windowsapps\\openai.codex")) score += 30;
  if (lowered.endsWith("\\codex.exe") && !lowered.includes("\\resources\\")) score += 10;
  return score;
}

export async function discoverMsixInstallLocations({
  env = process.env,
  home = homedir(),
  exec = execFileAsync,
  exists = (path) => access(path).then(() => true, () => false),
} = {}) {
  const locations = [];

  // Appx 包元数据最准；失败时退回扫 WindowsApps 目录
  try {
    const { stdout } = await exec("powershell", [
      "-NoProfile",
      "-Command",
      "Get-AppxPackage | Where-Object { -not $_.IsFramework -and ($_.Name -eq 'OpenAI.Codex' -or $_.Name -match 'OpenAI\\.(Codex|ChatGPT)') } | Select-Object -ExpandProperty InstallLocation",
    ]);
    for (const line of stdout.split(/\r?\n/)) {
      const location = line.trim();
      if (location) locations.push(location);
    }
  } catch {
    // 无 Appx 权限或 PowerShell 受限时走目录扫描
  }

  const programFiles64 = env.ProgramW6432 ?? env.ProgramFiles ?? "C:\\Program Files";
  const windowsAppsRoots = uniquePaths([
    win32.join(programFiles64, "WindowsApps"),
    "C:\\Program Files\\WindowsApps",
    "D:\\WindowsApps",
    win32.join(env.SystemDrive ?? "C:", "Program Files", "WindowsApps"),
  ]);

  for (const root of windowsAppsRoots) {
    if (!(await exists(root))) continue;
    let entries = [];
    try {
      entries = await readdir(root, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (!/^OpenAI\.(Codex|ChatGPT)_/i.test(entry.name)) continue;
      locations.push(win32.join(root, entry.name));
    }
  }

  const exePaths = [];
  for (const location of uniquePaths(locations)) {
    for (const name of ["ChatGPT.exe", "Codex.exe"]) {
      exePaths.push(win32.join(location, "app", name));
      exePaths.push(win32.join(location, name));
    }
  }
  return exePaths;
}
