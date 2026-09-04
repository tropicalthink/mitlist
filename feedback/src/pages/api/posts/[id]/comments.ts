import type { APIRoute } from "astro";
import { addComment, isPostId } from "../../../../lib/board";
import { clientIp, friendlyError, jsonError, readInput, wantsJson } from "../../../../lib/http";
import { ensureVoter } from "../../../../lib/voter";

const BODY_MAX = 2000;
const NAME_MAX = 80;

export const POST: APIRoute = async (context) => {
  const { params, request, cookies, redirect, url } = context;
  const json = wantsJson(request);
  const id = params.id;
  if (!isPostId(id)) {
    return json
      ? Response.json({ error: "not_found", message: "No such post." }, { status: 404 })
      : redirect("/", 303);
  }
  const postPath = `/p/${encodeURIComponent(id)}`;
  const input = await readInput(request);

  if (input.website) {
    return json ? Response.json({ id: null }, { status: 201 }) : redirect(postPath, 303);
  }

  const body = (input.body ?? "").trim();
  const authorName = (input.name ?? "").trim().slice(0, NAME_MAX);

  const fail = (code: string, message: string) =>
    json
      ? Response.json({ error: code, message }, { status: 400 })
      : redirect(`${postPath}?error=${code}#comments`, 303);

  if (!body) return fail("empty", "Write something first.");
  if (body.length > BODY_MAX) return fail("long", `Comments are at most ${BODY_MAX} characters.`);

  const voterRef = ensureVoter(cookies, url.protocol === "https:");

  try {
    const comment = await addComment(
      id,
      { body, voterRef, authorName: authorName || undefined },
      clientIp(context)
    );
    if (json) return Response.json(comment, { status: 201 });
    // ?c= lets the page script remember which comment is this browser's.
    return redirect(`${postPath}?c=${encodeURIComponent(comment.id)}#comments`, 303);
  } catch (error) {
    if (json) return jsonError(error);
    return redirect(`${postPath}?error=${friendlyError(error).code}#comments`, 303);
  }
};
