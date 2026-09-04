import type { APIRoute } from "astro";
import { logout } from "../../../lib/mitlist";
import { clearSession, readSession } from "../../../lib/session";

export const POST: APIRoute = async ({ cookies, redirect }) => {
  const session = readSession(cookies);
  if (session) {
    try {
      await logout(session);
    } catch {
      // The tokens are dropped either way; mitlist's copy expires on its own.
    }
  }
  clearSession(cookies);
  return redirect("/", 303);
};
