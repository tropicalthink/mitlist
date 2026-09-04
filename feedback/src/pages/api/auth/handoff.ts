import type { APIRoute } from "astro";
import { exchangeHandoff, MitlistError } from "../../../lib/mitlist";
import { readInput } from "../../../lib/http";
import { takeNext, writeSession } from "../../../lib/session";

// The end of a Google or Apple sign-in. mitlist sends the browser back to
// /auth/callback with a one-time handoff code; that page posts it here, and
// this turns it into a session. Codes are single-use, so a replay fails.
export const POST: APIRoute = async (context) => {
  const { request, cookies, redirect, url } = context;
  const input = await readInput(request);
  const code = (input.code ?? "").trim();
  const next = takeNext(cookies);

  if (!code) return redirect("/login?error=oauth", 303);

  try {
    const { tokens } = await exchangeHandoff(code);
    writeSession(cookies, tokens, url.protocol === "https:");
  } catch (error) {
    if (!(error instanceof MitlistError)) console.error("handoff failed", error);
    return redirect(`/login?error=oauth&next=${encodeURIComponent(next)}`, 303);
  }
  return redirect(next, 303);
};
