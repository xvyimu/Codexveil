const port = 9335;
const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const target = list.find((item) => item.type === "page" && item.url?.startsWith("app://"));
if (!target) throw new Error("no app page");
console.log("target", target.id, target.url);

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  ws.addEventListener("open", resolve, { once: true });
  ws.addEventListener("error", () => reject(new Error("ws error")), { once: true });
  setTimeout(() => reject(new Error("ws timeout")), 5000);
});

let nextId = 1;
function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    const timer = setTimeout(() => reject(new Error(`timeout ${method}`)), 10000);
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
  const q = (sel) => Boolean(document.querySelector(sel));
  return {
    mainSurface: q('main.main-surface'),
    aside: q('aside.app-shell-left-panel'),
    composer: q('.composer-surface-chrome'),
    roleMain: q('[role="main"]'),
    dreamStyle: Boolean(document.getElementById('codex-dream-skin-style')),
    dreamChrome: Boolean(document.getElementById('codex-dream-skin-chrome')),
    heigeStyle: Boolean(document.getElementById('heige-codex-skin-style')),
    bodyClass: document.body?.className ?? null,
    title: document.title,
    protocol: location.protocol,
    sampleIds: [...document.querySelectorAll('[id]')].slice(0, 20).map((el) => el.id),
    sampleClasses: [...document.querySelectorAll('main,aside,[class*="composer"],[class*="shell"]')]
      .slice(0, 20)
      .map((el) => ({ tag: el.tagName, class: el.className?.toString?.().slice(0, 120) })),
  };
})()`;
const result = await send("Runtime.evaluate", {
  expression,
  awaitPromise: true,
  returnByValue: true,
});
console.log(JSON.stringify(result.result?.value ?? result, null, 2));
ws.close();
