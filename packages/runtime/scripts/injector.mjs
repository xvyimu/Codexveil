// === TOC (approximate line anchors; search // === Region: ) ===
// 1. Constants / version token                         ~L40+
// 2. parseArgs (--theme-dir, --state-root, modes)      Region: ParseArgs
// 3. CDP session / identity / targets                  Region: CdpSession
// 4. Theme load / catalog / payload budget             Region: ThemeLoad
// 5. Apply / verify / one-shot                         Region: Apply
// 6. Watch main loop + signals                         Region: Watch
// 7. Control-plane startup                             Region: ControlPlane
// 8. CLI entry (self-test / check-payload / watch)     Region: Main
// Single-file daemon by design (ADR 0001); do not split without publish copy list.

import fs from "node:fs/promises";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readImageMetadata } from "./image-metadata.mjs";
import { BROWSER_ID_PATTERN, isValidBrowserId, validatedDebuggerUrl } from "./cdp-url-guard.mjs";
import {
  MAX_THEME_CATALOG_ENTRIES,
  MAX_THEME_CATALOG_BYTES,
  MAX_CATALOG_MEMBER_BYTES,
  evaluateCatalogMemberBudget,
} from "./theme-catalog-budget.mjs";

const scriptPath = fileURLToPath(import.meta.url);
const here = path.dirname(scriptPath);
const root = path.resolve(here, "..");
// Version is the sole authority written by publish-runtime.ps1 (-Version arg).
// The placeholder pattern below stays literal in the repo copy so dev runs
// (`node packages/runtime/scripts/injector.mjs`) resolve to "dev"; publish
// rewrites the placeholder to the release version in both this file and in
// versions/<id>/scripts/injector.mjs.
// Note: after publish-runtime.ps1 -Version X, the repo source is also stamped
// (e.g. "1.3.25"); SKIN_VERSION === "dev" only on unpublished working copies.
const SKIN_VERSION_TOKEN = "1.3.25";
const SKIN_VERSION = SKIN_VERSION_TOKEN === "__" + "SKIN_VERSION__" ? "dev" : SKIN_VERSION_TOKEN;
const MAX_ART_BYTES = 16 * 1024 * 1024;
const DEFAULT_PAYLOAD_BUDGET_BYTES = 4 * 1024 * 1024;
// Strong audit less often: catalog stamp checks already cover normal switches.
const STRONG_THEME_AUDIT_MS = 60000;
// BROWSER_ID_PATTERN / isValidBrowserId: packages/runtime/scripts/cdp-url-guard.mjs

class CdpIdentityMismatchError extends Error {}

// === Region: ParseArgs ===
function parseArgs(argv) {
  const options = {
    port: 9335,
    mode: "watch",
    timeoutMs: 30000,
    screenshot: null,
    reload: false,
    browserId: null,
    themeDir: path.join(root, "assets"),
    /** Explicit state root for control.port / control.token / state.json patches.
     * Prefer over dirname(themeDir) so soft reattach / dev never write under versions/<id>. */
    stateRoot: null,
    pauseFile: null,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--port") options.port = Number(argv[++i]);
    else if (arg === "--once") options.mode = "once";
    else if (arg === "--watch") options.mode = "watch";
    else if (arg === "--verify") options.mode = "verify";
    else if (arg === "--remove") options.mode = "remove";
    else if (arg === "--timeout-ms") options.timeoutMs = Number(argv[++i]);
    else if (arg === "--browser-id") options.browserId = argv[++i];
    else if (arg === "--theme-dir") options.themeDir = path.resolve(argv[++i]);
    else if (arg === "--state-root") options.stateRoot = path.resolve(argv[++i]);
    else if (arg === "--pause-file") options.pauseFile = path.resolve(argv[++i]);
    else if (arg === "--screenshot") options.screenshot = path.resolve(argv[++i]);
    else if (arg === "--reload") options.reload = true;
    else if (arg === "--self-test") options.mode = "self-test";
    else if (arg === "--check-payload") options.mode = "check-payload";
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!Number.isInteger(options.port) || options.port < 1024 || options.port > 65535) {
    throw new Error(`Invalid port: ${options.port}`);
  }
  if (!Number.isInteger(options.timeoutMs) || options.timeoutMs < 250 || options.timeoutMs > 120000) {
    throw new Error(`Invalid timeout: ${options.timeoutMs}`);
  }
  if (options.browserId !== null && !isValidBrowserId(options.browserId)) {
    throw new Error(`Invalid browser ID: ${options.browserId}`);
  }
  if (["watch", "once", "verify", "remove"].includes(options.mode) && !options.browserId) {
    throw new Error(`--browser-id is required in ${options.mode} mode`);
  }
  return options;
}

function browserIdFromVersion(version, port) {
  const url = validatedDebuggerUrl(version, port);
  const parsed = new URL(url);
  const match = parsed.pathname.match(/^\/devtools\/browser\/([A-Za-z0-9._-]{1,200})$/);
  if (!match || parsed.search || parsed.hash || !isValidBrowserId(match[1])) {
    throw new Error("Rejected an invalid CDP browser identity URL");
  }
  return match[1];
}

function isValidCdpPageTarget(item, port) {
  if (item?.type !== "page" || !item.url?.startsWith("app://") || !isValidBrowserId(item.id) ||
      !item.webSocketDebuggerUrl) return false;
  try {
    const debuggerUrl = new URL(validatedDebuggerUrl(item, port));
    return debuggerUrl.pathname === `/devtools/page/${item.id}`;
  } catch {
    return false;
  }
}

// === Region: CdpSession ===
class CdpSession {
  constructor(target, port) {
    this.target = target;
    this.ws = new WebSocket(validatedDebuggerUrl(target, port));
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
    this.closed = false;
  }

