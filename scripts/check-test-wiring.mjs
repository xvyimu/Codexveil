/**
 * Test wiring gate (PROJECT §9.2 · DoD 1).
 *
 * Fails if a *.test.mjs / *.test.ps1 file exists in the repo but no package.json
 * script runs it, or if a wired script is not reachable from `test:unit`.
 *
 * Why: 2026-07-21 `c22dbc9` ("docs: GitHub identity README", a rebase replay)
 * silently dropped `test:state-io` + `test:fs-io` that `3f36e56` had added 80
 * minutes earlier. Both unit tests kept passing on demand but never ran in
 * `npm test` or CI for weeks — a green gate that proved nothing about them.
 * An orphan test is worse than no test: it reads as coverage without being it.
 *
 * Contract packages own their own runner (`test:contracts` → vitest/node --test
 * inside the workspace package), so packages/contracts is out of scope here.
 *
 * Run: node scripts/check-test-wiring.mjs  |  npm run test:wiring
 */
import { readdir, readFile } from "node:fs/promises";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(fileURLToPath(import.meta.url), "..", "..");

// Owned by `test:contracts` via the workspace filter, not by a root script.
const SKIP_DIRS = new Set(["node_modules", "dist", "vendor", ".git", "versions"]);
const SKIP_PREFIXES = ["packages/contracts/"];
// Live-only gates: need a running Codex / CDP / loopback control plane.
// Documented as "不进 CI" in CLAUDE.md; wired but deliberately outside test:unit.
const LIVE_ONLY_SCRIPTS = new Set(["test:control"]);

async function walkTests(dir, acc = []) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return acc;
  }
  for (const e of entries) {
    const p = join(dir, e.name);
    if (e.isDirectory()) {
      if (SKIP_DIRS.has(e.name)) continue;
      await walkTests(p, acc);
    } else if (e.isFile() && /\.test\.(mjs|ps1)$/.test(e.name)) {
      acc.push(relative(repoRoot, p).replace(/\\/g, "/"));
    }
  }
  return acc;
}

const pkg = JSON.parse(await readFile(join(repoRoot, "package.json"), "utf8"));
const scripts = pkg.scripts || {};

const testFiles = (await walkTests(repoRoot)).filter(
  (f) => !SKIP_PREFIXES.some((p) => f.startsWith(p)),
);

/** Scripts that directly invoke a given test file. */
function scriptsRunning(file) {
  return Object.entries(scripts)
    .filter(([, cmd]) => cmd.replace(/\\/g, "/").includes(file))
    .map(([name]) => name);
}

/** Script names reachable from `test:unit` via `npm run <name>` chains. */
function reachableFromUnit() {
  const seen = new Set();
  const queue = ["test:unit"];
  while (queue.length) {
    const name = queue.shift();
    if (seen.has(name)) continue;
    seen.add(name);
    const cmd = scripts[name];
    if (!cmd) continue;
    for (const m of cmd.matchAll(/npm run ([\w:-]+)/g)) queue.push(m[1]);
  }
  return seen;
}

const reachable = reachableFromUnit();

let failed = 0;
function ok(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

ok(testFiles.length > 0, `discovered test files (${testFiles.length})`);
ok(Boolean(scripts["test:unit"]), "test:unit script exists");

for (const file of testFiles) {
  const runners = scriptsRunning(file);
  if (runners.length === 0) {
    ok(false, `${file} — no package.json script runs it (orphan test)`);
    continue;
  }
  const live = runners.filter((r) => LIVE_ONLY_SCRIPTS.has(r));
  if (live.length === runners.length) {
    console.log(`ok: ${file} — live-only via ${live.join(", ")} (outside test:unit by design)`);
    continue;
  }
  const inUnit = runners.filter((r) => reachable.has(r));
  ok(
    inUnit.length > 0,
    `${file} — wired (${runners.join(", ")}) and reachable from test:unit`,
  );
}

if (failed > 0) {
  console.error(`\ncheck-test-wiring: ${failed} failed`);
  process.exit(1);
}
console.log("\ncheck-test-wiring: all passed");
