/**
 * Dev/CI-plane cross-check: themes normalizeColors output ⊂ contracts palette (ADR 0004 U1).
 *
 * WHY dev-plane only: theme-schema.mjs loads on the user's machine (dream-adapter /
 * index.mjs → apply/kick). It MUST stay free of third-party npm (ADR 0004 D1/D6),
 * so themes never imports @codex-skin/contracts (which pulls zod). Instead this test
 * feeds the runtime output of validateThemeManifest into the contract parser and asserts
 * the two definitions have not drifted — catching a v5-style "假关闭" silently.
 *
 * Requires contracts to be built first (dist/). package.json wires that via
 * test:themes-contracts → build:contracts && this file. Standalone:
 *   pnpm run build:contracts && node packages/themes/theme-contracts-align.test.mjs
 */
import { access, readdir, readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { validateThemeManifest } from "./theme-schema.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
const contractsDist = join(repoRoot, "packages", "contracts", "dist", "index.js");
const injectorPath = join(repoRoot, "packages", "runtime", "scripts", "injector.mjs");
const COLOR_KEYS = ["accent", "secondary", "surface", "text"];

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

// Guard: dist must exist. A missing build is a setup error, not a silent pass.
try {
  await access(contractsDist);
} catch {
  console.error(
    `FAIL: contracts dist missing at ${contractsDist}\n` +
      "      run `pnpm run build:contracts` first (test:themes-contracts does this).",
  );
  process.exit(1);
}

const { parsePaletteWithSurface, CSS_COLOR_RE } = await import(
  pathToFileURL(contractsDist).href
);

// --- S1: contracts CSS_COLOR_RE tracks the real injector source of truth ------
// contracts/src/css-color.ts documents "aligned with injector.mjs"; pin to the
// live file instead of a third re-literal (a stale copy would keep greening).
{
  const injectorSrc = await readFile(injectorPath, "utf8");
  // injector.mjs currently embeds the same literal in two local scopes
  // (loadTheme + thumb path). Capture every site and require them equal.
  const reLiteral =
    /const cssColor = (\/\^\(\?:#\[\\da-f\]\{3,8\}\|\(\?:rgb\|hsl\|oklch\|oklab\)\\\(\[\^;\{\}]\{1,96\}\\\)\)\$\/i)/g;
  const sites = [...injectorSrc.matchAll(reLiteral)].map((m) => m[1]);
  assert(sites.length >= 1, `injector.mjs exposes ≥1 cssColor regex (found ${sites.length})`);
  assert(
    sites.every((s) => s === sites[0]),
    "injector.mjs cssColor regex sites are identical to each other",
  );

  // Rebuild the RegExp from the captured source+flags so source/flags match contracts.
  const m = sites[0].match(/^\/(.+)\/([a-z]*)$/);
  assert(Boolean(m), "captured injector regex is a /pattern/flags literal");
  const injectorRe = new RegExp(m[1], m[2]);
  assert(
    CSS_COLOR_RE.source === injectorRe.source && CSS_COLOR_RE.flags === injectorRe.flags,
    "contracts CSS_COLOR_RE matches injector.mjs cssColor (live source)",
  );
}

// --- normalizeColors output ⊂ paletteWithSurface for every bundled theme -----
// Only the cross-package acceptance path lives here. Catalog size, schema
// shape, and contract reject-paths are owned by test:themes / test:contracts.
{
  const bundledRoot = join(repoRoot, "themes");
  const entries = await readdir(bundledRoot, { withFileTypes: true });
  const dirs = entries.filter((e) => e.isDirectory()).map((e) => e.name).sort();

  await Promise.all(
    dirs.map(async (id) => {
      try {
        const raw = JSON.parse(await readFile(join(bundledRoot, id, "theme.json"), "utf8"));
        const colors = validateThemeManifest(raw).colors;
        const parsed = parsePaletteWithSurface(colors);
        for (const key of COLOR_KEYS) {
          assert(
            parsed[key] === colors[key],
            `${id}: ${key} survives parsePaletteWithSurface (${colors[key]} → ${parsed[key]})`,
          );
        }
      } catch (error) {
        assert(false, `${id}: themes⊂contracts — ${error?.message ?? error}`);
      }
    }),
  );
}

if (failed > 0) {
  console.error(`\ntheme-contracts-align.test: ${failed} failed`);
  process.exit(1);
}
console.log("\ntheme-contracts-align.test: all passed");
