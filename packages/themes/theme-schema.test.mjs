/**
 * Minimal dual-format theme schema gate (no test framework).
 * Run: node packages/themes/theme-schema.test.mjs  |  npm run test:themes
 */
import { mkdtemp, writeFile, rm, mkdir, copyFile, access } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import {
  loadTheme,
  validateThemeManifest,
  contrastRatio,
  assertReadableTextSurface,
} from "./theme-schema.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
// Product catalog is arina-only (see docs/PRODUCT-LAYERS.md / atelier-v3-matrix).
const heigeThemeDir = join(repoRoot, "themes", "preset-arina-hashimoto");
const dreamThemeJson = join(repoRoot, "packages", "runtime", "assets", "theme.json");
const dreamHero = join(repoRoot, "packages", "runtime", "assets", "dream-reference.jpg");

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

// --- validateThemeManifest: heige shape ---
{
  const m = validateThemeManifest({
    schemaVersion: 1,
    id: "genshin-night",
    name: "原神 · 星夜",
    hero: "hero.webp",
    colors: {
      accent: "#e0b458",
      secondary: "#7a86d8",
      surface: "#171a2e",
      text: "#f0e6c8",
    },
    copy: { brand: "CODEX SKIN", tagline: "x", headline: "y" },
    art: { focusX: 0.72, focusY: 0.45, safeArea: "left", taskMode: "ambient" },
  });
  assert(m.hero === "hero.webp", "heige hero preserved");
  assert(m.colors.accent === "#E0B458", "heige colors normalized upper hex");
  assert(m.copy?.tagline === "x", "heige copy.tagline");
}

// --- validateThemeManifest: DreamSkin catalog shape ---
{
  const m = validateThemeManifest({
    schemaVersion: 1,
    id: "preset-arina-hashimoto",
    name: "桥本有菜",
    image: "dream-reference.jpg",
    palette: {
      accent: "#E8A0BF",
      secondary: "#C9A0DC",
      surface: "#1A1218",
      text: "#FFF0F5",
    },
    brandSubtitle: "CODEX DREAM SKIN",
    tagline: "柔光",
    quote: "MAKE SOMETHING WONDERFUL",
    art: { focusX: 0.72, focusY: 0.45, safeArea: "left", taskMode: "ambient" },
  });
  assert(m.hero === "dream-reference.jpg", "DreamSkin image → hero");
  assert(m.colors.accent === "#E8A0BF", "DreamSkin palette → colors");
  assert(m.copy?.brand === "CODEX DREAM SKIN", "brandSubtitle → copy.brand");
  assert(m.copy?.tagline === "柔光", "tagline → copy.tagline");
}

// --- reject path escape ---
{
  let threw = false;
  try {
    validateThemeManifest({
      schemaVersion: 1,
      id: "bad-theme",
      name: "bad",
      hero: "../escape.webp",
    });
  } catch {
    threw = true;
  }
  assert(threw, "rejects hero path with ..");
}

// --- TD-04: reject dangerous top-level keys (case-insensitive) ---
{
  let threw = false;
  let message = "";
  try {
    validateThemeManifest({
      schemaVersion: 1,
      id: "evil-theme",
      name: "evil",
      hero: "hero.webp",
      scripts: { postinstall: "rm -rf /" },
    });
  } catch (error) {
    threw = true;
    message = error?.message ?? String(error);
  }
  assert(threw, "rejects top-level scripts");
  assert(message.includes("scripts"), "dangerous-key error names field scripts");
}
{
  let threw = false;
  let message = "";
  try {
    validateThemeManifest({
      schemaVersion: 1,
      id: "evil-hooks",
      name: "evil",
      hero: "hero.webp",
      HOOKS: [],
    });
  } catch (error) {
    threw = true;
    message = error?.message ?? String(error);
  }
  assert(threw, "rejects top-level HOOKS (case-insensitive)");
  assert(message.includes("HOOKS"), "dangerous-key error preserves original key case");
}
// Nested scripts under copy must still pass (top-level only).
{
  const m = validateThemeManifest({
    schemaVersion: 1,
    id: "nested-ok",
    name: "nested ok",
    hero: "hero.webp",
    copy: { brand: "X", tagline: "y", headline: "z" },
    thumb: "thumb.webp",
  });
  assert(m.id === "nested-ok", "legal fields (thumb/copy) still accepted");
}

