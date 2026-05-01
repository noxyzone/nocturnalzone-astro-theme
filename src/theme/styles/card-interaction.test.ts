import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("card interaction styling", () => {
  it("does not add hover affordance to non-clickable cards", () => {
    const themeCss = readFileSync("src/theme/styles/theme.css", "utf8");

    expect(themeCss).not.toMatch(/\.nz-card:hover/);
  });
});
