/// <reference types="astro/client" />

// Bindings and vars come from wrangler.jsonc via `wrangler types`
// (worker-configuration.d.ts). Secrets are not in that file, so they are
// declared here.
declare namespace Cloudflare {
  interface Env {
    REQTRACK_APP_KEY?: string;
    /** "1" makes a local `wrangler dev` call REQTRACK_URL over plain fetch. */
    REQTRACK_DIRECT?: string;
  }
}

declare namespace App {
  interface Locals {
    /** The signed-in mitlist user, resolved by the middleware. */
    user: import("./lib/mitlist").MitlistUser | null;
    session: import("./lib/session").Session | null;
  }
}