  async open() {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        try { this.ws.close(); } catch {}
        reject(new Error("CDP WebSocket open timed out"));
      }, 5000);
      this.ws.addEventListener("open", () => { clearTimeout(timeout); resolve(); }, { once: true });
      this.ws.addEventListener("error", () => { clearTimeout(timeout); reject(new Error("CDP WebSocket open failed")); }, { once: true });
    });
    this.ws.addEventListener("message", (event) => this.onMessage(event));
    this.ws.addEventListener("error", () => this.close());
    this.ws.addEventListener("close", () => {
      this.closed = true;
      for (const waiter of this.pending.values()) {
        clearTimeout(waiter.timeout);
        waiter.reject(new Error("CDP socket closed"));
      }
      this.pending.clear();
    });
    await this.send("Runtime.enable");
    await this.send("Page.enable");
    return this;
  }

  onMessage(event) {
    let message;
    try {
      message = JSON.parse(String(event.data));
    } catch {
      this.close();
      return;
    }
    if (message.id) {
      const waiter = this.pending.get(message.id);
      if (!waiter) return;
      clearTimeout(waiter.timeout);
      this.pending.delete(message.id);
      if (message.error) waiter.reject(new Error(`${message.error.message} (${message.error.code})`));
      else waiter.resolve(message.result);
      return;
    }
    for (const listener of this.listeners.get(message.method) ?? []) listener(message.params ?? {});
  }

  on(method, listener) {
    const listeners = this.listeners.get(method) ?? [];
    listeners.push(listener);
    this.listeners.set(method, listeners);
  }

  send(method, params = {}) {
    if (this.closed) return Promise.reject(new Error("CDP session is closed"));
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP command timed out: ${method}`));
      }, 10000);
      this.pending.set(id, { resolve, reject, timeout });
      try {
        this.ws.send(JSON.stringify({ id, method, params }));
      } catch (error) {
        clearTimeout(timeout);
        this.pending.delete(id);
        reject(error);
      }
    });
  }

  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true,
      userGesture: false,
    });
    if (result.exceptionDetails) {
      const detail = result.exceptionDetails.exception?.description ?? result.exceptionDetails.text;
      throw new Error(`Renderer evaluation failed: ${detail}`);
    }
    return result.result?.value;
  }

  close() {
    for (const waiter of this.pending.values()) {
      clearTimeout(waiter.timeout);
      waiter.reject(new Error("CDP session closed"));
    }
    this.pending.clear();
    if (!this.closed) {
      try { this.ws.close(); } catch {}
    }
    this.closed = true;
  }
}

class BrowserIdentityAnchor {
  constructor(url) {
    this.ws = new WebSocket(url);
    this.closed = false;
    this.ws.addEventListener("close", () => { this.closed = true; });
    this.ws.addEventListener("error", () => {
      this.closed = true;
      try { this.ws.close(); } catch {}
    });
  }

  async open() {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.close();
        reject(new Error("CDP browser identity WebSocket open timed out"));
      }, 5000);
      this.ws.addEventListener("open", () => { clearTimeout(timeout); resolve(); }, { once: true });
      this.ws.addEventListener("error", () => {
        clearTimeout(timeout);
        reject(new Error("CDP browser identity WebSocket open failed"));
      }, { once: true });
      this.ws.addEventListener("close", () => {
        clearTimeout(timeout);
        reject(new Error("CDP browser identity WebSocket closed during startup"));
      }, { once: true });
    });
    if (this.closed) throw new Error("CDP browser identity WebSocket is already closed");
    return this;
  }

  close() {
    if (!this.closed) {
      try { this.ws.close(); } catch {}
    }
    this.closed = true;
  }
}

async function fetchCdpJson(port, resource) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2000);
  try {
    const response = await fetch(`http://127.0.0.1:${port}${resource}`, {
      redirect: "error",
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

async function listAppTargets(port, expectedBrowserId = null) {
  const targets = await fetchCdpJson(port, "/json/list");
  if (!Array.isArray(targets)) throw new Error("CDP target list is not an array");
  if (expectedBrowserId) {
    const version = await fetchCdpJson(port, "/json/version");
    const actualBrowserId = browserIdFromVersion(version, port);
    if (actualBrowserId !== expectedBrowserId) {
      throw new CdpIdentityMismatchError(
        `CDP browser identity changed from ${expectedBrowserId} to ${actualBrowserId}`,
      );
    }
  }
  return targets.filter((item) => isValidCdpPageTarget(item, port));
}

async function connectBrowserIdentityAnchor(port, expectedBrowserId) {
  const version = await fetchCdpJson(port, "/json/version");
  const actualBrowserId = browserIdFromVersion(version, port);
  if (actualBrowserId !== expectedBrowserId) {
    throw new CdpIdentityMismatchError(
      `CDP browser identity changed from ${expectedBrowserId} to ${actualBrowserId}`,
    );
  }
  return new BrowserIdentityAnchor(validatedDebuggerUrl(version, port)).open();
}

const THEME_CHOICES = {
  appearance: new Set(["auto", "light", "dark"]),
  safeArea: new Set(["auto", "left", "right", "center", "none"]),
  taskMode: new Set(["auto", "ambient", "banner", "off"]),
};

function normalizedUnit(value, name) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0 || number > 1) {
    throw new Error(`${name} must be null or a number between 0 and 1`);
  }
  return number;
}

function normalizedChoice(value, name, choices, fallback) {
  if (value === null || value === undefined || value === "") return fallback;
  if (!choices.has(value)) throw new Error(`${name} has an unsupported value: ${value}`);
  return value;
}

function normalizedText(value, name, fallback, maxLength = 120) {
  if (value === null || value === undefined || value === "") return fallback;
  if (typeof value !== "string" || value.length > maxLength || /[\u0000-\u001f]/.test(value)) {
    throw new Error(`${name} must be a short single-line string`);
  }
  return value;
}

// === Region: ThemeLoad ===
async function loadTheme(themeDir) {
  const realThemeDir = await fs.realpath(themeDir);
  const themePath = path.join(realThemeDir, "theme.json");
  const themeText = await fs.readFile(themePath, "utf8");
  const raw = JSON.parse(themeText);
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error("Theme root must be an object");
  }
  const image = normalizedText(raw.image, "image", null, 240);
  if (!image || path.isAbsolute(image)) throw new Error("Theme image must be a relative path");
  const imagePath = path.resolve(realThemeDir, image);
  const relativeImage = path.relative(realThemeDir, imagePath);
  if (!relativeImage || relativeImage.startsWith("..") || path.isAbsolute(relativeImage)) {
    throw new Error("Theme image must remain inside the selected theme directory");
  }
  const extension = path.extname(imagePath).toLowerCase();
  if (![".png", ".jpg", ".jpeg", ".webp"].includes(extension)) {
    throw new Error(`Unsupported theme image format: ${extension || "missing"}`);
  }
  const realImagePath = await fs.realpath(imagePath);
  const realRelativeImage = path.relative(realThemeDir, realImagePath);
  if (!realRelativeImage || realRelativeImage.startsWith("..") || path.isAbsolute(realRelativeImage)) {
    throw new Error("Theme image cannot escape through a link or junction");
  }
  const art = raw.art && typeof raw.art === "object" && !Array.isArray(raw.art) ? raw.art : {};
  const palette = raw.palette && typeof raw.palette === "object" && !Array.isArray(raw.palette)
    ? raw.palette : {};
  const name = normalizedText(raw.name, "name", "Codex Dream Skin", 120);
  const theme = {
    id: normalizedText(raw.id, "id", "custom", 80),
    name,
    // Brand strings feed the heige-style left-top overlay. brandSubtitle falls
    // back to the theme name so every theme shows at least its name; tagline is
    // optional (blank -> the headline line is simply not rendered).
    brandSubtitle: normalizedText(raw.brandSubtitle, "brandSubtitle", name, 80),
    tagline: normalizedText(raw.tagline, "tagline", "", 160),
    image,
    appearance: normalizedChoice(raw.appearance, "appearance", THEME_CHOICES.appearance, "auto"),
    art: {
      focusX: normalizedUnit(art.focusX, "art.focusX"),
      focusY: normalizedUnit(art.focusY, "art.focusY"),
      safeArea: normalizedChoice(art.safeArea, "art.safeArea", THEME_CHOICES.safeArea, "auto"),
      taskMode: normalizedChoice(art.taskMode, "art.taskMode", THEME_CHOICES.taskMode, "auto"),
    },
    palette: {},
  };
  // Pass full heige/DreamSkin palette (not just accent). surface/text drive
  // renderer resolveAppearance + optional CSS vars; omitting surface forced
  // appearance:auto onto flaky shell light → white flash on project open.
  const cssColor = /^(?:#[\da-f]{3,8}|(?:rgb|hsl|oklch|oklab)\([^;{}]{1,96}\))$/i;
  for (const key of ["accent", "secondary", "surface", "text"]) {
    if (typeof palette[key] === "string" && palette[key].trim()) {
      const value = palette[key].trim();
      if (!cssColor.test(value)) {
        throw new Error(`palette.${key} is not a supported CSS color`);
      }
      theme.palette[key] = value;
    }
  }
  const [themeStat, imageStat] = await Promise.all([fs.stat(themePath), fs.stat(realImagePath)]);
  if (!imageStat.isFile()) throw new Error("Theme image is not a file");
  if (imageStat.size < 1) throw new Error("Theme image cannot be empty");
  if (imageStat.size > MAX_ART_BYTES) {
    throw new Error(`Theme image exceeds the ${MAX_ART_BYTES / 1024 / 1024} MB limit`);
  }
  const imageBytes = await fs.readFile(realImagePath);
  if (imageBytes.length < 1 || imageBytes.length > MAX_ART_BYTES) {
    throw new Error(`Theme image must be between 1 byte and ${MAX_ART_BYTES / 1024 / 1024} MB`);
  }
  const artMetadata = readImageMetadata(imageBytes, extension);
  if (!artMetadata) {
    throw new Error("Theme image metadata is invalid or exceeds the 16384px / 50MP safety limit");
  }
  theme.artMetadata = artMetadata;
  const fingerprint = createHash("sha256")
    .update(themeText, "utf8")
    .update("\0")
    .update(imageBytes)
    .digest("hex");
  return {
    theme,
    themePath,
    imagePath: realImagePath,
    imageBytes,
    fingerprint,
    sourceStamp: `${themeStat.size}:${themeStat.mtimeMs}:${imageStat.size}:${imageStat.mtimeMs}`,
  };
}

