/**
 * @file kick-inject.mjs
 * @description 主题写入 active-theme 后立刻注入。
 * 优先走 watch 控制面 POST /kick（进程内热缓存，无第二 node）；
 * 控制面不可达时再 spawn injector --once。
 */
import { spawn } from "node:child_process";
import { access, readFile } from "node:fs/promises";
import { join } from "node:path";
import { resolveStudioPaths } from "../constants.mjs";
import { probeCdpPort } from "../cdp/cdp-port.mjs";

const MAX_CAPTURE_CHARS = 8_000;

async function pathExists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

function appendCapped(buffer, chunk) {
  if (buffer.length >= MAX_CAPTURE_CHARS) return buffer;
  const next = buffer + String(chunk);
  return next.length > MAX_CAPTURE_CHARS
    ? `${next.slice(0, MAX_CAPTURE_CHARS)}\n…[truncated]`
    : next;
}

async function readJsonFile(path) {
  const raw = await readFile(path, "utf8");
  return JSON.parse(raw.replace(/^﻿/, ""));
}

async function resolveInjectorPath(state, installRoot) {
  try {
    const currentPath = join(installRoot, "current.json");
    if (await pathExists(currentPath)) {
      const current = await readJsonFile(currentPath);
      const rel = String(current?.relativeEnginePath || "").replaceAll("/", "\\");
      if (rel) {
        const candidate = join(installRoot, rel, "scripts", "injector.mjs");
        if (await pathExists(candidate)) return candidate;
      }
    }
  } catch {
    // fall through
  }
  if (typeof state?.injectorPath === "string" && (await pathExists(state.injectorPath))) {
    return state.injectorPath;
  }
  return null;
}

async function probeCdpOpen(port, timeoutMs = 1000) {
  const probe = await probeCdpPort(port, { timeoutMs });
  return Boolean(probe.open);
}

function resolveNodePath(state) {
  if (typeof state?.nodePath === "string" && state.nodePath.trim()) {
    return state.nodePath;
  }
  return process.execPath;
}

async function resolveControlPort(state, stateRoot) {
  if (Number.isInteger(Number(state?.controlPort)) && Number(state.controlPort) >= 1024) {
    return Number(state.controlPort);
  }
  try {
    const p = join(stateRoot, "control.port");
    if (await pathExists(p)) {
      const n = Number((await readFile(p, "utf8")).trim());
      if (Number.isInteger(n) && n >= 1024) return n;
    }
  } catch {
    // ignore
  }
  return 9336;
}

