import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://example.com",
  output: "static",
  devToolbar: {
    enabled: false,
  },
  integrations: [],
});
