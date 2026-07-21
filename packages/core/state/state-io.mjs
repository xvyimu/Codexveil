/**
 * @file state-io.mjs
 * @description L3a 状态层共享 IO（仅 packages/core 内使用）。
 *
 * 抽离 kick / freshness / dreamskin-guard 中重复的 pathExists + JSON 读取，
 * 避免三处各写一遍 access/BOM 解析。不跨包导出到 runtime（runtime 自包含约束）。
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
 * Read UTF-8 text trimmed; empty file → "".
 * @param {string} path
 * @returns {Promise<string>}
 */
export async function readTextTrim(path) {
  return (await readFile(path, "utf8")).trim();
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

/**
 * @param {unknown} pid
 * @returns {boolean}
 */
export function isProcessAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    // Windows: ESRCH / EINVAL → missing; EPERM / EACCES → exists but no signal rights
    if (error && (error.code === "EPERM" || error.code === "EACCES")) return true;
    return false;
  }
}
