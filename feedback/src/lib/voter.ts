import type { AstroCookies } from "astro";

// Who is voting. The site has no accounts, so a visitor is a random id in a
// cookie, minted the first time they vote, post, or comment. reqtrack only
// ever stores a hash of it; it exists so a vote counts once per browser and a
// visitor can be shown which comments are theirs.
export const VOTER_COOKIE = "mitlist_feedback_voter";
const VOTER_PATTERN = /^web_[0-9a-f]{32}$/;
const ONE_YEAR = 60 * 60 * 24 * 365;

function mint(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return "web_" + Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function ensureVoter(cookies: AstroCookies, secure: boolean): string {
  const existing = cookies.get(VOTER_COOKIE)?.value;
  if (existing && VOTER_PATTERN.test(existing)) return existing;
  const voter = mint();
  cookies.set(VOTER_COOKIE, voter, {
    path: "/",
    httpOnly: true,
    sameSite: "lax",
    secure,
    maxAge: ONE_YEAR,
  });
  return voter;
}
