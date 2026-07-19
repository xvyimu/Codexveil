/** @file path-utils.mjs - 路径去重与首个存在探测 */
export function uniquePaths(paths) {
  const seen = new Set();
  const result = [];
  for (const path of paths) {
    if (!path || typeof path !== "string") continue;
    const key = process.platform === "win32" ? path.toLowerCase() : path;
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(path);
  }
  return result;
}

export async function firstExisting(paths, exists) {
  for (const path of paths) {
    if (await exists(path)) return path;
  }
  return null;
}
