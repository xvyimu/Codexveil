/** Pure CDP WebSocket URL + browser/page id guards (loopback-only). Used by injector.mjs. */

export const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]", "::1"]);

/** CDP target / browser id shape (page id, browser id path segment). */
export const BROWSER_ID_PATTERN = /^[A-Za-z0-9._-]{1,200}$/;

/**
 * @param {unknown} id
 * @returns {boolean}
 */
export function isValidBrowserId(id) {
  return typeof id === "string" && id.length > 0 && BROWSER_ID_PATTERN.test(id);
}

/**
 * @param {{ webSocketDebuggerUrl: string }} target
 * @param {number} port
 * @returns {string} href
 */
export function validatedDebuggerUrl(target, port) {
  const url = new URL(target.webSocketDebuggerUrl);
  const pathIsValid = /^\/devtools\/(?:page|browser)\/[A-Za-z0-9._-]{1,200}$/.test(url.pathname);
  if (url.protocol !== "ws:" || !LOOPBACK_HOSTS.has(url.hostname) || Number(url.port) !== port ||
      url.username || url.password || url.search || url.hash || !pathIsValid) {
    throw new Error("Rejected a CDP WebSocket URL outside the allowed loopback endpoint shape");
  }
  return url.href;
}
