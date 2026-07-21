/**
 * @file state-io.test.mjs
 * @description Unit tests for shared state IO helpers (no network, no install root).
 */
import { mkdir, writeFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { isProcessAlive, pathExists, readJsonFile, readTextTrim } from "./state-io.mjs";

function assert(cond, msg) {
  if (!cond) throw new Error(msg || "assert failed");
}

const root = join(tmpdir(), `codex-skin-state-io-${process.pid}-${Date.now()}`);
await mkdir(root, { recursive: true });

try {
  const missing = join(root, "nope.json");
  assert((await pathExists(missing)) === false, "missing path → false");

  const plain = join(root, "plain.json");
  await writeFile(plain, JSON.stringify({ a: 1 }), "utf8");
  assert((await pathExists(plain)) === true, "existing path → true");
  assert((await readJsonFile(plain)).a === 1, "plain json parse");

  const bom = join(root, "bom.json");
  await writeFile(bom, "﻿" + JSON.stringify({ b: 2 }), "utf8");
  assert((await readJsonFile(bom)).b === 2, "BOM-stripped json parse");

  assert(isProcessAlive(0) === false, "pid 0 not alive");
  assert(isProcessAlive(-1) === false, "negative pid not alive");
  assert(isProcessAlive(process.pid) === true, "current pid alive");

  const textFile = join(root, "port.txt");
  await writeFile(textFile, "  9336\n", "utf8");
  assert((await readTextTrim(textFile)) === "9336", "readTextTrim strips ws");

  console.log("state-io.test: pass");
} finally {
  await rm(root, { recursive: true, force: true });
}
