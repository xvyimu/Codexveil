/** Theme load / catalog (injector extract). Same semantics as former injector Region: ThemeLoad. */
import fs from "node:fs/promises";
import { createHash } from "node:crypto";
import path from "node:path";
import { readImageMetadata } from "./image-metadata.mjs";
import {
  MAX_THEME_CATALOG_ENTRIES,
  MAX_CATALOG_MEMBER_BYTES,
  evaluateCatalogMemberBudget,
} from "./theme-catalog-budget.mjs";

export const MAX_ART_BYTES = 16 * 1024 * 1024;

export const THEME_CHOICES = {
  appearance: new Set(["auto", "light", "dark"]),
  safeArea: new Set(["auto", "left", "right", "center", "none"]),
  taskMode: new Set(["auto", "ambient", "banner", "off"]),
};

export function normalizedUnit(value, name) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0 || number > 1) {
    throw new Error(`${name} must be null or a number between 0 and 1`);
  }
  return number;
}

export function normalizedChoice(value, name, choices, fallback) {
  if (value === null || value === undefined || value === "") return fallback;
  if (!choices.has(value)) throw new Error(`${name} has an unsupported value: ${value}`);
  return value;
}

export function normalizedText(value, name, fallback, maxLength = 120) {
  if (value === null || value === undefined || value === "") return fallback;
  if (typeof value !== "string" || value.length > maxLength || /[\u0000-\u001f]/.test(value)) {
    throw new Error(`${name} must be a short single-line string`);
  }
  return value;
}

export async function loadTheme(themeDir) {
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

/** Shared by catalog entries and loadPayload (payload-builder will import later). */
export function imageDataUrl(loadedTheme) {
  const extension = path.extname(loadedTheme.imagePath).toLowerCase();
  const mime = extension === ".jpg" || extension === ".jpeg" ? "image/jpeg"
    : extension === ".webp" ? "image/webp" : "image/png";
  return "data:" + mime + ";base64," + loadedTheme.imageBytes.toString("base64");
}

export function themesRootFor(themeDir) {
  return path.join(path.dirname(path.resolve(themeDir)), "themes");
}

export async function readCatalogSourceStamp(themeDir) {
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

export async function loadCatalogMember(themeDir) {
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

export async function loadThemeCatalog(themeDir, activeTheme) {
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

export async function readThemeSourceStamp(loadedTheme) {
  const [themeStat, imageStat] = await Promise.all([
    fs.stat(loadedTheme.themePath),
    fs.stat(loadedTheme.imagePath),
  ]);
  return `${themeStat.size}:${themeStat.mtimeMs}:${imageStat.size}:${imageStat.mtimeMs}`;
}
