/**
 * @file thumb.mjs
 * @description Generate catalog thumbs for F6 payload.
 * Priority:
 * 1) cached thumb
 * 2) copy if already <= MAX_MEMBER
 * 3) Python Pillow (handles WebP on this machine)
 * 4) ffmpeg scale
 * 5) ImageMagick magick
 * 6) System.Drawing (PNG/JPEG only)
 */
import { spawn } from "node:child_process";
import { copyFile, stat, writeFile } from "node:fs/promises";
import { pathExists } from "./fs-io.mjs";
import { basename, dirname, extname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const MAX_EDGE = 640;
const MAX_MEMBER = 96 * 1024;
const TARGET_BYTES = 64 * 1024;


function run(cmd, args, timeoutMs = 20000) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let err = "";
    const timer = setTimeout(() => {
      try {
        child.kill();
      } catch {}
      resolve({ code: -1, out, err: err || "timeout" });
    }, timeoutMs);
    child.stdout.on("data", (c) => {
      out += String(c);
    });
    child.stderr.on("data", (c) => {
      err += String(c);
    });
    child.on("error", (e) => {
      clearTimeout(timer);
      resolve({ code: -1, out, err: e.message });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ code: code ?? -1, out, err });
    });
  });
}

async function generateViaPillow(sourcePath, destPath, maxEdge) {
  // Write a tiny temp script to avoid shell quoting issues with Chinese paths.
  const scriptPath = join(tmpdir(), `codex-skin-thumb-${process.pid}-${Date.now()}.py`);
  const script = `
from PIL import Image
import sys
src, dst, edge = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src)
im = im.convert("RGB")
im.thumbnail((edge, edge))
im.save(dst, "JPEG", quality=72, optimize=True)
print(im.size[0], im.size[1])
`;
  await writeFile(scriptPath, script, "utf8");
  try {
    const r = await run("python", [scriptPath, sourcePath, destPath, String(maxEdge)], 25000);
    if (r.code !== 0) return { ok: false, detail: (r.err || r.out || "pillow-fail").slice(0, 240) };
    const st = await stat(destPath).catch(() => null);
    if (!st || st.size < 32) return { ok: false, detail: "pillow-empty" };
    return { ok: true, bytes: st.size, detail: "pillow" };
  } finally {
    try {
      const { unlink } = await import("node:fs/promises");
      await unlink(scriptPath);
    } catch {}
  }
}

async function generateViaFfmpeg(sourcePath, destPath, maxEdge) {
  // ffmpeg can decode webp when built with libwebp (common on winget/local builds).
  const r = await run(
    "ffmpeg",
    [
      "-y",
      "-i",
      sourcePath,
      "-vf",
      `scale='min(${maxEdge},iw)':'min(${maxEdge},ih)':force_original_aspect_ratio=decrease`,
      "-q:v",
      "5",
      destPath,
    ],
    25000,
  );
  if (r.code !== 0) return { ok: false, detail: (r.err || r.out || "ffmpeg-fail").slice(0, 240) };
  const st = await stat(destPath).catch(() => null);
  if (!st || st.size < 32) return { ok: false, detail: "ffmpeg-empty" };
  return { ok: true, bytes: st.size, detail: "ffmpeg" };
}

async function generateViaMagick(sourcePath, destPath, maxEdge) {
  const r = await run(
    "magick",
    [sourcePath, "-resize", `${maxEdge}x${maxEdge}>`, "-quality", "72", destPath],
    25000,
  );
  if (r.code !== 0) return { ok: false, detail: (r.err || r.out || "magick-fail").slice(0, 240) };
  const st = await stat(destPath).catch(() => null);
  if (!st || st.size < 32) return { ok: false, detail: "magick-empty" };
  return { ok: true, bytes: st.size, detail: "magick" };
}

async function generateViaDrawing(sourcePath, destPath, maxEdge) {
  const ps = `
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$src = ${JSON.stringify(sourcePath)}
$dst = ${JSON.stringify(destPath)}
$max = ${maxEdge}
$img = [System.Drawing.Image]::FromFile($src)
try {
  $w = $img.Width; $h = $img.Height
  $scale = [Math]::Min(1.0, $max / [Math]::Max($w, $h))
  $nw = [Math]::Max(1, [int][Math]::Round($w * $scale))
  $nh = [Math]::Max(1, [int][Math]::Round($h * $scale))
  $bmp = New-Object System.Drawing.Bitmap $nw, $nh
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, 0, 0, $nw, $nh)
  $g.Dispose()
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]72)
  if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force }
  $bmp.Save($dst, $codec, $ep)
  $bmp.Dispose(); $ep.Dispose()
  Write-Output ((Get-Item -LiteralPath $dst).Length)
} finally { $img.Dispose() }
`;
  const r = await run("powershell.exe", [
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-Command",
    ps,
  ]);
  if (r.code !== 0) return { ok: false, detail: (r.err || r.out || "drawing-fail").slice(0, 240) };
  const bytes = Number(String(r.out).trim());
  return {
    ok: Number.isFinite(bytes) && bytes > 0,
    bytes: Number.isFinite(bytes) ? bytes : undefined,
    detail: "drawing",
  };
}

/**
 * @param {{ sourcePath: string, destPath?: string, maxEdge?: number }} opts
 */
