// @ts-check
import { defineConfig } from "astro/config";
import cloudflare from "@astrojs/cloudflare";

// Every page reads the live board from reqtrack, so nothing is prerendered.
// The app key stays a Worker secret: the browser only ever talks to this site.
export default defineConfig({
  site: "https://feedback.mitlist.me",
  output: "server",
  adapter: cloudflare({ imageService: "passthrough" }),
  session: false,
});
