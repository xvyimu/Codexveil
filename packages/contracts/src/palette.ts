import { z } from "zod";
import { isCssColor } from "./css-color.js";

const cssColor = z
  .string()
  .trim()
  .min(1)
  .refine(isCssColor, { message: "not a supported CSS color" });

/**
 * Palette four-color contract (TD-V5-LESSON / ARCHITECTURE).
 * Missing `surface` → renderer surfaceLuma path breaks → white-flash risk.
 */
export const paletteSchema = z
  .object({
    accent: cssColor.optional(),
    secondary: cssColor.optional(),
    surface: cssColor.optional(),
    text: cssColor.optional(),
  })
  .strict();

export type Palette = z.infer<typeof paletteSchema>;

/** Require surface for dark/light inference consumers (apply/kick paths). */
export const paletteWithSurfaceSchema = paletteSchema.refine(
  (p) => typeof p.surface === "string" && p.surface.length > 0,
  { message: "palette.surface is required for appearance inference", path: ["surface"] },
);

export type PaletteWithSurface = z.infer<typeof paletteWithSurfaceSchema>;

export function parsePalette(input: unknown): Palette {
  return paletteSchema.parse(input);
}

export function parsePaletteWithSurface(input: unknown): PaletteWithSurface {
  return paletteWithSurfaceSchema.parse(input);
}

export function safeParsePalette(input: unknown) {
  return paletteSchema.safeParse(input);
}
