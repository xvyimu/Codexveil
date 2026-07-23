/**
 * dream-adapter pure + disk write gate (no CDP / network).
 * Run: node packages/themes/dream-adapter.test.mjs  |  npm run test:adapter
 */
import { mkdtemp, mkdir, writeFile, readFile, copyFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  heigeManifestToDreamSkin,
  writeActiveThemeFromHeige,
} from "./dream-adapter.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
// Bundled art for writeActiveThemeFromHeige (arina-only catalog).
const sampleHero = join(repoRoot, "themes", "preset-arina-hashimoto", "hero.jpg");

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

// --- heigeManifestToDreamSkin pure mapping ---
{
  const m = heigeManifestToDreamSkin({
    id: "adapter-demo",
    name: "Adapter Demo",
    hero: "hero.webp",
    colors: {
      accent: "#E0B458",
      secondary: "#7A86D8",
      surface: "#171A2E",
      text: "#F0E6C8",
    },
    copy: { brand: "CODEX SKIN", tagline: "night", headline: "MAKE" },
    art: { focusX: 0.5, focusY: 0.4, safeArea: "left", taskMode: "ambient" },
  });
  assert(m.id === "adapter-demo", "heigeManifestToDreamSkin id");
  assert(m.image === "hero.webp", "heigeManifestToDreamSkin image from hero");
  assert(m.palette?.accent === "#E0B458", "heigeManifestToDreamSkin palette.accent");
  assert(m.brandSubtitle === "CODEX SKIN", "heigeManifestToDreamSkin brandSubtitle");
}

// --- writeActiveThemeFromHeige → tmp stateRoot ---
{
  const themeDir = await mkdtemp(join(tmpdir(), "codex-skin-adapter-theme-"));
  const stateRoot = await mkdtemp(join(tmpdir(), "codex-skin-adapter-state-"));
  try {
    await writeFile(
      join(themeDir, "theme.json"),
      JSON.stringify(
        {
          schemaVersion: 1,
          id: "adapter-write",
          name: "Adapter Write",
          hero: "hero.jpg",
          colors: {
            accent: "#E0B458",
            secondary: "#7A86D8",
            surface: "#171A2E",
            text: "#F0E6C8",
          },
          copy: { brand: "CODEX SKIN", tagline: "x", headline: "y" },
          art: { focusX: 0.72, focusY: 0.45, safeArea: "left", taskMode: "ambient" },
        },
        null,
        2,
      ),
      "utf8",
    );
    await copyFile(sampleHero, join(themeDir, "hero.jpg"));

    const written = await writeActiveThemeFromHeige({
      heigeThemeDir: themeDir,
      stateRoot,
    });
    assert(written.id === "adapter-write", "writeActiveThemeFromHeige returns id");
    assert(typeof written.imageName === "string" && written.imageName.startsWith("art-"), "imageName art-*");

    const activeJson = join(stateRoot, "active-theme", "theme.json");
    const raw = JSON.parse(await readFile(activeJson, "utf8"));
    assert(raw.id === "adapter-write", "active-theme/theme.json has id");
    assert(typeof raw.image === "string" && raw.image.length > 0, "active-theme/theme.json has image");
    assert(raw.image === written.imageName, "active image matches written.imageName");
  } finally {
    await rm(themeDir, { recursive: true, force: true });
    await rm(stateRoot, { recursive: true, force: true });
  }
}

if (failed > 0) {
  console.error(`\ndream-adapter.test: ${failed} failed`);
  process.exit(1);
}
console.log("\ndream-adapter.test: all passed");
