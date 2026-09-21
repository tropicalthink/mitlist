export const supportedLanguages = ["en", "de", "es", "fr", "nl"] as const;

export type SiteLanguage = (typeof supportedLanguages)[number];

export const languageNames: Record<SiteLanguage, string> = {
  en: "English",
  de: "Deutsch",
  es: "Español",
  fr: "Français",
  nl: "Nederlands",
};

export const site = {
  origin: "https://mitlist.me",
  appUrl: "https://app.mitlist.me",
  apiUrl: "https://api.mitlist.me/api/v1",
  mobileBetaPath: "/mobile-beta",
  playStoreUrl: "https://play.google.com/store/apps/details?id=me.mitlist",
  docsUrl: "https://docs.mitlist.me",
  statusUrl: "https://status.mitlist.me",
  feedbackUrl: "https://feedback.mitlist.me",
  repositoryUrl: "https://github.com/tropicalthink/mitlist",
  price: {
    freeMembers: 4,
    monthlyEuro: "3.99",
    yearlyEuro: "29.99",
  },
  contact: {
    general: "hi@mitlist.me",
    support: "support@mitlist.me",
    privacy: "privacy@mitlist.me",
    legal: "legal@mitlist.me",
    security: "security@mitlist.me",
  },
  analytics: {
    cloudflareToken: "cd937df3e2e24407a59ff8f4fe7d5fcf",
  },
} as const;

export function localizedPath(language: SiteLanguage, path = "") {
  const suffix = path && !path.startsWith("/") ? `/${path}` : path;
  return `/${language}${suffix || "/"}`;
}
