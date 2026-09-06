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

## What to wire up before launch

- **Mobile testing:** `/testing` collects email, Android/iOS selection and
  consent. Store badges select the matching platform on that page. Invitations
  are sent manually after adding people to the appropriate store testing group.
- **GitHub URL:** the `GITHUB` constant at the top of `index.astro`.

## Commands

| Command           | Action                                  |
| :---------------- | :-------------------------------------- |
| `npm install`     | Install dependencies                    |
| `npm run dev`     | Dev server at `localhost:4321`          |
| `npm run build`   | Build to `./dist/`                      |
| `npm run preview` | Preview the production build            |

## Testing signup and feature board

The homepage and `/testing` have a compact callout linking directly to
`https://feedback.mitlist.me`. The feature board is also linked in the header
and footer. The landing site does not fetch board data or need an intake key.

Signups post to `https://api.mitlist.me/api/v1/testing/signups` (override with
`PUBLIC_MITLIST_API_URL` at build time for a local or self-hosted backend).
Deploy backend migration `000064` and the signup endpoint **before** publishing
the landing update. The backend's `TESTING_SIGNUP_ORIGIN` defaults to
`https://mitlist.me`; change it for a different landing origin. This CORS
permission covers only the public signup endpoint.

For the private export and invitation workflow, see
[the testing operator guide](../backend/docs/testing-signups.md).
