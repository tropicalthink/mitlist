import { defineMiddleware } from "astro:middleware";
import { resolveUser } from "./lib/session";

// Every page and API route sees the signed-in user (or null) on locals, so
// nothing renders or writes on a guess.
export const onRequest = defineMiddleware(async (context, next) => {
  const resolved = await resolveUser(context.cookies, context.url.protocol === "https:");
  context.locals.user = resolved?.user ?? null;
  context.locals.session = resolved?.session ?? null;
  return next();
});
