// wait-shell.mjs — adaptive readiness for Codex Store DOM renames
// usage: node wait-shell.mjs <port> [timeoutMs]
//
// Optimizations vs 1.3.x baseline (PAIN-POINTS #15 cold shell 10s+):
// - Reuse one CDP WebSocket per page target (no reconnect every poll)
// - Adaptive backoff: 120ms while CDP missing / not ready, cap 500ms
// - Default deadline 45s (was hard 90s); overridable via argv[3]
// - Prefer the first app:// page; drop dead sockets quickly
// - Early structural pass: root + app protocol + (main|composer|shell)
//   without requiring sidebar (collapsed rail used to delay pass)

const port = Number(process.argv[2]);
const timeoutMs = (() => {
  const n = Number(process.argv[3]);
  if (Number.isInteger(n) && n >= 3000 && n <= 120000) return n;
  return 45000;
})();
if (!Number.isInteger(port) || port < 1) {
  console.error("usage: node wait-shell.mjs <port> [timeoutMs]");
  process.exit(2);
}

const started = Date.now();
const deadline = started + timeoutMs;

function okTarget(t) {
  return (
    t?.type === "page" &&
    String(t.url || "").startsWith("app://") &&
    typeof t.webSocketDebuggerUrl === "string" &&
    t.webSocketDebuggerUrl.length > 0
  );
}

function probeExpression() {
  // Keep expression tiny — evaluated every poll.
  return `(() => {
    const q = (sel) => { try { return !!document.querySelector(sel); } catch { return false; } };
    const shell = q('main.main-surface') || q('main[class*="main-surface"]') || q('main');
    const sidebar = q('aside.app-shell-left-panel') || q('aside[class*="left-panel"]') || q('aside[class*="sidebar"]') || q('nav[class*="sidebar"]');
    const composer = q('.composer-surface-chrome') || q('[class*="composer-surface"]') || q('[data-codex-composer]');
    const main = q('[role="main"]');
    const root = q('#root');
    const app = location.protocol === 'app:';
    const ready = document.readyState;
    // classic: full shell; structural: enough to inject without sidebar
    const classic = shell && sidebar && (composer || main);
    const structural = root && app && (main || composer || shell) && ready !== 'loading';
    return {
      shell, sidebar, composer, main, root, app, ready,
      url: location.href,
      pass: app && (classic || structural),
    };
  })()`;
}

class CdpPage {
  constructor(target) {
    this.target = target;
    this.ws = null;
    this.nextId = 1;
    this.pending = new Map();
    this.closed = true;
  }

  async open(timeout = 2500) {
    if (this.ws && !this.closed) return;
    this.closed = true;
    this.pending.forEach((p) => {
      try { p.reject(new Error("reconnect")); } catch {}
    });
    this.pending.clear();
    const ws = new WebSocket(this.target.webSocketDebuggerUrl);
    this.ws = ws;
    await new Promise((resolve, reject) => {
      const t = setTimeout(() => {
        try { ws.close(); } catch {}
        reject(new Error("ws timeout"));
      }, timeout);
      ws.addEventListener(
        "open",
        () => {
          clearTimeout(t);
          resolve();
        },
        { once: true },
      );
      ws.addEventListener(
        "error",
        () => {
          clearTimeout(t);
          reject(new Error("ws err"));
        },
        { once: true },
      );
    });
    this.closed = false;
    ws.addEventListener("message", (ev) => {
      let msg;
      try {
        msg = JSON.parse(String(ev.data));
      } catch {
        return;
      }
      if (!msg.id) return;
      const waiter = this.pending.get(msg.id);
      if (!waiter) return;
      clearTimeout(waiter.timer);
      this.pending.delete(msg.id);
      if (msg.error) waiter.reject(new Error(msg.error.message || "cdp error"));
      else waiter.resolve(msg.result);
    });
    ws.addEventListener("close", () => {
      this.closed = true;
      for (const waiter of this.pending.values()) {
        clearTimeout(waiter.timer);
        waiter.reject(new Error("ws closed"));
      }
      this.pending.clear();
    });
    await this.send("Runtime.enable", {}, 3000);
  }

  send(method, params = {}, timeoutMs = 4000) {
    if (this.closed || !this.ws) return Promise.reject(new Error("ws closed"));
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error("cmd timeout " + method));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      try {
        this.ws.send(JSON.stringify({ id, method, params }));
      } catch (e) {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(e);
      }
    });
  }

  async probe() {
    const result = await this.send(
      "Runtime.evaluate",
      {
        expression: probeExpression(),
        returnByValue: true,
        awaitPromise: true,
      },
      4000,
    );
    return result?.result?.value ?? null;
  }

  close() {
    try {
      this.ws?.close();
    } catch {}
    this.closed = true;
  }
}

async function listPages() {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 1200);
  try {
    const res = await fetch(`http://127.0.0.1:${port}/json/list`, {
      signal: ctrl.signal,
    });
    const list = await res.json();
    return (Array.isArray(list) ? list : []).filter(okTarget);
  } finally {
    clearTimeout(t);
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function main() {
  /** @type {Map<string, CdpPage>} */
  const sessions = new Map();
  let delay = 120;
  let lastPassDetail = null;

  while (Date.now() < deadline) {
    const elapsed = Date.now() - started;
    try {
      const pages = await listPages();
      if (pages.length === 0) {
        console.log(
          JSON.stringify({
            wait: "no-page",
            elapsedMs: elapsed,
            nextDelayMs: delay,
          }),
        );
      } else {
        // Drop sessions for targets that disappeared
        const live = new Set(pages.map((p) => p.id));
        for (const [id, sess] of sessions) {
          if (!live.has(id)) {
            sess.close();
            sessions.delete(id);
          }
        }

        for (const page of pages) {
          let sess = sessions.get(page.id);
          if (!sess) {
            sess = new CdpPage(page);
            sessions.set(page.id, sess);
          } else {
            // Target may recycle the debugger URL
            sess.target = page;
          }
          try {
            if (sess.closed) await sess.open(2500);
            const v = await sess.probe();
            const line = {
              target: page.id,
              elapsedMs: elapsed,
              ...v,
            };
            console.log(JSON.stringify(line));
            if (v?.pass) {
              lastPassDetail = line;
              for (const s of sessions.values()) s.close();
              process.exit(0);
            }
            // Not ready yet — keep connection warm, tighten delay
            delay = 120;
          } catch (e) {
            console.log(
              JSON.stringify({
                target: page.id,
                waitError: String(e.message || e),
                elapsedMs: elapsed,
              }),
            );
            try {
              sess.close();
            } catch {}
            sessions.delete(page.id);
            delay = Math.min(400, delay + 40);
          }
        }
      }
    } catch (e) {
      console.log(
        JSON.stringify({
          waitError: String(e.message || e),
          elapsedMs: elapsed,
          nextDelayMs: delay,
        }),
      );
      // CDP list not up yet — back off a bit but stay snappy early
      delay = Math.min(500, Math.max(150, delay + 50));
    }

    if (Date.now() + delay >= deadline) break;
    await sleep(delay);
    // Mild backoff when repeatedly not ready with live pages
    delay = Math.min(500, Math.floor(delay * 1.15));
  }

  for (const s of sessions.values()) s.close();
  console.error(
    JSON.stringify({
      error: "shell markers not ready",
      elapsedMs: Date.now() - started,
      timeoutMs,
      lastPassDetail,
    }),
  );
  process.exit(2);
}

main().catch((e) => {
  console.error(String(e?.stack || e));
  process.exit(2);
});
