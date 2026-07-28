/**
 * Local / maintainer dependency audit against the official npm registry.
 *
 * Why: many China mirrors (e.g. registry.npmmirror.com) omit the bulk
 * advisories endpoint `/-/npm/v1/security/advisories/bulk`. Bare `pnpm audit`
 * then fails with ERR_PNPM_AUDIT_ENDPOINT_NOT_EXISTS even when the tree is clean.
 *
 * This script does **not** change global user config and does **not** write tokens.
 * Run: node scripts/audit-local.mjs
 *      npm run audit:deps
 *
 * CI: .github/workflows/themes-gate.yml forces the same registry flag.
 * Evidence: docs/ops/cv-audit-registry-evidence-2026-07-28.md
 */
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const OFFICIAL = "https://registry.npmjs.org";
const root = join(dirname(fileURLToPath(import.meta.url)), "..");

const extra = process.argv.slice(2);
const args = ["audit", `--registry=${OFFICIAL}`, ...extra];

console.log(`[audit-local] pnpm ${args.join(" ")}`);
console.log(`[audit-local] cwd=${root}`);
console.log(
  "[audit-local] note: mirrors without the bulk advisories API will fail bare `pnpm audit`; this path always hits npmjs.org",
);

const r = spawnSync("pnpm", args, {
  cwd: root,
  stdio: "inherit",
  shell: true,
  env: {
    ...process.env,
    // Prefer explicit CLI flag; also neutralize common env overrides for this process only.
    npm_config_registry: OFFICIAL,
    NPM_CONFIG_REGISTRY: OFFICIAL,
  },
});

if (r.error) {
  console.error(`[audit-local] failed to spawn pnpm: ${r.error.message}`);
  process.exit(1);
}

process.exit(r.status ?? 1);