// --- B · text/surface contrast gate (readability) ---
{
  const blackWhite = contrastRatio("#FFFFFF", "#000000");
  assert(blackWhite > 20, "contrastRatio white/black is high");
  const ok = assertReadableTextSurface({
    text: "#F0E6C8",
    surface: "#171A2E",
    accent: "#E0B458",
    secondary: "#7A86D8",
  });
  assert(ok >= 4.5, "assertReadableTextSurface accepts genshin-like pair");
  let threw = false;
  let message = "";
  try {
    validateThemeManifest({
      schemaVersion: 1,
      id: "low-contrast",
      name: "low contrast",
      hero: "hero.webp",
      colors: {
        accent: "#888888",
        secondary: "#777777",
        surface: "#808080",
        text: "#818181",
      },
    });
  } catch (error) {
    threw = true;
    message = error?.message ?? String(error);
  }
  assert(threw, "rejects low text/surface contrast");
  assert(
    /contrast/i.test(message),
    "low-contrast error mentions contrast",
  );
}

// --- loadTheme on bundled theme (arina-only catalog) ---
{
  await access(join(heigeThemeDir, "theme.json"));
  const loaded = await loadTheme(heigeThemeDir);
  assert(loaded.manifest.id === "preset-arina-hashimoto", "loadTheme preset-arina-hashimoto id");
  assert(loaded.manifest.colors.accent === "#E8A0BF", "loadTheme palette non-empty");
  assert(!!loaded.heroPath, "loadTheme heroPath resolved");
}

// --- loadTheme on DreamSkin-format temp dir (runtime assets shape) ---
{
  const dir = await mkdtemp(join(tmpdir(), "codex-skin-theme-"));
  try {
    const raw = await (await import("node:fs/promises")).readFile(dreamThemeJson, "utf8");
    const parsed = JSON.parse(raw);
    await writeFile(join(dir, "theme.json"), JSON.stringify(parsed, null, 2), "utf8");
    await copyFile(dreamHero, join(dir, parsed.image || "dream-reference.jpg"));
    const loaded = await loadTheme(dir);
    assert(loaded.manifest.id === "preset-arina-hashimoto", "loadTheme dream catalog id");
    assert(loaded.manifest.colors.accent === "#E8A0BF", "loadTheme dream palette");
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

// --- loadTheme every bundled themes/* directory (TEST-02) ---
{
  const { readdir } = await import("node:fs/promises");
  const bundledRoot = join(repoRoot, "themes");
  const entries = await readdir(bundledRoot, { withFileTypes: true });
  const dirs = entries.filter((e) => e.isDirectory()).map((e) => e.name).sort();
  assert(dirs.length >= 1, `bundled theme count >= 1 (arina-only; got ${dirs.length})`);
  let loadedCount = 0;
  for (const id of dirs) {
    const dir = join(bundledRoot, id);
    try {
      await access(join(dir, "theme.json"));
    } catch {
      assert(false, `loadTheme ${id}: theme.json missing`);
      continue;
    }
    const loaded = await loadTheme(dir);
    assert(loaded.manifest.id === id, `loadTheme ${id}: manifest.id matches dir`);
    assert(!!loaded.manifest.colors?.accent, `loadTheme ${id}: accent present`);
    assert(!!loaded.heroPath, `loadTheme ${id}: heroPath resolved`);
    loadedCount += 1;
  }
  assert(loadedCount === dirs.length, `loadTheme all bundled themes (${loadedCount}/${dirs.length})`);
}

if (failed > 0) {
  console.error(`\ntheme-schema.test: ${failed} failed`);
  process.exit(1);
}
console.log("\ntheme-schema.test: all passed");
