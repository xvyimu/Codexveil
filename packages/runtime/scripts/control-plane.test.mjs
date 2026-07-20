/**
 * Control-plane token gate regression (SEC-01).
 * Run: node packages/runtime/scripts/control-plane.test.mjs
 * Not in CI (starts a loopback server on 9347+).
 */
import { mkdtemp, rm, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { startControlPlane, CONTROL_TOKEN_HEADER } from "./control-plane.mjs";

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

async function httpJson(method, url, { headers = {}, body = null } = {}) {
  const res = await fetch(url, {
    method,
    headers,
    body: body == null ? undefined : body,
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    json = null;
  }
  return { status: res.status, json };
}

async function main() {
  const stateRoot = await mkdtemp(join(tmpdir(), "codex-skin-cp-test-"));
  let plane = null;
  try {
    plane = await startControlPlane({
      stateRoot,
      preferredPort: 9347,
      getHealth: async () => ({ healthy: true, probe: "test" }),
      onKick: async () => ({ ok: true, mode: "test-kick" }),
      onFocus: async () => ({ focused: true, ms: 0 }),
    });
    assert(plane.port != null && plane.port >= 9347, `bound port >= 9347 (got ${plane.port})`);
    assert(Boolean(plane.token) && plane.token.length >= 16, "token present from ensureToken");

    const base = `http://127.0.0.1:${plane.port}`;
    const tokenFromFile = (await readFile(join(stateRoot, "control.token"), "utf8")).trim();
    assert(tokenFromFile === plane.token, "control.token file matches plane.token");

    const health = await httpJson("GET", `${base}/health`);
    assert(health.status === 200, `GET /health → 200 (got ${health.status})`);
    assert(health.json?.ok === true, "GET /health body.ok");
    assert(health.json?.tokenPresent === true, "GET /health tokenPresent");
    assert(health.json?.tokenRequiredForMutations === true, "GET /health tokenRequiredForMutations");

    const noToken = await httpJson("POST", `${base}/kick`);
    assert(noToken.status === 401, `POST /kick no token → 401 (got ${noToken.status})`);
    assert(noToken.json?.reason === "token-required", "POST /kick no token reason=token-required");

    const wrong = await httpJson("POST", `${base}/kick?token=deadbeef`);
    assert(wrong.status === 401, `POST /kick wrong token → 401 (got ${wrong.status})`);

    const okHeader = await httpJson("POST", `${base}/kick`, {
      headers: { [CONTROL_TOKEN_HEADER]: plane.token },
    });
    assert(okHeader.status === 200, `POST /kick correct header → 200 (got ${okHeader.status})`);
    assert(okHeader.json?.ok === true, "POST /kick correct header body.ok");

    const okQuery = await httpJson("POST", `${base}/kick?token=${encodeURIComponent(plane.token)}`);
    assert(okQuery.status === 200, `POST /kick correct query → 200 (got ${okQuery.status})`);
  } finally {
    if (plane?.close) await plane.close();
    await rm(stateRoot, { recursive: true, force: true });
  }

  if (failed) {
    console.error(`\n${failed} assertion(s) failed`);
    process.exit(1);
  }
  console.log("\nall passed");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
