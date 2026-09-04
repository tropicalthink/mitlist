import { env } from "cloudflare:workers";

// The public feedback board is a thin window onto mitlist's board in reqtrack
// (Staffroom). Everything here runs on the server; the browser never sees the
// app key or talks to reqtrack directly.
//
// A visitor's identity on the board is their mitlist user id, the same
// voterRef the app sends, so votes and comments are shared between the two.
// Reads for a signed-in user carry that id and are not cached, so hasVoted
// and isMine are exact; anonymous reads are cached and shared.

export type BoardStatus = "new" | "in_progress" | "done";
export type BoardKind = "feature" | "bug";
export type BoardSort = "top" | "new";

export interface BoardPost {
  id: string;
  title: string;
  description: string | null;
  status: BoardStatus;
  kind: BoardKind;
  voteCount: number;
  hasVoted: boolean;
  commentCount: number;
  createdAt: number;
  updatedAt: number;
}

export interface BoardComment {
  id: string;
  body: string;
  authorKind: "customer" | "staff";
  authorName: string | null;
  isMine: boolean;
  createdAt: number;
}

export interface BoardPostDetail extends BoardPost {
  comments: BoardComment[];
}

export interface BoardUpdate {
  id: string;
  title: string;
  description: string | null;
  kind: BoardKind;
  release: string | null;
  shippedAt: number;
  voteCount: number;
  commentCount: number;
  staffNote: string | null;
}

export interface VoteResult {
  requestId: string;
  voteCount: number;
  hasVoted: boolean;
}

export class BoardError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = "BoardError";
  }
}

const BOARD_PATH = "/api/v1/intake/board";
const DEFAULT_URL = "https://reqtrack.tropicalthink.com";
// How long an anonymous read is reused before asking reqtrack again. Writes
// evict the entries they change.
const CACHE_SECONDS = 30;

function config() {
  const key = env.REQTRACK_APP_KEY;
  if (!key) {
    throw new BoardError(503, "not_configured", "REQTRACK_APP_KEY is not set on this Worker");
  }
  const base = (env.REQTRACK_URL || DEFAULT_URL).replace(/\/+$/, "");
  return { key, base };
}

interface CallOptions {
  method?: "GET" | "POST" | "PUT" | "DELETE";
  body?: unknown;
  voterRef?: string;
  clientIp?: string | null;
}

async function call<T>(path: string, opts: CallOptions = {}): Promise<T> {
  const { key, base } = config();
  const headers = new Headers({ "X-App-Key": key, Accept: "application/json" });
  if (opts.body !== undefined) headers.set("Content-Type", "application/json");
  if (opts.voterRef) headers.set("X-Submitter-Ref", opts.voterRef);
  // reqtrack rate-limits per visitor address. Over the service binding the
  // header we set is the one it reads; over the public internet Cloudflare
  // replaces it with this Worker's own address and every visitor would share
  // one bucket, which is why anonymous reads are cached below.
  if (opts.clientIp) headers.set("CF-Connecting-IP", opts.clientIp);

  const request = new Request(`${base}${BOARD_PATH}${path}`, {
    method: opts.method ?? "GET",
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });

  // Locally there is no reqtrack-api to bind to: `astro dev` goes straight
  // to REQTRACK_URL, and `wrangler dev` does the same when REQTRACK_DIRECT is
  // set in .dev.vars.
  const direct = import.meta.env.DEV || env.REQTRACK_DIRECT === "1" || !env.REQTRACK;
  const response = direct ? await fetch(request) : await env.REQTRACK.fetch(request);

  if (!response.ok) {
    let code = "upstream_error";
    let message = `reqtrack responded ${response.status}`;
    try {
      const body = (await response.json()) as { error?: string; message?: string };
      code = body.error ?? code;
      message = body.message ?? message;
    } catch {
      // A non-JSON error body (a Cloudflare error page, say) keeps the default.
    }
    throw new BoardError(response.status, code, message);
  }
  return (await response.json()) as T;
}

// --- Read cache (anonymous reads only) ------------------------------------

function cacheKey(path: string): Request {
  // The host is a label, not a destination: cache keys only need to be URLs.
  return new Request(`https://board-cache.mitlist.internal${BOARD_PATH}${path}`);
}

function openCache(): Cache | null {
  try {
    const store = (globalThis as { caches?: { default?: Cache } }).caches;
    return store?.default ?? null;
  } catch {
    return null;
  }
}

async function cached<T>(path: string, load: () => Promise<T>): Promise<T> {
  const cache = openCache();
  if (!cache) return load();
  const key = cacheKey(path);
  try {
    const hit = await cache.match(key);
    if (hit) return (await hit.json()) as T;
  } catch {
    // A cache read failure just means a fresh read.
  }
  const value = await load();
  try {
    await cache.put(
      key,
      new Response(JSON.stringify(value), {
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": `public, max-age=${CACHE_SECONDS}`,
        },
      })
    );
  } catch {
    // Not being able to cache is not an error the visitor should see.
  }
  return value;
}

