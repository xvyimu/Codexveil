/**
 * Pure-function gate for CDP exposure evaluation (no netstat / network).
 * Run: node packages/core/cdp/cdp-exposure.test.mjs  |  npm run test:cdp-exposure
 */
import {
  CDP_LOCAL_TRUST_ADVICE,
  evaluateCdpExposure,
  formatCdpExposureNote,
  inspectCdpExposure,
  isLoopbackListenAddress,
  parseNetstatListeners,
} from "./cdp-exposure.mjs";

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

// 1. loopback address classification
{
  for (const addr of ["127.0.0.1", "127.0.0.53", "[::1]", "::1"]) {
    assert(isLoopbackListenAddress(addr) === true, `loopback: ${addr}`);
  }
  for (const addr of ["0.0.0.0", "[::]", "::", "192.168.1.5", "10.0.0.2", "", null]) {
    assert(isLoopbackListenAddress(addr) === false, `non-loopback: ${String(addr)}`);
  }
}

// 2. netstat parse: keep only LISTENING rows on the requested port
{
  const stdout = [
    "Active Connections",
    "",
    "  Proto  Local Address          Foreign Address        State           PID",
    "  TCP    127.0.0.1:9335         0.0.0.0:0              LISTENING       4242",
    "  TCP    127.0.0.1:9336         0.0.0.0:0              LISTENING       4242",
    "  TCP    0.0.0.0:9335           0.0.0.0:0              LISTENING       9999",
    "  TCP    127.0.0.1:9335         127.0.0.1:52233        ESTABLISHED     4242",
    "  TCP    [::1]:9335             [::]:0                 LISTENING       4242",
  ].join("\r\n");
  const listeners = parseNetstatListeners(stdout, 9335);
  assert(listeners.length === 3, "parse → 3 listeners on 9335 (skips 9336 + established)");
  assert(
    listeners.some((entry) => entry.address === "0.0.0.0" && entry.pid === 9999),
    "parse keeps wildcard listener with pid",
  );
  assert(parseNetstatListeners(stdout, 9222).length === 0, "parse → empty for unused port");
  assert(parseNetstatListeners(null, 9335).length === 0, "parse tolerates non-string stdout");
}

// 3. evaluate: loopback-only → ok
{
  const exposure = evaluateCdpExposure({
    port: 9335,
    listeners: [{ address: "127.0.0.1" }, { address: "[::1]" }],
  });
  assert(exposure.listening === true, "loopback-only → listening=true");
  assert(exposure.loopbackOnly === true, "loopback-only → loopbackOnly=true");
  assert(exposure.exposedAddresses.length === 0, "loopback-only → no exposed addresses");
  assert(exposure.advice === CDP_LOCAL_TRUST_ADVICE, "advice string is attached");
  assert(
    formatCdpExposureNote(exposure).includes("loopback"),
    "note mentions loopback for ok case",
  );
}

// 4. evaluate: wildcard listener → warning
{
  const exposure = evaluateCdpExposure({
    port: 9335,
    listeners: [{ address: "127.0.0.1" }, { address: "0.0.0.0" }],
  });
  assert(exposure.loopbackOnly === false, "wildcard → loopbackOnly=false");
  assert(
    exposure.exposedAddresses.length === 1 && exposure.exposedAddresses[0] === "0.0.0.0",
    "wildcard → exposedAddresses=[0.0.0.0]",
  );
  const note = formatCdpExposureNote(exposure);
  assert(note.startsWith("警告"), "wildcard note starts with 警告");
  assert(note.includes("局域网"), "wildcard note warns about LAN exposure");
}

// 5. evaluate: not listening → loopbackOnly stays null
{
  const exposure = evaluateCdpExposure({ port: 9335, listeners: [] });
  assert(exposure.listening === false, "no listeners → listening=false");
  assert(exposure.loopbackOnly === null, "no listeners → loopbackOnly=null");
  assert(
    formatCdpExposureNote(exposure).includes("未在监听"),
    "no listeners note says not listening",
  );
}

// 6. evaluate: not checked (non-win32 / netstat failure)
{
  const exposure = evaluateCdpExposure({ port: 9335, checked: false, reason: "netstat-failed" });
  assert(exposure.checked === false, "not-checked → checked=false");
  assert(exposure.loopbackOnly === null, "not-checked → loopbackOnly=null");
  assert(
    formatCdpExposureNote(exposure).includes("netstat-failed"),
    "not-checked note carries reason",
  );
}

// 7. inspect: injected exec, win32 path end-to-end
{
  const stdout = [
    "  TCP    127.0.0.1:9335         0.0.0.0:0              LISTENING       4242",
  ].join("\r\n");
  const exposure = await inspectCdpExposure({
    port: 9335,
    platform: "win32",
    exec: async () => ({ stdout }),
  });
  assert(exposure.checked === true, "inspect(win32) → checked=true");
  assert(exposure.loopbackOnly === true, "inspect(win32) → loopbackOnly=true");
}

// 8. inspect: exec throws for both protos → not-checked
{
  const exposure = await inspectCdpExposure({
    port: 9335,
    platform: "win32",
    exec: async () => {
      throw new Error("netstat unavailable");
    },
  });
  assert(exposure.checked === false, "inspect exec failure → checked=false");
  assert(exposure.reason === "netstat-failed", "inspect exec failure → reason=netstat-failed");
}

// 9. inspect: non-win32 → platform-unsupported (product is Windows-only)
{
  const exposure = await inspectCdpExposure({ port: 9335, platform: "darwin" });
  assert(exposure.checked === false, "inspect(darwin) → checked=false");
  assert(
    exposure.reason === "platform-unsupported",
    "inspect(darwin) → reason=platform-unsupported",
  );
}

// 10. inspect: invalid port → invalid-port
{
  const exposure = await inspectCdpExposure({ port: 80, platform: "win32" });
  assert(exposure.checked === false, "inspect(invalid port) → checked=false");
  assert(exposure.reason === "invalid-port", "inspect(invalid port) → reason=invalid-port");
}

if (failed > 0) {
  console.error(`cdp-exposure tests: ${failed} failure(s)`);
  process.exit(1);
}
console.log("cdp-exposure tests: all passed");
