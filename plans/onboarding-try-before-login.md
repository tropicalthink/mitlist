> **Superseded in part.** Section 3 (recommended flow) is replaced by `onboarding-feature-tour.md` (2026-09-03). Sections 1, 2 and 4 still apply.

# Onboarding: try before login

A first-launch flow where the very first screen after the splash is a working
household board with sample content the user can touch, and the account ask
arrives only when they want to keep or share what they made.

Status: proposal. Nothing implemented.

---

## 1. Current first-launch flow

What happens today, factually.

1. `main.dart` → `routerProvider` starts at `/_session` (`SessionBootstrapScreen`).
   `resolveAppRedirect` (`frontend/lib/router_redirect.dart`) holds every route
   there while `authBootstrapProvider` is loading, carrying the requested path
   in `?continue=`.
2. Signed out, the redirect sends everything to `/welcome`. The only exemptions
   are `authRoutePrefixes` (`/welcome`, `/login`, `/signup`, `/auth/callback`)
   and `publicRoutePrefixes` (`/r/` — shared recipes). `/join/<code>` is
   rewritten to `/welcome?invite=<code>`.
3. `WelcomeScreen` (`frontend/lib/screens/auth/welcome_screen.dart`) paints the
   cork board: a taped "mitlist" paper plus four **static, illustrative** pinned
   scraps (`ListScrap`, `ReceiptScrap`, `ChoreScrap`, `RecipeScrap` from
   `widgets/board/artifact_scraps.dart`) that drop in on a 1200 ms timeline.
   They are decoration — wrapped in `ExcludeSemantics`, not tappable.
   Three actions, in visual priority order:
   - **Create free household** (solid orange) → `/signup`
   - **Sign in** (outline) → `/login`
   - **Continue as guest** (ghost, neutral ink) → `authService.createGuest()`
   - footnote: *"No sign-up needed. Add an account later to keep your data."*
4. `createGuest()` (`services/auth_service.dart:362`) POSTs `/auth/guest` with
   App Check (mobile) / Turnstile (web) attestation, saves a real token pair,
   sets `authStateProvider = true` and `isGuestProvider = true`, and pins
   `pendingAuthNavigation = '/onboarding'`.
5. `OnboardingScreen` (`screens/auth/onboarding_screen.dart`, 1095 lines) is a
   four-beat cork-board flow: `_Stage.choose` (create note vs join slip) →
   `_Stage.name` (household name written on the sticky note + currency) →
   `_Stage.invite` (invite code + QR torn off) → `_Stage.ready` (three
   orientation rules). It creates a **real server-side group**.
6. `/home` → `HouseholdHubScreen`. If no group resolves it bounces back to
   `/onboarding`. Otherwise: app bar, `HubQuickStart` strip
   (`widgets/hub/onboarding_card.dart` — ghost artifacts for list / chore /
   expense that fill in and take a DONE stamp as you create the real thing,
   plus an invite slip with dashed empty seats), `PinwallSection`,
   `ActivityWall`, and a `hubQuickAdd` FAB.

**Net effect today:** a first-time user sees a marketing collage, then must pick
an auth path, then must name a household, before a single real feature is
visible. The guest escape hatch exists but is the third, quietest button and it
still dead-ends into the household-creation form.

### What already exists that helps a lot

| Asset | Where | Why it matters |
|---|---|---|
| Guest accounts, zero user input | `auth_service.dart:362` `/auth/guest` | An account can be created without ever asking the user for anything. |
| Guest → real account | `auth_service.dart:453` `/auth/guest/convert`, plus OAuth `link=1` handling in `router_redirect.dart` and `oauth_callback_screen.dart:97` | The "keep this" upgrade path is already built for email, Google and Apple. |
| Offline-first writes | `repositories/list_repository.dart` (optimistic local row + `enqueueOutbox` + `drainOutboxOnce`), `repositories/outbox_drainer.dart` | Local-only writes with a later replay is an established pattern in this codebase, not a new invention. |
| Local Drift store | `storage/app_database.dart` | Real tables for lists, list items, expenses, recipes; JSON-blob caches for chores, finance summary, settlements, pinwall, meal plans, calendar, hub group, groups list, activity. Every one has an `upsert*` writer. A whole board can be materialised locally with no network. |
| Board / artifact widget kit | `widgets/board/cork_board.dart`, `artifact_scraps.dart`, `widgets/hub/*` | The sandbox can be built from components that already look right. |
| Quick-start scaffolding | `widgets/hub/onboarding_card.dart`, `providers/onboarding_provider.dart` | Progress-through-artifacts UI and a SharedPreferences dismissal flag already exist. |
| Public-route escape | `publicRoutePrefixes = ['/r/']` in `router_redirect.dart` | The precedent for "a signed-out visitor may see this route" is already in place; the sandbox adds one more prefix. |

