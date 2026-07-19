// wait-shell.mjs — adaptive readiness for Codex Store DOM renames
// usage: node wait-shell.mjs <port>
const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1) {
  console.error("usage: node wait-shell.mjs <port>");
  process.exit(2);
}

const deadline = Date.now() + 90_000;

function okTarget(t) {
  return (
    t?.type === "page" &&
    String(t.url || "").startsWith("app://") &&
    t.webSocketDebuggerUrl
  );
}

function probeExpression() {
  return `(() => {
    const q = (sel) => { try { return !!document.querySelector(sel); } catch { return false; } };
    const shell = q('main.main-surface') || q('main[class*="main-surface"]') || q('main[class*="MainSurface"]') || q('main');
    const sidebar = q('aside.app-shell-left-panel') || q('aside[class*="left-panel"]') || q('aside[class*="sidebar"]') || q('nav[class*="sidebar"]');
    const composer = q('.composer-surface-chrome') || q('[class*="composer-surface"]') || q('[class*="ComposerSurface"]');
    const main = q('[role="main"]');
    const root = q('#root');
    const app = location.protocol === 'app:';
    const classic = shell && sidebar && (composer || main);
    const structural = root && app && (main || composer || shell);
    return {
      shell, sidebar, composer, main, root, app, ready: document.readyState,
      url: location.href,
      pass: app && (classic || structural),
    };
  })()`;
}

async function main() {
  while (Date.now() < deadline) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const pages = (Array.isArray(list) ? list : []).filter(okTarget);
      for (const page of pages) {
        const ws = new WebSocket(page.webSocketDebuggerUrl);
        await new Promise((resolve, reject) => {
          const t = setTimeout(() => reject(new Error("ws timeout")), 4000);
          ws.addEventListener("open", () => {
            clearTimeout(t);
            resolve();
          }, { once: true });
          ws.addEventListener("error", () => {
            clearTimeout(t);
            reject(new Error("ws err"));
          }, { once: true });
        });
        let id = 1;
        const send = (method, params = {}) =>
          new Promise((resolve, reject) => {
            const mid = id++;
            const timer = setTimeout(() => reject(new Error("cmd timeout " + method)), 5000);
            const onMsg = (ev) => {
              const msg = JSON.parse(String(ev.data));
              if (msg.id !== mid) return;
              clearTimeout(timer);
              ws.removeEventListener("message", onMsg);
              if (msg.error) reject(new Error(msg.error.message));
              else resolve(msg.result);
            };
            ws.addEventListener("message", onMsg);
            ws.send(JSON.stringify({ id: mid, method, params }));
          });
        await send("Runtime.enable");
        const result = await send("Runtime.evaluate", {
          expression: probeExpression(),
          returnByValue: true,
          awaitPromise: true,
        });
        ws.close();
        const v = result?.result?.value;
        console.log(JSON.stringify({ target: page.id, ...v }));
        if (v?.pass) process.exit(0);
      }
    } catch (e) {
      console.log(JSON.stringify({ waitError: String(e.message || e) }));
    }
    await new Promise((r) => setTimeout(r, 700));
  }
  console.error("shell markers not ready");
  process.exit(2);
}

main();
