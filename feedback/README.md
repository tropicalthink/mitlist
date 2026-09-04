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
├── lib/voter.ts        # random-id cookie so a vote counts once per browser
├── lib/http.ts         # form-or-JSON helpers shared by the API routes
├── lib/format.ts       # status labels, relative dates, excerpts
├── pages/index.astro   # Feedback: list, status/kind filters, sort, search
├── pages/roadmap.astro # Under review / In progress / Shipped columns
├── pages/updates.astro # Changelog from GET /board/updates, grouped by release
├── pages/new.astro     # Post form
├── pages/p/[id].astro  # Post detail and conversation
├── pages/api/          # POST posts, PUT/POST vote, POST comments
└── scripts/board.ts    # progressive enhancement: votes without reload, "You" marks
```

### Identity without accounts

There are no logins. The first time a visitor votes, posts, or comments, the
API sets a random `web_…` id in an HttpOnly cookie and sends that as the
`voterRef`; reqtrack stores only a hash. The pages themselves are cached
without any per-visitor state, so the browser remembers in `localStorage` which
posts it upvoted and which comments it wrote, purely to highlight them. Losing
that only loses the highlight: a repeat vote is a no-op upstream.

### Rate limits and caching

reqtrack allows 30 intake calls per minute per visitor address. The Worker
calls reqtrack over a **service binding** (`REQTRACK` → `reqtrack-api`) and
forwards the visitor's address, and it caches every read for 30 seconds in the
Workers cache, evicting the entries a write changes. Locally the binding has
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
