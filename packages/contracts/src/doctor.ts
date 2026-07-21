import { z } from "zod";

/** Subset of doctor JSON used by shells / freshness gates (ADR 0004). */
export const doctorControlSchema = z
  .object({
    port: z.number().int().positive().nullable().optional(),
    tokenPresent: z.boolean(),
  })
  .strict();

export const doctorFreshnessSchema = z
  .object({
    fresh: z.boolean(),
    reason: z.string().optional(),
    expectedRuntimeId: z.string().nullable().optional(),
    actualRuntimeId: z.string().nullable().optional(),
  })
  .passthrough();

export const doctorSliceSchema = z
  .object({
    control: doctorControlSchema.optional(),
    injectorPathFreshness: doctorFreshnessSchema.optional(),
    themeCount: z.number().int().nonnegative().optional(),
    skippedThemeCount: z.number().int().nonnegative().optional(),
  })
  .passthrough();

export type DoctorSlice = z.infer<typeof doctorSliceSchema>;

export function parseDoctorSlice(input: unknown): DoctorSlice {
  return doctorSliceSchema.parse(input);
}

export function assertDoctorSlice(input: unknown): DoctorSlice {
  return parseDoctorSlice(input);
}
