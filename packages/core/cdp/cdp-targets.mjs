/** @file cdp-targets.mjs - renderer target 发现 */
import {
  DEFAULT_DISCOVERY_TIMEOUT_MS,
  DEFAULT_POLL_MS,
  DEFAULT_WAIT_TIMEOUT_MS,
  awaitBeforeDeadline,
  buildHttpError,
  errorMessage,
  isRendererTarget,
  sleepWithTimer,
  validateDuration,
  validatePort,
} from "./cdp-helpers.mjs";

export function filterRendererTargets(targets) {
  if (!Array.isArray(targets)) {
    throw new TypeError("renderer targets must be an array");
  }
  return targets.filter(isRendererTarget).sort(compareTargets);
}

export async function fetchRendererTargets(
  port,
  {
    fetchImpl = globalThis.fetch,
    timeoutMs = DEFAULT_DISCOVERY_TIMEOUT_MS,
  } = {},
) {
  validatePort(port);
  validateDuration(timeoutMs, "timeoutMs", { allowZero: false });
  if (typeof fetchImpl !== "function") {
    throw new TypeError("fetchImpl must be a function");
  }

  const endpoint = `http://127.0.0.1:${port}/json/list`;
  const controller = new AbortController();
  const deadline = Date.now() + timeoutMs;
  let response;
  try {
    response = await awaitBeforeDeadline(
      Promise.resolve(
        fetchImpl(endpoint, { redirect: "error", signal: controller.signal }),
      ),
      {
        deadline,
        timeoutMs,
        label: "renderer target discovery",
        onTimeout: () => controller.abort(),
      },
    );
  } catch (error) {
    throw new Error(
      `failed to fetch renderer targets from ${endpoint}: ${errorMessage(error)}`,
      { cause: error },
    );
  }

  if (response === null || typeof response !== "object" || response.ok !== true) {
    throw buildHttpError(response);
  }
  if (typeof response.json !== "function") {
    throw new Error("malformed renderer target response: missing JSON body reader");
  }

  let targets;
  try {
    targets = await awaitBeforeDeadline(Promise.resolve(response.json()), {
      deadline,
      timeoutMs,
      label: "renderer target discovery JSON",
      onTimeout: () => controller.abort(),
    });
  } catch (error) {
    throw new Error(
      `malformed renderer target JSON from ${endpoint}: ${errorMessage(error)}`,
      { cause: error },
    );
  }
  if (!Array.isArray(targets)) {
    throw new Error("malformed renderer target JSON: expected an array");
  }

  return filterRendererTargets(targets);
}

export async function waitForRendererTargets(
  port,
  {
    timeoutMs = DEFAULT_WAIT_TIMEOUT_MS,
    pollMs = DEFAULT_POLL_MS,
    fetchImpl = globalThis.fetch,
    sleep = sleepWithTimer,
  } = {},
) {
  validatePort(port);
  validateDuration(timeoutMs, "timeoutMs", { allowZero: true });
  validateDuration(pollMs, "pollMs", { allowZero: false });
  if (typeof sleep !== "function") {
    throw new TypeError("sleep must be a function");
  }

  let elapsedMs = 0;
  const deadline = Date.now() + timeoutMs;
  let lastError = new Error("no renderer discovery attempt completed");

  while (true) {
    try {
      const remainingBudgetMs = Math.max(
        1,
        Math.min(timeoutMs - elapsedMs, deadline - Date.now()),
      );
      const targets = await fetchRendererTargets(port, {
        fetchImpl,
        timeoutMs: remainingBudgetMs,
      });
      if (targets.length > 0) return targets;
      lastError = new Error("no matching app:// page renderer targets");
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
    }

    if (elapsedMs >= timeoutMs || Date.now() >= deadline) {
      throw new Error(
        `timed out after ${timeoutMs}ms waiting for renderer targets on 127.0.0.1:${port}: ${lastError.message}`,
        { cause: lastError },
      );
    }

    const delayMs = Math.min(pollMs, timeoutMs - elapsedMs);
    await sleep(delayMs);
    elapsedMs += delayMs;
  }
}

