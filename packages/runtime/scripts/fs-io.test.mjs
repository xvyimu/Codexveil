/**
 * @file fs-io.test.mjs
 */
import { mkdir, writeFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { pathExists, readJsonFile } from "./fs-io.mjs";

function assert(cond, msg) {
  if (!cond) throw new Error(msg || "assert failed");
}

const root = join(tmpdir(), `codex-skin-fs-io-${process.pid}-${Date.now()}`);
await mkdir(root, { recursive: true });
try {
  assert((await pathExists(join(root, "x"))) === false, "missing");
  const f = join(root, "a.json");
  await writeFile(f, JSON.stringify({ ok: 1 }), "utf8");
  assert((await pathExists(f)) === true, "exists");
  assert((await readJsonFile(f)).ok === 1, "json");
  const b = join(root, "b.json");
  await writeFile(b, "﻿" + JSON.stringify({ ok: 2 }), "utf8");
  assert((await readJsonFile(b)).ok === 2, "bom");
  console.log("fs-io.test: pass");
} finally {
  await rm(root, { recursive: true, force: true });
}
