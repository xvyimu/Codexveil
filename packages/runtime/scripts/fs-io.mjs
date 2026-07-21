/**
 * @file fs-io.mjs
 * @description Runtime-local filesystem helpers (self-contained).
 *
 * Duplicates the *idea* of packages/core/state/state-io.mjs but MUST NOT import
 * packages/core (publish copies runtime alone into versions/<id>/).
 */
import { access, readFile } from "node:fs/promises";

/**
 * @param {string} p
 * @returns {Promise<boolean>}
 */
export async function pathExists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

/**
 * Read UTF-8 JSON; strip leading BOM if present.
 * @param {string} path
 * @returns {Promise<unknown>}
 */
export async function readJsonFile(path) {
  const raw = await readFile(path, "utf8");
  return JSON.parse(raw.replace(/^﻿/, ""));
}
