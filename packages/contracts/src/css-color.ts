/**
 * CSS color subset aligned with packages/runtime/scripts/theme-load.mjs loadTheme.
 * Keep in sync when theme-load regex changes.
 */
export const CSS_COLOR_RE =
  /^(?:#[\da-f]{3,8}|(?:rgb|hsl|oklch|oklab)\([^;{}]{1,96}\))$/i;

export function isCssColor(value: string): boolean {
  return CSS_COLOR_RE.test(value.trim());
}
