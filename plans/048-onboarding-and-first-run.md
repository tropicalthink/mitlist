# Plan 048: First run and Home — stop new users feeling lost (staged)

> **Executor instructions**: This is a staged plan. Stages 1–3 are independent
> of each other and can run in parallel on separate branches; stages 4–7 build
> on them in the order given. Implement **one stage per agent**. Before starting
> a stage, re-read "Decisions", "Current state" and that stage's section, run
> the drift check below, and confirm the cited evidence still holds (line
> numbers are as of commit `08357fc`, 2026-10-05; re-grep rather than trust
> them). Each stage has its own done criteria and STOP conditions; if a STOP
> condition occurs, stop and report rather than improvising. When a stage is
> done, update the stage table below and this plan's row in `plans/README.md`.
> The first task of each stage is to expand its section into exact steps
> against live code.
>
> **House rules that apply to every stage**: design-system components only
> (`AppCard`, `AppButton`, `AppIcon`, `mitlistAppBar`, `showAppDialog`),
> `mitlistColors` / `mitlistSpacing` tokens, 2px outlines and square corners,
> light and dark mode, ≥44dp touch targets, `tooltip` on every `IconButton`,
> every user-facing string in `frontend/lib/l10n/app_en.arb` (plus the other
> `app_*.arb` files, machine-translated is acceptable with a `TODO translate`
> note in the PR), `dart analyze lib/` + `flutter test` green before every
> commit, `go build ./... && go test ./...` for backend stages. No
> `Co-Authored-By` trailers.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat 08357fc..HEAD -- \
>   frontend/lib/router.dart \
>   frontend/lib/router_redirect.dart \
>   frontend/lib/screens/auth/ \
>   frontend/lib/screens/tour/ \
>   frontend/lib/screens/home/household_hub_screen.dart \
>   frontend/lib/widgets/hub/ \
>   frontend/lib/widgets/pinwall/pinwall_stat_rows.dart \
>   frontend/lib/providers/onboarding_provider.dart \
>   frontend/lib/l10n/app_en.arb \
>   backend/internal/services/group_service.go \
>   backend/internal/services/chore_service.go \
>   backend/internal/services/widget_service.go
> ```

## Status

- **Priority**: P1 (direct user feedback: "lost, didn't know what to do")
- **Effort**: XL overall (stages S–L each)
- **Risk**: MEDIUM: touches the first-run funnel and Home; one backend data
  fix (chore rotation) changes existing rows
- **Depends on**: none. Supersedes the "three things to know" recap from
  `onboarding-feature-tour.md`; that plan's tour survives in shortened form
  (stage 6).
- **Planned at**: commit `08357fc`, 2026-10-05
- **Research**: code audit, Mobbin flow/screen survey, web evidence review,
  2026-10-02 → 2026-10-05. Sources at the end.

## Stage table

| Stage | Title | Effort | Depends on | Status |
|-------|-------|--------|------------|--------|
| 1 | Backend: chore rotations include members who join later | S | — | TODO |
| 2 | Home summary bugs: balance is the caller's, counts are the caller's, `$`/`€` hardcodes | S | — | TODO |
| 3 | Quick add adds; dead ends get a way out | S–M | — | TODO |
| 4 | Home opens with a "Needs you" block | M–L | 2 | TODO |
| 5 | Quick start becomes a plain checklist; solo invite card stays | M | 4 | TODO |
| 6 | Shorter first run: 3-page tour, join+create on one screen, intent question replaces the recap | M–L | 5 | TODO |
| 7 | Invited members get a first run of their own | M | 1, 4, 5 | TODO |
| 8 | Measurement: activation event, funnel events, usability script | S | — (ship with or before 4) | TODO |

Status values: TODO | IN PROGRESS | DONE | BLOCKED (reason) | REJECTED (reason).

## Why this matters

Several users told us they opened mitlist, were "lost", and did not know what
to do. The audit's conclusion: mitlist does not lack onboarding; it has a lot
of it, but all of it sits **before** the person reaches their household, and
then it stops. Once inside, Home does not say what needs them, "Quick add" does
not add anything, several screens dead-end with no action, and someone who
joins through an invite link gets no orientation at all and (because of a
backend bug) is never assigned a chore that already existed.

The product principles in `PRODUCT.md` already say what Home should do: *"One
primary action per screen"* and *"What's due, clearly — overdue chores,
balances, unpurchased items immediately scannable."* The current Home violates
both. This plan brings the app back to those principles rather than adding a
new layer of tips.

## Current state (evidence, as of `08357fc`)

### First-run sequence (creator)

About 13 screens before Home:

1. `/welcome` (`screens/auth/welcome_screen.dart`): "Your household,
   organized." → **Get started** / I have an account.
2. `/tour` (`screens/tour/`): six interactive pages on a throwaway sample
   household "Flat 3B" (`tour_state.dart:171`): Why, Lists, Money, Chores,
   Recipes, Finish. Skip jumps to the last page.
3. `/signup` (`screens/auth/signup_screen.dart`): name, email, password,
   confirm password.
4. `/verify`: 8-character emailed code, blocking.
5. `/onboarding` (`screens/auth/onboarding_screen.dart`, `enum _Stage {
   choose, name, invite, ready }`): choose create/join → name + currency →
   invite code / QR / share → "Your household is ready. Three things to know."
   (Home shows what needs attention / Tabs keep each part in its place / The +
   button adds something from anywhere) → **Open {name}** → `/home`.

### Invitee sequence

`/join/CODE` signed-out → `/welcome?invite=CODE` (only "Create account to
join" / "Sign in to join") → signup → verify → `/join/CODE`
(`screens/auth/join_landing_screen.dart`, "You're in." → `goNamed('home')`,
line 127). No tour, no ready stage, no named welcome, nothing assigned.
`member:joined` is published on the SSE hub (`group_service.go:360`, `:514`)
but no client code listens for it (grep `member:joined` in `frontend/lib`
returns nothing).

### Home (`screens/home/household_hub_screen.dart:770-782`)

Body order: `HubQuickStart` (only while `hubQuickStartDismissedProvider` is
false) → `PinwallSection` → `ActivityWall`. FAB "Quick add" (`:670`) →
`showQuickAddSheet`.

- "At a glance" lives inside the cork board under the note composer and starts
  collapsed: `bool _expanded = false;` (`widgets/hub/pinwall_section.dart:390`),
  toggled only by tap.
- **Balance row is always "$0 · settled"**: `pinwall_stat_rows.dart:275` sums
  `b.total` over all members; `BalanceEntry.Total = Paid − Owed` per member, so
  the household sum is zero by construction. Currency symbol is a hardcoded
  `$` (`:288-291`) and `_formatCents` drops cents (`:249`).
- Chores row counts household-wide due/overdue, not the caller's. Lists row
  counts lists, not open items.
- Quick-start steps (`widgets/hub/onboarding_card.dart`): Create a list / Add
  a chore / Track an expense, drawn as rotated "ghost" paper scraps at low
  alpha; the "Invite flatmates" slip never counts toward progress; the whole
  strip returns `SizedBox.shrink()` once `doneCount == steps.length`
  (`:118`), so invitees to an established household never see it and the
  invite prompt vanishes for a solo founder after three steps. Dismissal is a
  global `SharedPreferences` bool (`providers/onboarding_provider.dart`,
  `hub_quick_start_dismissed`, not per household); the restore row is on the
  You screen (`account_screen.dart:825-836`) while the toast says "Account".

### Quick add (`widgets/hub/quick_add_sheet.dart`)

Every option only navigates: `goNamed('money')` (`:26`), `goNamed('lists')`
(`:35`), `goNamed('chores')` (`:44`), `pushNamed('shoppingTrip')` (`:58`).
"Start shopping trip" in a new household lands on
`shoppingTripNoLists` with no action
(`screens/shopping/shopping_trip_screen.dart:580`).

### Dead ends and false signals

- Meal plan with no recipes: `mealPlanNoRecipes` with no button
  (`screens/meal_plans/meal_plan_screen.dart:855`).
- Calendar empty state: no add action (long-press only).
- Money → Settlements with no expenses: confetti + "All settled up!"
  (`screens/money/expenses_screen.dart:285`, `_hasPlayedConfetti`).
- First recipe defaults to private ("Save for household" off,
  `screens/recipes/recipe_creation_screen.dart:71-74`).
- Chores/Lists/Kitchen/Money each show two primary buttons for the same action
  (empty-state CTA + FAB).

### Backend: later joiners never enter chore rotations

`chore_service.go:140-156` snapshots `member_order` at chore creation.
`RebuildMemberOrdersForGroup` (`:918`) and its alias `SyncMemberOrderForGroup`
(`:970`) have **no non-test callers**. `GroupService.JoinGroup`
(`group_service.go:327`) and `ApproveClaim` (`:477`) do not call either, and
`GroupService` has no reference to `ChoreService` (`:29-34`). Result: a chore
created before a member joins rotates among the original members forever.

### Vocabulary drift

Tour says "Recipes", the tab says "Kitchen" (`navKitchen`). Toast says
"Account", the tab says "You". "Pinwall", "Pin it", "Open board", "At a glance"
are never introduced (the tour skips the pinwall). Kitchen and Lists use
near-identical icons (`icons.dart:34` `format_list_bulleted` vs `:54`
`format_list_numbered`).

### What already exists that helps

| Asset | Where | Use |
|---|---|---|
| Per-caller balance already computed | `backend/internal/services/widget_service.go:279` `widgetBalance` | Reuse for the Home Balance row and the "Needs you" block |
| Per-caller snapshot (open items, due chores, tonight's meal, balance) | `GET /widget/snapshot`, `widget_service.go` | The "Needs you" data shape already exists; expose the same shape to the app or reuse the service |
| Creation sheets callable from anywhere | `CreateListSheet`, `ChoreCreationSheet.show`, `ExpenseCreationSheet.show` (already used by `onboarding_card.dart`) | Quick add can open them directly |
| Guest accounts | `auth_service.dart` `createGuest()` | Lets stage 6 defer the email gate |
| Nav badges | `providers/nav_badge_provider.dart` | Same counts the "Needs you" block should show |
| Tests to extend | `test/hub_quick_start_test.dart`, `test/household_hub_screen_test.dart`, `test/onboarding_screen_test.dart`, `test/join_landing_screen_test.dart`, `test/welcome_screen_test.dart` | Keep green; add cases per stage |

## Decisions

These were taken during research; executors follow them and do not reopen them
without a founder note.

1. **Teach in context, not up front.** The "three things to know" recap goes;
   each thing it claimed becomes true on the screen itself (Home shows what
   needs you; + really adds). Evidence: NN/g found tutorial viewers no more
   successful than non-viewers and rating tasks as harder.
2. **Checklist, not seeded sample data.** Where references disagree
   (Chime/Deel/Hatch checklist widget vs Todoist/Craft/Angi seeded starter
   content), mitlist keeps a checklist. Sample chores or expenses in a
   *shared* household could be mistaken for real obligations. Suggestions are
   offered as tappable chips the person chooses, never pre-inserted.
3. **One primary action per screen.** Where an empty state has a CTA, the FAB
   is hidden (or the reverse), never both.
4. **The checklist launches real actions, pre-ticks "Household created",
   includes "Invite someone", and collapses rather than disappearing.** It
   stays available per household, not per device.
5. **Home order**: Needs you → Quick start (while incomplete) → Pinwall →
   Activity. The pinwall is a feature, not the front door.
6. **Invitees are a first-class path.** They get a named welcome ("Sam
   invited you to Flat 3B"), land inside the household, and get their own
   three-step checklist (tick an item, claim or complete a chore, see your
   balance).
7. **Shorten, don't delete, the pre-signup tour**: ≤3 pages (Lists, Money,
   Chores), skippable from page 1, no sample pinwall. Join and create live on
   one screen. One intent question ("What do you want to sort out first?")
   replaces the recap and picks the first checklist step.
8. **Email verification stops blocking.** The person uses the household
   first; the code is asked for from an inline banner/row, and only gates
   actions that need a verified address (inviting by email, billing). STOP if
   the backend requires verification for group creation — report instead of
   loosening server checks without a founder note.
9. **Names**: the tab is "Kitchen" everywhere (tour copy changes to match),
   the account tab is "You" everywhere, and the Kitchen icon becomes a
   food/cooking glyph. "Pinwall" is introduced once, on its own empty state.
10. **No new l10n hardcodes**; the stage-2 fixes remove the known ones.

## Stages

### Stage 1: Backend — chore rotations include later joiners (S)

**Files**: `backend/internal/services/group_service.go`,
`backend/internal/services/chore_service.go`, container wiring
(`backend/internal/api/...` where services are constructed; grep
`NewGroupService`), tests in `backend/internal/services/`.

**Steps**
1. Give `GroupService` an optional collaborator for rotation rebuilds. Prefer a
   small interface (`memberOrderSyncer { SyncMemberOrderForGroup(ctx, groupID) error }`)
   with a `SetMemberOrderSyncer` setter, mirroring `SetHub`, so the existing
   constructor signature and mocks stay valid.
2. Call it after a successful membership change in `JoinGroup`
   (`group_service.go:327-362`) and `ApproveClaim` (`:477-514`), and after a
   member leaves/is removed (grep `LeaveGroup`, `RemoveMember`). Log and
   continue on error; joining must not fail because a rebuild failed.
3. Confirm what `RebuildMemberOrdersForGroup` does with chores whose
   `member_order` was customised by hand (if that exists): it must append new
   members, not reset a deliberate order. If the function resets, adjust it to
   append-missing / remove-gone instead, and say so in the PR.
4. Wire the real `ChoreService` into `GroupService` in the container.
5. Tests: join → existing chore's member order now contains the new member;
   approve claim → same; remove → member gone; rebuild failure does not fail
   the join.
6. Run a one-off backfill (SQL or a `cmd/` admin command, executor's choice,
   documented in the PR) that rebuilds member orders for every group, since
   production rows are already wrong. Do **not** run it against prod yourself;
   note it in the PR under "Deploy steps" (see `mitlist-prod-deploy` memory:
   migrations/one-offs are applied manually).

**Done when**: tests above pass; `go build ./... && go vet ./... && go test ./...`
clean; AGENTS.md unchanged unless a new endpoint/migration is added.

**STOP if**: `member_order` has semantics beyond "rotation participants"
(e.g. it encodes assignment history), or chores reference members by position
anywhere else.

### Stage 2: Home summary bugs (S)

**Files**: `frontend/lib/widgets/pinwall/pinwall_stat_rows.dart`, the
provider feeding it (grep `balances` / `FinanceSummary` in `frontend/lib/providers`),
`frontend/lib/widgets/hub/pinwall_section.dart`, and the three hardcode sites
below.

**Steps**
1. Balance row shows the **caller's** net position in the household currency,
   formatted with the same currency formatter the Money screen uses (grep
   `formatCurrency` / `NumberFormat` in `screens/money`). Cents kept. Copy:
   "You owe €12.50" / "You're owed €8.00" / "Settled up" / "No expenses yet"
   (distinguish "nothing to settle" from "nothing recorded"; Decision 1 and
   the Settlements confetti bug share this root).
2. Chores row counts the caller's due + overdue chores (same source as
   `navBadgeCountsProvider`), copy "2 due · 1 overdue" / "Nothing on you".
3. Lists row counts open items across lists, copy "14 to buy" / "Lists are
   empty".
4. "At a glance" defaults to expanded; stage 4 relocates it. Keep the toggle.
5. Remove hardcodes: `€` in `shopping_trip_screen.dart:431,789,1067`; `$` in
   `pinwall_stat_rows.dart`; hardcoded `'You'` and English strings in
   `widgets/money/settlement_confirmation_dialog.dart:56-65` (grep to
   confirm path); `'claimed'` in `screens/lists/list_detail_screen.dart:1519`.
6. Guard `posts.value!` in `pinwall_section.dart` (around `:214`, "Open
   board" pill) with a null check.
7. Settlements tab: no confetti and no "All settled up!" when the household
   has zero expenses; show "No expenses yet" with a single "Add expense" CTA
   (`expenses_screen.dart:265-290`).

**Done when**: a widget test renders the stat rows with a two-member summary
where the caller owes money and asserts the row text; `dart analyze lib/`
clean; `flutter test` green.

**STOP if**: the summary payload the hub receives has no per-member balance
(then add it to the backend summary endpoint in this stage, reusing
`widgetBalance`).

### Stage 3: Quick add adds; dead ends get a way out (S–M)

**Files**: `frontend/lib/widgets/hub/quick_add_sheet.dart`,
`screens/shopping/shopping_trip_screen.dart`,
`screens/meal_plans/meal_plan_screen.dart`, calendar screen (grep
`calendarEmpty` in `app_en.arb`), `screens/recipes/recipe_creation_screen.dart`,
empty states of Chores/Lists/Kitchen/Money.

**Steps**
1. Quick add options open the creation sheets directly: "Add expense" →
   `ExpenseCreationSheet.show`, "Add chore" → `ChoreCreationSheet.show`,
   "Add to a list" → a list picker (or straight to the only list, or
   `CreateListSheet` when none) with the composer focused, "Pin a note" →
   pinwall composer focused. Add "Scan a receipt or list" → `/scanner`
   (mobile only; hide on web). Reuse the launch code from
   `onboarding_card.dart` rather than duplicating it.
2. "Start shopping trip" with no lists: offer **Create a shopping list**
   that opens `CreateListSheet` and returns to the trip. Hide the option in
   Quick add when there are no lists, or keep it and let it lead to the
   create sheet — executor's choice, documented.
3. Meal plan with no recipes: add primary CTA "Add a recipe" (opens recipe
   creation) and secondary "Import from a link".
4. Calendar empty state: primary CTA "Add a chore" (the most common dated
   item) and a one-line hint that long-press adds on a day.
5. First recipe: default "Save for household" **on**.
6. Chores/Lists/Kitchen/Money empty states: keep the empty-state CTA, hide
   the FAB while the empty state is showing (Decision 3). Empty-state copy
   says what the person gets, not how the card behaves.
7. Empty-state suggestion chips (Decision 2): Chores → 6 common chores (Take
   out bins, Clean bathroom, Vacuum, Kitchen surfaces, Water plants, Empty
   dishwasher) each prefilled into `ChoreCreationSheet`; Lists → "Groceries"
   / "Household supplies" / "To do" create a named list. Strings in l10n.

**Done when**: widget tests for Quick add assert each option opens its sheet
(use the existing `test/household_hub_screen_test.dart` overrides);
`flutter test` green; `dart analyze lib/` clean; a manual pass on a fresh
household reaches an expense, a chore and a list item from Home in ≤2 taps each.

**STOP if**: `ExpenseCreationSheet` / `ChoreCreationSheet` require a
`groupId` the hub does not have in context (then thread it through from
`currentGroupIdProvider`, do not create a new provider).

### Stage 4: Home opens with a "Needs you" block (M–L) — depends on 2

**Files**: `screens/home/household_hub_screen.dart`, new
`widgets/hub/needs_you_section.dart`, `widgets/hub/pinwall_section.dart`,
providers (reuse `navBadgeCountsProvider`'s sources; consider a
`homeSnapshotProvider` mirroring `GET /widget/snapshot`), backend if a new
endpoint is needed.

**Design** (references: Asana "A task is due today" and bunq pending items,
links in Sources):
- An `AppCard` at the top of Home titled **Needs you** with up to five rows,
  each a feature-labelled line with an inline action:
  - overdue/due chore → "Chore · Take out bins · overdue 1d" → **Done** /
    **Swap**
  - amount owed → "Money · You owe Sam €12.50" → **Settle**
  - open list items → "Lists · 14 to buy on Groceries" → **Open**
  - tonight's meal → "Kitchen · Tonight: Shakshuka" → **Open**
  - a pinned reminder due today → **Open**
- Below the rows, the three count tiles from "At a glance" (chores on you /
  your balance / items to buy), always visible; `PinwallSection` loses its
  collapsed summary.
- Two distinct zero states: **"All caught up"** (household has data, nothing
  on you) vs **"Not set up yet"** (household has no chores/expenses/items),
  the latter pointing at the checklist (stage 5).
- Order of Home becomes: Needs you → `HubQuickStart` → `PinwallSection` →
  `ActivityWall`.
- The FAB must not cover the last activity row: add bottom padding equal to
  FAB height + `mitlistSpacing.lg` to the scroll view.

**Steps**
1. Decide data source: prefer one request. If the hub already fetches chores,
   lists and the finance summary separately, compose them client-side; else
   add `GET /home/snapshot` reusing `WidgetService` (same shape as the widget
   snapshot, session auth). Document the choice.
2. Build `NeedsYouSection` with loading skeleton (`hub_skeleton` pattern),
   error state, both zero states.
3. Inline actions reuse existing flows: chore complete = the same call the
   Chores tab uses (check offline outbox path, see AGENTS.md note on drains);
   Settle opens the existing settlement sheet.
4. Reorder the hub body; remove the collapsed summary from `PinwallSection`.
5. Tests: `household_hub_screen_test.dart` cases for populated, all-caught-up
   and not-set-up states.

**Done when**: Home on a populated household shows my overdue chore, my
balance and items to buy above the fold on a 360×800 viewport (screenshot in
PR); both zero states render; tests green.

**STOP if**: completing a chore from Home needs a write path that bypasses the
outbox (then route through the repository, never Dio directly).

### Stage 5: Quick start as a plain checklist; solo invite card (M) — depends on 4

**Files**: `widgets/hub/onboarding_card.dart` (rewrite; keep the public
`HubQuickStart` name so the hub import stays), `providers/onboarding_provider.dart`,
`screens/account/account_screen.dart:825-836`, `app_en.arb`.

**Design** (references: Chime, Discord Setup Progress, Splitwise "You're the
only one here!"):
- `AppCard` titled **Get the house going** with a segmented progress bar
  "2 of 5". Rows: circle check · imperative title · one-line subline ·
  chevron. Hierarchy by fill colour (done = primary fill, next = outlined
  accent, rest = neutral), **no rotation, no alpha below the disabled token**.
- Steps: ✓ Household created (pre-ticked; Nunes & Drèze endowed progress) ·
  Invite someone · Create a list · Add a chore · Track an expense. The
  intent answer from stage 6 moves its step to the first open position.
- Header chevron **collapses** to a one-line "Quick start · 2 of 5" bar;
  there is no permanent dismiss. The card hides on its own at 5/5.
- State per household, not per device: key `hub_quick_start_collapsed:<groupId>`
  in SharedPreferences (or server-side group member preference if one exists;
  grep `member_preferences`). Remove the global `hub_quick_start_dismissed`
  and the You-screen restore row; update its test.
- **Solo invite card**: while the household has one member, a separate
  `AppCard` under the checklist: "You're the only one here" · dashed empty
  member slots · **Share invite link** / **Show code**. It stays until a
  second member joins, independent of checklist progress. For an invitee into
  an established household the checklist shows the stage-7 joiner steps
  instead of the creator steps.

**Done when**: `hub_quick_start_test.dart` rewritten for the new rows and
collapse; a test for the solo card disappearing at two members; strings
localised; analyzer and tests green.

**STOP if**: a server-side per-member preference store exists but would need
a migration for this key (then use SharedPreferences and note the follow-up).

### Stage 6: Shorter first run (M–L) — depends on 5

**Files**: `screens/tour/` (`tour_pages.dart`, `tour_screen.dart`,
`tour_finish_page.dart`), `screens/auth/onboarding_screen.dart`,
`screens/auth/signup_screen.dart`, `screens/auth/verify_email_screen.dart`,
`router_redirect.dart`, `app_en.arb`, tests `onboarding_screen_test.dart`,
`welcome_screen_test.dart`, tour tests (grep `tour` in `frontend/test`).

**Steps**
1. **Tour → 3 pages**: Lists, Money, Chores (keep the sandbox interactions;
   drop Why, Recipes and the sample pinwall; the Finish page's actions move
   onto page 3's bottom sheet). "Skip" visible from page 1 and goes straight
   to signup. Rename any "Recipes" copy to "Kitchen". Check the
   `onboarding-feature-tour.md` rationale; the founder's 3–6 range is still
   met at 3.
2. **Join + create on one screen**: `_Stage.choose` shows the invite-code
   field inline (Life360 / Notion pattern), paste-aware, with "Create a new
   household" as the second action. If an `invite` param is present skip the
   screen entirely (stage 7).
3. **Name + currency**: currency defaults from the device locale with a
   small "Change" affordance; no separate step.
4. **Invite step**: keep, one screen, skippable with "Later" (Slack
   pattern); it is also the checklist's step 2, so skipping costs nothing.
5. **Intent question replaces `_Stage.ready`**: "What do you want to sort
   out first?" → Shopping lists / Splitting costs / Chores / Just looking.
   Store the answer per household (same store as stage 5) and let the
   checklist reorder on it. "Just looking" → Home unchanged. Then `/home`.
6. **Email verification stops blocking** (Decision 8): after signup, land in
   `/onboarding` immediately; show a dismissible banner on Home "Confirm your
   email to invite by email and keep your account" with the code entry inline.
   Check backend middleware for routes that require a verified email; only
   those keep the gate. Guests already skip this.
7. Signup form: drop "confirm password" (show/hide toggle instead). Keep
   Google/Apple first on the signup screen.

**Done when**: a creator who skips the tour reaches Home in ≤6 screens from
cold start (welcome → signup → join/create → name → invite-or-later → intent
→ Home; state the real count in the PR), down from ~13 today; all
auth/onboarding/tour tests updated and green; redirect tests cover the
unverified-but-signed-in state.

**STOP if**: backend rejects group creation or any core write for unverified
users (report which routes; do not change server auth policy in this stage).

### Stage 7: Invited members get a first run (M) — depends on 1, 4, 5

**Files**: `screens/auth/welcome_screen.dart`, `screens/auth/join_landing_screen.dart`,
`router_redirect.dart`, `widgets/hub/onboarding_card.dart` (joiner steps),
`services/` SSE listener (grep `domain_event` / `sse` in `frontend/lib/services`),
backend: `GET /invites/{code}` preview if it does not exist (grep `invite`
handlers), `app_en.arb`.

**Steps**
1. **Invite preview**: `/welcome?invite=CODE` fetches household name and
   inviter name (add a public, rate-limited `GET /invites/{code}/preview`
   returning `{household_name, inviter_name, member_count}` if absent) and
   shows "Sam invited you to Flat 3B" above the auth buttons. Primary
   "Continue with Google/Apple/email", secondary "I have an account".
2. After auth the invitee goes straight to the join landing; `/onboarding` is
   never shown. Join landing shows the household name, member avatars, and
   **Open Flat 3B**.
3. **Joiner checklist** (stage 5 card variant): ✓ Joined Flat 3B · Tick
   something off a list · Take or complete a chore · Check your balance.
   Shown when `member_count > 1` at join time and the household already has
   data; otherwise the creator checklist.
4. **Needs you** for a fresh joiner with nothing assigned: "Nothing on you
   yet — here's what the house is working on" with the household's open
   items (read-only), so the screen is not empty.
5. **Tell the household**: listen for `member:joined` on the client SSE
   stream and refresh members/activity; add an activity entry "Sam joined"
   on the backend if the activity table does not already record joins (grep
   `activity` in `group_service.go`).
6. Chores tab for a joiner says "Nothing on you yet" **only** if true after
   stage 1's rebuild; verify end-to-end that a pre-existing weekly chore now
   shows the joiner in its rotation.

**Done when**: `join_landing_screen_test.dart` and `welcome_screen_test.dart`
cover the preview and the direct landing; an integration test (mocked
services) walks link → signup → join → Home with the joiner checklist; the
long-deferred "guest continue with invite" case in `welcome_screen_test.dart`
is either fixed here or explicitly re-deferred in the PR.

**STOP if**: exposing household name + inviter name on an unauthenticated
preview is judged a privacy issue (ask the founder; fallback: show only
"You've been invited to a household").

### Stage 8: Measurement (S) — ship with or before stage 4

**Files**: analytics/event plumbing (grep `analytics`, `track(`, `event` in
`frontend/lib/services`; if none exists, this stage adds a minimal
backend-side event via existing activity/telemetry, not a third-party SDK
without a founder note), `backend/internal/jobs/` for the weekly rollup.

**Steps**
1. Funnel events (creator and invitee tagged separately): `welcome_shown`,
   `tour_started`, `tour_skipped(page)`, `tour_completed`, `signup_completed`,
   `household_created|joined`, `intent_answered(value)`, `first_item_added`,
   `checklist_step_done(step)`, `home_needs_you_action(type)`.
2. **Activation metric** (one number, weekly): a household is *activated*
   when, within 7 days of creation, **≥2 distinct members have each acted on a
   shared item** (completed a chore, checked a list item, added or settled an
   expense). Single-player precursor: ≥3 items added in session 1. Compute in
   a weekly job or SQL view; surface in Staffroom or the weekly summary job
   output.
3. **Usability script** (store as `plans/048-usability-script.md`): five
   sessions, creator and invitee on separate phones, questions: (1) first
   thing you'd do; (2) where you'd see what you need to do today; (3) add a
   weekly item and say what happens next; (4) get your housemate set up; (5)
   invitee with only the link: join, then "what did this app seem to be
   for?". Run before stage 6 ships if at all possible.

**Done when**: events emitted and visible in whatever store is chosen; the
activation query exists and runs; the script file exists.

## Implementation record

(empty — executors append per stage: what was built, verified, deviations)

## Open questions for the founder

1. Where does the "users were lost" feedback live? It is not in the request
   tracker (Mitlist app has four requests, none about confusion). If there
   are store reviews, emails or chat logs, their wording should inform the
   copy in stages 4–6.
2. Decision 8 (non-blocking email verification): confirm, since it touches
   abuse protection for guests/invites.
3. Stage 7 preview endpoint exposing household + inviter name to anyone with
   the code: acceptable?
4. Is dropping "Why" and "Recipes" from the tour acceptable given the
   2026-09-03 direction of 3–6 screens? (Plan keeps 3.)

## Sources (researched 2026-10-02 → 2026-10-05)

Mobbin flows and screens (patterns borrowed):
- Splitwise onboarding https://mobbin.com/flows/bd8e8a85-eb7a-4cb5-84fc-c532e572ba20 ; creating a group ("You're the only one here!") https://mobbin.com/flows/48011a8d-9b9a-4a35-870f-95460cfd3795 ; placeholder invited members https://mobbin.com/flows/211ed153-bdc6-4a16-9688-adb6532a3e04 ; groups home https://mobbin.com/screens/8d4a1f26-0dd5-488c-a257-990a28c15159
- Life360 join/create on one screen https://mobbin.com/screens/b85ca57e-6a8d-4ce7-8fc4-c6f9e1c1f865 ; invite code https://mobbin.com/screens/a3589921-f6d4-468d-a702-70c2ee835d44
- Slack create workspace (name → skippable invite → question → "Start here") https://mobbin.com/flows/5908e7aa-8a4f-4594-8b23-7c8623eb0a66
- Discord create + Setup Progress card https://mobbin.com/flows/cedad318-5f7d-4bb4-a5c6-44c7e0f1d704 ; Discord join flow (joiner checklist "Get Started 0/4") https://mobbin.com/flows/e1e37c5b-1ba8-410b-b67e-e6f21c57ee1f
- Todoist intent question https://mobbin.com/screens/aa47a527-5c42-4f26-89a8-3649314fb739 ; Notion inline invite code https://mobbin.com/flows/5ed77200-e4f1-4053-b071-aa716a704569
- Home "needs you": Asana https://mobbin.com/screens/08f13f7c-4bdd-4503-be48-10669d37eb44 ; bunq https://mobbin.com/screens/e69218fc-71c5-46dd-8554-0eb5b73155ad ; Apple Reminders https://mobbin.com/screens/84be367a-1f4e-48ac-8740-541510d01dad
- Checklists: Chime https://mobbin.com/screens/5964d1f6-e082-4612-a968-568b09e2cc8a ; Hatch https://mobbin.com/screens/1fa74fcf-3b16-43ef-bd69-cba043761086 ; Deel https://mobbin.com/screens/63e34f8f-acb6-4620-bfd6-dbb38ef1508d ; Todoist https://mobbin.com/screens/7ff218cf-1ddd-47ee-9123-72535e5f9283
- Empty states with suggestions: Greenlight chores https://mobbin.com/screens/c29f371a-6300-46d7-9fd9-de1c6416bfe8 ; Alexa lists https://mobbin.com/screens/80e57b66-0a8f-4a35-aa46-9a0d0d5f785b ; MyFitnessPal recipes https://mobbin.com/screens/133a7f94-495b-4ee4-82b2-d9f29365c488
- Create menus that create: Jobber https://mobbin.com/screens/85be30de-6c55-4b32-a446-5caff51d4595 ; ClickUp https://mobbin.com/screens/0e44273f-368a-4510-8de7-dc5c991ab92d
- Solo invite prompts: Alma https://mobbin.com/screens/5527cc36-d4e5-464e-9eef-a29f520b07fb ; Numo https://mobbin.com/screens/b1dcc56c-72c7-497d-bd4e-aa757c116ec7

Evidence:
- NN/g, mobile tutorials do not improve task success: https://www.nngroup.com/articles/mobile-tutorials/
- NN/g, empty-state design: https://www.nngroup.com/articles/empty-state-interface-design/
- Produktly 2026 benchmarks (vendor data; tour completion by step count): https://produktly.com/research/saas-onboarding-benchmarks-2026
- Chameleon product-tour benchmarks (user-initiated tours, progress indicators): https://www.chameleon.io/blog/product-tour-benchmarks-highlights
- Nunes & Drèze, endowed progress effect: https://ideas.repec.org/a/oup/jconrs/v32y2006i4p504-512.html
- MeasuringU, first click predicts task success: https://measuringu.com/do-click-tests-predict-live-site-clicks/
- Sweepy review (pre-filled rooms/chores): https://www.commonsensemedia.org/app-reviews/sweepy-home-cleaning-schedule
- OurHome review (abandoned unless recurring tasks entered early): https://www.littledayout.com/parent-review-ourhome-app-for-home-organisation-and-behaviour-management/

Evidence quality: code findings verified in this repo; Mobbin had none of the
direct household competitors (Cozi, Honeydue, AnyList, Bring!, Tricount,
Sweepy, FamilyWall); no public data exists on household-app onboarding, so the
Home and checklist designs are pattern transfers to be validated with the
stage-8 usability sessions.
