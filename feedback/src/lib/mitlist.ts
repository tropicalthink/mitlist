import { env } from "cloudflare:workers";

// The mitlist backend, used only for sign-in. The board itself lives in
// reqtrack; mitlist is who you are. Same account, same user id, as the app,
// so a vote cast here and a vote cast in the app are the same vote.

export interface MitlistUser {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  isGuest: boolean;
}

export interface TokenPair {
  access: string;
  refresh: string;
}

export interface Providers {
  google: boolean;
  apple: boolean;
  password: boolean;
}

export class MitlistError extends Error {
  constructor(
    public readonly status: number,
    message: string
  ) {
    super(message);
    this.name = "MitlistError";
  }
}

const DEFAULT_API = "https://api.mitlist.me/api/v1";
const PROVIDERS_CACHE_SECONDS = 300;

export function apiBase(): string {
  return (env.MITLIST_API_URL || DEFAULT_API).replace(/\/+$/, "");
}

interface CallOptions {
  method?: "GET" | "POST";
  body?: unknown;
  token?: string;
}

async function call<T>(path: string, opts: CallOptions = {}): Promise<T> {
  const headers = new Headers({ Accept: "application/json" });
  if (opts.body !== undefined) headers.set("Content-Type", "application/json");
  if (opts.token) headers.set("Authorization", `Bearer ${opts.token}`);

  const method = opts.method ?? "GET";
  const init = {
    method,
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  };
  let response: Response;
  try {
    response = await fetch(`${apiBase()}${path}`, init);
  } catch (error) {
    // A dropped connection on a read is worth one more try; a write is not,
    // since it may already have happened.
    if (method !== "GET") throw error;
    response = await fetch(`${apiBase()}${path}`, init);
  }

  if (!response.ok) {
    let message = `mitlist responded ${response.status}`;
    try {
      const body = (await response.json()) as { message?: string; error?: string };
      message = body.message ?? body.error ?? message;
    } catch {
      // Keep the status-based message.
    }
    throw new MitlistError(response.status, message);
  }
  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

interface RawUser {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  is_guest: boolean;
}

interface RawTokens {
  user?: RawUser;
  access_token: string;
  refresh_token: string;
}

function toUser(raw: RawUser): MitlistUser {
  return {
    id: raw.id,
    email: raw.email,
    firstName: raw.first_name ?? "",
    lastName: raw.last_name ?? "",
    isGuest: Boolean(raw.is_guest),
  };
}

function toTokens(raw: RawTokens): TokenPair {
  return { access: raw.access_token, refresh: raw.refresh_token };
}

/** Which sign-in doors the server has open. Cached: it changes with deploys, not visits. */
export async function providers(): Promise<Providers> {
  const cache = openCache();
  const key = new Request(`${apiBase()}/oauth/providers`);
  if (cache) {
    try {
      const hit = await cache.match(key);
      if (hit) return (await hit.json()) as Providers;
    } catch {
      // Fall through to a live read.
    }
  }
  const raw = await call<Partial<Providers>>("/oauth/providers");
  const value: Providers = {
    google: Boolean(raw.google),
    apple: Boolean(raw.apple),
    password: Boolean(raw.password),
  };
  if (cache) {
    try {
      await cache.put(
        key,
        new Response(JSON.stringify(value), {
          headers: {
            "Content-Type": "application/json",
            "Cache-Control": `public, max-age=${PROVIDERS_CACHE_SECONDS}`,
          },
        })
      );
    } catch {
      // Not cached this time.
    }
  }
  return value;
}

export async function login(
  email: string,
  password: string
): Promise<{ user: MitlistUser | null; tokens: TokenPair }> {
  const raw = await call<RawTokens>("/auth/login", { method: "POST", body: { email, password } });
  return { user: raw.user ? toUser(raw.user) : null, tokens: toTokens(raw) };
}

/** Turn the one-time code the backend appends to our OAuth callback into a session. */
export async function exchangeHandoff(
  code: string
): Promise<{ user: MitlistUser | null; tokens: TokenPair }> {
  const raw = await call<RawTokens>("/oauth/handoff/exchange", { method: "POST", body: { code } });
  return { user: raw.user ? toUser(raw.user) : null, tokens: toTokens(raw) };
}

/** Rotates the pair: the old refresh token is dead after this. */
export async function refresh(refreshToken: string): Promise<TokenPair> {
  const raw = await call<RawTokens>("/auth/token/refresh", {
    method: "POST",
    body: { refresh_token: refreshToken },
  });
  return toTokens(raw);
}

export async function me(accessToken: string): Promise<MitlistUser> {
  return toUser(await call<RawUser>("/auth/me", { token: accessToken }));
}

export async function logout(tokens: TokenPair): Promise<void> {
  await call<void>("/auth/logout", {
    method: "POST",
    token: tokens.access,
    body: { refresh_token: tokens.refresh },
  });
}

/** Where to send the browser to start a Google or Apple sign-in. */
export function oauthStartUrl(provider: "google" | "apple", callbackUrl: string): string {
  const url = new URL(`${apiBase()}/oauth/${provider}`);
  url.searchParams.set("redirect_uri", callbackUrl);
  return url.toString();
}

function openCache(): Cache | null {
  try {
    const store = (globalThis as { caches?: { default?: Cache } }).caches;
    return store?.default ?? null;
  } catch {
    return null;
  }
}
