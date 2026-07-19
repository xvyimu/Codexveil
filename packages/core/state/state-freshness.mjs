/**
 * @file state-freshness.mjs
 * @description 检查 state.json 是否与 current.json runtime 对齐。
 */
import { access, readFile } from "node:fs/promises";
import { join } from "node:path";
import { resolveStudioPaths } from "../constants.mjs";

async function pathExists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

async function readJson(path) {
  const raw = await readFile(path, "utf8");
  return JSON.parse(raw.replace(/^﻿/, ""));
}

/**
 * @param {{ installRoot?: string, stateRoot?: string }} [opts]
 */
export async function inspectInjectorPathFreshness({
  installRoot = resolveStudioPaths().installRoot,
  stateRoot = resolveStudioPaths().dreamStateRoot,
} = {}) {
  const result = {
    fresh: false,
    reason: "unknown",
    expectedInjectorPath: null,
    actualInjectorPath: null,
    expectedRuntimeId: null,
    actualRuntimeId: null,
    currentJsonPresent: false,
    stateJsonPresent: false,
  };

  const currentPath = join(installRoot, "current.json");
  const statePath = join(stateRoot, "state.json");
  result.currentJsonPresent = await pathExists(currentPath);
  result.stateJsonPresent = await pathExists(statePath);

  if (!result.currentJsonPresent) {
    result.reason = "missing-current-json";
    return result;
  }
  if (!result.stateJsonPresent) {
    result.reason = "missing-state-json";
    return result;
  }

  let current;
  let state;
  try {
    current = await readJson(currentPath);
  } catch {
    result.reason = "bad-current-json";
    return result;
  }
  try {
    state = await readJson(statePath);
  } catch {
    result.reason = "bad-state-json";
    return result;
  }

  const rel = String(current?.relativeEnginePath || "").replaceAll("/", "\\");
  const expectedRuntimeId = current?.runtimeId ? String(current.runtimeId) : null;
  const expectedInjectorPath = rel
    ? join(installRoot, rel, "scripts", "injector.mjs")
    : null;
  const actualInjectorPath =
    typeof state?.injectorPath === "string" ? state.injectorPath : null;
  const actualRuntimeId = state?.runtimeId ? String(state.runtimeId) : null;

  result.expectedInjectorPath = expectedInjectorPath;
  result.actualInjectorPath = actualInjectorPath;
  result.expectedRuntimeId = expectedRuntimeId;
  result.actualRuntimeId = actualRuntimeId;

  if (!expectedInjectorPath) {
    result.reason = "current-missing-relativeEnginePath";
    return result;
  }
  if (!(await pathExists(expectedInjectorPath))) {
    result.reason = "expected-injector-missing-on-disk";
    return result;
  }
  if (!actualInjectorPath) {
    result.reason = "state-missing-injectorPath";
    return result;
  }

  const pathFresh =
    expectedInjectorPath.toLowerCase() === actualInjectorPath.toLowerCase();
  const runtimeFresh =
    !expectedRuntimeId ||
    !actualRuntimeId ||
    expectedRuntimeId.toLowerCase() === actualRuntimeId.toLowerCase();

  if (pathFresh && runtimeFresh) {
    result.fresh = true;
    result.reason = "ok";
    return result;
  }
  if (!pathFresh) {
    result.reason = "injector-path-drift";
    return result;
  }
  result.reason = "runtimeId-drift";
  return result;
}