function imageDataUrl(loadedTheme) {
  const extension = path.extname(loadedTheme.imagePath).toLowerCase();
  const mime = extension === ".jpg" || extension === ".jpeg" ? "image/jpeg"
    : extension === ".webp" ? "image/webp" : "image/png";
  return "data:" + mime + ";base64," + loadedTheme.imageBytes.toString("base64");
}

function themesRootFor(themeDir) {
  return path.join(path.dirname(path.resolve(themeDir)), "themes");
}

async function readCatalogSourceStamp(themeDir) {
  // Cheap change detector for the watch loop: root + child dir mtimes only.
  // Full catalog fingerprint is still computed inside loadThemeCatalog on audit.
  const savedRoot = themesRootFor(themeDir);
  try {
    const realSavedRoot = await fs.realpath(savedRoot);
    const rootStat = await fs.stat(realSavedRoot);
    const candidates = (await fs.readdir(realSavedRoot, { withFileTypes: true }))
      .filter((entry) => entry.isDirectory())
      .sort((left, right) => left.name.localeCompare(right.name));
    const parts = [`${rootStat.size}:${rootStat.mtimeMs}`];
    for (const candidate of candidates) {
      try {
        const candidatePath = path.join(realSavedRoot, candidate.name);
        const realCandidatePath = await fs.realpath(candidatePath);
        const relative = path.relative(realSavedRoot, realCandidatePath);
        if (!relative || relative.startsWith("..") || path.isAbsolute(relative)) continue;
        const dirStat = await fs.stat(realCandidatePath);
        parts.push(`${candidate.name}@${dirStat.mtimeMs}`);
      } catch {
        parts.push(`${candidate.name}:bad`);
      }
    }
    return parts.join("|");
  } catch (error) {
    if (error?.code === "ENOENT") return "missing";
    throw error;
  }
}

