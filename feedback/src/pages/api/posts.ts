import type { APIRoute } from "astro";
import { createPost, type BoardKind } from "../../lib/board";
import { clientIp, jsonError, readInput, wantsJson } from "../../lib/http";
import { ensureVoter } from "../../lib/voter";

const TITLE_MAX = 200;
const DESCRIPTION_MAX = 5000;
const CONTACT_MAX = 255;

export const POST: APIRoute = async (context) => {
  const { request, cookies, redirect, url } = context;
  const json = wantsJson(request);
  const input = await readInput(request);

  // Honeypot. Bots fill every field; people never see this one. Pretend it
  // worked so the bot moves on, and send nothing upstream.
  if (input.website) {
    return json ? Response.json({ requestId: null }, { status: 201 }) : redirect("/", 303);
  }

  const title = (input.title ?? "").trim();
  const description = (input.description ?? "").trim();
  const kind: BoardKind = input.kind === "bug" ? "bug" : "feature";
  const contact = (input.contact ?? "").trim();

  const fail = (code: string, message: string) => {
    if (json) return Response.json({ error: code, message }, { status: 400 });
    const back = new URL("/new", url);
    back.searchParams.set("kind", kind);
    back.searchParams.set("error", code);
    return redirect(back.pathname + back.search, 303);
  };

  if (!title) return fail("title", "Give it a short title first.");
  if (title.length > TITLE_MAX) return fail("title_long", `Titles are at most ${TITLE_MAX} characters.`);
  if (description.length > DESCRIPTION_MAX) {
    return fail("description_long", `Descriptions are at most ${DESCRIPTION_MAX} characters.`);
  }
  if (contact && (contact.length > CONTACT_MAX || !contact.includes("@"))) {
    return fail("contact", "That email address does not look right.");
  }

  const voterRef = ensureVoter(cookies, url.protocol === "https:");

  try {
    const { requestId } = await createPost(
      {
        title,
        description: description || undefined,
        kind,
        voterRef,
        submitterContact: contact || undefined,
      },
      clientIp(context)
    );
    if (json) return Response.json({ requestId }, { status: 201 });
    return redirect(`/p/${encodeURIComponent(requestId)}?posted=1`, 303);
  } catch (error) {
    if (json) return jsonError(error);
    const back = new URL("/new", url);
    back.searchParams.set("kind", kind);
    back.searchParams.set("error", "upstream");
    return redirect(back.pathname + back.search, 303);
  }
};
