/**
 * Skin stamp unit tests (no I/O).
 * Run: node packages/runtime/scripts/stamp.test.mjs
 */
import { computeSkinStamp } from "./stamp.mjs";

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    failed += 1;
    console.error("FAIL:", msg);
  } else {
    console.log("ok:", msg);
  }
}

function assertEqual(actual, expected, msg) {
  assert(
    actual === expected,
    `${msg} (got ${JSON.stringify(actual)}, want ${JSON.stringify(expected)})`,
  );
}

const base = {
  engine: "1.3.25",
  css: ".root{color:red}",
  themeId: "miku-488137",
  themeHash: "abc123",
  rendererRev: "rev-1",
};

// 1. Stable input → two calls equal
{
  const a = computeSkinStamp(base);
  const b = computeSkinStamp({ ...base });
  assertEqual(a, b, "stable input: equal digests");
  assertEqual(a.length, 64, "digest is 64-char hex");
  assert(/^[0-9a-f]{64}$/.test(a), "digest is lowercase hex");
}

// 2. themeHash change → stamp changes
{
  const a = computeSkinStamp(base);
  const b = computeSkinStamp({ ...base, themeHash: "abc124" });
  assert(a !== b, "themeHash change: stamp changes");
}

// 3. rendererRev change → stamp changes
{
  const a = computeSkinStamp(base);
  const b = computeSkinStamp({ ...base, rendererRev: "rev-2" });
  assert(a !== b, "rendererRev change: stamp changes");
}

// 4. Missing fields → no throw; equivalent to empty string
{
  const empty = computeSkinStamp({});
  const explicit = computeSkinStamp({
    engine: "",
    css: "",
    themeId: "",
    themeHash: "",
    rendererRev: "",
  });
  assertEqual(empty, explicit, "missing fields == empty strings");
  assertEqual(empty.length, 64, "empty input still 64-char digest");

  const partial = computeSkinStamp({ engine: "e", themeId: "t" });
  const filled = computeSkinStamp({
    engine: "e",
    css: "",
    themeId: "t",
    themeHash: "",
    rendererRev: "",
  });
  assertEqual(partial, filled, "partial fields pad with empty string");
}

// Non-string / nullish inputs: null/undefined → "" (via ??); others via String(...)
{
  const a = computeSkinStamp({
    engine: 1,
    css: null,
    themeId: undefined,
    themeHash: true,
    rendererRev: { x: 1 },
  });
  const b = computeSkinStamp({
    engine: "1",
    css: "",
    themeId: "",
    themeHash: "true",
    rendererRev: "[object Object]",
  });
  assertEqual(a, b, "nullish → empty; other non-strings via String");
}

if (failed > 0) {
  console.error(`stamp.test: ${failed} failure(s)`);
  process.exit(1);
}
console.log("stamp.test: pass");
