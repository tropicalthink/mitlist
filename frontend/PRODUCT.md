# Product

## Register

product

## Users

Members of a household (roommates, partners, families) coordinating shared life: shopping lists, chores, recurring and one-off expenses, recipes, and a shared "pinwall" of notes. Used on phones, often mid-task: standing in a kitchen, walking a grocery store, settling up money. The user is usually doing something in the physical world while the app keeps the group in sync.

## Product Purpose

mitlist replaces the scattered group chats, fridge sticky-notes, and "who paid for what" spreadsheets that households run on. Success is the app disappearing into the routine: a list gets cleared on a shopping trip, a chore gets marked done, an expense gets split, with no friction and no ambiguity about who did what.

## Brand Personality

Tactile, honest, a little playful. Neo-brutalist: hard 90-degree corners, 2px ink-black borders, flat offset shadows, no gradients, no glass. Space Grotesk throughout. The interface feels like physical objects on a warm paper desk: index cards, sticky notes, a cork pinwall, a rubber stamp. Three words: **sturdy, tactile, warm.**

## Anti-references

- Generic Material-You / rounded-everything SaaS softness. The hard edges are the brand; never round them to look "friendly."
- Glassmorphism, gradient fills, drop-shadow blur, gradient text. The system uses flat color and crisp offset shadows only.
- Sterile fintech minimalism. This is a home, not a bank dashboard; warmth and a little play are the point.
- Over-decorated dashboards / hero-metric template. Function leads; delight is reserved for moments.

## Design Principles

1. **Physical objects, not screens.** Every surface should feel like something you could pick up: a card, a note, a stamp. Motion is the weight and snap of real things, not UI choreography.
2. **The hard edge is sacred.** Radius 0, 2px borders, flat shadows. Identity preservation wins over any softening instinct.
3. **Delight at moments, calm in between.** Dense, legible, fast for the routine work; a genuine payoff at the satisfying beats (clearing a list, marking done, settling up).
4. **Earned familiarity.** Standard affordances for standard tasks. Surprise is spent on the one moment that matters per screen, never on reinventing a checkbox.
5. **Respect the body.** Reduced-motion is a first-class path with a beautiful static alternative, not an afterthought. Touch targets stay honest (44px).

## Accessibility & Inclusion

WCAG AA contrast on body and interactive text. Every animation has a `prefers-reduced-motion` / `MediaQuery.disableAnimations` alternative (already the pattern in `AnimatedCheckToggle`). 44px minimum touch targets. Full light and dark themes. Semantic labels on interactive controls.
