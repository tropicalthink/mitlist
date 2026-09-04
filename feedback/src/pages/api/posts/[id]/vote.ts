import type { APIRoute } from "astro";
import { isPostId, removeVote, upvote } from "../../../../lib/board";
import {
  clientIp,
  friendlyError,
  jsonError,
  readInput,
  requireUser,
  wantsJson,
  withParam,
} from "../../../../lib/http";

// One handler, three spellings: the page script sends PUT to add and DELETE
// to take back; the plain form POSTs with intent=add|remove. All idempotent.
async function handle(context: Parameters<APIRoute>[0], remove: boolean): Promise<Response> {
  const { params, request, redirect, url } = context;
  const json = wantsJson(request);
  const id = params.id;
  if (!isPostId(id)) {
    return json
      ? Response.json({ error: "not_found", message: "No such post." }, { status: 404 })
      : redirect("/", 303);
  }

  const user = requireUser(context);
  if (user instanceof Response) return user;

  const back = safeReferer(request, url) ?? `/p/${encodeURIComponent(id)}`;

  try {
    const result = remove
      ? await removeVote(id, user.id, clientIp(context))
      : await upvote(id, user.id, clientIp(context));
    if (json) return Response.json(result);
    return redirect(back, 303);
  } catch (error) {
    if (json) return jsonError(error);
    return redirect(withParam(back, "error", friendlyError(error).code), 303);
  }
}

export const PUT: APIRoute = (context) => handle(context, false);
export const DELETE: APIRoute = (context) => handle(context, true);
export const POST: APIRoute = async (context) => {
  // handle() never reads the body itself, so consuming it here is fine.
  const input = await readInput(context.request);
  return handle(context, input.intent === "remove");
};

function safeReferer(request: Request, site: URL): string | null {
  const referer = request.headers.get("Referer");
  if (!referer) return null;
  try {
    const parsed = new URL(referer);
    if (parsed.origin !== site.origin) return null;
    parsed.searchParams.delete("error");
    return parsed.pathname + parsed.search + parsed.hash;
  } catch {
    return null;
  }
}
