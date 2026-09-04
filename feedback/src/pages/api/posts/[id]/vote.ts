import type { APIRoute } from "astro";
import { isPostId, upvote } from "../../../../lib/board";
import { clientIp, friendlyError, jsonError, wantsJson, withParam } from "../../../../lib/http";
import { ensureVoter } from "../../../../lib/voter";

// Forms can only POST, the page script sends PUT; both mean the same thing
// and both are idempotent per voter.
const vote: APIRoute = async (context) => {
  const { params, request, cookies, redirect, url } = context;
  const json = wantsJson(request);
  const id = params.id;
  if (!isPostId(id)) {
    return json
      ? Response.json({ error: "not_found", message: "No such post." }, { status: 404 })
      : redirect("/", 303);
  }

  const voterRef = ensureVoter(cookies, url.protocol === "https:");
  const back = safeReferer(request, url) ?? `/p/${encodeURIComponent(id)}`;

  try {
    const result = await upvote(id, voterRef, clientIp(context));
    if (json) return Response.json(result);
    // The page script reads ?voted= to remember this browser's vote.
    return redirect(withParam(back, "voted", id), 303);
  } catch (error) {
    if (json) return jsonError(error);
    return redirect(withParam(back, "error", friendlyError(error).code), 303);
  }
};

function safeReferer(request: Request, site: URL): string | null {
  const referer = request.headers.get("Referer");
  if (!referer) return null;
  try {
    const parsed = new URL(referer);
    if (parsed.origin !== site.origin) return null;
    parsed.searchParams.delete("voted");
    parsed.searchParams.delete("error");
    return parsed.pathname + parsed.search + parsed.hash;
  } catch {
    return null;
  }
}

export const POST = vote;
export const PUT = vote;
