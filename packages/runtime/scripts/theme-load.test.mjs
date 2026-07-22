/**
 * theme-load offline regression (injector-split S2).
 * Run: node packages/runtime/scripts/theme-load.test.mjs
 */
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  THEME_CHOICES,
  normalizedUnit,
  normalizedChoice,
  normalizedText,
  loadTheme,
  loadCatalogMember,
  readThemeSourceStamp,
  imageDataUrl,
} from "./theme-load.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

function assertEqual(actual, expected, msg) {
  assert(actual === expected, `${msg} (got ${JSON.stringify(actual)}, want ${JSON.stringify(expected)})`);
}

async function assertThrows(fn, needle, msg) {
  let err;
  try {
    await fn();
  } catch (e) {
    err = e;
  }
  assert(Boolean(err), msg + " (expected throw)");
  if (err && needle) {
    assert(String(err.message).includes(needle), `${msg} (message contains ${JSON.stringify(needle)}: ${err.message})`);
  }
}

// --- pure helpers ---
assert(THEME_CHOICES.appearance.has("auto"), "THEME_CHOICES.appearance has auto");
assertEqual(normalizedUnit(null, "x"), null, "normalizedUnit null → null");
assertEqual(normalizedUnit(0.5, "x"), 0.5, "normalizedUnit 0.5");
await assertThrows(() => Promise.resolve(normalizedUnit(2, "art.focusX")), "art.focusX", "normalizedUnit >1 throws");
assertEqual(normalizedChoice("", "a", THEME_CHOICES.appearance, "auto"), "auto", "normalizedChoice empty → fallback");
assertEqual(normalizedText(null, "n", "fb"), "fb", "normalizedText null → fallback");

// --- loadTheme against repo theme if present ---
const candidateThemes = [
  path.join(repoRoot, "themes", "default"),
  path.join(repoRoot, "packages", "runtime", "assets"),
];
let sampleDir = null;
for (const d of candidateThemes) {
  try {
    await fs.access(path.join(d, "theme.json"));
    sampleDir = d;
    break;
  } catch {
    // try next
  }
}

if (sampleDir) {
  const loaded = await loadTheme(sampleDir);
  assert(loaded.theme && typeof loaded.theme === "object", "loadTheme returns theme object");
  assert(typeof loaded.fingerprint === "string" && loaded.fingerprint.length === 64, "fingerprint sha256 hex");
  assert(typeof loaded.sourceStamp === "string" && loaded.sourceStamp.includes(":"), "sourceStamp shape size:mtime:…");
  assert(Buffer.isBuffer(loaded.imageBytes) && loaded.imageBytes.length > 0, "imageBytes non-empty buffer");
  const stamp2 = await readThemeSourceStamp(loaded);
  assertEqual(stamp2, loaded.sourceStamp, "readThemeSourceStamp matches loadTheme sourceStamp");
  const dataUrl = imageDataUrl(loaded);
  assert(dataUrl.startsWith("data:image/"), "imageDataUrl prefix");

  // palette: missing keys must not be default-filled
  for (const key of ["accent", "secondary", "surface", "text"]) {
    if (!(key in loaded.theme.palette)) {
      assert(loaded.theme.palette[key] === undefined, `missing palette.${key} stays undefined (no default)`);
    }
  }
} else {
  console.log("skip: no sample theme.json under themes/default or runtime/assets");
}

// --- fixture: illegal palette color throws with palette. ---
const tmp = await fs.mkdtemp(path.join(os.tmpdir(), "theme-load-"));
try {
  // minimal 1x1 PNG
  const png = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
    "base64",
  );
  await fs.writeFile(path.join(tmp, "art.png"), png);
  await fs.writeFile(
    path.join(tmp, "theme.json"),
    JSON.stringify({
      id: "fixture-bad-color",
      name: "Bad Color",
      image: "art.png",
      palette: { accent: "not-a-color" },
    }),
  );
  await assertThrows(() => loadTheme(tmp), "palette.", "illegal palette color throws palette.*");

  // absolute image path rejected
  await fs.writeFile(
    path.join(tmp, "theme.json"),
    JSON.stringify({
      id: "fixture-abs",
      name: "Abs",
      image: path.resolve(tmp, "art.png"),
    }),
  );
  await assertThrows(() => loadTheme(tmp), "relative path", "absolute image rejected");

  // escape via ..
  await fs.writeFile(
    path.join(tmp, "theme.json"),
    JSON.stringify({
      id: "fixture-escape",
      name: "Esc",
      image: "../art.png",
    }),
  );
  await assertThrows(() => loadTheme(tmp), "inside the selected theme directory", "image .. escape rejected");

  // legal 4-color palette
  await fs.writeFile(
    path.join(tmp, "theme.json"),
    JSON.stringify({
      id: "fixture-ok",
      name: "Ok",
      image: "art.png",
      palette: {
        accent: "#abc",
        secondary: "#112233",
        surface: "rgb(1,2,3)",
        text: "#ffffffff",
      },
    }),
  );
  const ok = await loadTheme(tmp);
  assertEqual(ok.theme.palette.accent, "#abc", "palette.accent written");
  assertEqual(ok.theme.palette.secondary, "#112233", "palette.secondary written");
  assertEqual(ok.theme.palette.surface, "rgb(1,2,3)", "palette.surface written");
  assertEqual(ok.theme.palette.text, "#ffffffff", "palette.text written");

  // catalog member: no thumb, art under MAX_CATALOG_MEMBER_BYTES → full
  const member = await loadCatalogMember(tmp);
  assert(member && member.isThumb === false, "loadCatalogMember without thumb keeps full small art");
} finally {
  await fs.rm(tmp, { recursive: true, force: true });
}

if (failed > 0) {
  console.error(`\n${failed} failure(s)`);
  process.exit(1);
}
console.log("\ntheme-load tests passed");
