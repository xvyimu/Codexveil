import { existsSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const coreCandidates = [
  new URL("../core/image-metadata.mjs", import.meta.url),
  new URL("../../core/image-metadata.mjs", import.meta.url),
];
const coreUrl = coreCandidates.find((candidate) => existsSync(fileURLToPath(candidate)));
if (!coreUrl) throw new Error("Dream Skin shared image metadata core is missing.");
const core = await import(coreUrl.href);

export const MAX_IMAGE_DIMENSION = core.MAX_IMAGE_DIMENSION;
export const MAX_IMAGE_PIXELS = core.MAX_IMAGE_PIXELS;
export const classifyImageDimensions = core.classifyImageDimensions;
export const readImageMetadata = core.readImageMetadata;

// The Windows theme store uses this read-only CLI before copying a selected
// image. Parsing stays in the shared core; this adapter only handles local I/O.
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [mode, imagePath] = process.argv.slice(2);
  if (mode !== "--check" || !imagePath) {
    console.error("Usage: image-metadata.mjs --check <image>");
    process.exitCode = 2;
  } else {
    try {
      const resolved = path.resolve(imagePath);
      const bytes = await fs.readFile(resolved);
      const metadata = readImageMetadata(bytes, path.extname(resolved));
      if (!metadata) throw new Error("Image metadata is invalid or exceeds the 16384px / 50MP safety limit");
      console.log(JSON.stringify(metadata));
    } catch (error) {
      console.error(error?.message ?? String(error));
      process.exitCode = 2;
    }
  }
}