---

## 2. Mobbin references

Grouped by pattern. Each is a live Mobbin link.

### A. Sample-data sandbox — the core pattern

**1. Copilot Money — "Demo mode"** · [flow](https://mobbin.com/flows/f49d08d4-5812-49de-84cc-34c9b30b5507) · also [Entering demo mode](https://mobbin.com/flows/dd16a35e-4cff-4f9d-a916-5de109880555)

The closest thing to what mitlist wants, in an adjacent category (money).
Steps: the sign-up screen carries a small **"Demo Mode ▶"** affordance in the
top-right corner, above the Apple/email sign-up buttons. Tapping it drops you
straight into the *real* app chrome — Dashboard, Transactions, Categories,
Recurrings tabs — fully populated with a plausible fake month ($4,120 budgeted,
$235 left, Netflix $12.99, Chevron −$37.26, category rings). A slim bar pinned
above the app bar reads **"You're in demo mode"** with an **✕**. Coach-mark
cards ("Spending Target", "What You've Spent", each with a GOT IT button)
explain the non-obvious numbers *in situ*, not on a slide. Tapping ✕ opens a
confirm dialog: "Leaving demo mode — Ready to go back? / Cancel / Leave demo
mode". Demo mode is also re-enterable later from Settings ("Demo Mode → Enter
demo mode").

- **Signup sits:** entirely outside; demo is a branch off the signup screen, and
  leaving demo returns you to signup. Nothing inside demo is gated.
- **Borrow:** the one-line persistent demo bar with a single exit; the confirm
  dialog on exit; coach marks attached to the real widget rather than a carousel;
  keeping demo reachable forever from settings (useful for support and for the
  App Store review account).
- **Avoid:** their demo is read-only theatre — you can't add a transaction.
  mitlist's whole thesis is *touch it*, so ours must accept writes.

**2. Notion — Onboarding** · [flow](https://mobbin.com/flows/2ada33fc-fedc-4d26-a89a-96714e261e81)

After sign-in and an interests questionnaire ("What are some areas of
interest?" — Habit tracking, Food & nutrition, To-do list…), the workspace is
**not empty**. The sidebar is pre-seeded with real editable pages: "👋 Welcome
to Notion!", "Getting Started on Mobile", "Habit Tracker", "Weekly To-do List",
"Personal Website". Opening "To do list" shows actual plausible rows ("Buy new
house plants", "Pay utility bills"). One "Some essential tips" screen shows a
phone-in-phone illustration with a single instruction ("Touch and hold to
reorder any content") rather than a five-slide tour.

- **Signup sits:** before. That's the part to invert.
- **Borrow:** seeded content is *ordinary and useful*, not "Sample Item 1". The
  questionnaire answers pick which templates get seeded — a cheap way to make a
  generic sandbox feel personal.
- **Avoid:** seeding seven pages. Two or three artifacts is the ceiling for a
  household board before it reads as clutter.

**3. monday.com — Browsing tutorial / "Your first board"** · [flow](https://mobbin.com/flows/d35a64a4-8d5e-41f8-8656-c881c7b0b923)

Home shows a **"Finish setting up — 33% Completed"** ring with a checklist
("Create your first board ✓", "Get started with basics", "Unlock the full
experience"). Tapping through lands on a board pre-filled with placeholder rows
(Item 1/2/3, Group 1/2) and Status chips already coloured Working on it / Done /
Stuck; blue coach bubbles ("Statuses can show task progress at a glance", 2 of 3,
Next) point at the real cells.

- **Signup sits:** before (B2B).
- **Borrow:** *placeholder rows are the tour*. The tooltip points at a real
  interactive cell, so the first tap is a real edit.
- **Avoid:** the percentage-complete ring — that's gamification, which PRODUCT.md
  rules out. `HubQuickStart`'s existing "ghost artifact fills in and takes a DONE
  stamp" is the mitlist-native version of the same idea and already ships.

**4. Fabric — Tasks** · [flow](https://mobbin.com/flows/1f4c49bb-a54f-4b0b-b944-b04486ae088b)

A tight before/after: the same Tasks screen shown empty ("Create your first task
— Plan your goals, todos and set reminders" + a single `+ Create new task`
button) and then populated with two real rows ("Learn about gestalt · 1 related
item · Apr 2 · Medium").

- **Borrow:** worth showing the founder as the A/B of what we're replacing. The
  empty version is what mitlist's hub looks like on day one for a real signup;
  the populated version is what the sandbox delivers in zero taps.

**5. Squarespace — View demo site** · [flow](https://mobbin.com/flows/1e97eb76-df5e-4676-aab1-7a2508e027f5)

Template picker → **"VIEW DEMO SITE"** opens the actual rendered demo at
`crosby-demo.squarespace.com` with a persistent dark pill docked bottom-right:
**"Create A Site Like This — Free trial. Instant access."** Or **"START WITH
THIS DESIGN"** to skip the demo entirely.

- **Signup sits:** in the floating pill, always present, never blocking.
- **Borrow:** the *sticky, small, non-modal* conversion affordance riding along
  with the demo. It never interrupts; it's just always in reach.

### B. Delayed signup / continue-as-guest

**6. IHG Hotels & Rewards — "Continue as guest"** · [flow](https://mobbin.com/flows/68d72ee8-ca80-4576-9760-ae046d12a000)

Welcome screen: Sign in | Join for free, with an underlined **"Continue as
Guest ›"** below. Choosing it lands on a fully functional Home with a search
field and a "Your stays" section; the top of the screen carries a thin
persistent strip **"Sign in or join IHG One Rewards ›"**. The Account tab is
where the real wall lives — it shows only Sign in / Join for free.

- **What's gated:** identity-bound surfaces (Account, member rates). Search and
  browse are open.
- **Borrow:** the guest state is advertised by a slim inline strip, not a modal;
  the account tab is the honest place to park the upgrade ask.
- **Avoid:** guest is still the visually weakest of three options — exactly
  mitlist's current mistake.

**7. American Airlines — Onboarding** · [flow](https://mobbin.com/flows/6b528238-ded4-48b2-8b45-8ea9d71db138)

Three actions, and **"Continue as guest"** is a full-width outlined button of
the same size as "Log in" — visual parity, not a footnote. The joining ask is
demoted to a text link ("Join the AAdvantage® program →"). After entering, the
Home screen carries a card selling the programme with a "Join for free" button —
the ask is *content on the page*, in line with everything else.

- **Borrow:** button parity for the try-it path, and moving the signup pitch
  into an ordinary card in the feed rather than an interstitial.

**8. Mimo — Creating an account** · [flow](https://mobbin.com/flows/1e24aff9-29e8-4ca2-8a89-4ae78848f4ff)

You learn first — the path map, the first lesson, XP — and the account form
(email → "Set a password", step 2/3) appears afterward, framed as securing
progress you can already see on the Profile screen (streak, XP, league).

- **Borrow:** the account form is short (2–3 fields) and arrives *after* there's
  something on screen worth protecting.

### C. The save-your-work wall — where the ask lands

**9. Duolingo — Creating a profile** · [flow](https://mobbin.com/flows/7948bb0a-4b84-42f6-8b10-5f7374d39237)

After the first lesson, the owl says **"Don't lose your progress! Let's create a
profile."** with **CREATE PROFILE** and a plain **LATER**. Only then: name,
email, or Google / Facebook / Apple.

- **Borrow:** loss-framing ("don't lose") beats gain-framing ("sign up to
  unlock"), and the dismissal is a real, unpunished **Later**.
- **Avoid:** the mascot. mitlist has no mascot and PRODUCT.md forbids the
  register.

**10. Vocabulary — Creating an account** · [flow](https://mobbin.com/flows/4c02ae69-39ac-4f81-9b73-9289c7d7c5ac)

The wall is a sheet titled **"Keep your data safe — Create an account so you
never lose favorites, collections, and settings when you reinstall or switch
devices"**, offering only Sign in with Apple / Sign in with Google. Before
signing in, Settings shows an "Account → Sign in" row; afterwards the same row
reads "Signed in with Apple".

- **Borrow:** copy that names the *concrete* things at risk (favorites,
  collections, settings) rather than "your data"; two OAuth buttons only, no
  form; the settings row that flips state.

**11. Blinkist — Onboarding** · [flow](https://mobbin.com/flows/a9e95e3d-961b-422b-b217-d3fe6fe34e0f)

A four-step questionnaire ("STEP 1 OF 4 — What are your biggest goals right
now?" with a reassuring "You can always update your answers"), then a **taste
step** — "Does this title look interesting to you?" with a real book card and
👍/👎 — then the paywall, then a home feed already shaped by the answers.

- **Borrow:** the taste step is an *interaction*, not a question — the user
  touches product content during onboarding.
- **Avoid:** the trial paywall at step 5. mitlist gates nothing on money at
  first run (billing starts at 5+ members).

### D. Personalisation questionnaire — used to seed, not to stall

**12. Buddy — Onboarding** · [flow](https://mobbin.com/flows/eecfa79b-3250-429f-9432-de16e4d34552)

"**How can we help?** Tell us what you're interested in so we can customise the
app for your needs" — a 2×3 grid of tappable cards (Make a budget, Track my
spending, Save for a goal, Pay off debt, Share with partner, Sync between
devices). Then permission priming for notifications with an in-app explainer
screen ("A little nudge?") *before* the OS dialog.

- **Borrow:** one screen, one question, multi-select, answers used to decide what
  gets seeded; and priming notifications with an explanation first — mitlist has
  chore reminders and will want the same.
- **Avoid:** Buddy runs six screens before any value. One question maximum.

**13. Numo — Onboarding + Creating a first task** · [flow](https://mobbin.com/flows/8050d78c-3f1b-435e-a0c5-1d0137137aaf) · [first task](https://mobbin.com/flows/96c4f619-f8e8-41f2-8789-c255a52c61fa)

Mid-onboarding, with a progress bar and a permanent "Skip onboarding" in the
corner, a screen just says **"Let's try now! — Type 1 task you wanna do…"** with
the keyboard already up. You do the product's core verb before the account
exists. (An earlier step also shows a fake social card — "She committed to do
this today: ☑ Clean the dishes" with a "Support her with a like" arrow.)

- **Borrow:** the single-field "do the real thing right now" beat and the
  permanently visible skip.
- **Avoid:** their "Doing the magic" loading screen and the fake-social nudge —
  manufactured, and gamified.

### E. Value carousel / product tour — mostly what to avoid

**14. Splitwise — Onboarding** · [flow](https://mobbin.com/flows/bd8e8a85-eb7a-4cb5-84fc-c532e572ba20) · [creating a group](https://mobbin.com/flows/48011a8d-9b9a-4a35-870f-95460cfd3795)

The most direct competitor, and it does the opposite of this proposal: splash →
**Sign up (email + password) first** → *then* a three-slide pastel carousel with
an illustrated fake balances card ("Overall, you are owed $64.64 · Beach trip ·
House stuff") → then a genuinely empty app ("You have not added any friends
yet"). Group creation is a form (name + Trip / Home / Couple / Other chips), and
a new group shows "You're the only one here! / Add members / Share a link".

- **Borrow (one thing):** the group-type chips (Trip / **Home** / Couple /
  Other) are a fast, low-friction personalisation input.
- **Avoid (the rest):** it shows a *picture* of populated data during the
  carousel and then hands you an empty app — the exact bait-and-switch this
  proposal exists to prevent. Also the aesthetic: PRODUCT.md names Splitwise's
  softness as an anti-reference.

**15. Craft — Browsing tutorial** · [flow](https://mobbin.com/flows/261e0d10-aa8e-4396-af24-3bae256990de)

A tour where each slide is a live control: "Drag And Drop Anything — Dragging
and dropping is the primary way to manipulate content in Craft – Give it a try!"
and the Next button stays **disabled until you actually drag the block**. Same
for "Easy Styling — Swipe ← or → on me". Home afterwards is seeded with Travel
Planner / Meal Planner / Getting Started docs.

- **Borrow:** if mitlist ever wants to teach a gesture (swipe-to-check on a list
  item), this is how — gate Next on the real gesture, one gesture only.
- **Avoid:** fourteen screens.

**16. Gymshark — View guided tour** · [flow](https://mobbin.com/flows/3615cf57-e900-41d0-84b5-4dc09a91ad0e)

Classic dark-scrim coach marks over the real app ("Tap here to see your workout
history and resume your plan. / Got it"), stepping across tabs.

- **Avoid, mostly:** scrim-dimming the whole app to point at one button is heavy
  and reads as a manual. Copilot's inline light cards (ref 1) do the same job
  without dimming. Keep at most two, and never on first paint.

---

## 3. Recommended flow for mitlist

Design constraints carried through every screen below: hard edges
(`BorderRadius.zero`), 2px outlines, orange `#F97316` used sparingly for the one
primary action, Space Grotesk headings, no gradients, no mascot, no progress
percentage, no confetti. **No carousel.** PRODUCT.md #1 *"Disappear into the
task"* means the sandbox is not a tutorial that happens to contain data — it is
the product, with data in it.

### Screen 0 — Welcome (keep, re-rank)

Same cork board, same four dropped scraps, same 1200 ms entrance. Three changes:

- The primary orange button becomes **"Look around"** (working title; alternates:
  "Start a board", "Try it"). It leads to the sandbox.
- "Create free household" collapses into a secondary line with sign-in:
  **"Sign in"** (outline) and, under it, a quiet **"I have an invite code"**.
  Ref: American Airlines (7) gives the try-it path *button parity*; here it gets
  primacy because there is nothing to lose by trying.
- The footnote changes from "No sign-up needed. Add an account later to keep your
  data." to something honest about the sandbox: **"Nothing saved yet — have a
  poke around first."**
- **The invite path is untouched.** `?invite=` still short-circuits to the
  `_InvitePinnedNote` + create/join buttons. Someone arriving from a flatmate's
  link has already been sold; do not detour them through a sandbox.

Time from cold start to Screen 1: one tap.

### Screen 1 — The sandbox board (`/try`)

This is `HouseholdHubScreen` rendered against a local sandbox household, not a
new screen. Same app bar, same `PinwallSection`, same `ActivityWall`, same
`hubQuickAdd` FAB, same bottom nav — all five tabs live and tappable.

**Household name:** "Flat 3B" — specific enough to read as someone's real home,
generic enough not to be anyone's. Members: **you** plus two seeded flatmates,
**Sam** and **Ines** (initials avatars only, no photos).

**Seeded artifacts** (deliberately small — three visible things; ref Notion (2),
"don't seed seven"):

| Where | Seed |
|---|---|
| Lists | **"Weekend groceries"** — 6 items: Milk 2L, Sourdough, Eggs (12), Coffee beans 500g, Washing-up liquid, Bin bags. Two already checked (Milk, Eggs) so the check state is visibly meaningful and the strike-through style is on screen from the first frame. |
| Money | **"Pizza night" €42.00 — paid by Sam, split 3 ways** (€14.00 each) and **"Washing machine repair" €90.00 — paid by you, split 3 ways**. The net line reads "Sam owes you €16.00". Two expenses, because one expense cannot demonstrate a *balance*, and the balance is the point. |
| Chores | **"Take out bins" — due tomorrow, Ines**; **"Clean the bathroom" — due Saturday, you**; **"Hoover the hallway" — overdue by 2 days, Sam**. One overdue on purpose: PRODUCT.md #4 is "What's due, clearly", and the overdue treatment is the strongest thing the chores screen does. |
| Kitchen | **"Shakshuka"** — 6 ingredients, 4 steps, 25 min, serves 3. Enough that Cook Mode has something to run. One recipe only. |
| Calendar | Populated for free by the existing aggregate: the chore due dates and the two expense dates already land on the week view. Add nothing. |
| Pinwall | One note, in a flatmate's voice: **"Landlord coming Thursday 10am — someone needs to be in"**, pinned, with a reminder set. |

Currency: **€** by default, but re-derived from device locale (`$`, `£`, `€`) so
a US user doesn't see euros. Dates are relative ("tomorrow", "Saturday", "2 days
ago") and computed at seed time so the board is never stale.

**Everything is writable.** Check an item, add "Olive oil" to the groceries, tick
"Take out bins" done, add an expense from the FAB, open Quick Add. Every one of
those writes goes to local Drift and stays. This is the single hardest line to
hold and the single biggest difference from Copilot (1), which is read-only.

**How the sandbox announces itself** — one slim strip, pinned under the app bar,
in the board idiom: a torn paper tab reading **"Sample household — nothing is
saved yet"** with a single right-aligned action, **"Keep this"**. No ✕ (leaving
is what "Keep this" and the back gesture are for; an ✕ that throws away work is a
trap). Ref: Copilot's "You're in demo mode" bar (1) for the shape, Squarespace
(5) for the always-present-never-blocking conversion affordance. About 32px tall,
neutral ink on cork, 2px bottom rule; it blocks nothing.

**Coach marks: at most two, and not on first paint.** Ref Copilot (1) and
monday (3), against Gymshark (16). Fire on first *arrival at the relevant tab*,
not on load:

1. On the Money tab, once, anchored to the balance line: *"Sam owes you €16.00 —
   that's the two expenses above, split three ways."* (GOT IT)
2. On the first list-item check: nothing. The strike-through explains itself.

Prefer one over two. If in doubt, ship zero and let the artifacts speak — which
is exactly what `HubQuickStart` already does with its ghost-to-DONE progression.

### Screen 1.5 — The optional one-question personaliser (defer to v2)

Ref Buddy (12), Blinkist (11), Splitwise's Home/Trip/Couple chips (14). If the
board ever needs to feel more personal, ask **one** question on entry — *"Who are
you living with?"* → **Flatmates / Partner / Family** — and vary the seed
(flatmate names, chore set, whether the expense is "Pizza night" or "Nursery
fees"). **Do not build this in v1.** It adds a screen between tap and value,
which is the thing we're removing. Ship the generic flatmate seed, measure, then
decide.

### The account ask — triggers, in priority order

The ask has exactly one destination: a bottom sheet titled in the loss frame,
ref Duolingo (9) and Vocabulary (10).

> **Keep this board**
> Sign in and Flat 3B becomes your household — your lists, expenses and chores
> come with you, and you can invite the people you actually live with.
>
> [ Continue with Google ]  [ Continue with Apple ]
> [ Use email instead ]
> *Not now*

The copy names the concrete things at stake (ref 10: "favorites, collections, and
settings" rather than "your data"). **"Not now" is always present and never
punished** (ref 9's LATER).

Triggers, most → least important:

1. **They tap "Keep this"** on the sandbox strip. The explicit path. Always
   available.
2. **They try to invite someone.** Inviting is the one thing genuinely impossible
   without a server — an invite code has to exist somewhere real. Tapping invite
   (from `HubQuickStart`'s seats slip or the household menu) opens the sheet with
   swapped copy: *"Invites need an account — so your flatmates have something to
   join."* This is the highest-intent moment in the whole flow and the only
   **hard** gate.
3. **Meaningful authorship**, not raw interaction count. Fire once when the user
   has created **3 things of their own** (a list item, an expense, a chore, a
   note). Checking a seeded item does *not* count; authoring does. Three is a
   guess — make it a constant and tune it. Never fire twice in a session, and
   never within 60s of app open.
4. **Returning to a sandbox on a later day.** On the second calendar day with an
   unpromoted sandbox, the strip's copy changes once to *"Still just on this
   phone"* — the strip, not a sheet. A second session is interest, not commitment.
5. **Explicitly NOT: app backgrounding / leaving.** An exit-intent modal on a
   household app is hostile and, on mobile, unreliable. Skip it.

Everything else stays open. Nothing in lists / money / chores / kitchen /
calendar is gated. PRODUCT.md #1: the UI clears the path.

### What happens to the sandbox on signup

**Promote, don't discard** — the entire premise collapses if the user's twenty
minutes of poking evaporates.

On successful auth (guest, Google, Apple or email):

1. Create the real household server-side, named **"Flat 3B"** but with the name
   field pre-filled and **editable in the same sheet** — most people will rename
   it to their actual flat. Currency carried across from the sandbox.
2. Replay **only what the user authored** through the normal repositories. The
   seeded sample content is *dropped*, not uploaded. Concretely: the "Weekend
   groceries" list is recreated only if the user touched it, and then only with
   the items they added, plus any seeded items they explicitly checked (checking
   is a statement of intent about that item). Sam and Ines are not created as
   users — the real member list is just you, with `HubQuickStart`'s dashed empty
   seats waiting.
3. Show one confirmation, in the board idiom, of what came across: *"Kept: 1 list
   (4 items), 2 expenses, 1 chore."* Then land on `/home`.
4. Wipe the sandbox rows from Drift.

**The alternative — promoting everything including the seed —** is simpler to
build and worse to live with: the user's real household then contains a fake €42
pizza and two ghost flatmates they have to delete one by one. Reject it.

If replay proves too fiddly for v1, the acceptable fallback is: promote the
user-authored items only from **lists and expenses** (the two backed by real
Drift tables with an existing outbox path), discard authored chores/notes, and
have the confirmation name exactly what was kept. Do not silently drop things.

---

## 4. Implementation sketch

### Routing

`frontend/lib/router_redirect.dart`

- Add `'/try'` to a new `sandboxRoutePrefixes` — keep it separate from
  `publicRoutePrefixes`, because `/r/` is a *server-backed* public route and
  `/try` is a *no-server* route; the distinction will matter when the session
  bootstrap reasons about them.
- In the `!input.authState && !isAuthRoute` branch, let `/try` through exactly as
  `/r/` is let through today.
- In the `isSessionBootstrapPath` branch, add `/try` to the set of
  `continueTarget`s a signed-out visitor may keep (alongside auth and public
  routes), so a cold start into the sandbox survives bootstrap.
- **Signed-in users must not land on `/try`.** Add: if `authState` and the
  location starts with `/try`, redirect to `/home`. Otherwise a returning real
  user who taps a stale link ends up in a fake household — the worst possible bug
  here.

`frontend/lib/router.dart`

- New `GoRoute(path: '/try', name: 'sandbox', …)` using `_boardPage` so it
  crossfades from `/welcome` on the same cork surface (the existing comment on
  `_boardPage` describes exactly this intent).
- Decision to make: **does the sandbox live inside `StatefulShellRoute` or
  outside it?** Inside is what makes the bottom nav real, which is most of the
  value. Cheapest route: make the shell branches themselves sandbox-aware via a
  `sandboxModeProvider` rather than duplicating five routes under `/try/*`. `/try`
  then becomes a thin entry route that flips the provider and redirects to
  `/home`, with `router_redirect` allowing `/home` and the other shell tabs when
  sandbox is active and `authState` is false. This keeps one copy of every screen.
  It does mean the redirect resolver takes a new input field
  (`sandboxActive`) — extend `AppRedirectInput` and extend its existing pure unit
  tests.
- `currentGroupIdProvider` holds the reserved sandbox id while active; the
  existing `authStateProvider` listener that clears it on sign-out must not fight
  with that.

### Where the sandbox data lives — the real decision

**Option A — build on the existing server-backed guest account.**

Make "Look around" call `createGuest()`, auto-create a household server-side
(skipping `_Stage.choose` / `_Stage.name`), and seed it — either client-side
through the normal create APIs, or with a backend `seed=sample` flag on group
creation.

- **Pros:** almost everything already works. Real group, real invite codes, real
  sync, real settlement maths. The upgrade path is *already built*
  (`/auth/guest/convert` plus the `link=1` OAuth flow) — meaning no
  promotion/replay code at all, because the data was never local-only.
  Multi-device continuity. The guest concept and `isGuestProvider` already thread
  through `account_screen.dart`.
- **Cons:** a network round-trip and an attestation challenge (App Check /
  Turnstile) stand between the tap and the board — on a bad connection the very
  first impression is a spinner or an error toast. Every install, including every
  bot, creates a user + group + seed rows; that is a real abuse and storage
  surface needing a TTL reaper for unconverted guests. And it is dishonest about
  "nothing is saved yet" — it *is* saved, on our server, under an account the
  user didn't know they made. Offline first launch is impossible.

**Option B — purely local Drift sandbox, zero backend.**

A reserved group id (e.g. `sandbox-local`). A new seeder writes directly to the
existing Drift tables and caches: `upsertListsRows` + `upsertListItemsRows`,
`upsertExpensesRows`, `upsertFinanceSummary`, `upsertCurrentChores`,
`upsertSettlements`, `upsertPinwallPosts`, `upsertRecipesRows`, `upsertHubGroup`,
`upsertGroupsList`, `upsertMealPlanRange`, `upsertHubActivities` — every one of
those writers already exists (`storage/app_database.dart`, roughly lines
872–1580). Reads already prefer these caches. Writes need one thing:
**suppress the outbox.** The repositories already separate "optimistic local row"
from `enqueueOutbox` + `drainOutboxOnce`, so a `sandboxMode` check that skips the
enqueue and the drain is a small, well-localised change per repository.

- **Pros:** instant — no network, no spinner, no attestation; works on a plane and
  in App Store review. Zero abuse surface and zero server cost per curious
  installer. "Nothing is saved yet" is *literally true*, which matters for the
  copy and for trust. No junk accounts to reap. Signup happens exactly when the
  user chooses it.
- **Cons:** the promotion/replay step must be written (see §3) and is the real
  cost of this option. Some screens reach services directly rather than through
  repositories and will hit a null API or a 401 in sandbox mode — each needs an
  audit and a guard. Invites genuinely cannot work (correct — that's trigger 2).
  A sandbox does not survive a reinstall.

**Recommendation: Option B, with the existing guest account reused as the
*landing* for promotion.**

That is: the sandbox is local and offline (Option B's pros are exactly the
product's stated premise), and the moment the user taps "Keep this" we call the
**existing** `createGuest()` — still asking them for nothing — create the real
household, replay their authored items, and land them on the real `/home`. Email
/ Google / Apple then upgrade that guest later through the flow that already
ships (`/auth/guest/convert`, `link=1`). This gets the instant, honest,
zero-cost first launch *and* reuses every piece of the existing auth machinery
for the hard part. The only genuinely new code is the seeder, the sandbox-mode
guard, and the replay.

Reject a third option (fake read-only screenshots / a mock data layer used only
for display) outright: that is Splitwise's bait-and-switch (ref 14), and it fails
the founder's "actually poke at it" requirement.

### Files to touch

Existing:

- `frontend/lib/router.dart` — `/try` route; sandbox-aware `currentGroupIdProvider`.
- `frontend/lib/router_redirect.dart` — allow `/try` and the shell tabs while
  signed out with sandbox active; bounce signed-in users off `/try`; new
  `AppRedirectInput.sandboxActive`.
- `frontend/lib/screens/auth/welcome_screen.dart` — re-rank the three actions;
  "Look around" becomes primary; new footnote copy. Keep the invite branch as-is.
- `frontend/lib/screens/home/household_hub_screen.dart` — render the sandbox
  strip; skip `_resolveAndLoad`'s bounce-to-`/onboarding` when sandbox is active.
- `frontend/lib/repositories/list_repository.dart`, `finance_repository.dart`,
  `chore_repository.dart`, `pinwall_repository.dart`, `recipe_repository.dart`,
  `meal_plan_repository.dart` — skip `enqueueOutbox` / `drainOutboxOnce` in
  sandbox mode.
- `frontend/lib/providers/auth_provider.dart` — sandbox coexisting with
  `authStateProvider == false`.
- `frontend/lib/widgets/hub/onboarding_card.dart` — the invite slip becomes the
  hard-gate trigger in sandbox mode.
- `frontend/lib/screens/you/account_screen.dart` — an "Account → Sign in" row for
  the sandbox state (ref Vocabulary, 10).
- `frontend/lib/l10n/app_en.arb` (+ other locales) — new strings; retire or
  rewrite `welcomeContinueAsGuest` / `welcomeGuestFootnote`.
- `frontend/test/frontend_flows_test.dart` — sandbox entry, a write, and
  promotion.

New:

- `frontend/lib/sandbox/sandbox_seed.dart` — the sample household as data
  (locale-aware currency, relative dates).
- `frontend/lib/sandbox/sandbox_seeder.dart` — writes the seed into Drift.
- `frontend/lib/sandbox/sandbox_promoter.dart` — diff authored-vs-seeded, replay
  through repositories, wipe.
- `frontend/lib/providers/sandbox_provider.dart` — `sandboxModeProvider`,
  authored-item counter, ask-trigger state.
- `frontend/lib/widgets/board/sandbox_strip.dart` — the torn-paper "nothing is
  saved yet" tab.
- `frontend/lib/sheets/keep_this_sheet.dart` — the save-your-work sheet.

Backend: **none** for this plan. (Optional later: a `?seed=sample` flag on group
creation, only if Option A is ever revisited.)

### Suggested sequencing

1. Seed + seeder + `/try` route + sandbox-aware hub, read-only. Ships a
   Copilot-grade demo on its own and is independently useful.
2. Writes: outbox suppression + repository guards + the services-called-directly
   audit.
3. The strip, the sheet, and trigger 1 ("Keep this") + trigger 2 (invite).
4. Promotion / replay.
5. Triggers 3 and 4, plus copy tuning.

---

## 5. Open questions

1. **Is the sandbox a *demo of a shared flat*, or *your* flat before it's real?**
   The plan assumes the former (Sam and Ines are seeded, and are dropped on
   promotion). The alternative — an empty board named after nothing, seeded only
   with a shopping list — is more honest but far less persuasive, because
   balances and chore rotation only make sense with more than one person.
2. **What is the primary button's word?** "Look around" / "Try it" / "Start a
   board" / "See how it works". This is the single highest-leverage string in the
   app and it should be picked deliberately, not by me.
3. **How hard is the invite gate?** Proposed as the one hard wall. The softer
   alternative — let the sandbox generate a *fake* invite code that visibly does
   nothing, purely to show the QR / share sheet — demos the mechanism but risks a
   user actually sending a dead link to a flatmate, which is worse than a gate.
   Confirm the hard gate.
4. **Does the sandbox survive?** If a user pokes for ten minutes, backgrounds the
   app and returns three days later, do they find "Flat 3B" waiting (proposed:
   yes, until promoted or explicitly discarded), or a fresh sandbox? And is there
   ever an explicit "start over / clear the sample" affordance, or only "Keep
   this"?
5. **Does this replace the guest button entirely, or sit beside it?** Proposed:
   replace — "Continue as guest" and "Look around" would confuse two paths into
   one slot, and the guest account becomes an *implementation detail* of "Keep
   this" rather than a user-facing choice. Confirm nothing else in the product
   (support, App Store review notes, the billing flow) depends on guest being a
   visible first-run option.