async function forget(paths: string[]): Promise<void> {
  const cache = openCache();
  if (!cache) return;
  await Promise.all(
    paths.map((path) =>
      cache.delete(cacheKey(path)).catch(() => {
        // Stale for at most CACHE_SECONDS.
      })
    )
  );
}

const LIST_PATH = "/requests?sort=new";
const UPDATES_PATH = "/updates";
const detailPath = (id: string) => `/requests/${encodeURIComponent(id)}`;

// --- Reads ---------------------------------------------------------------

/** Every post on the board, newest first. Sort and filter locally so one
 * upstream read serves every view of the list. */
export async function listPosts(voterRef?: string): Promise<BoardPost[]> {
  const load = () => call<{ items: BoardPost[] }>(LIST_PATH, { voterRef });
  const { items } = voterRef ? await load() : await cached(LIST_PATH, load);
  return items;
}

export function sortPosts(posts: BoardPost[], sort: BoardSort): BoardPost[] {
  const sorted = [...posts];
  if (sort === "top") {
    sorted.sort((a, b) => b.voteCount - a.voteCount || b.createdAt - a.createdAt);
  } else {
    sorted.sort((a, b) => b.createdAt - a.createdAt);
  }
  return sorted;
}

export async function getPost(id: string, voterRef?: string): Promise<BoardPostDetail> {
  const load = () => call<BoardPostDetail>(detailPath(id), { voterRef });
  return voterRef ? load() : cached(detailPath(id), load);
}

/** What shipped, most recent first. Falls back to the plain list when the
 * tracker predates the updates endpoint, so the page never goes blank. */
export async function listUpdates(): Promise<BoardUpdate[]> {
  try {
    const { items } = await cached(UPDATES_PATH, () =>
      call<{ items: BoardUpdate[] }>(UPDATES_PATH)
    );
    return items;
  } catch (error) {
    // A tracker without the endpoint falls through to its Access-protected
    // admin routes, so the miss shows up as 401, not only 404.
    if (!(error instanceof BoardError) || (error.status !== 404 && error.status !== 401)) {
      throw error;
    }
    const posts = await listPosts();
    return posts
      .filter((post) => post.status === "done")
      .sort((a, b) => b.updatedAt - a.updatedAt)
      .map((post) => ({
        id: post.id,
        title: post.title,
        description: post.description,
        kind: post.kind,
        release: null,
        shippedAt: post.updatedAt,
        voteCount: post.voteCount,
        commentCount: post.commentCount,
        staffNote: null,
      }));
  }
}

// --- Writes --------------------------------------------------------------

export interface NewPost {
  title: string;
  description?: string;
  kind: BoardKind;
  voterRef: string;
  submitterContact?: string;
}

export async function createPost(
  input: NewPost,
  clientIp: string | null
): Promise<{ requestId: string }> {
  const result = await call<{ requestId: string }>("/requests", {
    method: "POST",
    clientIp,
    body: {
      title: input.title,
      description: input.description,
      kind: input.kind,
      voterRef: input.voterRef,
      submitterContact: input.submitterContact,
      sourcePage: "feedback.mitlist.me/new",
      metadata: { platform: "web", source: "feedback.mitlist.me" },
    },
  });
  await forget([LIST_PATH, UPDATES_PATH]);
  return result;
}

export async function upvote(id: string, voterRef: string, clientIp: string | null): Promise<VoteResult> {
  const result = await call<VoteResult>(`${detailPath(id)}/upvote`, {
    method: "PUT",
    clientIp,
    body: { voterRef },
  });
  await forget([LIST_PATH, UPDATES_PATH, detailPath(id)]);
  return result;
}

export async function removeVote(
  id: string,
  voterRef: string,
  clientIp: string | null
): Promise<VoteResult> {
  const result = await call<VoteResult>(`${detailPath(id)}/upvote`, {
    method: "DELETE",
    clientIp,
    body: { voterRef },
  });
  await forget([LIST_PATH, UPDATES_PATH, detailPath(id)]);
  return result;
}

export async function addComment(
  id: string,
  input: { body: string; voterRef: string; authorName?: string },
  clientIp: string | null
): Promise<BoardComment> {
  const result = await call<BoardComment>(`${detailPath(id)}/comments`, {
    method: "POST",
    clientIp,
    body: input,
  });
  await forget([LIST_PATH, detailPath(id)]);
  return result;
}

export async function deleteComment(
  id: string,
  commentId: string,
  voterRef: string,
  clientIp: string | null
): Promise<{ deleted: true }> {
  const result = await call<{ deleted: true }>(
    `${detailPath(id)}/comments/${encodeURIComponent(commentId)}`,
    { method: "DELETE", clientIp, body: { voterRef } }
  );
  await forget([LIST_PATH, detailPath(id)]);
  return result;
}

/** Board ids are reqtrack ids: short, url-safe, no lookalikes to guard. */
export function isPostId(value: string | undefined): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{4,64}$/.test(value);
}
