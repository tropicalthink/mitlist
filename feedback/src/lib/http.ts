import type { APIContext } from "astro";
import { BoardError } from "./board";
import type { MitlistUser } from "./mitlist";

// The API routes serve two callers with one handler: the page's own script
// (JSON, no reload) and the plain HTML form it enhances (redirect back).
export function wantsJson(request: Request): boolean {
  const accept = request.headers.get("Accept") ?? "";
  const contentType = request.headers.get("Content-Type") ?? "";
  return accept.includes("application/json") || contentType.includes("application/json");
}

export async function readInput(request: Request): Promise<Record<string, string>> {
  const contentType = request.headers.get("Content-Type") ?? "";
  if (contentType.includes("application/json")) {
    const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;
    return Object.fromEntries(
      Object.entries(body).map(([key, value]) => [key, typeof value === "string" ? value : ""])
    );
  }
  const form = await request.formData().catch(() => new FormData());
  const out: Record<string, string> = {};
  for (const [key, value] of form.entries()) {
    if (typeof value === "string") out[key] = value;
  }
  return out;
}

export function clientIp(context: APIContext): string | null {
  const header = context.request.headers.get("CF-Connecting-IP");
  if (header) return header;
  try {
    return context.clientAddress;
  } catch {
    return null;
  }
}

/** Where a sign-in should come back to: the page the request came from. */
export function loginHref(next: string): string {
  return `/login?next=${encodeURIComponent(next)}`;
}

/**
 * The signed-in user, or the response that turns the caller away: 401 for
 * the page script, a bounce to sign-in for a plain form.
 */
export function requireUser(context: APIContext): MitlistUser | Response {
  const user = context.locals.user;
  if (user) return user;
  if (wantsJson(context.request)) {
    return Response.json(
      { error: "unauthorized", message: "Sign in with your mitlist account to do that." },
      { status: 401 }
    );
  }
  const referer = context.request.headers.get("Referer");
  let next = "/";
  if (referer) {
    try {
      const parsed = new URL(referer);
      if (parsed.origin === context.url.origin) next = parsed.pathname + parsed.search;
    } catch {
      // Not a URL we can go back to.
    }
  }
  return context.redirect(loginHref(next), 303);
}

/** A message a visitor can act on, for whatever went wrong upstream. */
export function friendlyError(error: unknown): { status: number; code: string; message: string } {
  if (error instanceof BoardError) {
    if (error.status === 429) {
      return {
        status: 429,
        code: "rate_limited",
        message: "That is a lot of activity at once. Give it a minute and try again.",
      };
    }
    if (error.status === 404) {
      return { status: 404, code: "not_found", message: "That is no longer on the board." };
    }
    if (error.status === 400) {
      return { status: 400, code: "invalid", message: error.message };
    }
    if (error.status === 503) {
      return {
        status: 503,
        code: "unavailable",
        message: "The board is not connected to the tracker yet. Try again later.",
      };
    }
  }
  console.error("board error", error);
  return {
    status: 502,
    code: "upstream_error",
    message: "The board could not be reached. Try again in a moment.",
  };
}

export function jsonError(error: unknown): Response {
  const friendly = friendlyError(error);
  return Response.json({ error: friendly.code, message: friendly.message }, { status: friendly.status });
}

export function withParam(path: string, key: string, value: string): string {
  const url = new URL(path, "https://feedback.mitlist.me");
  url.searchParams.set(key, value);
  return url.pathname + url.search + url.hash;
}
