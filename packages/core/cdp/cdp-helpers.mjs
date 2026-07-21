/** @file cdp-helpers.mjs - CDP 校验/错误构造 */
export const MIN_PORT = 1024;
export const MAX_PORT = 65535;
export const DEFAULT_WAIT_TIMEOUT_MS = 5000;
export const DEFAULT_POLL_MS = 100;
export const DEFAULT_COMMAND_TIMEOUT_MS = 5000;
export const DEFAULT_CONNECT_TIMEOUT_MS = 5000;
export const DEFAULT_DISCOVERY_TIMEOUT_MS = 5000;

/** @param {unknown} port @returns {boolean} */
export function isValidPort(port) {
  return Number.isInteger(port) && port >= MIN_PORT && port <= MAX_PORT;
}

export function validatePort(port) {
  if (!isValidPort(port)) {
    throw new TypeError(
      `port must be an integer from ${MIN_PORT} through ${MAX_PORT}`,
    );
  }
  return port;
}

export function validateDuration(value, name, { allowZero }) {
  const minimum = allowZero ? 0 : Number.EPSILON;
  if (!Number.isFinite(value) || value < minimum) {
    const qualifier = allowZero ? "non-negative" : "positive";
    throw new TypeError(`${name} must be a finite ${qualifier} number`);
  }
  return value;
}

export function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

export function parseLoopbackWebSocketUrl(value) {
  if (typeof value !== "string" || value.length === 0 || value !== value.trim()) {
    throw new TypeError("webSocketDebuggerUrl must be a non-empty URL string");
  }

  let parsed;
  try {
    parsed = new URL(value);
  } catch (error) {
    throw new TypeError(`webSocketDebuggerUrl is invalid: ${errorMessage(error)}`, {
      cause: error,
    });
  }

  if (
    parsed.protocol !== "ws:" ||
    parsed.hostname !== "127.0.0.1" ||
    parsed.username ||
    parsed.password ||
    parsed.hash ||
    !parsed.port
  ) {
    throw new TypeError(
      "webSocketDebuggerUrl must use ws://127.0.0.1 with an explicit port",
    );
  }

  validatePort(Number(parsed.port));
  return parsed;
}

export function isRendererTarget(target) {
  if (
    target === null ||
    typeof target !== "object" ||
    Array.isArray(target) ||
    target.type !== "page" ||
    typeof target.url !== "string" ||
    !target.url.startsWith("app://")
  ) {
    return false;
  }

  try {
    parseLoopbackWebSocketUrl(target.webSocketDebuggerUrl);
    return true;
  } catch {
    return false;
  }
}

export function compareText(left, right) {
  if (left < right) return -1;
  if (left > right) return 1;
  return 0;
}

export function compareTargets(left, right) {
  const leftKeys = [
    String(left.id ?? ""),
    left.url,
    left.webSocketDebuggerUrl,
  ];
  const rightKeys = [
    String(right.id ?? ""),
    right.url,
    right.webSocketDebuggerUrl,
  ];

  for (let index = 0; index < leftKeys.length; index += 1) {
    const comparison = compareText(leftKeys[index], rightKeys[index]);
    if (comparison !== 0) return comparison;
  }
  return 0;
}

export function sleepWithTimer(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export async function awaitBeforeDeadline(
  promise,
  { deadline, timeoutMs, label, onTimeout },
) {
  const remainingMs = Math.max(0, deadline - Date.now());
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          onTimeout?.();
          reject(new Error(`${label} timed out after ${timeoutMs}ms`));
        }, remainingMs);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

export function buildHttpError(response) {
  const status = Number.isInteger(response?.status)
    ? String(response.status)
    : "unknown status";
  const statusText =
    typeof response?.statusText === "string" && response.statusText.length > 0
      ? ` ${response.statusText}`
      : "";
  return new Error(`renderer target discovery failed with HTTP ${status}${statusText}`);
}

export function buildCdpError(method, payload) {
  const code = payload && Object.hasOwn(payload, "code") ? payload.code : undefined;
  const message =
    typeof payload?.message === "string" ? payload.message : "unknown CDP error";
  const codeText = code === undefined ? "" : ` (${code})`;
  const error = new Error(`CDP ${method} failed${codeText}: ${message}`);
  error.name = "CdpProtocolError";
  if (code !== undefined) error.code = code;
  if (payload && Object.hasOwn(payload, "data")) error.data = payload.data;
  return error;
}

export function buildEvaluationError(exceptionDetails) {
  const description = exceptionDetails?.exception?.description;
  const text = exceptionDetails?.text;
  const detail =
    typeof description === "string" && description.length > 0
      ? description
      : typeof text === "string" && text.length > 0
        ? text
        : "unknown JavaScript exception";
  const error = new Error(`Runtime.evaluate failed: ${detail}`);
  error.name = "CdpEvaluationError";
  error.exceptionDetails = exceptionDetails;
  return error;
}

