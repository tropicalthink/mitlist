# mitlist

## Design Context

### Users

Primary users are people in **shared households** (roommates, partners, families) who need to coordinate **lists, money, chores, and recipes** in one place. They are often switching contexts quickly (kitchen, store, on the go) and need clarity, low cognitive load, and a sense that the app supports collaboration without taking over.

### Brand Personality

**Warm, punchy, organized, intuitive, in control** — the UI should feel approachable and human (warmth), with confident hierarchy and motion where it helps (punchy), clear structure and predictable patterns (organized), scannable copy and obvious affordances (intuitive), and user-driven flows that avoid nagging or obscuring actions (**keeps you in control**).

### Aesthetic Direction

- **Target feel**: a blend of **Google Keep**-style speed and light structure with **Apple Notes**-like calm surfaces and typography-forward clarity — quick capture, scannable cards, note-like simplicity rather than “business dashboard” density.
- **Implementation note**: the Flutter app currently uses **Material 3** as the base (`ThemeData`, M3 `ColorScheme`). The product direction is **not** to lean on stock Material “chrome” or default patterns where they read as generic app UI; prefer custom composition using existing `MitlistTheme` tokens, `App*` widgets, and deliberate layout over prefab Material screens.
- **Anti-patterns to avoid**:
  - “Material Design 2012” density: hamburger-mystery meat, heavy ripples on everything, busy FAB clusters, Holo-era leftovers.
  - **ERP / enterprise** aesthetics: dense tables-first layouts, form-heavy wizards, grey-on-grey corporate neutrals, unclear primary actions.
- **Theme**: **Light and dark** are both supported (`ThemeMode.system`); design new surfaces for **both** using `MitlistTheme.light` / `MitlistTheme.dark` and `MitlistColors` — avoid light-only one-offs.

### Design Principles

1. **Notes, not back office** — Favor list-first and card-based layouts, generous whitespace, and obvious primary actions; avoid data-grid or admin-panel defaults for household tasks.
2. **Borders and type carry the brand** — The established **2px outlines**, **square primary geometry**, and **Space Grotesk** hierarchy are intentional; extend them before introducing new visual languages.
3. **Punchy, not loud** — Use **orange primary** and motion (Lottie, confetti, haptics) for meaningful moments, not for constant distraction.
4. **User stays in control** — Prefer undo-friendly patterns, clear destructive flows, and settings that are easy to find; no dark patterns.
5. **Evolving away from “stock Material”** — When new UI is added, **compose** with existing primitives (`app_card`, `app_button`, `app_bottom_sheet`, theme spacing) and **custom layout**; do not add screens that look like unstyled Material examples.

### Frontend implementation pointers

- **Design tokens**: `frontend/lib/theme/` — `colors.dart` (e.g. primary orange scale, warm neutrals), `typography.dart` (Space Grotesk + JetBrains Mono for mono; logo may move to Mathilde per TODO), `spacing.dart`, `theme.dart` (M3 theme wiring), `shadows.dart`, `animations.dart`.
- **Reusable UI**: `frontend/lib/widgets/` — `app_*` components, `empty_state`, `skeleton`, `filter_pill`, etc.
- **App shell**: `frontend/lib/app.dart` — `MaterialApp.router`, `mitlist` title, system theme mode.

---

_Established via teach-impeccable (April 2026). Refine this section as the product and visual language evolve._
