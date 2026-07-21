/**
 * @file control-plane.mjs
 * @description Loopback HTTP control plane hosted inside the watch injector.
 * Endpoints: GET /health, POST /focus, POST /kick, POST /open-healthy
 * Bind: 127.0.0.1 only.
 * Auth: POST mutating routes require control.token via header x-codex-skin-token
 * only (GET /health stays open for FastLaunch health probes). Query ?token= is ignored.
 */
import http from "node:http";
import { spawn } from "node:child_process";
import { readFile, writeFile, mkdir, rename } from "node:fs/promises";
import { pathExists, readJsonFile } from "./fs-io.mjs";
import { homedir } from "node:os";
import { join } from "node:path";
import { randomBytes, timingSafeEqual } from "node:crypto";

const DEFAULT_PORT = 9336;
const PORT_SCAN = 11; // 9336..9346
export const CONTROL_TOKEN_HEADER = "x-codex-skin-token";

/**
 * Constant-time string compare for tokens.
 * - non-string → false
 * - different byte lengths → false (do NOT call timingSafeEqual)
 * - same length → timingSafeEqual on utf8 buffers
 */
function tokensEqual(provided, expected) {
  if (typeof provided !== "string" || typeof expected !== "string") return false;
  const a = Buffer.from(provided, "utf8");
  const b = Buffer.from(expected, "utf8");
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}


function stateRootDefault() {
  // Fallback only when injector did not pass stateRoot (dev / mis-invocation).
  // Prefer startControlPlane({ stateRoot }) from watch with active-theme dirname.
  const local = process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local");
  return join(local, "CodexDreamSkin");
}

async function ensureToken(stateRoot) {
  const tokenPath = join(stateRoot, "control.token");
  if (await pathExists(tokenPath)) {
    try {
      const existing = (await readFile(tokenPath, "utf8")).trim();
      if (existing) return existing;
    } catch {
      // regenerate
    }
  }
  const token = randomBytes(16).toString("hex");
  await mkdir(stateRoot, { recursive: true });
  await writeFile(tokenPath, token + "\n", "utf8");
  return token;
}

async function atomicWriteText(filePath, text) {
  const dir = join(filePath, ".."); // parent of filePath
  await mkdir(dir, { recursive: true });
  const tmp = join(dir, `.state-write.${process.pid}.${Date.now()}.tmp`);
  await writeFile(tmp, text, "utf8");
  await rename(tmp, filePath);
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
    const state = await readJsonFile(statePath);
    state.controlPort = port;
    state.controlUpdatedAt = new Date().toISOString();
    await atomicWriteText(statePath, JSON.stringify(state, null, 2) + "\n");
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
      }, Math.max(800, timeoutMs + 300));
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
      // Intentionally ignore url.searchParams.get("token") — header only.
      const rawHeader = req.headers[CONTROL_TOKEN_HEADER];
      const headerToken = Array.isArray(rawHeader) ? rawHeader[0] : rawHeader;
      const send = (code, body) => {
        const data = JSON.stringify(body);
        res.writeHead(code, {
          "Content-Type": "application/json; charset=utf-8",
          "Content-Length": Buffer.byteLength(data),
          "Cache-Control": "no-store",
        });
        res.end(data);
      };

      // GET /health stays open: FastLaunch + doctor probes. Mutating POSTs need header token.
      const isHealthGet =
        req.method === "GET" && (pathName === "/health" || pathName === "/");
      if (!isHealthGet && token && !tokensEqual(headerToken, token)) {
        return send(401, {
          ok: false,
          reason: "token-required",
          detail: "provide header x-codex-skin-token (see control.token)",
        });
      }

      if (isHealthGet) {
        const health = await opts.getHealth();
        return send(200, {
          ok: true,
          ...health,
          tokenPresent: Boolean(token),
          tokenRequiredForMutations: Boolean(token),
        });
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
        // 不阻塞等 focus：旧实现 await focusViaPowerShell() 会冷启 PS +
        // Focus-CodexSkinWindow，最差 Math.max(1200, timeout+600)ms，把
        // open-healthy 调用方（含 VBS / open.ps1 TimeoutMs=200）拖成"卡死"。
        // 这里立即返回 healthy；焦点由调用方（native exe / 自身 focus）负责，
        // 另起 fire-and-forget 一次 best-effort focus 不拖 HTTP。
        const focusJob = opts.onFocus
          ? opts.onFocus()
          : focusViaPowerShell({ timeoutMs: 400 });
        // 不等待；吞掉 rejection，避免 unhandledRejection
        Promise.resolve(focusJob).catch(() => {});
        return send(200, {
          ok: true,
          healthy: true,
          focused: false,
          focus: { focused: false, ms: 0, detail: "async" },
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
