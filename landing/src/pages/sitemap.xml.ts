import { supportedLanguages, site } from "../data/site";

export function GET() {
  const fixed = [
    "/",
    "/mobile-beta",
    "/hosting",
    "/transparency",
    "/security",
    "/terms",
    "/privacy",
    "/agb",
    "/datenschutz",
    "/impressum",
  ];
  const localized = supportedLanguages.flatMap((language) => [
    `/${language}/`,
    `/${language}/mobile-beta`,
  ]);
  const urls = [...fixed, ...localized]
    .map((path) => `<url><loc>${new URL(path, site.origin)}</loc></url>`)
    .join("");
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`,
    { headers: { "Content-Type": "application/xml; charset=utf-8" } },
  );
}
