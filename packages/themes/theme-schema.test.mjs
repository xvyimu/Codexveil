/**
 * Minimal dual-format theme schema gate (no test framework).
 * Run: node packages/themes/theme-schema.test.mjs  |  npm run test:themes
 */
import { mkdtemp, writeFile, rm, mkdir, copyFile, access } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { loadTheme, validateThemeManifest } from "./theme-schema.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
const heigeThemeDir = join(repoRoot, "themes", "genshin-night");
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

// --- loadTheme on bundled heige theme ---
{
  await access(join(heigeThemeDir, "theme.json"));
  const loaded = await loadTheme(heigeThemeDir);
  assert(loaded.manifest.id === "genshin-night", "loadTheme genshin-night id");
  assert(loaded.manifest.colors.accent === "#E0B458", "loadTheme palette non-empty");
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

if (failed > 0) {
  console.error(`\ntheme-schema.test: ${failed} failed`);
  process.exit(1);
}
console.log("\ntheme-schema.test: all passed");