async function loadCatalogMember(themeDir) {
  // Prefer thumb.* first so large themes avoid multi-MB art reads on catalog rebuild.
  for (const name of ["thumb.jpg", "thumb.jpeg", "thumb.webp", "thumb.png"]) {
    const thumbPath = path.join(themeDir, name);
    try {
      const thumbStat = await fs.stat(thumbPath);
      if (!thumbStat.isFile() || thumbStat.size < 32 || thumbStat.size > MAX_CATALOG_MEMBER_BYTES) continue;
      const themePath = path.join(themeDir, "theme.json");
      const themeText = await fs.readFile(themePath, "utf8");
      const raw = JSON.parse(themeText);
      if (!raw || typeof raw !== "object" || Array.isArray(raw)) continue;
      const theme = {
        id: normalizedText(raw.id, "id", path.basename(themeDir), 80),
        name: normalizedText(raw.name, "name", path.basename(themeDir), 120),
        image: name,
        appearance: normalizedChoice(raw.appearance, "appearance", THEME_CHOICES.appearance, "auto"),
        art: raw.art && typeof raw.art === "object" ? {
          focusX: normalizedUnit(raw.art.focusX, "art.focusX"),
          focusY: normalizedUnit(raw.art.focusY, "art.focusY"),
          safeArea: normalizedChoice(raw.art.safeArea, "art.safeArea", THEME_CHOICES.safeArea, "auto"),
          taskMode: normalizedChoice(raw.art.taskMode, "art.taskMode", THEME_CHOICES.taskMode, "auto"),
        } : { focusX: null, focusY: null, safeArea: "auto", taskMode: "auto" },
        palette: {},
      };
      if (raw.palette && typeof raw.palette === "object" && !Array.isArray(raw.palette)) {
        const cssColor = /^(?:#[\da-f]{3,8}|(?:rgb|hsl|oklch|oklab)\([^;{}]{1,96}\))$/i;
        for (const key of ["accent", "secondary", "surface", "text"]) {
          if (typeof raw.palette[key] === "string" && raw.palette[key].trim()) {
            const value = raw.palette[key].trim();
            if (cssColor.test(value)) theme.palette[key] = value;
          }
        }
      }
      const thumbBytes = await fs.readFile(thumbPath);
      const ext = path.extname(thumbPath).toLowerCase();
      const artMetadata = readImageMetadata(thumbBytes, ext);
      if (artMetadata) theme.artMetadata = artMetadata;
      const fingerprint = createHash("sha256")
        .update(themeText, "utf8")
        .update("\0thumb\0")
        .update(thumbBytes)
        .digest("hex");
      return {
        theme,
        themePath,
        imagePath: thumbPath,
        imageBytes: thumbBytes,
        fingerprint,
        sourceStamp: `${thumbStat.size}:${thumbStat.mtimeMs}`,
        isThumb: true,
      };
    } catch {
      // try next thumb name / fall through
    }
  }

  // No usable thumb: only keep full art if it already fits catalog budget.
  const full = await loadTheme(themeDir).catch(() => null);
  if (!full) return null;
  if (full.imageBytes.length <= MAX_CATALOG_MEMBER_BYTES) {
    return { ...full, isThumb: false };
  }
  return null;
}

async function loadThemeCatalog(themeDir, activeTheme) {
  const entries = [];
  const fingerprints = [];
  const usedKeys = new Set();
  let catalogImageBytes = 0;
  let skippedLarge = 0;
  let skippedBudget = 0;
  let thumbCount = 0;
  const stampParts = [];

  const add = (key, loadedTheme, { requireFull = false } = {}) => {
    const size = loadedTheme.imageBytes.length;
    const decision = evaluateCatalogMemberBudget({
      currentEntryCount: entries.length,
      currentCatalogImageBytes: catalogImageBytes,
      candidateImageBytes: size,
      requireFull,
    });
    if (!decision.accept) {
      if (decision.reason === "member-too-large") skippedLarge += 1;
      else if (decision.reason === "catalog-bytes") skippedBudget += 1;
      // max-entries: no skip counter (preserve current behavior)
      return false;
    }
    let uniqueKey = key;
    let suffix = 2;
    while (usedKeys.has(uniqueKey)) {
      uniqueKey = key + "-" + suffix;
      suffix += 1;
    }
    usedKeys.add(uniqueKey);
    entries.push({
      key: uniqueKey,
      name: loadedTheme.theme.name,
      config: loadedTheme.theme,
      artDataUrl: imageDataUrl(loadedTheme),
    });
    fingerprints.push(uniqueKey + ":" + loadedTheme.fingerprint);
    catalogImageBytes = decision.nextCatalogImageBytes;
    if (loadedTheme.isThumb) thumbCount += 1;
    return true;
  };

  add("active", activeTheme, { requireFull: true });

  let catalogSourceStamp = "missing";
  const savedRoot = themesRootFor(themeDir);
  try {
    const realSavedRoot = await fs.realpath(savedRoot);
    const rootStat = await fs.stat(realSavedRoot);
    stampParts.push(`${rootStat.size}:${rootStat.mtimeMs}`);
    const candidates = (await fs.readdir(realSavedRoot, { withFileTypes: true }))
      .filter((entry) => entry.isDirectory())
      .sort((left, right) => left.name.localeCompare(right.name));
    const settled = await Promise.all(candidates.map(async (candidate) => {
      try {
        const candidatePath = path.join(realSavedRoot, candidate.name);
        const realCandidatePath = await fs.realpath(candidatePath);
        const relative = path.relative(realSavedRoot, realCandidatePath);
        if (!relative || relative.startsWith("..") || path.isAbsolute(relative)) {
          return { stamp: `${candidate.name}:skip`, theme: null };
        }
        const dirStat = await fs.stat(realCandidatePath);
        const loaded = await loadCatalogMember(realCandidatePath);
        return {
          stamp: `${candidate.name}@${dirStat.mtimeMs}@${loaded ? loaded.fingerprint.slice(0, 16) : "bad"}`,
          theme: loaded,
        };
      } catch {
        return { stamp: `${candidate.name}:bad`, theme: null };
      }
    }));
    for (const item of settled) stampParts.push(item.stamp);
    catalogSourceStamp = stampParts.join("|");
    const extras = settled
      .map((item) => item.theme)
      .filter((theme) => theme && theme.fingerprint !== activeTheme.fingerprint && !theme.fingerprint.startsWith(activeTheme.fingerprint))
      .filter((theme) => theme.theme.id !== activeTheme.theme.id)
      .sort((a, b) => a.imageBytes.length - b.imageBytes.length);
    for (const theme of extras) {
      if (entries.length >= MAX_THEME_CATALOG_ENTRIES) break;
      add("saved:" + theme.theme.id, theme);
    }
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }

  return {
    entries,
    fingerprint: fingerprints.join("|"),
    catalogImageBytes,
    catalogSourceStamp,
    skippedLarge,
    skippedBudget,
    thumbCount,
  };
}

async function loadPayload(themeDir = path.join(root, "assets"), candidateTheme = null) {
  const loadedTheme = candidateTheme ?? await loadTheme(themeDir);
  const [css, template, themeCatalog] = await Promise.all([
    fs.readFile(path.join(root, "assets", "dream-skin.css"), "utf8"),
    fs.readFile(path.join(root, "assets", "renderer-inject.js"), "utf8"),
    loadThemeCatalog(themeDir, loadedTheme),
  ]);
  // Active art rides __DREAM_ART_JSON__ as a data URL so the renderer paints the
  // right-half hero (heige-style). __DREAM_THEME_JSON__ carries the active theme
  // config (art focus + palette + brand copy) that drives the ::before/::after
  // brand overlay. Catalog stays the F6 channel (best-effort; may be dropped by
  // older renderers that only read 3 args).
  // bubbleStyle from ui-prefs.json (borderless|card) — conversation chrome.
  let bubbleStyle = "borderless";
  try {
    const stateRoot = path.dirname(path.resolve(themeDir));
    const prefsPath = path.join(stateRoot, "ui-prefs.json");
    const prefsRaw = await fs.readFile(prefsPath, "utf8");
    const prefs = JSON.parse(prefsRaw.replace(/^﻿/, ""));
    if (prefs && typeof prefs.bubbleStyle === "string") {
      const bs = prefs.bubbleStyle.trim().toLowerCase();
      if (bs === "card" || bs === "borderless") bubbleStyle = bs;
    }
  } catch {
    // missing prefs → borderless default
  }
  const themeForInject = { ...loadedTheme.theme, bubbleStyle };
  const activeArtDataUrl = imageDataUrl(loadedTheme);
  const payload = template
    .replace("__DREAM_CSS_JSON__", JSON.stringify(css))
    .replace("__DREAM_ART_JSON__", JSON.stringify(activeArtDataUrl))
    .replace("__DREAM_THEME_JSON__", JSON.stringify(themeForInject))
    .replace("__DREAM_THEME_CATALOG_JSON__", JSON.stringify(themeCatalog.entries));
  const fingerprint = createHash("sha256")
    .update(loadedTheme.fingerprint)
    .update("\0")
    .update(themeCatalog.fingerprint)
    .update("\0")
    .update(bubbleStyle)
    .digest("hex");
  const { imageBytes: _imageBytes, ...themeState } = loadedTheme;
  return {
    ...themeState,
    activeThemeFingerprint: loadedTheme.fingerprint,
    catalogSourceStamp: themeCatalog.catalogSourceStamp,
    fingerprint,
    imageBytes: loadedTheme.imageBytes.length,
    catalogImageBytes: themeCatalog.catalogImageBytes,
    themeCount: themeCatalog.entries.length,
    catalogSkippedLarge: themeCatalog.skippedLarge ?? 0,
    catalogSkippedBudget: themeCatalog.skippedBudget ?? 0,
    catalogThumbCount: themeCatalog.thumbCount ?? 0,
    payload,
  };
}

async function fileExists(filePath) {
  if (!filePath) return false;
  try {
    return (await fs.stat(filePath)).isFile();
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

async function readThemeSourceStamp(loadedTheme) {
  const [themeStat, imageStat] = await Promise.all([
    fs.stat(loadedTheme.themePath),
    fs.stat(loadedTheme.imagePath),
  ]);
  return `${themeStat.size}:${themeStat.mtimeMs}:${imageStat.size}:${imageStat.mtimeMs}`;
}

async function probeSession(session) {
  // Adaptive markers: Codex Store updates often rename classes; keep classic
  // selectors first, then fall back to stable structural signals.
  return session.evaluate(`(() => {
    const q = (sel) => {
      try { return Boolean(document.querySelector(sel)); } catch { return false; }
    };
    const markers = {
      shell: q('main.main-surface') || q('main[class*="main-surface"]') || q('main[class*="MainSurface"]'),
      sidebar: q('aside.app-shell-left-panel') || q('aside[class*="left-panel"]') || q('aside[class*="sidebar"]') || q('nav[class*="sidebar"]'),
      composer: q('.composer-surface-chrome') || q('[class*="composer-surface"]') || q('[class*="ComposerSurface"]'),
      main: q('[role="main"]') || q('main'),
      root: q('#root'),
      appProtocol: location.protocol === 'app:',
    };
    const classic = markers.shell && markers.sidebar && (markers.composer || markers.main);
    const structural = markers.root && markers.appProtocol && (markers.main || markers.composer || markers.shell);
    const soft = markers.appProtocol && markers.shell && markers.main;
    return {
      markers,
      codex: markers.appProtocol && (classic || structural || soft),
      probeVersion: 2,
    };
  })()`);
}

async function waitForCodexProbe(session, timeoutMs = 1800) {
  const deadline = Date.now() + timeoutMs;
  let probe = null;
  while (Date.now() < deadline) {
    try {
      probe = await probeSession(session);
      if (probe?.codex) return probe;
    } catch {
      // The renderer may be between documents while the early payload waits.
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  return probe;
}

async function connectTarget(target, port) {
  return new CdpSession(target, port).open();
}

async function connectCodexTargets(port, timeoutMs, expectedBrowserId) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const targets = await listAppTargets(port, expectedBrowserId);
      const connected = [];
      for (const target of targets) {
        let session;
        try {
          session = await connectTarget(target, port);
          const probe = await probeSession(session);
          if (probe?.codex) connected.push({ target, session, probe });
          else session.close();
        } catch (error) {
          session?.close();
          lastError = error;
        }
      }
      if (connected.length) return connected;
      lastError = new Error("No page matched the expected Codex shell markers");
    } catch (error) {
      if (error instanceof CdpIdentityMismatchError) throw error;
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 350));
  }
  throw new Error(`No verified Codex renderer on 127.0.0.1:${port}: ${lastError?.message ?? "timed out"}`);
}

// === Region: Apply ===
async function applyToSession(session, payload) {
  return session.evaluate(payload);
}

export function earlyPayloadFor(payload, revision) {
  return `(() => {
    const generationKey = "__CODEX_DREAM_SKIN_EARLY_GENERATION__";
    const appliedKey = "__CODEX_DREAM_SKIN_EARLY_APPLIED__";
    const generation = ${JSON.stringify(revision)};
    window[generationKey] = generation;
    let observer = null;
    let timeout = null;
    const stop = () => {
      observer?.disconnect();
      observer = null;
      if (timeout) clearTimeout(timeout);
      timeout = null;
    };
    const install = () => {
      if (window[generationKey] !== generation) { stop(); return true; }
      const root = document.documentElement;
      if (!root || !document.body) return false;
      // Adaptive readiness for Codex DOM renames after Store updates.
      const shell = document.querySelector('main.main-surface, main[class*="main-surface"], main[class*="MainSurface"], main');
      const sidebar = document.querySelector('aside.app-shell-left-panel, aside[class*="left-panel"], aside[class*="sidebar"], nav[class*="sidebar"]');
      const composer = document.querySelector('.composer-surface-chrome, [class*="composer-surface"], [class*="ComposerSurface"]');
      const mainRole = document.querySelector('[role="main"]');
      const ready =
        (shell && sidebar) ||
        (document.getElementById('root') && (shell || composer || mainRole));
      if (!ready) return false;
      stop();
      ${payload};
      window[appliedKey] = generation;
      return true;
    };
    if (install()) return;
    if (typeof MutationObserver === "function" && document.documentElement) {
      observer = new MutationObserver(install);
      observer.observe(document.documentElement, { childList: true, subtree: true });
    }
    timeout = setTimeout(stop, 10000);
  })()`;
}

async function registerEarlyPayload(session, payload, revision) {
  const result = await session.send("Page.addScriptToEvaluateOnNewDocument", {
    source: earlyPayloadFor(payload, revision),
  });
  return result.identifier ?? null;
}

async function removeEarlyPayload(session, identifier) {
  if (!identifier || session.closed) return;
  await session.send("Page.removeScriptToEvaluateOnNewDocument", { identifier }).catch(() => {});
}

async function removeFromSession(session) {
  return session.evaluate(`(() => {
    window.__CODEX_DREAM_SKIN_DISABLED__ = true;
    const state = window.__CODEX_DREAM_SKIN_STATE__;
    if (state?.cleanup) return state.cleanup();
    document.documentElement?.classList.remove(
      'codex-dream-skin', 'dream-theme-light', 'dream-theme-dark',
      'dream-art-wide', 'dream-art-standard', 'dream-focus-left',
      'dream-focus-center', 'dream-focus-right', 'dream-safe-left',
      'dream-safe-center', 'dream-safe-right', 'dream-safe-none',
      'dream-task-ambient', 'dream-task-banner', 'dream-task-off',
      'dream-has-art', 'dream-has-brand', 'dream-has-headline'
    );
    for (const property of [
      '--dream-art', '--dream-art-position', '--dream-focus-x', '--dream-focus-y',
      '--dream-accent', '--dream-accent-ink', '--dream-image-luma',
      '--dream-brand', '--dream-headline'
    ]) document.documentElement?.style.removeProperty(property);
    document.querySelectorAll('.dream-home').forEach((node) => node.classList.remove('dream-home'));
    document.querySelectorAll('.dream-task').forEach((node) => node.classList.remove('dream-task'));
    document.querySelectorAll('.dream-home-shell').forEach((node) => node.classList.remove('dream-home-shell'));
    document.getElementById('codex-dream-skin-style')?.remove();
    document.getElementById('codex-dream-skin-chrome')?.remove();
    delete window.__CODEX_DREAM_SKIN_STATE__;
    return true;
  })()`);
}

async function verifyRemovedSession(session) {
  return session.evaluate(`(() =>
    !document.documentElement.classList.contains('codex-dream-skin') &&
    !document.documentElement.style.getPropertyValue('--dream-art') &&
    !document.querySelector('.dream-home') &&
    !document.querySelector('.dream-task') &&
    !document.querySelector('.dream-home-shell') &&
    !document.getElementById('codex-dream-skin-style') &&
    !document.getElementById('codex-dream-skin-chrome') &&
    !window.__CODEX_DREAM_SKIN_STATE__
  )()`);
}

async function verifySession(session) {
  return session.evaluate(`(() => {
    const box = (node) => {
      if (!node) return null;
      const r = node.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height) };
    };
    const first = (sels) => {
      for (const selector of sels) {
        try {
          const node = document.querySelector(selector);
          if (node) return { selector, node };
        } catch {}
      }
      return { selector: sels[0], node: null };
    };
    const glass = (sels) => {
      const hit = first(Array.isArray(sels) ? sels : [sels]);
      if (!hit.node) return { selector: hit.selector, found: false };
      const style = getComputedStyle(hit.node);
      return {
        selector: hit.selector,
        found: true,
        tag: hit.node.tagName,
        backgroundColor: style.backgroundColor,
        borderColor: style.borderColor,
        borderRadius: style.borderRadius,
        boxShadow: style.boxShadow,
        backdropFilter: style.backdropFilter || style.webkitBackdropFilter || 'none',
      };
    };
    const home = document.querySelector('.dream-home');
    const suggestions = home?.querySelector('.group\\\\/home-suggestions') ?? null;
    const cards = suggestions ? [...suggestions.querySelectorAll('button')].map(box) : [];
    const composerHit = first([
      '.composer-surface-chrome',
      '[class*="composer-surface"]',
      '[data-codex-composer-root]',
      '[data-codex-composer="true"]',
      '[data-codex-composer]',
    ]);
    const sidebarHit = first([
      'aside.app-shell-left-panel',
      'aside[class*="left-panel"]',
      'aside[class*="sidebar"]',
      'nav[class*="sidebar"]',
      '[data-app-shell-sidebar-trigger]',
    ]);
    const result = {
      installed: document.documentElement.classList.contains('codex-dream-skin'),
      version: window.__CODEX_DREAM_SKIN_STATE__?.version ?? null,
      expectedVersion: ${JSON.stringify(SKIN_VERSION)},
      stylePresent: Boolean(document.getElementById('codex-dream-skin-style')),
      chromePresent: Boolean(document.getElementById('codex-dream-skin-chrome')),
      chromePointerEvents: getComputedStyle(document.getElementById('codex-dream-skin-chrome') || document.body).pointerEvents,
      homePresent: Boolean(home),
      suggestionsPresent: Boolean(suggestions),
      hero: box(home?.firstElementChild?.firstElementChild?.firstElementChild),
      cards,
      composer: box(composerHit.node),
      sidebar: box(sidebarHit.node) || box(document.querySelector('aside')),
      glassSurfaces: {
        composer: glass([
          '.composer-surface-chrome',
          '[class*="composer-surface"]',
          '[data-codex-composer-root]',
          '[data-codex-composer="true"]',
        ]),
        user: glass([
          '[data-user-message-bubble]',
          '[data-message-author-role="user"]',
          '[data-message-author-role*="user"]',
          '[class*="user-message"]',
          '[class*="UserMessage"]',
        ]),
        assistant: glass([
          '[data-local-conversation-final-assistant]',
          '[data-message-author-role="assistant"]',
          '[data-message-author-role*="assistant"]',
          'article:has([data-message-author-role="assistant"])',
          '[class*="assistant-message"]',
          '[class*="AssistantMessage"]',
        ]),
        approval: glass([
          '[data-codex-approval-surface]',
          '[data-approval]',
          '[class*="approval"]',
          '[class*="permission"]',
        ]),
      },
      viewport: { width: innerWidth, height: innerHeight },
      documentOverflow: {
        x: document.documentElement.scrollWidth > document.documentElement.clientWidth,
        y: document.documentElement.scrollHeight > document.documentElement.clientHeight,
      },
    };
    // Session bubbles are optional on home. When conversation nodes exist, require
    // at least one bubble surface to be found so chat glass regressions fail verify.
    const shellOk = Boolean(result.composer) || Boolean(result.sidebar) || Boolean(document.querySelector('main, [role="main"]'));
    const inConversation = Boolean(
      result.glassSurfaces?.user?.found ||
      result.glassSurfaces?.assistant?.found ||
      document.querySelector('[data-message-author-role], [data-user-message-bubble], [data-local-conversation-final-assistant]')
    );
    const conversationOk = !inConversation || Boolean(
      result.glassSurfaces?.user?.found ||
      result.glassSurfaces?.assistant?.found ||
      result.composer
    );
    result.inConversation = inConversation;
    result.conversationOk = conversationOk;
    result.pass = result.installed && result.version === result.expectedVersion &&
      result.stylePresent && result.chromePresent &&
      result.chromePointerEvents === 'none' && shellOk && conversationOk &&
      (!result.homePresent || (Boolean(result.hero) &&
        (!result.suggestionsPresent || (result.cards.length >= 2 && result.cards.length <= 4))));
    return result;
  })()`);
}

async function waitForVerifiedSession(session, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastResult;
  let lastError;
  while (Date.now() < deadline) {
    try {
      lastResult = await verifySession(session);
      lastError = null;
      if (lastResult.pass) return lastResult;
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  if (!lastResult && lastError) throw lastError;
  return lastResult;
}

async function capture(session, outputPath) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await session.send("Input.dispatchKeyEvent", { type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
  await session.send("Input.dispatchKeyEvent", { type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
  const viewport = await session.evaluate("({ width: innerWidth, height: innerHeight })");
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseMoved",
    x: Math.round(viewport.width * 0.64),
    y: Math.round(viewport.height * 0.62),
    button: "none",
  });
  await new Promise((resolve) => setTimeout(resolve, 300));
  const result = await session.send("Page.captureScreenshot", {
    format: "png",
    fromSurface: true,
    captureBeyondViewport: false,
  });
  await fs.writeFile(outputPath, Buffer.from(result.data, "base64"));
}

async function runOneShot(options) {
  const connected = await connectCodexTargets(options.port, options.timeoutMs, options.browserId);
  const loadedPayload = (options.mode === "once" || options.reload)
    ? await loadPayload(options.themeDir) : null;
  const payload = loadedPayload?.payload ?? null;
  const results = [];
  let screenshotCaptured = false;
  try {
    for (const { target, session, probe } of connected) {
      try {
        if (options.mode === "remove") await removeFromSession(session);
        else if (options.mode === "once") await applyToSession(session, payload);
        if (options.mode === "once") {
          // Short settle only — verify loop already polls; 850ms was pure tax.
          await new Promise((resolve) => setTimeout(resolve, 120));
        }
        if (options.reload) {
          await session.send("Page.reload", { ignoreCache: true });
          await new Promise((resolve) => setTimeout(resolve, 1600));
          if (options.mode !== "remove") await applyToSession(session, payload);
        }
        const verified = options.mode === "remove"
          ? await verifyRemovedSession(session)
          : (options.reload || options.mode === "once" || options.mode === "verify")
            ? await waitForVerifiedSession(session, options.timeoutMs)
            : await verifySession(session);
        results.push({ targetId: target.id, markers: probe.markers, result: verified });
        if (options.screenshot && !screenshotCaptured) {
          await capture(session, options.screenshot);
          screenshotCaptured = true;
        }
      } finally {
        session.close();
      }
    }
  } finally {
    for (const { session } of connected) session.close();
  }
  console.log(JSON.stringify({ mode: options.mode, port: options.port, targets: results }, null, 2));
  const failed = results.length === 0 || results.some((item) =>
    options.mode === "remove" ? item.result !== true : !item.result?.pass);
  if (failed) process.exitCode = 2;
}

// === Region: Watch ===
async function runWatch(options) {
  const identityAnchor = await connectBrowserIdentityAnchor(options.port, options.browserId);
  const sessions = new Map();
  const earlyScripts = new Map();
  const fallbackTargets = new Map();
  const fallbackListeners = new Set();
  const targetFailures = new Map();
  let stopping = false;
  let listFailures = 0;
  let lastListErrorLogAt = 0;
  let lastThemeErrorLogAt = 0;
  let lastStrongThemeAuditAt = 0;
  let loadedPayload = null;
  let paused = false;
  // 事件驱动主题刷新：active-theme 变更后尽快审计，而不是干等整轮 sleep
  let themeDirty = true;
  let themeWatchers = [];
  let themeDebounceTimer = null;
  let controlPlane = null;
  const markThemeDirty = (reason = "fs-watch") => {
    themeDirty = true;
    if (themeDebounceTimer) clearTimeout(themeDebounceTimer);
    // 合并短时间多次写（theme.json + 图片）
    themeDebounceTimer = setTimeout(() => {
      themeDirty = true;
    }, 80);
    if (reason) {
      // 低频日志，避免刷屏
    }
  };
  try {
    const fsNative = await import("node:fs");
    const watchTargets = [options.themeDir];
    // 同时看上级 themes catalog（F6 多主题）
    try {
      watchTargets.push(path.dirname(path.resolve(options.themeDir)));
    } catch {}
    for (const target of watchTargets) {
      try {
        const watcher = fsNative.watch(target, { persistent: false }, () => markThemeDirty("watch"));
        watcher.on?.("error", () => {});
        themeWatchers.push(watcher);
      } catch {
        // watch 不可用时仍可走轮询兜底
      }
    }
  } catch {
    // ignore
  }
  const stop = () => {
    stopping = true;
    for (const w of themeWatchers) {
      try { w.close(); } catch {}
    }
    themeWatchers = [];
    if (themeDebounceTimer) clearTimeout(themeDebounceTimer);
    try { controlPlane?.close?.(); } catch {}
  };
  const rejectTarget = (target, baseDelayMs, error = null) => {
    const previous = targetFailures.get(target.id) ?? { failures: 0, lastLogAt: 0 };
    const failures = previous.failures + 1;
    const delayMs = Math.min(30000, baseDelayMs * (2 ** Math.min(failures - 1, 4)));
    const now = Date.now();
    if (error && (failures === 1 || now - previous.lastLogAt >= 30000)) {
      console.error(`[dream-skin] inject failed for ${target.id}: ${error.message}; retrying in ${delayMs}ms`);
      previous.lastLogAt = now;
    }
    targetFailures.set(target.id, { failures, lastLogAt: previous.lastLogAt, until: now + delayMs });
  };
  const attachLoadFallback = (id, target, session) => {
    if (fallbackListeners.has(id)) return;
    fallbackListeners.add(id);
    let lastReinjectErrorLogAt = 0;
    session.on("Page.loadEventFired", () => {
      if (!fallbackTargets.get(id)) return;
      setTimeout(() => {
        const operation = paused ? removeFromSession(session) : applyToSession(session, loadedPayload.payload);
        operation.catch((error) => {
          if (Date.now() - lastReinjectErrorLogAt >= 30000) {
            console.error(`[dream-skin] reinject failed for ${target.id}: ${error.message}`);
            lastReinjectErrorLogAt = Date.now();
          }
        });
      }, 250);
    });
  };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);

  try {
    loadedPayload = await loadPayload(options.themeDir);
    lastStrongThemeAuditAt = Date.now();
    paused = await fileExists(options.pauseFile);

    // === Region: ControlPlane ===
    // Control plane: zero extra long-lived process; serves open/kick/focus.
    try {
      const { startControlPlane, focusViaPowerShell } = await import("./control-plane.mjs");
      // Prefer explicit --state-root; else dirname(themeDir) when themeDir is
      // .../active-theme; never invent LOCALAPPDATA here (runtime self-contained).
      const stateRootForPlane =
        options.stateRoot || path.dirname(path.resolve(options.themeDir));
      controlPlane = await startControlPlane({
        stateRoot: stateRootForPlane,
        getHealth: async () => ({
          healthy: !stopping && !identityAnchor.closed && !paused,
          browserId: options.browserId,
          port: options.port,
          sessionCount: sessions.size,
          payloadStamp: loadedPayload?.fingerprint ?? null,
          paused,
          themeDir: options.themeDir,
          stateRoot: stateRootForPlane,
        }),
        onFocus: () => focusViaPowerShell({ timeoutMs: 500 }),
        onKick: async () => {
          const started = Date.now();
          try {
            if (paused) return { ok: false, reason: "paused", ms: Date.now() - started };
            if (identityAnchor.closed) return { ok: false, reason: "cdp-closed", ms: Date.now() - started };
            // Hot path: reload active-theme and apply to live sessions (no second node).
            const candidateTheme = await loadTheme(options.themeDir);
            let next = loadedPayload;
            const stampChanged = !loadedPayload ||
              (await readThemeSourceStamp(loadedPayload).catch(() => null)) !== candidateTheme.sourceStamp;
            if (stampChanged || !loadedPayload) {
              next = await loadPayload(options.themeDir, candidateTheme);
              loadedPayload = next;
              lastStrongThemeAuditAt = Date.now();
              themeDirty = false;
            }
            let applied = 0;
            const errors = [];
            for (const [id, session] of sessions) {
              try {
                await applyToSession(session, loadedPayload.payload);
                applied += 1;
              } catch (error) {
                errors.push({ id, message: error?.message || String(error) });
              }
            }
            return {
              ok: applied > 0 || sessions.size === 0,
              mode: "watch-kick",
              applied,
              sessions: sessions.size,
              fingerprint: loadedPayload?.fingerprint ?? null,
              ms: Date.now() - started,
              errors: errors.slice(0, 3),
              note: sessions.size === 0 ? "no-sessions-yet" : "applied",
            };
          } catch (error) {
            return {
              ok: false,
              reason: "kick-failed",
              detail: error?.message || String(error),
              ms: Date.now() - started,
            };
          }
        },
      });
    } catch (error) {
      console.error(`[dream-skin] control plane failed to start: ${error?.message || error}`);
    }

    while (!stopping) {
      if (identityAnchor.closed) {
        console.error("[dream-skin] original CDP browser identity closed; watcher is stopping instead of reconnecting");
        process.exitCode = 3;
        break;
      }
      let targets = [];
      try {
        targets = await listAppTargets(options.port);
        listFailures = 0;
      } catch (error) {
        listFailures += 1;
        const retryMs = Math.min(10000, 1000 * (2 ** Math.min(listFailures - 1, 4)));
        if (listFailures === 1 || Date.now() - lastListErrorLogAt >= 30000) {
          console.error(`[dream-skin] ${new Date().toISOString()} ${error.message}; retrying in ${retryMs}ms`);
          lastListErrorLogAt = Date.now();
        }
        await new Promise((resolve) => setTimeout(resolve, retryMs));
        continue;
      }

      const nextPaused = await fileExists(options.pauseFile);
      let nextPayload = loadedPayload;
      if (!nextPaused) {
        try {
          const now = Date.now();
          // 事件脏标记优先；否则最多 30s 强审计一次
          let shouldAudit =
            themeDirty ||
            !loadedPayload ||
            now - lastStrongThemeAuditAt >= STRONG_THEME_AUDIT_MS;
          if (!shouldAudit) {
            try {
              const [activeStamp, catalogStamp] = await Promise.all([
                readThemeSourceStamp(loadedPayload),
                readCatalogSourceStamp(options.themeDir),
              ]);
              shouldAudit = activeStamp !== loadedPayload.sourceStamp
                || catalogStamp !== loadedPayload.catalogSourceStamp;
            } catch {
              shouldAudit = true;
            }
          }
          if (shouldAudit) {
            themeDirty = false;
            const candidateTheme = await loadTheme(options.themeDir);
            const candidatePayload = await loadPayload(options.themeDir, candidateTheme);
            lastStrongThemeAuditAt = now;
            if (!loadedPayload || candidatePayload.fingerprint !== loadedPayload.fingerprint) {
              nextPayload = candidatePayload;
            } else {
              loadedPayload.sourceStamp = candidateTheme.sourceStamp;
              loadedPayload.catalogSourceStamp = candidatePayload.catalogSourceStamp;
            }
          }
        } catch (error) {
          if (Date.now() - lastThemeErrorLogAt >= 30000) {
            console.error(`[dream-skin] theme update rejected: ${error.message}; keeping the active theme`);
            lastThemeErrorLogAt = Date.now();
          }
        }
      }
      const pauseChanged = nextPaused !== paused;
      const payloadChanged = !nextPaused && nextPayload !== loadedPayload;
      loadedPayload = nextPayload;
      paused = nextPaused;

      if (pauseChanged || payloadChanged) {
        for (const [id, session] of sessions) {
          try {
            const previousEarlyScript = earlyScripts.get(id);
            if (paused) {
              await removeFromSession(session);
              await removeEarlyPayload(session, previousEarlyScript);
              earlyScripts.delete(id);
              fallbackTargets.delete(id);
              fallbackListeners.delete(id);
            } else {
              let nextEarlyScript = null;
              try {
                nextEarlyScript = await registerEarlyPayload(
                  session,
                  loadedPayload.payload,
                  loadedPayload.fingerprint,
                );
                if (!nextEarlyScript) throw new Error("CDP did not return an early-script identifier");
                fallbackTargets.set(id, false);
              } catch (error) {
                fallbackTargets.set(id, true);
                console.error(`[dream-skin] early theme refresh unavailable for ${id}: ${error.message}`);
                attachLoadFallback(id, { id }, session);
              }
              if (nextEarlyScript) earlyScripts.set(id, nextEarlyScript);
              else earlyScripts.delete(id);
              await removeEarlyPayload(session, previousEarlyScript);
              await applyToSession(session, loadedPayload.payload);
            }
          } catch (error) {
            console.error(`[dream-skin] live theme update failed for ${id}: ${error.message}`);
            await removeEarlyPayload(session, earlyScripts.get(id));
            earlyScripts.delete(id);
            fallbackTargets.delete(id);
            fallbackListeners.delete(id);
            session.close();
            sessions.delete(id);
          }
        }
        console.log(paused ? "[dream-skin] paused" : `[dream-skin] active theme ${loadedPayload.theme.id}`);
      }

      const activeIds = new Set(targets.map((target) => target.id));
      for (const id of targetFailures.keys()) {
        if (!activeIds.has(id)) targetFailures.delete(id);
      }
      for (const [id, session] of sessions) {
        if (!activeIds.has(id) || session.closed) {
          await removeEarlyPayload(session, earlyScripts.get(id));
          earlyScripts.delete(id);
          fallbackTargets.delete(id);
          fallbackListeners.delete(id);
          session.close();
          sessions.delete(id);
          targetFailures.delete(id);
        }
      }

      for (const target of targets) {
        if (identityAnchor.closed) break;
        if (sessions.has(target.id)) continue;
        if ((targetFailures.get(target.id)?.until ?? 0) > Date.now()) continue;
        let session;
        let earlyScriptId = null;
        try {
          session = await connectTarget(target, options.port);
          if (identityAnchor.closed) throw new CdpIdentityMismatchError("Original CDP browser identity closed");
          let earlyInjectionFallback = false;
          if (!paused) {
            try {
              earlyScriptId = await registerEarlyPayload(
                session,
                loadedPayload.payload,
                loadedPayload.fingerprint,
              );
              if (!earlyScriptId) throw new Error("CDP did not return an early-script identifier");
              await session.evaluate(earlyPayloadFor(loadedPayload.payload, loadedPayload.fingerprint));
            } catch (error) {
              await removeEarlyPayload(session, earlyScriptId);
              earlyScriptId = null;
              earlyInjectionFallback = true;
              console.error(`[dream-skin] early injection unavailable for ${target.id}: ${error.message}`);
            }
          }
          const probe = await waitForCodexProbe(session);
          if (!probe?.codex) {
            await removeEarlyPayload(session, earlyScriptId);
            rejectTarget(target, 5000);
            session.close();
            continue;
          }
          fallbackTargets.set(target.id, earlyInjectionFallback);
          if (earlyInjectionFallback) attachLoadFallback(target.id, target, session);
          if (identityAnchor.closed) throw new CdpIdentityMismatchError("Original CDP browser identity closed");
          let earlyApplied = false;
          if (!paused && !earlyInjectionFallback) {
            earlyApplied = await session.evaluate(
              `window.__CODEX_DREAM_SKIN_EARLY_APPLIED__ === ${JSON.stringify(loadedPayload.fingerprint)}`,
            ).catch(() => false);
          }
          if (paused) await removeFromSession(session);
          else if (!earlyApplied) await applyToSession(session, loadedPayload.payload);
          sessions.set(target.id, session);
          if (earlyScriptId) earlyScripts.set(target.id, earlyScriptId);
          targetFailures.delete(target.id);
          console.log(`[dream-skin] injected target ${target.id}`);
        } catch (error) {
          await removeEarlyPayload(session, earlyScriptId);
          fallbackTargets.delete(target.id);
          fallbackListeners.delete(target.id);
          session?.close();
          if (identityAnchor.closed || error instanceof CdpIdentityMismatchError) break;
          rejectTarget(target, 2500, error);
        }
      }
      await new Promise((resolve) => setTimeout(resolve, 400));
    }
  } finally {
    identityAnchor.close();
    for (const [id, session] of sessions) {
      await removeEarlyPayload(session, earlyScripts.get(id));
      session.close();
    }
    earlyScripts.clear();
    fallbackTargets.clear();
    fallbackListeners.clear();
  }
}

// === Region: Main ===
if (path.resolve(process.argv[1] || "") === path.resolve(scriptPath)) {
  const options = parseArgs(process.argv.slice(2));
  if (options.mode === "self-test") {
  const valid = validatedDebuggerUrl({ webSocketDebuggerUrl: `ws://127.0.0.1:${options.port}/devtools/page/test` }, options.port);
  const browserId = browserIdFromVersion({
    webSocketDebuggerUrl: `ws://127.0.0.1:${options.port}/devtools/browser/test-browser`,
  }, options.port);
  const invalid = [
    "ws://example.com/devtools/page/test",
    `ws://127.0.0.1:${options.port + 1}/devtools/page/test`,
    `wss://127.0.0.1:${options.port}/devtools/page/test`,
    `ws://user@127.0.0.1:${options.port}/devtools/page/test`,
    `ws://127.0.0.1:${options.port}/unexpected/test`,
    `ws://127.0.0.1:${options.port}/devtools/page/test?query=1`,
  ];
  for (const value of invalid) {
    let rejected = false;
    try { validatedDebuggerUrl({ webSocketDebuggerUrl: value }, options.port); } catch { rejected = true; }
    if (!rejected) throw new Error(`CDP URL validation accepted an unsafe URL: ${value}`);
  }
  const invalidBrowserUrls = [
    `ws://127.0.0.1:${options.port}/devtools/page/not-a-browser`,
    `ws://127.0.0.1:${options.port}/devtools/browser/bad%20id`,
    `ws://127.0.0.1:${options.port}/devtools/browser/test?query=1`,
  ];
  for (const value of invalidBrowserUrls) {
    let rejected = false;
    try { browserIdFromVersion({ webSocketDebuggerUrl: value }, options.port); } catch { rejected = true; }
    if (!rejected) throw new Error(`Browser identity validation accepted an unsafe URL: ${value}`);
  }
  const validPageTarget = {
    id: "page-test",
    type: "page",
    url: "app://codex/",
    webSocketDebuggerUrl: `ws://127.0.0.1:${options.port}/devtools/page/page-test`,
  };
  const invalidPageTargets = [
    { ...validPageTarget, webSocketDebuggerUrl: `ws://127.0.0.1:${options.port}/devtools/browser/page-test` },
    { ...validPageTarget, id: "other-page" },
    { ...validPageTarget, id: 123 },
    { ...validPageTarget, type: "other" },
  ];
  if (!valid || browserId !== "test-browser" || !isValidCdpPageTarget(validPageTarget, options.port) ||
      invalidPageTargets.some((item) => isValidCdpPageTarget(item, options.port))) {
    throw new Error("CDP URL and target validation self-test failed");
  }
  console.log(JSON.stringify({ pass: true, version: SKIN_VERSION, test: "loopback-cdp-validation" }));
  } else if (options.mode === "check-payload") {
    const loaded = await loadPayload(options.themeDir);
    const unresolved = ["__DREAM_CSS_JSON__", "__DREAM_ART_JSON__", "__DREAM_THEME_JSON__", "__DREAM_THEME_CATALOG_JSON__"]
      .some((placeholder) => loaded.payload.includes(placeholder));
    if (unresolved) {
      throw new Error("Payload placeholders were not fully replaced");
    }
    const payloadBytes = Buffer.byteLength(loaded.payload);
    console.log(JSON.stringify({
      pass: true,
      version: SKIN_VERSION,
      imageBytes: loaded.imageBytes,
      catalogImageBytes: loaded.catalogImageBytes,
      themeCount: loaded.themeCount,
      catalogSkippedLarge: loaded.catalogSkippedLarge ?? 0,
      catalogSkippedBudget: loaded.catalogSkippedBudget ?? 0,
      catalogThumbCount: loaded.catalogThumbCount ?? 0,
      payloadBytes,
      payloadBudgetBytes: DEFAULT_PAYLOAD_BUDGET_BYTES,
      withinPayloadBudget: payloadBytes <= DEFAULT_PAYLOAD_BUDGET_BYTES,
      themeId: loaded.theme.id,
      appearance: loaded.theme.appearance,
      art: loaded.theme.art,
      artMetadata: loaded.theme.artMetadata ?? null,
    }));
  } else if (options.mode === "watch") await runWatch(options);
  else await runOneShot(options);
}
