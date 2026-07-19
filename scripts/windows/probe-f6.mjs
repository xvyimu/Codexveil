const port = 9335;
const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const target = list.find((item) => item.type === "page" && item.url?.startsWith("app://"));
if (!target) throw new Error("no page");
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  ws.addEventListener("open", resolve, { once: true });
  ws.addEventListener("error", () => reject(new Error("ws")), { once: true });
  setTimeout(() => reject(new Error("timeout")), 5000);
});
let nextId = 1;
function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    const timer = setTimeout(() => reject(new Error(method)), 8000);
    function onMessage(event) {
      const message = JSON.parse(String(event.data));
      if (message.id !== id) return;
      clearTimeout(timer);
      ws.removeEventListener("message", onMessage);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
    }
    ws.addEventListener("message", onMessage);
    ws.send(JSON.stringify({ id, method, params }));
  });
}
await send("Runtime.enable");
const expression = `(() => {
  const state = window.__CODEX_DREAM_SKIN_STATE__;
  const catalog = state?.catalog;
  return {
    hasState: Boolean(state),
    version: state?.version ?? null,
    themeCount: Array.isArray(catalog) ? catalog.length : 0,
    names: Array.isArray(catalog) ? catalog.map((t) => t.name) : [],
    active: state?.catalog ? (catalog.find((t) => t === state) || catalog[0])?.name : null,
    dreamStyle: Boolean(document.getElementById('codex-dream-skin-style')),
    dreamChrome: Boolean(document.getElementById('codex-dream-skin-chrome')),
  };
})()`;
const result = await send("Runtime.evaluate", {
  expression,
  awaitPromise: true,
  returnByValue: true,
});
console.log(JSON.stringify(result.result?.value ?? result, null, 2));
// simulate F6 once
const f6 = await send("Runtime.evaluate", {
  expression: `(() => {
    const state = window.__CODEX_DREAM_SKIN_STATE__;
    if (state?.cycleTheme) {
      const before = state.catalog?.findIndex((t) => t.key === (state.catalog && window.localStorage.getItem('codexDreamSkin.selectedTheme'))) ;
      state.cycleTheme();
      return {
        ok: true,
        themeCount: state.catalog?.length ?? 0,
        selected: window.localStorage.getItem('codexDreamSkin.selectedTheme') || window.localStorage.getItem('codex-dream-skin-selected-theme'),
        keys: Object.keys(localStorage).filter((k) => /dream|theme|skin/i.test(k)),
      };
    }
    return { ok: false, reason: 'no cycleTheme' };
  })()`,
  awaitPromise: true,
  returnByValue: true,
});
console.log("F6 sim", JSON.stringify(f6.result?.value ?? f6, null, 2));
ws.close();
