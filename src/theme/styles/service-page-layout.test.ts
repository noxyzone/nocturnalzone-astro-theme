import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("service page layout", () => {
  it("lets page intros use the same available width as the pricing table", () => {
    const themeCss = readFileSync("src/theme/styles/theme.css", "utf8");

    expect(themeCss).toMatch(/\.nz-page-intro\s*\{[^}]*max-width:\s*100%/s);
  });
});
