# First-launch feature tour (revision 2)

Supersedes section 3 of `onboarding-try-before-login.md`. Sections 1, 2 and 4 of
that file (current flow, wider Mobbin survey, sandbox implementation options)
still apply and are referenced below.

Founder direction (2026-09-03): not a bare sandbox drop-in, and not a
Duolingo-length questionnaire. **Three to six screens that show what mitlist
can do, before any sign-in.** References: Yazio onboarding, Endel onboarding,
Duolingo onboarding.

## 1. What the three references actually do

### Yazio — Onboarding (18 screens)
https://mobbin.com/flows/003557b1-194e-477c-b307-5e051fa87371

- Thin progress bar top-left, back chevron, no skip.
- One bold headline per screen, black full-width pill button pinned to the
  bottom ("Next" / "Continue" / "Let's Go").
- The questionnaire is **interleaved with capability screens**: "Say hello to
  simple, sustainable weight loss" (a chart), "Get accurate tracking anywhere
  with AI" (a phone mockup of the real camera screen with real callouts),
  "Meal tips just for you". The capability screens are the part to borrow;
  the questions are the part the founder does not want.
- Mascot screens for pacing: "You're crushing it already!", "Way to shine,
  superstar! Only 57% get this far."
- Ends on a **hard sign-in wall**: Apple / Google / Email, no "later". Then a
  paywall, then the Diary tab. Avoid the hard wall.

### Endel — Onboarding (15 screens)
https://mobbin.com/flows/01afdd29-fd02-45fe-bdc3-9e654be9595a

- Problem → solution → capabilities. "We live in an over-stimulating world" →
  "That's why we made Endel" → one feature per screen, each a single line-art
  illustration, a headline, a muted subline, a full-width outlined Continue.
- Permission priming inline ("Get your peak productivity" → Allow Reminders,
  with Skip top-right).
- **"Sign In or Register" with a "Later" button and 3 page dots.** Later
  drops you into the app. A second, softer ask appears afterwards: "Set Up
  Account to Save Your Progress" with the same Later.
- Monochrome, hard-edged, no gradients. Closest to mitlist's tone of the three.

### Duolingo — Onboarding (20–24 screens, several near-identical flows)
e.g. https://mobbin.com/flows/b0b4f93f-5637-46ec-9d77-49ecda6b991d
(the exact flow id the founder linked did not surface in MCP search; all
Duolingo onboarding flows on Mobbin share the same structure.)

- Mascot speech bubble frames every screen, progress bar, one question per
  screen, "I'm committed" style button copy.
- Value is delivered before the account: first lesson happens, then
  "Create a profile to save your progress!" / **Later**.
- What to skip: the length, the widget-install detour, the mascot as a
  narrator. What to keep: account ask framed as *saving what you did*.

### The shared skeleton
1. Progress indicator (bar or dots), back, optional Skip.
2. 3–6 screens, each = one headline + one visual + one full-width button.
3. Account screen at the end **with an escape hatch** (Endel, Duolingo).
4. Then the real app.

## 2. Recommended flow for mitlist — six screens, one board

Founder decision (2026-09-03): the welcome screen offers exactly two things,
**"Get started"** and **"I have an account"**. Get started launches the tour.
The tour ends on the sign-in screen, and the escape hatch there is the
existing **"Continue as guest"** (server-backed guest account, already built),
not a local "not now". The "Continue as guest" button moves off the welcome
screen and onto the last tour screen.

### Screen 0 — Welcome (existing screen, two buttons)
Keep the scrap pillars and wordmark. Buttons become:
- **Get started** — primary orange, → `/tour`.
- **I have an account** — outline, → `/login`.
Remove the guest button and its footnote from this screen. Invite-code entry
stays as the quiet third affordance for `/join/<code>` arrivals, who bypass
the tour.

The one thing none of the three do that mitlist can: the "illustration" on
each screen is a **real, tappable widget** fed by the same local sample
household. Yazio shows a *picture* of its camera screen; we show the actual
list item tile, the actual expense card, the actual chore card. Every tap on
the tour writes into the same in-memory sandbox, so by the end the user has
already used the product. Nothing leaves the device.

Chrome shared by every tour screen:
- 2px orange progress bar, hard edges (Yazio), back chevron left, "Skip" text
  button right (Endel). Skip jumps to screen 6.
- Eyebrow label in JetBrains Mono caps (`LISTS`, `MONEY`, `CHORES`…).
- Headline in Space Grotesk, one short subline in body colour.
- Live widget in an `AppCard` with the 2px outline and offset shadow.
- Full-width orange `AppButton` "Next" pinned above the safe area.
- Light and dark supported; no illustrations, no mascots, no gradients.

### Screen 1 — Why (Endel's problem → solution, compressed to one screen)
Eyebrow: `FLAT 3B · 3 PEOPLE`
Headline: **"Who bought milk, who owes what, whose turn is it?"**
Subline: "mitlist is the shared notebook for the people you live with."
Visual: the real hub pinwall, scaled down, showing the sample household
(one list, one balance, one overdue chore). Not tappable on this screen;
it is the table of contents for the next four.
Button: "Show me"