async function kickViaControlPlane(controlPort, timeoutMs = 2500) {
  const ports = [controlPort, 9336, 9337, 9338, 9339, 9340].filter(
    (p, i, arr) => Number.isInteger(p) && p >= 1024 && arr.indexOf(p) === i,
  );
  for (const port of ports) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/kick`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (response.status === 404) continue;
      const body = await response.json().catch(() => ({}));
      if (response.ok && body?.ok) {
        return {
          ok: true,
          code: 0,
          detail: "control-plane-kick",
          mode: body.mode || "watch-kick",
          controlPort: port,
          ms: body.ms,
          applied: body.applied,
          stdout: JSON.stringify(body),
          stderr: "",
        };
      }
      if (response.status === 409 || body?.reason === "paused") {
        return {
          ok: false,
          skipped: true,
          reason: body?.reason || "unhealthy",
          controlPort: port,
          detail: body?.detail || "control plane refused kick",
        };
      }
    } catch {
      // try next port
    }
  }
  return null;
}

/**
 * @param {{
 *   stateRoot?: string,
 *   installRoot?: string,
 *   timeoutMs?: number,
 *   probeTimeoutMs?: number,
 *   preferControlPlane?: boolean,
 * }} [opts]
 */
export async function kickThemeInjectNow({
  stateRoot = resolveStudioPaths().dreamStateRoot,
  installRoot = resolveStudioPaths().installRoot,
  timeoutMs = 12_000,
  probeTimeoutMs = 1_000,
  preferControlPlane = true,
} = {}) {
  const statePath = join(stateRoot, "state.json");
  if (!(await pathExists(statePath))) {
    return { ok: false, skipped: true, reason: "no-state" };
  }

  let state;
  try {
    state = await readJsonFile(statePath);
  } catch {
    return { ok: false, skipped: true, reason: "bad-state" };
  }

  const port = Number(state.port);
  const browserId = typeof state.browserId === "string" ? state.browserId.trim() : "";
  const themeDir =
    (typeof state.themeDir === "string" && state.themeDir.trim()) ||
    join(stateRoot, "active-theme");

  if (!Number.isInteger(port) || port < 1024 || port > 65535 || !browserId) {
    return { ok: false, skipped: true, reason: "incomplete-state", port };
  }
  if (!(await pathExists(themeDir))) {
    return { ok: false, skipped: true, reason: "theme-dir-missing", port };
  }

  if (preferControlPlane) {
    const controlPort = await resolveControlPort(state, stateRoot);
    const viaCp = await kickViaControlPlane(controlPort, Math.min(timeoutMs, 4000));
    if (viaCp) return viaCp;
  }

  const injectorPath = await resolveInjectorPath(state, installRoot);
  if (!injectorPath) {
    return { ok: false, skipped: true, reason: "injector-missing", port };
  }

  if (!(await probeCdpOpen(port, probeTimeoutMs))) {
    return {
      ok: false,
      skipped: true,
      reason: "cdp-closed",
      port,
      injectorPath,
      detail: `CDP 127.0.0.1:${port} not open`,
    };
  }

  const nodePath = resolveNodePath(state);
  const args = [
    injectorPath,
    "--once",
    "--port",
    String(port),
    "--browser-id",
    browserId,
    "--theme-dir",
    themeDir,
    "--timeout-ms",
    String(timeoutMs),
  ];

  const result = await new Promise((resolve) => {
    let settled = false;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      resolve(value);
    };

    const child = spawn(nodePath, args, {
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      try {
        child.kill();
      } catch {
        // ignore
      }
      finish({
        ok: false,
        code: -1,
        detail: "kick inject timed out",
        stdout,
        stderr,
        injectorPath,
        port,
      });
    }, timeoutMs + 3_000);

    child.stdout?.on("data", (chunk) => {
      stdout = appendCapped(stdout, chunk);
    });
    child.stderr?.on("data", (chunk) => {
      stderr = appendCapped(stderr, chunk);
    });
    child.on("error", (error) => {
      clearTimeout(timer);
      finish({
        ok: false,
        code: -1,
        detail: error.message,
        stdout,
        stderr,
        injectorPath,
        port,
      });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      finish({
        ok: code === 0,
        code: code ?? -1,
        detail: code === 0 ? "injected" : stderr || stdout || `exit ${code}`,
        mode: "once-fallback",
        stdout,
        stderr,
        injectorPath,
        port,
      });
    });
  });

  return result;
}

/**
 * @param {{ ok?: boolean, skipped?: boolean, reason?: string, detail?: string, mode?: string }} kick
 */
export function formatKickResultNote(kick) {
  if (!kick) return "未执行即时注入";
  if (kick.ok) {
    if (kick.mode === "watch-kick" || kick.detail === "control-plane-kick") {
      return "已写入 active-theme 并经守护进程即时注入";
    }
    return "已写入 active-theme 并立即注入";
  }
  switch (kick.reason) {
    case "cdp-closed":
      return "已写入 active-theme；Codex CDP 未开放，请先打开带皮肤的 Codex";
    case "no-state":
    case "incomplete-state":
      return "已写入 active-theme；皮肤守护尚未初始化，请先打开 Codex";
    case "injector-missing":
      return "已写入 active-theme；injector 路径失效，请重新 publish/打开 Codex";
    case "paused":
      return "已写入 active-theme；皮肤已暂停，请 restore 后重试";
    default:
      return kick.detail
        ? `已写入 active-theme；即时注入未成功（${String(kick.detail).slice(0, 120)}）`
        : "已写入 active-theme；即时注入未成功，watch 将随后更新";
  }
}
