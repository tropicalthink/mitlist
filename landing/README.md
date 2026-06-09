# Mitlist landing

Marketing site for Mitlist, built with [Astro](https://astro.build). The visual
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

- **Store links:** replace the `href="#"` placeholders in `StoreBadges` (passed
  as `appStore` / `playStore` props) with real listing URLs.
- **GitHub URL:** the `GITHUB` constant at the top of `index.astro`.

## Commands

| Command           | Action                                  |
| :---------------- | :-------------------------------------- |
| `npm install`     | Install dependencies                    |
| `npm run dev`     | Dev server at `localhost:4321`          |
| `npm run build`   | Build to `./dist/`                      |
| `npm run preview` | Preview the production build            |
