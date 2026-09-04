import type { APIRoute } from "astro";
import { login, MitlistError } from "../../../lib/mitlist";
import { readInput, wantsJson } from "../../../lib/http";
import { safeNext, writeSession } from "../../../lib/session";

export const POST: APIRoute = async (context) => {
  const { request, cookies, redirect, url } = context;
  const json = wantsJson(request);
  const input = await readInput(request);
  const email = (input.email ?? "").trim();
  const password = input.password ?? "";
  const next = safeNext(input.next);

  const fail = (code: string, message: string, status = 400) => {
    if (json) return Response.json({ error: code, message }, { status });
    const back = new URL("/login", url);
    back.searchParams.set("error", code);
    if (next !== "/") back.searchParams.set("next", next);
    if (email) back.searchParams.set("email", email);
    return redirect(back.pathname + back.search, 303);
  };

  if (!email || !password) return fail("missing", "Enter your email and password.");

  try {
    const { tokens } = await login(email, password);
    writeSession(cookies, tokens, url.protocol === "https:");
  } catch (error) {
    if (error instanceof MitlistError && (error.status === 401 || error.status === 400 || error.status === 403)) {
      return fail("credentials", "That email and password do not match.", 401);
    }
    if (error instanceof MitlistError && error.status === 429) {
      return fail("rate_limited", "Too many attempts. Wait a minute and try again.", 429);
    }
    console.error("login failed", error);
    return fail("unavailable", "mitlist could not be reached. Try again in a moment.", 502);
  }

  if (json) return Response.json({ ok: true, next });
  return redirect(next, 303);
};
