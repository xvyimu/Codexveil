/**
 * @file state-freshness.mjs
 * @description 检查 state.json 是否与 current.json runtime 对齐。
 */
import { join } from "node:path";
import { resolveStudioPaths } from "../constants.mjs";
import { pathExists, readJsonFile } from "./state-io.mjs";

/**
 * Pure decision given already-resolved path/runtime fields.
 * No I/O. Used by inspectInjectorPathFreshness and unit tests.
 *
 * @param {{
 *   expectedInjectorPath: string | null,
 *   actualInjectorPath: string | null,
 *   expectedRuntimeId: string | null,
 *   actualRuntimeId: string | null,
 * }} input
 * @returns {{ fresh: boolean, reason: string }}
 */
export function evaluateInjectorPathFreshness({
  expectedInjectorPath,
  actualInjectorPath,
  expectedRuntimeId,
  actualRuntimeId,
}) {
  const pathFresh =
    Boolean(expectedInjectorPath) &&
    Boolean(actualInjectorPath) &&
    expectedInjectorPath.toLowerCase() === actualInjectorPath.toLowerCase();

  if (!pathFresh) {
    return { fresh: false, reason: "injector-path-drift" };
  }

  if (!expectedRuntimeId) {
    return { fresh: false, reason: "expected-runtimeId-missing" };
  }
  if (!actualRuntimeId) {
    return { fresh: false, reason: "actual-runtimeId-missing" };
  }

  if (expectedRuntimeId.toLowerCase() === actualRuntimeId.toLowerCase()) {
    return { fresh: true, reason: "ok" };
  }

  return { fresh: false, reason: "runtimeId-drift" };
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
    current = await readJsonFile(currentPath);
  } catch {
    result.reason = "bad-current-json";
    return result;
  }
  try {
    state = await readJsonFile(statePath);
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

  const decision = evaluateInjectorPathFreshness({
    expectedInjectorPath,
    actualInjectorPath,
    expectedRuntimeId,
    actualRuntimeId,
  });
  result.fresh = decision.fresh;
  result.reason = decision.reason;
  return result;
}
