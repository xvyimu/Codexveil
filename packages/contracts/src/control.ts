import { z } from "zod";

/** Align with packages/runtime/scripts/control-plane.mjs error bodies. */
export const controlErrorSchema = z
  .object({
    ok: z.literal(false),
    reason: z.string(),
    detail: z.string().optional(),
  })
  .passthrough();

export const controlOkSchema = z
  .object({
    ok: z.literal(true),
  })
  .passthrough();

export const controlHealthSchema = z
  .object({
    ok: z.boolean(),
    tokenPresent: z.boolean().optional(),
    tokenRequiredForMutations: z.boolean().optional(),
  })
  .passthrough();

export type ControlError = z.infer<typeof controlErrorSchema>;

export function parseControlError(input: unknown): ControlError {
  return controlErrorSchema.parse(input);
}