### Screen 2 — Lists
Eyebrow: `LISTS`
Headline: **"One list. Everyone adds. Whoever's at the shop buys."**
Visual: "Weekend groceries", six items, two already ticked by Sam. Tapping
ticks/unticks with the real strike-through animation. An inline add field
"Add something…" actually appends an item.
Subline under the card: "Sam added oat milk 5 min ago" (activity line, shows
that it is shared).
Button: "Next"

### Screen 3 — Money
Eyebrow: `MONEY`
Headline: **"Split the pizza. Stop doing mental maths."**
Visual: expense card "Pizza night · €42.00 · paid by you", with the split
chips [You] [Sam] [Ines] all selected. Tapping a chip toggles that person and
the balance line below recalculates live: "Sam owes you €14.00 · Ines owes
you €14.00". A second, non-interactive row "Washing machine repair · €90 ·
paid by Ines" makes the net balance interesting ("Overall: you owe Ines
€16.00").
Button: "Next"

### Screen 4 — Chores
Eyebrow: `CHORES`
Headline: **"Bins go out Thursday. It's Ines's turn, and she knows."**
Visual: three chore cards: "Take out bins · overdue · Ines" (overdue styling,
PRODUCT.md principle 4), "Clean bathroom · Sat · you", "Water plants ·
weekly · Sam". Tapping "Done" on yours marks it and the card flips to
"Next: Sam, in 7 days" showing rotation.
Button: "Next"

### Screen 5 — Recipes & meal plan (drop this one if we want 5 screens)
Eyebrow: `RECIPES`
Headline: **"Thursday is shakshuka. The eggs are already on the list."**
Visual: recipe card "Shakshuka · 4 servings" pinned to a mini week strip on
Thu. Button on the card "Add ingredients to Weekend groceries" — tapping it
adds 3 items and shows a toast "3 items added to Weekend groceries",
tying back to screen 2.
Button: "Next"

### Screen 6 — Your turn (Endel's Sign In or Register + Later)
Eyebrow: `YOUR HOUSEHOLD`
Headline: **"Now do it with the people you actually live with."**
Subline: "Create an account to set up your household and invite them. Free
for households up to 4."
Buttons, in this order: Continue with Google, Continue with Apple, Continue
with email (the same components the welcome screen uses today), then the
existing **"Continue as guest"** button with its footnote ("You can add an
email later to keep your data"), moved here from the welcome screen.
- Any of the four → the existing `/onboarding` create/join household flow.
  The tour's sample data is discarded; it was a demonstration, not a draft.
  (If we later want to carry over user-authored items, the promoter from the
  previous plan §4 still applies, but it is not in scope.)
- Guest works exactly as today: `createGuest()` then `/onboarding`, upgrade
  offered later via the existing Google/Apple/email link flow.

Invite-link arrivals (`/join/<code>`) skip the tour entirely, as before.
The tour is shown from "Get started" only; it is not auto-launched on a
timer and not gated by a seen-flag, so a returning signed-out user who taps
Get started again simply sees it again. Re-openable from You → "Take the
tour" for testing.

### What was deliberately left out
- No questionnaire (Yazio, Duolingo). One optional question "Who do you live
  with? Flatmates / Partner / Family" could seed better sample names later;
  deferred, it adds a screen between tap and value.
- No permission priming for notifications in the tour. Ask the first time
  a chore with a due date is created in a real household.
- No "Only 57% get this far" style pacing screens. mitlist's voice is direct.

## 3. Implementation sketch

Single phase. No backend changes, no Drift changes, no new auth work.
- `lib/screens/onboarding/tour_screen.dart` — `PageView` with 6 pages,
  progress bar, back, Skip (→ screen 6), Next. Route `/tour`, added to
  `authRoutePrefixes` in `router_redirect.dart` so signed-out users can reach
  it; signed-in users are bounced to `/home` like the other auth routes.
- `lib/screens/onboarding/tour_pages/` — one file per page; each composes
  existing widgets (list item tile, expense card, chore card, recipe card)
  against a `TourSandboxState` (plain `StateNotifier`, in memory, seeded
  from `lib/screens/onboarding/tour_seed.dart`). Disposed when the tour is
  left.
- `welcome_screen.dart` — reduce to "Get started" (→ `/tour`) and "I have an
  account" (→ `/login`). Move `_onGuestContinue`, its loading state and the
  guest footnote into the last tour page (extract to a small shared widget
  so both the tour and any future caller use one implementation).
- Screen 6 reuses the Google/Apple/email launchers from the welcome screen
  (extract them alongside the guest button). All four land on `/onboarding`
  as they do today.
- ARB strings for all six screens in en/de/es/fr/nl.
- Tests: redirect resolver cases for `/tour` (signed-out allowed, signed-in
  bounced, invite link still wins); widget test that ticking on screen 2 and
  adding ingredients on screen 5 mutate the same state; welcome screen test
  updated for the two-button layout.

Out of scope, kept in `onboarding-try-before-login.md` for later: the local
Drift sandbox hub and the promote-on-signup replay.

## 4. Decisions (2026-09-03)
1. Six screens, recipes included.
2. Sample currency is always dollars; the real household picks its own.
3. Sample names Sam and Ines stay as-is in every language. Sample item and
   chore names are also English in every language for now.
4. Built as `frontend/lib/screens/tour/` (state, screen, pages, finish page)
   plus `frontend/lib/widgets/guest_continue_button.dart`; route `/tour`.
   The "Not now" landing and the local Drift sandbox hub were dropped.
