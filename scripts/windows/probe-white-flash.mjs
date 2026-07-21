/**
 * Live CDP probe: white-flash / appearance health for codex-skin.
 * Run: node scripts/windows/probe-white-flash.mjs
 */
import { writeFile } from "node:fs/promises";
import { join } from "node:path";

const PORT = 9335;
const OUT = join(
  process.env.LOCALAPPDATA || "",
  "CodexDreamSkin",
  "probe-white-flash-result.json",
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

function parseRgb(str) {
  if (!str || typeof str !== "string") return null;
  const m = str.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i);
  if (!m) return null;
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

/** Approximate relative luminance from css color string (rgb or oklab L channel). */
function approxLumaFromCss(str) {
  const rgb = parseRgb(str);
  if (rgb) {
    const lin = rgb.map((v) => {
      const c = v / 255;
      return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
  }
  // oklab(L a b) / oklch(L c h) — L is perceptual lightness 0..1
  const okl = str.match(/okla?b?\(\s*([\d.]+)/i) || str.match(/oklch\(\s*([\d.]+)/i);
  if (okl) return Number(okl[1]);
  return null;
}

function relativeLuma(rgb) {
  if (!rgb) return null;
  const lin = rgb.map((v) => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
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

  const session = await new Cdp(
    validatedWs(page.webSocketDebuggerUrl, PORT),
  ).open();

  try {
    const snap = await session.evaluate(`(() => {
      const root = document.documentElement;
      const body = document.body;
      const main =
        document.querySelector("main.main-surface") ||
        document.querySelector("main") ||
        document.querySelector('[role="main"]');
      const state = window.__CODEX_DREAM_SKIN_STATE__;
      const csRoot = getComputedStyle(root);
      const csBody = body ? getComputedStyle(body) : null;
      const csMain = main ? getComputedStyle(main) : null;
      const className = root.className || "";
      return {
        hasState: Boolean(state),
        version: state?.version ?? null,
        hasSkinClass: className.includes("codex-dream-skin"),
        themeDark: className.includes("dream-theme-dark"),
        themeLight: className.includes("dream-theme-light"),
        artWide: className.includes("dream-art-wide"),
        hasArt: className.includes("dream-has-art"),
        hasMain: Boolean(main),
        homeShell: Boolean(main?.classList?.contains("dream-home-shell")),
        stylePresent: Boolean(document.getElementById("codex-dream-skin-style")),
        chromePresent: Boolean(document.getElementById("codex-dream-skin-chrome")),
        rootColorScheme: csRoot.colorScheme || null,
        bodyBg: csBody?.backgroundColor || null,
        mainBg: csMain?.backgroundColor || null,
        dreamCanvas: csRoot.getPropertyValue("--dream-canvas")?.trim() || null,
        dreamSurface: csRoot.getPropertyValue("--dream-surface")?.trim() || null,
        dreamText: csRoot.getPropertyValue("--dream-text")?.trim() || null,
        dreamAccent: csRoot.getPropertyValue("--dream-accent")?.trim() || null,
        dreamArt: (csRoot.getPropertyValue("--dream-art") || "").slice(0, 48),
        dataTheme: root.getAttribute("data-theme"),
        dataAppearance: root.getAttribute("data-appearance"),
        dataColorMode: root.getAttribute("data-color-mode"),
        configAppearance: state?.config?.appearance ?? null,
        configSurfaceLuma: state?.config?.surfaceLuma ?? null,
        profileAppearance: state?.profile?.appearance ?? null,
        disabled: Boolean(window.__CODEX_DREAM_SKIN_DISABLED__),
      };
    })()`);

    report.snapshot = snap;

    // Read active-theme palette via filesystem is outside page; infer health from classes + bg luma.
    const bodyLuma = approxLumaFromCss(snap.bodyBg);
    const mainLuma = approxLumaFromCss(snap.mainBg);
    report.checks.bodyLuma = bodyLuma;
    report.checks.mainLuma = mainLuma;

    report.checks.hasSkin = Boolean(snap.hasSkinClass && snap.stylePresent);
    report.checks.darkClass = Boolean(snap.themeDark);
    report.checks.notLightClass = !snap.themeLight;
    report.checks.mainPresent = Boolean(snap.hasMain);
    // Near-white paper ~ luma > 0.85 is the failure mode for night themes.
    // oklab body on dark tokens is ~0.16–0.25; paper white ~0.97.
    report.checks.bodyNotPaperWhite =
      bodyLuma == null ? Boolean(snap.themeDark) : bodyLuma < 0.75;
    report.checks.mainNotPaperWhite =
      mainLuma == null || mainLuma === 0
        ? true // transparent main is OK when body/art carry chrome
        : mainLuma < 0.75;
    report.checks.surfaceLumaPresent =
      typeof snap.configSurfaceLuma === "number" && Number.isFinite(snap.configSurfaceLuma);
    report.checks.surfaceImpliesDark =
      !report.checks.surfaceLumaPresent || snap.configSurfaceLuma <= 0.45
        ? Boolean(snap.themeDark)
        : true;

    // Simulate missing main: ensure path should NOT clear skin (new behavior).
    // We only check that clearSkinDom is not auto-run by evaluating a soft probe:
    // if ensure exists, call schedule path indirectly by dispatching a no-op mutation after
    // temporary main hide is too invasive; instead verify function source contains guard.
    const sourceGuard = await session.evaluate(`(() => {
      const style = document.getElementById("codex-dream-skin-style");
      // Cannot read closed-over ensure source; check runtime version stamp + state fields.
      const state = window.__CODEX_DREAM_SKIN_STATE__;
      return {
        version: state?.version ?? style?.dataset?.dreamVersion ?? null,
        hasEnsure: typeof state?.ensure === "function",
        hasCleanup: typeof state?.cleanup === "function",
      };
    })()`);
    report.sourceGuard = sourceGuard;

    // Kick ensure once and re-read classes (should stay dark for night palette themes).
    if (snap.hasState) {
      await session.evaluate(`(() => {
        const s = window.__CODEX_DREAM_SKIN_STATE__;
        try { s?.ensure?.(); } catch (e) { return String(e); }
        return "ok";
      })()`);
      const after = await session.evaluate(`(() => {
        const c = document.documentElement.className || "";
        return {
          themeDark: c.includes("dream-theme-dark"),
          themeLight: c.includes("dream-theme-light"),
          hasSkin: c.includes("codex-dream-skin"),
        };
      })()`);
      report.afterEnsure = after;
      report.checks.stillDarkAfterEnsure = Boolean(after.themeDark) && !after.themeLight;
    }

    // F6 / cycleTheme presence (bonus for P+C path)
    const f6 = await session.evaluate(`(() => {
      const s = window.__CODEX_DREAM_SKIN_STATE__;
      return {
        hasCycleTheme: typeof s?.cycleTheme === "function",
        hasSetTheme: typeof s?.setTheme === "function",
        catalogLen: Array.isArray(s?.catalog) ? s.catalog.length : null,
        keys: s ? Object.keys(s).slice(0, 30) : [],
      };
    })()`);
    report.f6 = f6;

    const required = [
      "hasSkin",
      "darkClass",
      "notLightClass",
      "mainPresent",
      "bodyNotPaperWhite",
      "mainNotPaperWhite",
      "surfaceLumaPresent",
      "surfaceImpliesDark",
    ];
    if (report.afterEnsure) required.push("stillDarkAfterEnsure");

    const failed = required.filter((k) => !report.checks[k]);
    report.failed = failed;
    report.pass = failed.length === 0;

    if (!report.pass) {
      report.notes.push(`failed checks: ${failed.join(", ")}`);
    }
    if (bodyLuma != null && bodyLuma >= 0.55 && snap.themeDark) {
      report.notes.push(
        "body luma mid/high while dark class set — may still look washed; inspect immersive layers",
      );
    }
    if (!f6.hasCycleTheme) {
      report.notes.push("F6 cycleTheme missing on live state (usage may be stale)");
    }

    // Config surfaceLuma should be present after fix for heige themes
    if (snap.configSurfaceLuma == null) {
      report.notes.push("state.config.surfaceLuma missing — injector may not pass palette.surface");
    } else {
      report.notes.push(`surfaceLuma=${snap.configSurfaceLuma}`);
    }
  } finally {
    session.close();
  }

  report.finishedAt = new Date().toISOString();
  await writeFile(OUT, JSON.stringify(report, null, 2), "utf8");
  console.log(JSON.stringify(report, null, 2));
  if (!report.pass) process.exitCode = 2;
}

main().catch((error) => {
  console.error(String(error?.stack || error));
  process.exitCode = 1;
});
