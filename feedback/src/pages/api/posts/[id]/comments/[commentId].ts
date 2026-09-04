import type { APIRoute } from "astro";
import { deleteComment, isPostId } from "../../../../../lib/board";
import {
  clientIp,
  friendlyError,
  jsonError,
  requireUser,
  wantsJson,
} from "../../../../../lib/http";

// A user removes their own comment. reqtrack only matches a comment this
// same user wrote, so there is nothing to check here beyond who is asking.
const remove: APIRoute = async (context) => {
  const { params, request, redirect } = context;
  const json = wantsJson(request);
  const id = params.id;
  const commentId = params.commentId;
  if (!isPostId(id) || !isPostId(commentId)) {
    return json
      ? Response.json({ error: "not_found", message: "No such comment." }, { status: 404 })
      : redirect("/", 303);
  }

  const user = requireUser(context);
  if (user instanceof Response) return user;

  const postPath = `/p/${encodeURIComponent(id)}`;
  try {
    const result = await deleteComment(id, commentId, user.id, clientIp(context));
    if (json) return Response.json(result);
    return redirect(`${postPath}#comments`, 303);
  } catch (error) {
    if (json) return jsonError(error);
    return redirect(`${postPath}?error=${friendlyError(error).code}#comments`, 303);
  }
};

export const DELETE = remove;
export const POST = remove;
