// Drives a real Chrome window at phone size so the product screenshots in
// public/screenshots can be recaptured from the live web app.
//
//   npm i --no-save playwright-core
//   node scripts/capture-screenshots.mjs [light|dark] [phone|ipad]
//
// The window opens at 430×932 CSS px (phone, the size every landing capture
// uses) or 1032×1376 CSS px (ipad: at 2× that is the 2064×2752 App Store
// Connect wants for 13-inch iPad screenshots), with a 2× device scale factor
// and the requested colour scheme. Log in there
// by hand, then append commands to scripts/.capture/commands.txt, one per line:
//
//   goto https://app.mitlist.me/chores     navigate
//   click 140 230                          tap at CSS-pixel coordinates
//   wheel 215 600 400                      scroll the wheel at a point
//   type hello                             type text into the focused field
//   press Enter                            press a key
//   js localStorage.getItem("x")           evaluate in the page
//   shot chores                            write scripts/.capture/out/chores.png
//   quit
//
// Every processed command is echoed to scripts/.capture/log.txt. Convert the
// PNGs to webp (quality ~82) and drop them into public/screenshots as
// <name>.webp or <name>-dark.webp.
import { chromium } from "playwright-core";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scheme = process.argv[2] === "dark" ? "dark" : "light";
const size = process.argv[3] === "ipad"
  ? { width: 1032, height: 1376 }
  : { width: 430, height: 932 };
const here = path.dirname(fileURLToPath(import.meta.url));
const work = path.join(here, ".capture");
const out = path.join(work, "out");
const cmdFile = path.join(work, "commands.txt");
const logFile = path.join(work, "log.txt");
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(cmdFile, "");
fs.writeFileSync(logFile, "");
const log = (message) => fs.appendFileSync(logFile, `${new Date().toISOString()} ${message}\n`);

const context = await chromium.launchPersistentContext(path.join(work, "profile"), {
  channel: "chrome",
  headless: false,
  viewport: size,
  deviceScaleFactor: 2,
  colorScheme: scheme,
  hasTouch: true,
  args: [`--window-size=${size.width + 40},${size.height + 68}`, "--force-device-scale-factor=1"],
});
const page = context.pages()[0] ?? (await context.newPage());
await page.goto("https://app.mitlist.me/home", { waitUntil: "domcontentloaded" });
// The app follows the system scheme by default; pin it so a stored preference
// cannot override the emulated one.
await page.evaluate((mode) => localStorage.setItem("flutter.theme_mode", JSON.stringify(mode)), scheme);
log(`launched ${scheme} ${size.width}x${size.height} ${page.url()}`);

let done = 0;
for (;;) {
  const lines = fs.readFileSync(cmdFile, "utf8").split(/\r?\n/).filter(Boolean);
  if (lines.length > done) {
    const line = lines[done++];
    const [cmd, ...rest] = line.split(" ");
    const arg = rest.join(" ");
    try {
      if (cmd === "goto") { await page.goto(arg, { waitUntil: "domcontentloaded" }); log(`goto ${arg} -> ${page.url()}`); }
      else if (cmd === "shot") { const file = path.join(out, `${arg}.png`); await page.screenshot({ path: file, type: "png" }); log(`shot ${file}`); }
      else if (cmd === "js") { const result = await page.evaluate(arg); log(`js -> ${JSON.stringify(result)}`); }
      else if (cmd === "click") { const [x, y] = arg.split(" ").map(Number); await page.mouse.click(x, y); log(`click ${x},${y}`); }
      else if (cmd === "wheel") { const [x, y, dy] = arg.split(" ").map(Number); await page.mouse.move(x, y); await page.mouse.wheel(0, dy); log(`wheel ${dy}`); }
      else if (cmd === "type") { await page.keyboard.type(arg); log(`type (${arg.length} chars)`); }
      else if (cmd === "press") { await page.keyboard.press(arg); log(`press ${arg}`); }
      else if (cmd === "url") { log(`url ${page.url()}`); }
      else if (cmd === "quit") { log("quit"); await context.close(); process.exit(0); }
      else log(`unknown ${line}`);
    } catch (error) { log(`error ${line}: ${error.message}`); }
  }
  await new Promise((resolve) => setTimeout(resolve, 500));
}
