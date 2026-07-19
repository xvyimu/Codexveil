/**
 * @file dream-adapter.mjs
 * @description heige 主题包 ↔ DreamSkin active-theme / catalog 适配层
 *
 * 热更新链路：
 *   writeActiveThemeFromHeige(themeDir)
 *     → 写 %LOCALAPPDATA%\CodexDreamSkin\active-theme\{theme.json, art-*}
 *     → watch injector 指纹变化 → Runtime.evaluate 注入
 *
 * 不要在这里直接 CDP 注入；日常禁止第二套 injector。
 */
import {
  copyFile,
  mkdir,
  readdir,
  rename,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import { basename, extname, join } from "node:path";
import { resolveStudioPaths } from "../core/constants.mjs";
import { loadTheme } from "./theme-schema.mjs";

const IMAGE_EXT = new Set([".png", ".jpg", ".jpeg", ".webp"]);

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * heige theme.json (hero/colors) → DreamSkin theme.json (image/palette/art)
 * @param {Record<string, unknown>} manifest
 * @param {{ imageFileName?: string }} [opts]
 */
export function heigeManifestToDreamSkin(manifest, { imageFileName } = {}) {
  if (!isRecord(manifest)) throw new Error("manifest must be an object");
  const image = imageFileName ?? manifest.hero ?? manifest.image;
  if (typeof image !== "string" || !image.trim()) {
    throw new Error("theme needs hero/image file name");
  }
  const colors = isRecord(manifest.colors) ? manifest.colors : {};
  const copy = isRecord(manifest.copy) ? manifest.copy : {};
  const art = isRecord(manifest.art) ? manifest.art : {};
  const palette = {};
  if (typeof colors.accent === "string" && colors.accent.trim()) {
    palette.accent = colors.accent.trim();
  }
  for (const key of ["secondary", "surface", "text"]) {
    if (typeof colors[key] === "string" && colors[key].trim()) {
      palette[key] = colors[key].trim();
    }
  }

  return {
    schemaVersion: 1,
    id: String(manifest.id ?? "custom"),
    name: String(manifest.name ?? manifest.id ?? "Codex Skin"),
    brandSubtitle: copy.brand ?? "CODEX SKIN",
    tagline: copy.tagline ?? copy.headline ?? "",
    projectPrefix: "选择项目 · ",
    projectLabel: "◉  选择项目",
    statusText: "SKIN ONLINE",
    quote: copy.headline ?? "MAKE SOMETHING WONDERFUL",
    appearance: manifest.appearance ?? "auto",
    art: {
      focusX: art.focusX ?? 0.72,
      focusY: art.focusY ?? 0.45,
      safeArea: art.safeArea ?? "left",
      taskMode: art.taskMode ?? "ambient",
    },
    image,
    palette,
    source: {
      engine: "heige",
      hero: manifest.hero ?? null,
      colors,
    },
  };
}

/** 同卷原子写 JSON（utf-8 无 BOM） */
async function atomicWriteJson(filePath, data) {
  const temp = `${filePath}.tmp-${process.pid}`;
  await writeFile(temp, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  await rm(filePath, { force: true });
  await rename(temp, filePath);
}

/**
 * 把 heige 主题目录写入 DreamSkin active-theme，触发 watch 热更新。
 * @param {{ heigeThemeDir: string, stateRoot?: string }} opts
 */
export async function writeActiveThemeFromHeige({
  heigeThemeDir,
  stateRoot = resolveStudioPaths().dreamStateRoot,
} = {}) {
  const loaded = await loadTheme(heigeThemeDir);
  const activeRoot = join(stateRoot, "active-theme");
  await mkdir(activeRoot, { recursive: true });

  const heroPath = loaded.heroPath;
  const ext = extname(heroPath).toLowerCase();
  if (!IMAGE_EXT.has(ext)) throw new Error(`unsupported image type ${ext}`);

  const imageName = `art-${Date.now().toString(36)}${ext}`;
  const destImage = join(activeRoot, imageName);
  await copyFile(heroPath, destImage);

  const dreamManifest = heigeManifestToDreamSkin(loaded.manifest, {
    imageFileName: imageName,
  });
  await atomicWriteJson(join(activeRoot, "theme.json"), dreamManifest);

  try {
    const entries = await readdir(activeRoot);
    for (const name of entries) {
      if (name === "theme.json" || name === imageName) continue;
      if (!name.startsWith("art-") && name !== "dream-reference.jpg") continue;
      await rm(join(activeRoot, name), { force: true });
    }
  } catch {
    // 清理失败不阻断换肤
  }

  return {
    id: dreamManifest.id,
    name: dreamManifest.name,
    activeRoot,
    imageName,
    themePath: join(activeRoot, "theme.json"),
  };
}

/**
 * 导入单个 heige 主题到 catalog：themes\<id>\
 * @param {{ heigeThemeDir: string, stateRoot?: string }} opts
 */
export async function importHeigeThemeToCatalog({
  heigeThemeDir,
  stateRoot = resolveStudioPaths().dreamStateRoot,
} = {}) {
  const loaded = await loadTheme(heigeThemeDir);
  const id = loaded.manifest.id;
  const savedRoot = join(stateRoot, "themes");
  const dest = join(savedRoot, id);
  await mkdir(savedRoot, { recursive: true });
  await rm(dest, { recursive: true, force: true });
  await mkdir(dest, { recursive: true });

  const ext = extname(loaded.heroPath).toLowerCase();
  const imageName = `hero${ext}`;
  await copyFile(loaded.heroPath, join(dest, imageName));
  if (loaded.logoPath) {
    await copyFile(loaded.logoPath, join(dest, basename(loaded.logoPath)));
  }
  if (loaded.polaroidPath) {
    await copyFile(loaded.polaroidPath, join(dest, basename(loaded.polaroidPath)));
  }

  const dreamManifest = heigeManifestToDreamSkin(loaded.manifest, {
    imageFileName: imageName,
  });
  await atomicWriteJson(join(dest, "theme.json"), dreamManifest);
  // Best-effort catalog thumb for F6 payload slim path
  try {
    const { ensureThemeThumb } = await import("../runtime/scripts/thumb.mjs");
    await ensureThemeThumb(dest, imageName);
    dreamManifest.thumb = "thumb.jpg";
    await atomicWriteJson(join(dest, "theme.json"), dreamManifest);
  } catch {
    // thumb optional
  }
  return { id, path: dest, name: dreamManifest.name };
}

/**
 * 批量导入开发仓 themes/* 到 DreamSkin catalog。
 * @param {{ bundledRoot: string, stateRoot?: string }} opts
 */
export async function importAllBundledThemes({
  bundledRoot,
  stateRoot = resolveStudioPaths().dreamStateRoot,
} = {}) {
  const entries = await readdir(bundledRoot, { withFileTypes: true });
  const imported = [];
  const failed = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const dir = join(bundledRoot, entry.name);
    try {
      await stat(join(dir, "theme.json"));
      imported.push(await importHeigeThemeToCatalog({ heigeThemeDir: dir, stateRoot }));
    } catch (error) {
      failed.push({ id: entry.name, error: error?.message ?? String(error) });
    }
  }
  return { imported, failed, savedRoot: join(stateRoot, "themes") };
}

/**
 * bump themes 目录 mtime，让 watch catalog 指纹立即变化。
 * @param {string} [stateRoot]
 */
export async function touchThemesCatalog(
  stateRoot = resolveStudioPaths().dreamStateRoot,
) {
  const savedRoot = join(stateRoot, "themes");
  await mkdir(savedRoot, { recursive: true });
  const marker = join(savedRoot, ".codex-skin-catalog-stamp");
  await writeFile(marker, `${new Date().toISOString()}\n`, "utf8");
  return marker;
}
