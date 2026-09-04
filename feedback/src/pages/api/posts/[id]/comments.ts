import type { APIRoute } from "astro";
import { addComment, isPostId } from "../../../../lib/board";
import {
  clientIp,
  friendlyError,
  jsonError,
  readInput,
  requireUser,
  wantsJson,
} from "../../../../lib/http";

const BODY_MAX = 2000;

export const POST: APIRoute = async (context) => {
  const { params, request, redirect } = context;
  const json = wantsJson(request);
  const id = params.id;
  if (!isPostId(id)) {
    return json
      ? Response.json({ error: "not_found", message: "No such post." }, { status: 404 })
      : redirect("/", 303);
  }

  const user = requireUser(context);
  if (user instanceof Response) return user;

  const postPath = `/p/${encodeURIComponent(id)}`;
  const input = await readInput(request);

  if (input.website) {
    return json ? Response.json({ id: null }, { status: 201 }) : redirect(postPath, 303);
  }

  const body = (input.body ?? "").trim();

  const fail = (code: string, message: string) =>
    json
      ? Response.json({ error: code, message }, { status: 400 })
      : redirect(`${postPath}?error=${code}#comments`, 303);

  if (!body) return fail("empty", "Write something first.");
  if (body.length > BODY_MAX) return fail("long", `Comments are at most ${BODY_MAX} characters.`);

  try {
    const comment = await addComment(
      id,
      { body, voterRef: user.id, authorName: user.firstName.trim() || undefined },
      clientIp(context)
    );
    if (json) return Response.json(comment, { status: 201 });
    return redirect(`${postPath}#comments`, 303);
  } catch (error) {
    if (json) return jsonError(error);
    return redirect(`${postPath}?error=${friendlyError(error).code}#comments`, 303);
  }
};
