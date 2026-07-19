/**
 * @file control-plane.mjs
 * @description Loopback HTTP control plane hosted inside the watch injector.
 * Endpoints: GET /health, POST /focus, POST /kick, POST /open-healthy
 * Bind: 127.0.0.1 only. Optional token from %LOCALAPPDATA%/CodexDreamSkin/control.token
 */
import http from "node:http";
import { spawn } from "node:child_process";
import { access, readFile, writeFile, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { randomBytes } from "node:crypto";

const DEFAULT_PORT = 9336;
const PORT_SCAN = 11; // 9336..9346

async function pathExists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

function stateRootDefault() {
  const local = process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local");
  return join(local, "CodexDreamSkin");
}

async function ensureToken(stateRoot) {
  const tokenPath = join(stateRoot, "control.token");
  if (await pathExists(tokenPath)) {
    try {
      return (await readFile(tokenPath, "utf8")).trim();
    } catch {
      // regenerate
    }
  }
  const token = randomBytes(16).toString("hex");
  await mkdir(stateRoot, { recursive: true });
  await writeFile(tokenPath, token + "\n", "utf8");
  return token;
}

async function writeControlPort(stateRoot, port) {
  try {
    await mkdir(stateRoot, { recursive: true });
    await writeFile(join(stateRoot, "control.port"), String(port) + "\n", "utf8");
  } catch {
    // ignore
  }
  try {
    const statePath = join(stateRoot, "state.json");
    if (!(await pathExists(statePath))) return;
    const raw = await readFile(statePath, "utf8");
    const state = JSON.parse(raw.replace(/^﻿/, ""));
    state.controlPort = port;
    state.controlUpdatedAt = new Date().toISOString();
    await writeFile(statePath, JSON.stringify(state, null, 2) + "\n", "utf8");
  } catch {
    // ignore
  }
}

/**
 * Focus via apps/launcher/focus-codex.ps1 (single WinFocus implementation).
 * Falls back to a tiny AppActivate-only snippet if the script is missing.
 */
export function focusViaPowerShell({ timeoutMs = 600, focusScriptPath = null } = {}) {
  const sw = Date.now();
  const localApp = process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local");
  const candidates = [
    focusScriptPath,
    join(localApp, "Programs", "CodexDreamSkin", "focus-codex.ps1"),
  ].filter(Boolean);

  const trySpawn = (args) =>
    new Promise((resolve) => {
      const child = spawn("powershell.exe", args, {
        windowsHide: true,
        stdio: ["ignore", "pipe", "pipe"],
      });
      let out = "";
      let err = "";
      const timer = setTimeout(() => {
        try {
          child.kill();
        } catch {}
        resolve({ focused: false, ms: Date.now() - sw, detail: "focus-timeout" });
      }, Math.max(1200, timeoutMs + 600));
      child.stdout.on("data", (c) => {
        out += String(c);
      });
      child.stderr.on("data", (c) => {
        err += String(c);
      });
      child.on("error", (e) => {
        clearTimeout(timer);
        resolve({ focused: false, ms: Date.now() - sw, detail: e.message });
      });
      child.on("close", () => {
        clearTimeout(timer);
        const focused = /FOCUSED/.test(out);
        resolve({
          focused,
          ms: Date.now() - sw,
          detail: (out + " " + err).trim().slice(0, 160) || "empty",
        });
      });
    });

  return (async () => {
    for (const script of candidates) {
      try {
        if (!(await pathExists(script))) continue;
        return await trySpawn([
          "-NoProfile",
          "-NonInteractive",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          script,
          "-TimeoutMs",
          String(timeoutMs),
        ]);
      } catch {
        // try next
      }
    }
    // Minimal fallback: title activate only
    return trySpawn([
      "-NoProfile",
      "-NonInteractive",
      "-Command",
      "$s=New-Object -ComObject WScript.Shell; if($s.AppActivate('Codex') -or $s.AppActivate('ChatGPT')){'FOCUSED'} else {'MISS'}",
    ]);
  })();
}

/**
 * @param {{
 *   getHealth: () => object | Promise<object>,
 *   onKick: () => Promise<object>,
 *   onFocus?: () => Promise<object>,
 *   stateRoot?: string,
 *   preferredPort?: number,
 * }} opts
 */
export async function startControlPlane(opts) {
  const stateRoot = opts.stateRoot || stateRootDefault();
  const token = await ensureToken(stateRoot);
  const preferred = opts.preferredPort || DEFAULT_PORT;

  const handler = async (req, res) => {
    try {
      const url = new URL(req.url || "/", `http://127.0.0.1`);
      const pathName = url.pathname.replace(/\/+$/, "") || "/";
      // optional token: ?token= or header x-codex-skin-token
      const qToken = url.searchParams.get("token");
      const hToken = req.headers["x-codex-skin-token"];
      if (token && qToken !== token && hToken !== token) {
        // still allow local unauthenticated for UX simplicity on same machine;
        // token is recorded for future tightening. Accept always from 127.0.0.1.
      }
      const send = (code, body) => {
        const data = JSON.stringify(body);
        res.writeHead(code, {
          "Content-Type": "application/json; charset=utf-8",
          "Content-Length": Buffer.byteLength(data),
          "Cache-Control": "no-store",
        });
        res.end(data);
      };

      if (req.method === "GET" && (pathName === "/health" || pathName === "/")) {
        const health = await opts.getHealth();
        return send(200, { ok: true, ...health, tokenPresent: Boolean(token) });
      }

      if (req.method === "POST" && pathName === "/focus") {
        const result = opts.onFocus
          ? await opts.onFocus()
          : await focusViaPowerShell();
        return send(result?.focused ? 200 : 204, { ok: Boolean(result?.focused), ...result });
      }

      if (req.method === "POST" && pathName === "/kick") {
        const result = await opts.onKick();
        return send(result?.ok ? 200 : 500, result);
      }

      if (req.method === "POST" && pathName === "/open-healthy") {
        const health = await opts.getHealth();
        if (!health?.healthy) {
          return send(409, { ok: false, reason: "unhealthy", ...health });
        }
        const focus = opts.onFocus
          ? await opts.onFocus()
          : await focusViaPowerShell();
        return send(200, {
          ok: true,
          healthy: true,
          focused: Boolean(focus?.focused),
          focus,
          ...health,
        });
      }

      send(404, { ok: false, reason: "not-found" });
    } catch (error) {
      try {
        const data = JSON.stringify({
          ok: false,
          reason: "error",
          detail: error?.message || String(error),
        });
        res.writeHead(500, {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(data),
        });
        res.end(data);
      } catch {
        // ignore
      }
    }
  };

  let server = null;
  let boundPort = null;
  for (let i = 0; i < PORT_SCAN; i += 1) {
    const port = preferred + i;
    try {
      server = await new Promise((resolve, reject) => {
        const s = http.createServer(handler);
        s.once("error", reject);
        s.listen(port, "127.0.0.1", () => {
          s.removeListener("error", reject);
          resolve(s);
        });
      });
      boundPort = port;
      break;
    } catch {
      server = null;
    }
  }
  if (!server || !boundPort) {
    console.error("[dream-skin] control plane: no free port in 9336-9346");
    return { port: null, close: async () => {}, token };
  }

  await writeControlPort(stateRoot, boundPort);
  console.error(`[dream-skin] control plane on 127.0.0.1:${boundPort}`);

  return {
    port: boundPort,
    token,
    close: () =>
      new Promise((resolve) => {
        try {
          server.close(() => resolve());
        } catch {
          resolve();
        }
      }),
  };
}
