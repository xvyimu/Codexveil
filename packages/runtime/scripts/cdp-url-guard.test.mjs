/**
 * CDP URL guard unit tests (no network).
 * Run: node packages/runtime/scripts/cdp-url-guard.test.mjs
 */
import {
  BROWSER_ID_PATTERN,
  LOOPBACK_HOSTS,
  isValidBrowserId,
  validatedDebuggerUrl,
} from "./cdp-url-guard.mjs";

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

function assertThrows(fn, msg) {
  let threw = false;
  try {
    fn();
  } catch {
    threw = true;
  }
  assert(threw, msg);
}

const PORT = 9335;

// Positive cases — construct legal URL strings (bare "::1" is not valid in ws:// host position;
// CDP/WHATWG expose IPv6 as "[::1]"; bare "::1" remains in LOOPBACK_HOSTS for hostname matching).
assert(LOOPBACK_HOSTS.has("::1"), "LOOPBACK_HOSTS includes bare ::1 for hostname match");
const positiveHosts = ["127.0.0.1", "localhost", "[::1]"];
for (const host of positiveHosts) {
  const href = `ws://${host}:${PORT}/devtools/page/test`;
  try {
    const got = validatedDebuggerUrl({ webSocketDebuggerUrl: href }, PORT);
    assert(typeof got === "string" && got.length > 0, `accepts loopback host ${host}`);
    assert(got === new URL(href).href, `href stable for ${host}`);
    assert(LOOPBACK_HOSTS.has(new URL(href).hostname), `hostname ${new URL(href).hostname} in LOOPBACK_HOSTS`);
  } catch (err) {
    assert(false, `accepts loopback host ${host}: ${err.message}`);
  }
}

// browser path
{
  const href = `ws://127.0.0.1:${PORT}/devtools/browser/test-browser`;
  const got = validatedDebuggerUrl({ webSocketDebuggerUrl: href }, PORT);
  assert(got === new URL(href).href, "accepts browser path");
}

// Negative cases (align injector self-test + extra guards)
const invalid = [
  "ws://example.com/devtools/page/test",
  `ws://127.0.0.1:${PORT + 1}/devtools/page/test`,
  `wss://127.0.0.1:${PORT}/devtools/page/test`,
  `ws://user@127.0.0.1:${PORT}/devtools/page/test`,
  `ws://127.0.0.1:${PORT}/unexpected/test`,
  `ws://127.0.0.1:${PORT}/devtools/page/test?query=1`,
  `ws://127.0.0.1:${PORT}/devtools/page/test#frag`,
  `ws://user:pass@127.0.0.1:${PORT}/devtools/page/test`,
  `ws://127.0.0.1:${PORT}/devtools/page/`,
  `ws://127.0.0.1:${PORT}/devtools/other/test`,
];

for (const value of invalid) {
  assertThrows(
    () => validatedDebuggerUrl({ webSocketDebuggerUrl: value }, PORT),
    `rejects unsafe URL: ${value}`,
  );
}

// Browser / page id shape (shared with injector parseArgs / page filter)
assert(BROWSER_ID_PATTERN.test("abc-123_X.y"), "BROWSER_ID_PATTERN accepts alnum._-");
assert(!BROWSER_ID_PATTERN.test(""), "BROWSER_ID_PATTERN rejects empty");
assert(!BROWSER_ID_PATTERN.test("has space"), "BROWSER_ID_PATTERN rejects space");
assert(!BROWSER_ID_PATTERN.test("a".repeat(201)), "BROWSER_ID_PATTERN rejects >200 chars");
assert(isValidBrowserId("page-1"), "isValidBrowserId accepts page-1");
assert(!isValidBrowserId(null), "isValidBrowserId rejects null");
assert(!isValidBrowserId(12), "isValidBrowserId rejects number");
assert(!isValidBrowserId(""), "isValidBrowserId rejects empty string");

if (failed > 0) {
  console.error(`cdp-url-guard.test: ${failed} failure(s)`);
  process.exit(1);
}
console.log("cdp-url-guard.test: pass");
