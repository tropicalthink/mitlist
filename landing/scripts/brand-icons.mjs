// Renders the header brand mark (SiteHeader.astro .brand__mark) into every
// icon the project ships: landing favicon/apple-touch-icon, Flutter launcher
// sources (assets/icon), and store upload PNGs (store/icons).
//
//   cd landing && node scripts/brand-icons.mjs
//   cd ../frontend && dart run flutter_launcher_icons
import sharp from "sharp";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const ORANGE = "#f97316";
const INK = "#1a1714";

// The check-list glyph from the header, 24-unit box, stroked in ink.
const GLYPH_PATHS =
  '<path d="M4 7.5l3 3 6-6.5"/><path d="M4 14.5l3 3 6-6.5"/>' +
  '<line x1="15" y1="6" x2="21" y2="6"/><line x1="15" y1="16" x2="21" y2="16"/>';

/**
 * @param {object} o
 * @param {number} o.size      canvas size in px
 * @param {number} o.glyph     glyph box as fraction of canvas (header: 20/38)
 * @param {boolean} o.border   draw the 2px-style ink border like the header
 * @param {boolean} o.fill     paint the orange square (false = transparent)
 */
function markSvg({ size, glyph = 20 / 38, border = false, fill = true }) {
  const g = size * glyph;
  const off = (size - g) / 2;
  const scale = g / 24;
  const bw = size * (2 / 38); // header border is 2px on a 38px tile
  const rect = fill
    ? `<rect width="${size}" height="${size}" fill="${ORANGE}"/>` +
      (border
        ? `<rect x="${bw / 2}" y="${bw / 2}" width="${size - bw}" height="${size - bw}" fill="none" stroke="${INK}" stroke-width="${bw}"/>`
        : "")
    : "";
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">` +
    rect +
    `<g transform="translate(${off} ${off}) scale(${scale})" fill="none" stroke="${INK}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">${GLYPH_PATHS}</g>` +
    `</svg>`
  );
}

const png = (svg, size) =>
  sharp(Buffer.from(svg), { density: 384 }).resize(size, size).png().toBuffer();

async function write(rel, buf) {
  const file = path.join(root, rel);
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, buf);
  console.log("wrote", rel);
}

// ---- Landing favicon (matches the header tile exactly, border included) ----
await write("landing/public/favicon.svg", markSvg({ size: 38, border: true }) + "\n");
await write("landing/public/apple-touch-icon.png", await png(markSvg({ size: 180 }), 180));

// favicon.ico: 16/32/48 PNG-in-ICO
const icoSizes = [16, 32, 48];
const icoPngs = await Promise.all(icoSizes.map((s) => png(markSvg({ size: s, border: true }), s)));
await write("landing/public/favicon.ico", buildIco(icoSizes, icoPngs));

// ---- Flutter launcher sources (flutter_launcher_icons reads these) ----
// Full-bleed orange, no border: iOS/Android/PWA mask their own corners.
await write("frontend/assets/icon/icon.png", await png(markSvg({ size: 1024 }), 1024));
// Adaptive foreground: transparent, glyph kept inside the 66% safe zone.
await write("frontend/assets/icon/icon_foreground.png", await png(markSvg({ size: 1024, glyph: 0.4, fill: false }), 1024));

// ---- Store uploads ----
await write("store/icons/app-store-1024.png", await png(markSvg({ size: 1024 }), 1024));
await write("store/icons/google-play-512.png", await png(markSvg({ size: 512 }), 512));
await write("store/icons/icon-bordered-1024.png", await png(markSvg({ size: 1024, border: true }), 1024));
await write("store/icons/icon.svg", markSvg({ size: 1024 }) + "\n");

function buildIco(sizes, pngs) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(sizes.length, 4);
  const dirs = [];
  let offset = 6 + 16 * sizes.length;
  sizes.forEach((s, i) => {
    const d = Buffer.alloc(16);
    d.writeUInt8(s === 256 ? 0 : s, 0); d.writeUInt8(s === 256 ? 0 : s, 1);
    d.writeUInt8(0, 2); d.writeUInt8(0, 3);
    d.writeUInt16LE(1, 4); d.writeUInt16LE(32, 6);
    d.writeUInt32LE(pngs[i].length, 8); d.writeUInt32LE(offset, 12);
    offset += pngs[i].length;
    dirs.push(d);
  });
  return Buffer.concat([header, ...dirs, ...pngs]);
}
