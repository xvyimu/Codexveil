// probe-session-dom.mjs — home + optional conversation markers for regression
// usage: node probe-session-dom.mjs [port]
import { writeFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";

const port = Number(process.argv[2] || 9335);
if (!Number.isInteger(port) || port < 1) {
  console.error("usage: node probe-session-dom.mjs [port]");
  process.exit(2);
}

const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const target = (Array.isArray(list) ? list : []).find(
  (t) => t?.type === "page" && String(t.url || "").startsWith("app://") && t.webSocketDebuggerUrl,
);
if (!target) {
  console.log(JSON.stringify({ ok: false, reason: "no-page" }));
  process.exit(2);
}

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  const t = setTimeout(() => reject(new Error("ws timeout")), 5000);
  ws.addEventListener("open", () => {
    clearTimeout(t);
    resolve();
  }, { once: true });
  ws.addEventListener("error", () => {
    clearTimeout(t);
    reject(new Error("ws error"));
  }, { once: true });
});

let id = 1;
const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const mid = id++;
    const timer = setTimeout(() => reject(new Error("timeout " + method)), 8000);
    const onMsg = (ev) => {
      const msg = JSON.parse(String(ev.data));
      if (msg.id !== mid) return;
      clearTimeout(timer);
      ws.removeEventListener("message", onMsg);
      if (msg.error) reject(new Error(msg.error.message || JSON.stringify(msg.error)));
      else resolve(msg.result);
    };
    ws.addEventListener("message", onMsg);
    ws.send(JSON.stringify({ id: mid, method, params }));
  });

await send("Runtime.enable");
const result = await send("Runtime.evaluate", {
  returnByValue: true,
  awaitPromise: true,
  expression: `(() => {
    const count = (sel) => { try { return document.querySelectorAll(sel).length; } catch { return -1; } };
    const first = (sels) => {
      for (const s of sels) {
        try {
          const n = document.querySelector(s);
          if (n) return s;
        } catch {}
      }
      return null;
    };
    const composerSels = ['.composer-surface-chrome','[class*="composer-surface"]','[data-codex-composer-root]','[data-codex-composer="true"]','[data-codex-composer]'];
    const userSels = ['[data-user-message-bubble]','[data-message-author-role="user"]','[data-message-author-role*="user"]','[class*="user-message"]','[class*="UserMessage"]'];
    const asstSels = ['[data-local-conversation-final-assistant]','[data-message-author-role="assistant"]','[data-message-author-role*="assistant"]','article:has([data-message-author-role="assistant"])','[class*="assistant-message"]'];
    const approvalSels = ['[data-codex-approval-surface]','[data-approval]','[class*="approval"]','[class*="permission"]'];
    const shellSels = ['main.main-surface','main[class*="main-surface"]','main','[role="main"]'];
    const sidebarSels = ['aside.app-shell-left-panel','aside[class*="left-panel"]','aside[class*="sidebar"]','nav[class*="sidebar"]'];
    const dataAttrs = new Set();
    for (const el of document.querySelectorAll('*')) {
      if (!el.attributes) continue;
      for (const a of el.attributes) {
        if (a.name.startsWith('data-') && /message|user|assistant|composer|conversation|bubble|approval|turn|role|codex/i.test(a.name + a.value)) {
          dataAttrs.add(a.name + (a.value ? '=' + String(a.value).slice(0, 40) : ''));
        }
      }
    }
    const hit = {
      composer: first(composerSels),
      user: first(userSels),
      assistant: first(asstSels),
      approval: first(approvalSels),
      shell: first(shellSels),
      sidebar: first(sidebarSels),
    };
    const counts = {
      composer: composerSels.map(s => ({ s, n: count(s) })).filter(x => x.n > 0),
      user: userSels.map(s => ({ s, n: count(s) })).filter(x => x.n > 0),
      assistant: asstSels.map(s => ({ s, n: count(s) })).filter(x => x.n > 0),
      messages: count('[data-message-author-role]'),
    };
    const onHome = Boolean(document.querySelector('.dream-home, [data-home-ambient-suggestions], main.main-surface.dream-home-shell'));
    const inConversation = counts.messages > 0 || Boolean(hit.user) || Boolean(hit.assistant);
    const styleEl = document.getElementById('codex-dream-skin-style');
    const cssText = styleEl?.textContent || '';
    const bubbleCssPresent = /data-user-message-bubble|data-message-author-role/.test(cssText);
    let userGlass = null;
    if (hit.user) {
      try {
        const node = document.querySelector(hit.user);
        if (node) {
          const s = getComputedStyle(node);
          userGlass = {
            selector: hit.user,
            backgroundColor: s.backgroundColor,
            borderRadius: s.borderRadius,
            backdropFilter: s.backdropFilter || s.webkitBackdropFilter || 'none',
          };
        }
      } catch {}
    }
    return {
      ok: true,
      url: location.href,
      title: document.title,
      dreamStyle: Boolean(styleEl),
      bubbleCssPresent,
      userGlass,
      bodyClass: document.body?.className || '',
      onHome,
      inConversation,
      hit,
      counts,
      dataAttrs: [...dataAttrs].slice(0, 60),
      // Shell + style + bubble CSS always; conversation nodes only when present.
      pass: Boolean(hit.shell || hit.composer) && Boolean(styleEl) && bubbleCssPresent,
      conversationPass: !inConversation || Boolean(hit.user || hit.assistant || hit.composer),
    };
  })()`,
});

ws.close();
const value = result?.result?.value ?? { ok: false };
const local = process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local");
const outDir = join(local, "CodexDreamSkin");
await mkdir(outDir, { recursive: true });
const outPath = join(outDir, "session-dom-probe.json");
const payload = {
  probedAt: new Date().toISOString(),
  port,
  targetId: target.id,
  ...value,
};
await writeFile(outPath, JSON.stringify(payload, null, 2) + "\n", "utf8");
console.log(JSON.stringify(payload, null, 2));
process.exit(value.pass && value.conversationPass ? 0 : 3);
