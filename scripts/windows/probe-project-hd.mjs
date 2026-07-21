/**
 * Live CDP probe: project-route HD art + bubble mode health.
 * Assert-style (not snapshot-only): default pass=false; fail → exit 2; CDP down → exit 1.
 * Run: node scripts/windows/probe-project-hd.mjs
 */
import { writeFile } from "node:fs/promises";
import { join } from "node:path";

const PORT = 9335;
const OUT = join(
  process.env.LOCALAPPDATA || "",
  "CodexDreamSkin",
  "probe-project-hd-result.json",
);

function validatedWs(url, port) {
  const parsed = new URL(url);
  if (
    parsed.protocol !== "ws:" ||
    parsed.hostname !== "127.0.0.1" ||
    Number(parsed.port) !== port
  ) {
    throw new Error(`Rejected debugger URL: ${url}`);
  }
  return url;
}

class Cdp {
  constructor(url) {
    this.ws = new WebSocket(url);
    this.nextId = 1;
    this.pending = new Map();
  }
  async open() {
    await new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error("ws open timeout")), 5000);
      this.ws.addEventListener(
        "open",
        () => {
          clearTimeout(t);
          resolve();
        },
        { once: true },
      );
      this.ws.addEventListener(
        "error",
        () => {
          clearTimeout(t);
          reject(new Error("ws open failed"));
        },
        { once: true },
      );
    });
    this.ws.addEventListener("message", (event) => {
      let msg;
      try {
        msg = JSON.parse(String(event.data));
      } catch {
        return;
      }
      if (!msg.id) return;
      const waiter = this.pending.get(msg.id);
      if (!waiter) return;
      clearTimeout(waiter.timeout);
      this.pending.delete(msg.id);
      if (msg.error) waiter.reject(new Error(msg.error.message));
      else waiter.resolve(msg.result);
    });
    await this.send("Runtime.enable");
    return this;
  }
  send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`timeout ${method}`));
      }, 12000);
      this.pending.set(id, { resolve, reject, timeout });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true,
    });
    if (result.exceptionDetails) {
      throw new Error(
        result.exceptionDetails.exception?.description ||
          result.exceptionDetails.text,
      );
    }
    return result.result?.value;
  }
  close() {
    try {
      this.ws.close();
    } catch {}
  }
}

async function main() {
  const report = {
    startedAt: new Date().toISOString(),
    port: PORT,
    pass: false,
    checks: {},
    notes: [],
  };

  const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
  const page = list.find(
    (item) => item.type === "page" && String(item.url || "").startsWith("app://"),
  );
  if (!page) throw new Error("no app:// page");
  report.targetId = page.id;
  report.title = page.title;

  const session = await new Cdp(validatedWs(page.webSocketDebuggerUrl, PORT)).open();
  try {
    const snap = await session.evaluate(`(() => {
      const root = document.documentElement;
      const c = root.className || "";
      const cs = getComputedStyle(root);
      const body = document.body ? getComputedStyle(document.body) : null;
      const task = document.querySelector(".dream-task");
      const before = task ? getComputedStyle(task, "::before") : null;
      const user = document.querySelector(
        '[data-message-author-role*="user"], [data-user-message-bubble], [class*="user-message"]',
      );
      const asst = document.querySelector(
        '[data-message-author-role*="assistant"], [data-local-conversation-final-assistant], [class*="assistant-message"]',
      );
      const u = user ? getComputedStyle(user) : null;
      const a = asst ? getComputedStyle(asst) : null;
      return {
        dark: c.includes("dream-theme-dark"),
        light: c.includes("dream-theme-light"),
        hasSkin: c.includes("codex-dream-skin"),
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
        userBorder: u ? u.borderTopWidth + " " + u.borderTopStyle : null,
        userRadius: u?.borderRadius || null,
        asstBorder: a ? a.borderTopWidth + " " + a.borderTopStyle : null,
        asstRadius: a?.borderRadius || null,
        hasUser: Boolean(user),
        hasAsst: Boolean(asst),
      };
    })()`);

    report.snapshot = snap;

    report.checks.hasSkin = Boolean(snap.hasSkin);
    report.checks.darkClass = Boolean(snap.dark);
    report.checks.notLightClass = !snap.light;
    report.checks.surfaceLumaPresent =
      typeof snap.surfaceLuma === "number" && Number.isFinite(snap.surfaceLuma);
    // Night themes should stay dark when surfaceLuma is present and low.
    report.checks.surfaceImpliesDark =
      !report.checks.surfaceLumaPresent || snap.surfaceLuma <= 0.45
        ? Boolean(snap.dark) && !snap.light
        : true;
    report.checks.bubbleModeKnown =
      Boolean(snap.bubbleBorderless) || Boolean(snap.bubbleCard);
    // When project task chrome is mounted, expect cover-ish art sizing (HD path).
    if (snap.hasTask) {
      const size = String(snap.taskBeforeSize || "").toLowerCase();
      report.checks.taskArtSized =
        size.includes("cover") || size.includes("%") || size.includes("px");
      const op = Number.parseFloat(snap.taskBeforeOpacity);
      report.checks.taskAmbientVisible =
        Number.isFinite(op) ? op >= 0.2 && op <= 1 : true;
    }

    const required = [
      "hasSkin",
      "darkClass",
      "notLightClass",
      "surfaceLumaPresent",
      "surfaceImpliesDark",
      "bubbleModeKnown",
    ];
    if (snap.hasTask) {
      required.push("taskArtSized", "taskAmbientVisible");
    }

    const failed = required.filter((k) => !report.checks[k]);
    report.failed = failed;
    report.pass = failed.length === 0;
    if (!report.pass) {
      report.notes.push(`failed checks: ${failed.join(", ")}`);
    }
    if (report.checks.surfaceLumaPresent) {
      report.notes.push(`surfaceLuma=${snap.surfaceLuma}`);
    } else {
      report.notes.push(
        "surfaceLuma missing — injector may not pass palette.surface (#rrggbb only for luma)",
      );
    }
    if (snap.hasTask) {
      report.notes.push(
        `task before size=${snap.taskBeforeSize} opacity=${snap.taskBeforeOpacity}`,
      );
    } else {
      report.notes.push(
        "no .dream-task in DOM — open a project/task route for full HD checks",
      );
    }
  } finally {
    session.close();
  }

  report.finishedAt = new Date().toISOString();
  try {
    if (process.env.LOCALAPPDATA) {
      await writeFile(OUT, JSON.stringify(report, null, 2), "utf8");
    }
  } catch {
    // ignore write errors (still print)
  }
  console.log(JSON.stringify(report, null, 2));
  if (!report.pass) process.exitCode = 2;
}

main().catch((error) => {
  console.error(String(error?.stack || error));
  process.exitCode = 1;
});
