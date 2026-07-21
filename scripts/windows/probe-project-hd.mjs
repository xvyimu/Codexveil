/** CDP snapshot for project-HD + bubble mode. */
const PORT = 9335;
const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const page = list.find((i) => i.type === "page" && String(i.url || "").startsWith("app://"));
if (!page) throw new Error("no page");
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => {
  ws.addEventListener("open", res, { once: true });
  ws.addEventListener("error", () => rej(new Error("ws")), { once: true });
  setTimeout(() => rej(new Error("timeout")), 5000);
});
let id = 1;
function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const my = id++;
    const t = setTimeout(() => reject(new Error(method)), 10000);
    function onMessage(event) {
      const msg = JSON.parse(String(event.data));
      if (msg.id !== my) return;
      clearTimeout(t);
      ws.removeEventListener("message", onMessage);
      if (msg.error) reject(new Error(JSON.stringify(msg.error)));
      else resolve(msg.result);
    }
    ws.addEventListener("message", onMessage);
    ws.send(JSON.stringify({ id: my, method, params }));
  });
}
await send("Runtime.enable");
const expression = `(() => {
  const root = document.documentElement;
  const c = root.className || "";
  const cs = getComputedStyle(root);
  const body = document.body ? getComputedStyle(document.body) : null;
  const task = document.querySelector(".dream-task");
  const before = task ? getComputedStyle(task, "::before") : null;
  const user = document.querySelector('[data-message-author-role*="user"], [data-user-message-bubble], [class*="user-message"]');
  const asst = document.querySelector('[data-message-author-role*="assistant"], [data-local-conversation-final-assistant], [class*="assistant-message"]');
  const u = user ? getComputedStyle(user) : null;
  const a = asst ? getComputedStyle(asst) : null;
  return {
    dark: c.includes("dream-theme-dark"),
    light: c.includes("dream-theme-light"),
    wide: c.includes("dream-art-wide"),
    bubbleCard: c.includes("dream-bubble-card"),
    bubbleBorderless: c.includes("dream-bubble-borderless"),
    bubbleAttr: root.getAttribute("data-dream-bubble-style"),
    surfaceLuma: window.__CODEX_DREAM_SKIN_STATE__?.config?.surfaceLuma ?? null,
    bubbleStyleCfg: window.__CODEX_DREAM_SKIN_STATE__?.config?.bubbleStyle ?? null,
    taskAmbient: cs.getPropertyValue("--dream-task-ambient-opacity").trim(),
    taskEdge: cs.getPropertyValue("--dream-task-immersive-edge").trim(),
    bodyBg: body?.backgroundColor || null,
    bodyImg: (body?.backgroundImage || "").slice(0, 48),
    hasTask: Boolean(task),
    taskBeforeOpacity: before?.opacity || null,
    taskBeforeSize: before?.backgroundSize || null,
    userBorder: u?.borderTopWidth + " " + u?.borderTopStyle,
    userRadius: u?.borderRadius || null,
    asstBorder: a ? a.borderTopWidth + " " + a.borderTopStyle : null,
    asstRadius: a?.borderRadius || null,
    hasUser: Boolean(user),
    hasAsst: Boolean(asst),
  };
})()`;
const r = await send("Runtime.evaluate", {
  expression,
  awaitPromise: true,
  returnByValue: true,
});
console.log(JSON.stringify(r.result?.value ?? r, null, 2));
ws.close();
