/**
 * CSS color subset aligned with packages/runtime/scripts/injector.mjs loadTheme.
 * Keep in sync when injector regex changes.
 */
export const CSS_COLOR_RE =
  /^(?:#[\da-f]{3,8}|(?:rgb|hsl|oklch|oklab)\([^;{}]{1,96}\))$/i;

export function isCssColor(value: string): boolean {
  return CSS_COLOR_RE.test(value.trim());
}
