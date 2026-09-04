import type { AstroCookies } from "astro";
import { MitlistError, me, refresh, type MitlistUser, type TokenPair } from "./mitlist";

// A signed-in visitor is a mitlist token pair in an HttpOnly cookie on this
// origin. The browser never sees the tokens and never talks to mitlist; every
// page resolves the cookie to a user server-side before rendering.

export const SESSION_COOKIE = "mitlist_feedback_session";
export const NEXT_COOKIE = "mitlist_feedback_next";
const SESSION_DAYS = 30;
// /auth/me answers are reused this long per access token. Access tokens live
// fifteen minutes, so a revoked session lingers here for at most five.
const ME_CACHE_SECONDS = 300;
// Refresh a little before expiry so a request never fails mid-flight.
const EXPIRY_SLACK_SECONDS = 30;

export interface Session extends TokenPair {}

export function readSession(cookies: AstroCookies): Session | null {
  const raw = cookies.get(SESSION_COOKIE)?.value;
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as { a?: unknown; r?: unknown };
    if (typeof parsed.a === "string" && typeof parsed.r === "string" && parsed.a && parsed.r) {
      return { access: parsed.a, refresh: parsed.r };
    }
  } catch {
    // A cookie we did not write.
  }
  return null;
}

export function writeSession(cookies: AstroCookies, session: Session, secure: boolean): void {
  cookies.set(SESSION_COOKIE, JSON.stringify({ a: session.access, r: session.refresh }), {
    path: "/",
    httpOnly: true,
    sameSite: "lax",
    secure,
    maxAge: 60 * 60 * 24 * SESSION_DAYS,
  });
}

export function clearSession(cookies: AstroCookies): void {
  cookies.delete(SESSION_COOKIE, { path: "/" });
}

/** Only ever an on-site path, so a login link cannot bounce people elsewhere. */
export function safeNext(value: string | null | undefined): string {
  if (!value || !value.startsWith("/") || value.startsWith("//") || value.startsWith("/\\")) {
    return "/";
  }
  return value;
}

export function rememberNext(cookies: AstroCookies, next: string, secure: boolean): void {
  cookies.set(NEXT_COOKIE, safeNext(next), {
    path: "/",
    httpOnly: true,
    sameSite: "lax",
    secure,
    maxAge: 600,
  });
}

export function takeNext(cookies: AstroCookies): string {
  const next = safeNext(cookies.get(NEXT_COOKIE)?.value);
  cookies.delete(NEXT_COOKIE, { path: "/" });
  return next;
}

function jwtExpiresAt(token: string): number | null {
  const parts = token.split(".");
  if (parts.length !== 3 || !parts[1]) return null;
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = atob(payload.padEnd(payload.length + ((4 - (payload.length % 4)) % 4), "="));
    const claims = JSON.parse(json) as { exp?: unknown };
    return typeof claims.exp === "number" ? claims.exp * 1000 : null;
  } catch {
    return null;
  }
}

async function tokenKey(token: string): Promise<Request> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  const hex = Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
  return new Request(`https://session-cache.mitlist.internal/me/${hex}`);
}

function openCache(): Cache | null {
  try {
    const store = (globalThis as { caches?: { default?: Cache } }).caches;
    return store?.default ?? null;
  } catch {
    return null;
  }
}

async function cachedMe(access: string): Promise<MitlistUser> {
  const cache = openCache();
  const key = cache ? await tokenKey(access) : null;
  if (cache && key) {
    try {
      const hit = await cache.match(key);
      if (hit) return (await hit.json()) as MitlistUser;
    } catch {
      // Ask mitlist instead.
    }
  }
  const user = await me(access);
  if (cache && key) {
    try {
      await cache.put(
        key,
        new Response(JSON.stringify(user), {
          headers: {
            "Content-Type": "application/json",
            "Cache-Control": `public, max-age=${ME_CACHE_SECONDS}`,
          },
        })
      );
    } catch {
      // Fine: the next request asks again.
    }
  }
  return user;
}

/**
 * Who this request is, or null. Rotates the token pair when the access token
 * is about to expire, and drops the cookie when mitlist no longer honours it,
 * so a signed-out or deleted account silently becomes a visitor.
 */
export async function resolveUser(
  cookies: AstroCookies,
  secure: boolean
): Promise<{ user: MitlistUser; session: Session } | null> {
  let session = readSession(cookies);
  if (!session) return null;

  const expiresAt = jwtExpiresAt(session.access);
  const stale = expiresAt === null || expiresAt - Date.now() < EXPIRY_SLACK_SECONDS * 1000;

  const rotate = async (): Promise<boolean> => {
    try {
      session = await refresh(session!.refresh);
      writeSession(cookies, session, secure);
      return true;
    } catch {
      clearSession(cookies);
      return false;
    }
  };

  if (stale && !(await rotate())) return null;

  try {
    const user = await cachedMe(session.access);
    return { user, session };
  } catch (error) {
    if (error instanceof MitlistError && error.status === 401) {
      if (!(await rotate())) return null;
      try {
        const user = await cachedMe(session.access);
        return { user, session };
      } catch {
        clearSession(cookies);
        return null;
      }
    }
    // mitlist is unreachable: treat the visitor as signed out for this
    // request rather than failing the page. The cookie stays for next time.
    console.error("session resolve failed", error);
    return null;
  }
}
