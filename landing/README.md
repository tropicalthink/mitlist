# mitlist landing

Marketing site for mitlist, built with [Astro](https://astro.build). The visual
system is pulled 1:1 from the Flutter app (`frontend/lib/theme/colors.dart`):
neo-brutalist warm-paper desk, hard 90° corners, 2px ink borders, flat offset
shadows, Space Grotesk, orange `#F97316` on ink `#1A1714`.

## Structure

```
src/
├── layouts/Layout.astro      # head, fonts, meta
├── components/
│   ├── Pinwall.astro         # interactive cork-board hero (hand-rolled drag physics)
│   └── StoreBadges.astro     # App Store / Google Play badges
├── pages/index.astro         # the page + section styles
└── styles/global.css         # design tokens + base
```

## The hero

`Pinwall.astro` is a cork board of draggable household objects (shopping card,
sticky notes, an overdue chore, an expense receipt). Drag, fling, and they
settle with inertia and a rotation wobble. No animation library; physics are a
small `requestAnimationFrame` loop. Respects `prefers-reduced-motion` (static,
still draggable, no inertia).

## Launch configuration

- Shared launch facts, URLs, pricing, and contact addresses live in
  `src/data/site.ts`; do not hardcode copies in components.
- `/mobile-beta` collects the required testing-invitation consent and a separate,
  optional launch-updates consent. `/testing` remains available for old links.
- Product screenshots live in `public/screenshots/*.webp` (phone captures of
  the live web app at 430×932 CSS px, 2× scale). Each `<name>.webp` has a
  `<name>-dark.webp` twin that the homepage serves under
  `prefers-color-scheme: dark`. `scripts/capture-screenshots.mjs` opens a
  phone-sized Chrome in either scheme for recapturing them.
  `npm run check:official-launch` fails while any `data-launch-placeholder`
  element remains in `HomePage.astro`.
- Localized homepages ship at `/en/`, `/de/`, `/es/`, `/fr/`, and `/nl/`.

## Commands

| Command           | Action                                  |
| :---------------- | :-------------------------------------- |
| `npm install`     | Install dependencies                    |
| `npm run dev`     | Dev server at `localhost:4321`          |
| `npm run build`   | Build to `./dist/`                      |
| `npm run preview` | Preview the production build            |

## Testing signup and feature board

The homepage and footer link to `https://feedback.mitlist.me` as the public
feedback-driven roadmap. The landing site does not fetch board data or need an
intake key.

Signups post to `https://api.mitlist.me/api/v1/testing/signups` (override with
`PUBLIC_MITLIST_API_URL` at build time for a local or self-hosted backend).
Deploy backend migrations `000064` and `000067` and the signup endpoint **before** publishing
the landing update. The backend's `TESTING_SIGNUP_ORIGIN` defaults to
`https://mitlist.me`; change it for a different landing origin. This CORS
permission covers only the public signup endpoint.

For the private export and invitation workflow, see
[the testing operator guide](../backend/docs/testing-signups.md).
Before changing the public-beta wording to an official launch, replace every
screenshot marked `data-launch-placeholder` and run `npm run check:official-launch`.
