# mitlist feedback

The public feedback board at [feedback.mitlist.me](https://feedback.mitlist.me):
the same board mitlist users see in the app (You → Feature board), opened up to
the web. Ideas and bug reports, upvotes, a public thread per post, a roadmap
grouped by status, and an updates page listing what shipped, newest first.

It holds no data of its own. Everything is read from and written to mitlist's
board in [reqtrack](https://github.com/whtvrboo/reqtrack) (Staffroom) through
its intake API, so staff triage in one place and both the app and this site
show the result.

## How it is built

[Astro](https://astro.build) rendered on demand on a Cloudflare Worker via
`@astrojs/cloudflare`. The Worker holds mitlist's intake app key as a secret and
proxies the few writes the pages need; the browser never talks to reqtrack.
Visual system is the same neo-brutalist warm paper as `../landing` and the app.

```
src/
├── lib/board.ts        # reqtrack client: reads (cached 30s), writes (evict), types
├── lib/mitlist.ts      # mitlist auth API: login, OAuth handoff, refresh, me, logout
├── lib/session.ts      # token-pair cookie, rotation, /auth/me check
├── middleware.ts       # puts the signed-in user on Astro.locals for every request
├── lib/http.ts         # form-or-JSON helpers shared by the API routes
├── lib/format.ts       # status labels, relative dates, excerpts
├── pages/index.astro   # Feedback: list, status/kind filters, sort, search
├── pages/roadmap.astro # Under review / In progress / Shipped columns
├── pages/updates.astro # Changelog from GET /board/updates, grouped by release
├── pages/login.astro   # Sign-in: password form + Google/Apple buttons
├── pages/auth/callback.astro  # OAuth landing: hands the code to /api/auth/handoff
├── pages/new.astro     # Post form (signed in only)
├── pages/p/[id].astro  # Post detail, conversation, delete-own-comment
├── pages/api/          # auth (login/handoff/logout), posts, vote add/remove, comments add/delete
└── scripts/board.ts    # progressive enhancement: vote toggles and comment deletes without reload
```

### Sign-in

Reading is open to everyone. Voting, posting, and commenting need a mitlist
account: the same one as the app. `/login` offers email + password and the
Google / Apple buttons the backend reports on `GET /oauth/providers`. A
password login posts to `/api/auth/login`; an OAuth login goes to
`api.mitlist.me/oauth/<provider>?redirect_uri=https://feedback.mitlist.me/auth/callback`,
comes back with a one-time handoff code in the URL fragment, and
`/auth/callback` posts it to `/api/auth/handoff`. Both end in an HttpOnly
cookie on this origin holding the access + refresh token pair; the browser
never sees them and never talks to mitlist.

`src/middleware.ts` resolves that cookie on every request: it rotates the pair
when the access token is about to expire, checks it against `/auth/me` (cached
five minutes per token), and drops the cookie when mitlist rejects it. Pages
read `Astro.locals.user`.

The mitlist user id is the `voterRef` sent to reqtrack, exactly what the app
sends, so votes and comments are shared between app and web, and a user can
take back a vote or delete a comment from either. reqtrack stores only a hash
of the id.

For Google and Apple to work, `https://feedback.mitlist.me/auth/callback` must
be in the backend's `OAUTH_REDIRECT_ALLOWLIST` (exact match).

### Rate limits and caching

reqtrack allows 30 intake calls per minute per visitor address. The Worker
calls reqtrack over a **service binding** (`REQTRACK` → `reqtrack-api`) and
forwards the visitor's address. Anonymous reads are cached for 30 seconds in
the Workers cache (writes evict what they change); a signed-in user's reads
carry their id and are not cached, so hasVoted and isMine are exact. Locally the binding has
nothing to talk to, so `astro dev` falls back to plain `fetch` against
`REQTRACK_URL`.

## Running it

```bash
npm install
cp .dev.vars.example .dev.vars   # then paste mitlist's intake key
npm run dev                      # http://localhost:4321, talks to the real tracker
npm run check                    # wrangler types + astro check
```

`REQTRACK_APP_KEY` is the same key the mobile app is built with
(`REQTRACK_APP_KEY` in `frontend/.env`). It only unlocks mitlist's public board
and intake endpoints, never staff data.

## Deploying

```bash
npx wrangler secret put REQTRACK_APP_KEY   # once
npm run deploy                              # astro build && wrangler deploy
```

`wrangler.jsonc` pins the custom domain `feedback.mitlist.me` (Cloudflare
creates the DNS record on first deploy) and the service binding to
`reqtrack-api`. There is no `workers.dev` URL on purpose.

## What staff control

Everything visible here is decided in Staffroom:

- A request appears once it is **public** (posts made here or in the app are
  public from the start; private intake submissions need the toggle).
- **Status** drives the Feedback filters, the Roadmap columns, and the Updates
  page (`done` = shipped). Declined and merged-away requests disappear.
- **Kind** (feature/bug) is the Boards filter.
- **Public replies** show in the thread as "mitlist team", and the latest one
  becomes the note under the entry on Updates.
- **Target release** on a request groups it under "Version X" on Updates;
  without one, entries group by the month they shipped.
