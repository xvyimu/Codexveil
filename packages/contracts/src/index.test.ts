import { describe, expect, it } from "vitest";
import {
  parsePalette,
  parsePaletteWithSurface,
  safeParsePalette,
  parseDoctorSlice,
  parseControlError,
  isCssColor,
} from "./index.js";

describe("isCssColor", () => {
  it("accepts hex and functional colors", () => {
    expect(isCssColor("#0a0a0a")).toBe(true);
    expect(isCssColor("#abc")).toBe(true);
    expect(isCssColor("oklab(0.2 0 0)")).toBe(true);
  });
  it("rejects empty and injection-ish", () => {
    expect(isCssColor("")).toBe(false);
    expect(isCssColor("red;}")).toBe(false);
  });
});

describe("parsePalette", () => {
  it("accepts genshin-night-like palette", () => {
    const p = parsePalette({
      accent: "#E0B458",
      secondary: "#8a7a50",
      surface: "#0a0a0a",
      text: "#F0E6C8",
    });
    expect(p.surface).toBe("#0a0a0a");
  });

  it("allows partial palette (accent only) for legacy paths", () => {
    const p = parsePalette({ accent: "#E0B458" });
    expect(p.accent).toBe("#E0B458");
    expect(p.surface).toBeUndefined();
  });

  it("rejects illegal color", () => {
    const r = safeParsePalette({ surface: "not-a-color" });
    expect(r.success).toBe(false);
  });

  it("parsePaletteWithSurface requires surface", () => {
    expect(() => parsePaletteWithSurface({ accent: "#fff" })).toThrow(/surface/i);
    expect(
      parsePaletteWithSurface({ accent: "#fff", surface: "#111111" }).surface,
    ).toBe("#111111");
  });
});

describe("doctor slice", () => {
  it("parses control + freshness subset", () => {
    const d = parseDoctorSlice({
      control: { port: 9336, tokenPresent: true },
      injectorPathFreshness: { fresh: true, reason: "ok" },
      themeCount: 11,
      skippedThemeCount: 0,
      extraIgnored: true,
    });
    expect(d.control?.tokenPresent).toBe(true);
    expect(d.injectorPathFreshness?.fresh).toBe(true);
    expect(d.themeCount).toBe(11);
  });
});

describe("control error", () => {
  it("parses token-required body", () => {
    const e = parseControlError({
      ok: false,
      reason: "token-required",
      detail: "provide header x-codex-skin-token",
    });
    expect(e.reason).toBe("token-required");
  });
});
