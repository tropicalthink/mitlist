import { readFile } from "node:fs/promises";

const homePage = await readFile(new URL("../src/components/HomePage.astro", import.meta.url), "utf8");

if (homePage.includes("data-launch-placeholder")) {
  console.error("Official launch blocked: replace every screenshot marked data-launch-placeholder.");
  process.exitCode = 1;
} else {
  console.log("Official launch check passed: no screenshot placeholders remain.");
}
