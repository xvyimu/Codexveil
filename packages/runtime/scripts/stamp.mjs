/** Pure inject-identity stamp (U1 Reconciler prep). Does not change inject decisions. */
import { createHash } from "node:crypto";

/**
 * Stable hex digest for inject identity (U1 stamp Reconciler prep).
 * Does NOT change inject decisions in this slice.
 *
 * @param {{
 *   engine: string,       // e.g. SKIN_VERSION or runtime id
 *   css: string,          // dream-skin.css text (or hash preimage)
 *   themeId: string,
 *   themeHash: string,    // active theme fingerprint / content hash
 *   rendererRev: string,  // renderer-inject identity (version token or content hash)
 * }} input
 * @returns {string} 64-char lowercase hex sha256
 */
export function computeSkinStamp({ engine, css, themeId, themeHash, rendererRev } = {}) {
  const parts = [engine, css, themeId, themeHash, rendererRev].map((value) =>
    String(value ?? ""),
  );
  return createHash("sha256").update(parts.join("\0"), "utf8").digest("hex");
}
