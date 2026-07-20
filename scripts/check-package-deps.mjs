/**
 * Static dependency boundary gate (ADR 0001 / PROJECT §3.2).
 * Fails if packages/core imports packages/runtime, or packages/runtime imports packages/core.
 * themes → runtime is only allowed as dynamic import of thumb.mjs (not checked as static).
 *
 * Run: node scripts/check-package-deps.mjs
 */
import { readdir, readFile, stat } from "node:fs/promises";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(fileURLToPath(import.meta.url), "..", "..");

const STATIC_FROM = /(?:from|import)\s*['"]([^'"]+)['"]/g;
// require is rare in ESM tree but catch anyway
const REQUIRE = /require\s*\(\s*['"]([^'"]+)['"]\s*\)/g;

async function walkMjs(dir, acc = []) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return acc;
  }
  for (const e of entries) {
    const p = join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name === "node_modules" || e.name === "vendor") continue;
      await walkMjs(p, acc);
    } else if (e.isFile() && (e.name.endsWith(".mjs") || e.name.endsWith(".js"))) {
      acc.push(p);
    }
  }
  return acc;
}

function collectSpecs(source) {
  const specs = [];
  for (const re of [STATIC_FROM, REQUIRE]) {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(source))) specs.push(m[1]);
  }
  return specs;
}

function isCross(spec, fromPkg, forbiddenPkg) {
  // relative imports that climb into sibling package
  // e.g. from packages/core/x.mjs: '../runtime/...' or '../../packages/runtime/...'
  if (!spec.startsWith(".")) return false;
  const norm = spec.replace(/\\/g, "/");
  if (fromPkg === "core" && /(?:^|\/)\.\.\/(?:\.\.\/)*(?:packages\/)?runtime(?:\/|$)/.test(norm)) {
    return true;
  }
  if (fromPkg === "runtime" && /(?:^|\/)\.\.\/(?:\.\.\/)*(?:packages\/)?core(?:\/|$)/.test(norm)) {
    return true;
  }
  // also catch bare packages/core from runtime or packages/runtime from core via multi-up
  if (fromPkg === "core" && norm.includes("/runtime/") && norm.includes("..")) {
    // path like ../../../packages/runtime/foo
    if (norm.includes("packages/runtime") || /\/runtime\/scripts\//.test(norm) || /\/runtime\/assets\//.test(norm)) {
      return true;
    }
  }
  if (fromPkg === "runtime" && norm.includes("packages/core")) return true;
  void forbiddenPkg;
  return false;
}

async function scanPackage(pkgName) {
  const root = join(repoRoot, "packages", pkgName);
  const files = await walkMjs(root);
  const violations = [];
  for (const file of files) {
    // skip tests if any under runtime for now — still enforce
    const src = await readFile(file, "utf8");
    for (const spec of collectSpecs(src)) {
      if (isCross(spec, pkgName, pkgName === "core" ? "runtime" : "core")) {
        violations.push({
          file: relative(repoRoot, file).replace(/\\/g, "/"),
          spec,
        });
      }
    }
  }
  return { files: files.length, violations };
}

const core = await scanPackage("core");
const runtime = await scanPackage("runtime");

let failed = 0;
function ok(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

ok(core.files > 0, `scanned packages/core (${core.files} files)`);
ok(runtime.files > 0, `scanned packages/runtime (${runtime.files} files)`);
ok(core.violations.length === 0, "core has no static import of runtime");
ok(runtime.violations.length === 0, "runtime has no static import of core");

for (const v of [...core.violations, ...runtime.violations]) {
  console.error(`  ${v.file} → ${v.spec}`);
}

// themes dynamic thumb is allowed; assert static import of runtime is absent
const themesRoot = join(repoRoot, "packages", "themes");
const themeFiles = await walkMjs(themesRoot);
let staticThemeRuntime = 0;
for (const file of themeFiles) {
  const src = await readFile(file, "utf8");
  // strip comments lightly — only fail on static from/import of runtime
  for (const spec of collectSpecs(src)) {
    if (spec.includes("runtime") && (spec.startsWith(".") || spec.includes("packages/runtime"))) {
      // dynamic import() is also matched by STATIC_FROM if written as import('...')
      // allow thumb.mjs only
      if (/thumb\.mjs/.test(spec)) continue;
      staticThemeRuntime += 1;
      console.error(`FAIL: themes → runtime non-thumb: ${relative(repoRoot, file)} → ${spec}`);
    }
  }
}
ok(staticThemeRuntime === 0, "themes has no non-thumb static/dynamic runtime import (thumb.mjs allowed)");

if (failed > 0) {
  console.error(`\ncheck-package-deps: ${failed} failed`);
  process.exit(1);
}
console.log("\ncheck-package-deps: all passed");