export async function generateThumb({
  sourcePath,
  destPath,
  maxEdge = MAX_EDGE,
} = {}) {
  if (!(await pathExists(sourcePath))) {
    return { ok: false, destPath: destPath || "", detail: "source-missing" };
  }
  const ext = extname(sourcePath).toLowerCase();
  destPath = destPath || join(dirname(sourcePath), "thumb.jpg");

  try {
    const [src, dst] = await Promise.all([
      stat(sourcePath),
      stat(destPath).catch(() => null),
    ]);
    if (dst && dst.size > 32 && dst.mtimeMs >= src.mtimeMs - 1000) {
      return { ok: true, destPath, bytes: dst.size, detail: "cached" };
    }
    if (src.size > 0 && src.size <= MAX_MEMBER) {
      // Keep original format when already small enough for F6 catalog.
      const smallDest =
        ext === ".webp" ? join(dirname(sourcePath), "thumb.webp") : destPath;
      await copyFile(sourcePath, smallDest);
      const st = await stat(smallDest);
      return { ok: true, destPath: smallDest, bytes: st.size, detail: "copy-small" };
    }
  } catch {
    // continue
  }

  // Prefer JPEG destination for oversized sources.
  if (!/\.jpe?g$/i.test(destPath)) {
    destPath = join(dirname(sourcePath), "thumb.jpg");
  }

  const attempts = [];
  for (const fn of [
    () => generateViaPillow(sourcePath, destPath, maxEdge),
    () => generateViaFfmpeg(sourcePath, destPath, maxEdge),
    () => generateViaMagick(sourcePath, destPath, maxEdge),
  ]) {
    const r = await fn();
    attempts.push(r.detail || (r.ok ? "ok" : "fail"));
    if (r.ok) return { destPath, ...r };
  }

  if (ext === ".png" || ext === ".jpg" || ext === ".jpeg") {
    const drawn = await generateViaDrawing(sourcePath, destPath, maxEdge);
    attempts.push(drawn.detail || "drawing");
    if (drawn.ok) return { destPath, ...drawn };
  }

  return {
    ok: false,
    destPath,
    detail: `no-decoder (${attempts.filter(Boolean).join(" | ") || "none"})`,
  };
}

export async function ensureThemeThumb(themeDir, imageName) {
  let source = imageName ? join(themeDir, imageName) : null;
  if (!source || !(await pathExists(source))) {
    for (const name of [
      "hero.webp",
      "hero.png",
      "hero.jpg",
      "hero.jpeg",
      "image.webp",
      "image.png",
    ]) {
      const p = join(themeDir, name);
      if (await pathExists(p)) {
        source = p;
        break;
      }
    }
  }
  if (!source) {
    try {
      const { readdir } = await import("node:fs/promises");
      const files = await readdir(themeDir);
      const art = files.find((f) => f.startsWith("art-") && /\.(webp|png|jpe?g)$/i.test(f));
      if (art) source = join(themeDir, art);
      else {
        const any = files.find((f) => /\.(webp|png|jpe?g)$/i.test(f) && !/^thumb\./i.test(f));
        if (any) source = join(themeDir, any);
      }
    } catch {
      // ignore
    }
  }
  if (!source) {
    return { ok: false, detail: "no-image", destPath: join(themeDir, "thumb.jpg") };
  }
  return generateThumb({ sourcePath: source });
}

export function thumbPathFor(themeDir) {
  return join(themeDir, "thumb.jpg");
}

export function isThumbFileName(name) {
  return /^thumb\.(jpe?g|webp|png)$/i.test(basename(name));
}

/**
 * Batch ensure thumbs for many theme directories (single node process).
 * @param {string[]} themeDirs
 */
export async function ensureThemeThumbsBatch(themeDirs = []) {
  const items = [];
  let ok = 0;
  let fail = 0;
  for (const dir of themeDirs) {
    const r = await ensureThemeThumb(dir);
    items.push({
      id: basename(dir),
      ok: Boolean(r?.ok),
      thumb: r?.destPath || "",
      bytes: r?.bytes || 0,
      detail: r?.detail || "",
    });
    if (r?.ok) ok += 1;
    else fail += 1;
  }
  return { total: themeDirs.length, ok, fail, items };
}

// CLI: node thumb.mjs --batch <dir1> <dir2> ...
// or:  node thumb.mjs --batch-root <themesRoot>
const isMain = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isMain) {
  const args = process.argv.slice(2);
  try {
    if (args[0] === "--batch-root" && args[1]) {
      const { readdir } = await import("node:fs/promises");
      const root = args[1];
      const entries = await readdir(root, { withFileTypes: true });
      const dirs = entries.filter((e) => e.isDirectory()).map((e) => join(root, e.name));
      const report = await ensureThemeThumbsBatch(dirs);
      console.log(JSON.stringify(report));
      process.exit(report.fail ? 2 : 0);
    }
    if (args[0] === "--batch") {
      const report = await ensureThemeThumbsBatch(args.slice(1));
      console.log(JSON.stringify(report));
      process.exit(report.fail ? 2 : 0);
    }
    console.error("Usage: thumb.mjs --batch-root <themesRoot> | --batch <themeDir...>");
    process.exit(2);
  } catch (error) {
    console.error(error?.message || String(error));
    process.exit(1);
  }
}

export { MAX_EDGE, TARGET_BYTES, MAX_MEMBER };
