const port = 9335;
const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const target = list.find((item) => item.type === "page" && item.url?.startsWith("app://"));
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
  const root = document.getElementById('root');
  const all = [...document.querySelectorAll('body *')].slice(0, 80).map((el) => ({
    tag: el.tagName,
    id: el.id || null,
    role: el.getAttribute('role'),
    cls: (el.className?.toString?.() || '').slice(0, 100),
  }));
  return {
    rootChildCount: root?.childElementCount ?? 0,
    rootHTML: root?.innerHTML?.slice(0, 1500) ?? null,
    bodyChildCount: document.body?.childElementCount ?? 0,
    sample: all,
  };
})()`;
const result = await send("Runtime.evaluate", {
  expression,
  awaitPromise: true,
  returnByValue: true,
});
console.log(JSON.stringify(result.result?.value ?? result, null, 2));
ws.close();
