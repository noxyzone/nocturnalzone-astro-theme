import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("bottom sheet styling", () => {
  it("uses an opaque panel background for readable mobile overlays", () => {
    const themeCss = readFileSync("src/theme/styles/theme.css", "utf8");
    const panelRule = themeCss.match(
      /\.nz-bottom-sheet__panel\s*\{(?<body>[^}]+)\}/,
    );

    expect(panelRule?.groups?.body).toContain(
      "background: var(--nz-bg-secondary);",
    );
  });
});
