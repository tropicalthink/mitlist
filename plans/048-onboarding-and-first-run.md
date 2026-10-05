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
| 1 | Backend: chore rotations include members who join later | S | — | DONE (2026-10-05; prod backfill not run yet) |
| 2 | Home summary bugs: balance is the caller's, counts are the caller's, `$`/`€` hardcodes | S | — | DONE (2026-10-05) |
| 3 | Quick add adds; dead ends get a way out | S–M | — | DONE (2026-10-05; manual device pass pending) |
| 4 | Home opens with a "Needs you" block | M–L | 2 | DONE (2026-10-05; device screenshot pending) |
| 5 | Quick start becomes a plain checklist; solo invite card stays | M | 4 | DONE (2026-10-05) |
| 6 | Shorter first run: 3-page tour, join+create on one screen, intent question replaces the recap | M–L | 5 | DONE (2026-10-05; step 6, non-blocking email, REJECTED by the founder: built, then reverted) |
| 7 | Invited members get a first run of their own | M | 1, 4, 5 | DONE (2026-10-05; migration 000079 to apply by hand) |
| 8 | Measurement: activation event, funnel events, usability script | S | — (ship with or before 4) | DONE (2026-10-05; sending off until the privacy policy is updated) |

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
   **REJECTED 2026-10-05** by the founder (open question 2): verification
   stays blocking. Stage 6 step 6 was built, then reverted.
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

### Stages 1–3 — 2026-10-05 (uncommitted on `new-main-fr`, on top of `1fa5167`)

Drift check at start: nothing changed since `08357fc` in the watched paths.
de/es/fr/nl strings are machine-translated: **TODO translate** review before
release.

**Stage 1 (backend rotations): DONE.**
- `GroupService` has an optional `memberOrderSyncer` (`SetMemberOrderSyncer`,
  mirrors `SetHub`), wired to `ChoreService` in
  `internal/container/container.go`. It runs after `JoinGroup`,
  `ApproveClaim`, `LeaveGroup` and `RemoveMember` under
  `context.WithoutCancel`. A failure is logged at warn level and never fails
  the membership change.
- Step 3: the old `RebuildMemberOrdersForGroup` **reset** each rotation to
  all members sorted by user id and ignored `assignment_config`, so it would
  have added people to chores limited to named members. It now appends
  eligible newcomers, drops members who left, and keeps everyone else's
  relative order. Chores limited to named members only admit those members.
  No API lets anyone reorder `member_order` by hand; `assignment_config` is
  the only deliberate shape. `current_index` keeps the same person due next
  (or the next remaining member if that person left); in a rotation of one
  the newcomer goes next. Pending assignments are never touched. Chores are
  read in pages of 500 (the old `(0,0)` call stopped at 50).
- `BulkUpdateRotationStates` could never have worked on Postgres: a ragged
  `uuid[][]` cannot be unnested one array per row, and pgxmock hid it. It is
  now one UPDATE per row inside a transaction.
- STOP check: `member_order` only lists rotation participants, and nothing
  else references members by position. Not hit.
- Backfill: `backend/cmd/rebuild-chore-rotations` (idempotent, `-dry-run`,
  same reconcile code). **Deploy steps** (after the API image with this
  change is live; nothing has been run against prod):
  1. `cd backend && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o rebuild-chore-rotations ./cmd/rebuild-chore-rotations` (match `ssh anansi uname -m`).
  2. `scp rebuild-chore-rotations anansi:/tmp/ && ssh anansi 'chmod 755 /tmp/rebuild-chore-rotations && docker cp /tmp/rebuild-chore-rotations <api-container>:/tmp/'`
  3. Dry run and read the `rotation rebuilt` lines: `ssh anansi 'docker exec <api-container> /tmp/rebuild-chore-rotations -dry-run'`
  4. Apply: `ssh anansi 'docker exec <api-container> /tmp/rebuild-chore-rotations'`. Expect `households_failed=0`; a second run reports `rotations_changed=0`.
  5. Clean up: `ssh anansi 'docker exec -u 0 <api-container> rm /tmp/rebuild-chore-rotations; rm /tmp/rebuild-chore-rotations'`
- Verified: `go build ./... && go vet ./... && go test ./...` clean. There is
  no real Postgres on the dev machine; repository tests use pgxmock.
- Follow-ups not done: a chore completion racing a join can write back the
  old `member_order` (millisecond window; the next membership change repairs
  it). A member who leaves keeps their pending assignment. `UpdateChore` does
  not rebuild when `assignment_config` changes. Account deletion does not end
  memberships. For stage 7: `GroupService.PreviewInvite` already exists.

**Stage 2 (Home summary bugs): DONE.**
- Balance row: the caller's own `BalanceEntry.total`, in the household
  currency through the Money screen's `formatExpenseCurrency`, cents kept.
  Copy: "You owe €12.50" / "You're owed €8.00" / "Settled up" / "No expenses
  yet" (an empty summary means nothing has been recorded).
  `PinwallFinanceStatRow` takes `currentUserId`; the hub and the board pass
  `me?.id`. No backend change: the summary already has per-member entries.
- Chores row counts only `assignedToMe`: "1 due · 1 overdue" / "Nothing on
  you". This also fixes a double count (a chore due yesterday counted as both
  due and overdue). The board's index card uses the same counts.
- Lists row: unchecked items across all active lists, from
  `listItemCountsProvider` (the Lists tab's own "N left" source). Real list
  types are shopping/todo/custom; `general` is legacy. **Deviation**: copy is
  "5 items left" / "All done" / "Lists are empty" rather than "14 to buy",
  because to-do lists count too and this matches the list cards.
  **Limitation for stage 4**: a list never opened on this device only
  contributes its cached preview rows. The widget snapshot's server-side
  `OpenCount` fixes that.
- "At a glance" starts expanded; the toggle stays.
- Hardcodes removed: `€` x3 in the shopping trip (now the household currency
  via `formatCurrency`), `$` in the stat rows. The settlement dialog compared
  display labels with the English word "You", which broke in every other
  language; it now takes `payerIsMe`/`payeeIsMe` by user id, and its
  sentences and "Confirming…" are localised. "· claimed" on list rows is
  localised.
- Open board no longer force-unwraps `posts.value!`: it opens on an empty
  board that fills in from the same provider.
- Settlements tab with no money activity: no confetti and no "All settled
  up!". It shows the timeline's "No expenses yet" body (extracted as
  `ExpenseNoExpensesBody`) with its single "Add first expense" button, and
  the Money FAB is hidden while that state shows (Decision 3).
- Not changed: `navBadgeCountsProvider` still counts the household's due
  chores, not the caller's. Stage 4 should decide whether the Chores badge
  follows "Needs you".
- Tests: `test/widgets/pinwall/pinwall_stat_rows_test.dart` (two members
  where the caller owes → "You owe €12.50"; owed; settled vs nothing
  recorded; a flatmate's chore; due + overdue; lists),
  `test/screens/money/expenses_screen_test.dart` (zero expenses on both
  tabs), board test updated.

**Stage 3 (Quick add adds; dead ends): DONE except the manual device pass.**
- New `widgets/hub/hub_create_actions.dart` holds the launch code the
  checklist had (`createListAndOpen`, `addExpenseAndNotify`) plus
  `addToAList`: the only list → straight in with the composer focused;
  several → a picker; none → the create sheet. `onboarding_card.dart` uses
  these helpers.
- `PinwallComposer.show()` opens the composer in a focused sheet; the
  board's "Add a note" uses it too.
- Quick add: Add expense → `ExpenseCreationSheet`; Add to a list →
  `addToAList`; Add chore → `ChoreCreationSheet`; Pin a note → composer
  sheet; Scan a receipt or list → `/scanner` (hidden on web).
- Step 2 decision: "Start shopping trip" is **hidden** while the household
  has no lists. The trip's own no-lists state also gets "Create a shopping
  list" for the other entry points: create sheet → into the new list → back
  to a reloaded trip.
- Meal plan picker with no recipes: "Add a recipe" opens recipe creation in
  manual mode (new `entryMode` route extra / `startManual`), "Import from a
  link" opens it in URL mode. The picker reloads on return, so the new recipe
  can be picked straight away.
- Calendar week and agenda empty states: an "Add chore" button and a one-line
  hint. The hint says "In Month view" because long-press only exists there.
  The agenda's old "Chores" navigation button is replaced.
- Recipe creation: "Save for household" now defaults on for every recipe,
  not only the first. With no household the recipe saves private and the
  switch shows off.
- Chores / Lists / Kitchen / Money hide the FAB while an empty state with its
  own button is showing, including the no-household states.
  `frontend_flows_test.dart` creation tests now go through the empty-state
  button and assert the FAB is gone.
- Suggestion chips (`widgets/empty_state_suggestions.dart`): the six chores
  prefill `ChoreCreationSheet`. Groceries / Household supplies (shopping) and
  To do (todo) prefill `CreateListSheet`, then open the new list. List chips
  only show while the household has no lists at all. Nothing is created until
  the person confirms the sheet (Decision 2).
- Copy: `listEmptyAllDesc` described card snippets and now says what the
  person gets. The other empty-state copy already did.
- Tests: `test/widgets/hub/quick_add_sheet_test.dart` (each option opens its
  sheet or route; the list picker; the trip hidden with no lists).
- **Not done**: the manual pass on a fresh household (an expense, a chore and
  a list item from Home in ≤2 taps each) needs a device run.

### Stage 4 — 2026-10-05 (uncommitted, on top of stages 1–3)

**Data source (step 1): composed on the device from the cached streams; no
new endpoint.** Home already had what it needs locally: chores
(`cachedCurrentChoresByGroupProvider`), the finance summary, settlements
(new `cachedSettlementsByGroupProvider`), lists and their item counts, the
pinwall posts and today's meals (the last two are already filled by the
existing `GET /groups/{id}/home` aggregate). Reading those instead of a
`/home/snapshot` request means the card paints offline, and every local
write updates it at once: ticking a chore off here or on the Chores tab
removes the row in the same frame, with no second source of truth to keep
in step. The one gap was list counts: a list nobody opened on this device
only had its preview lines cached. `ListRepository.fetchUnsyncedItems`
fills it: Home calls it behind the cached paint, it fetches each list not
fully fetched this session once, and the Lists tab's "N left" gets the same
fix.

**Built**
- `utils/home_summary.dart`: `choresOnMe`, `myBalance`, `largestDebt`,
  `openListItems`, `remindersLaterToday`. Needs you, its tiles, the board's
  index card and the Chores nav badge all count through these.
- `widgets/hub/needs_you_section.dart`: an `AppCard` "Needs you" with up to
  five rows (at most three chores, oldest overdue first), then the three
  count tiles. Rows and actions:
  - your overdue/due chore → **Done** (`ChoreRepository.completeOfflineFirst`,
    the Chores tab's outbox path, with the same Undo toast);
  - the largest payment you owe → **Settle** (the Money tab's confirmation
    dialog, then `recordSettlementOfflineFirst`). A pair that already has a
    pending settlement is skipped, as on the Money tab;
  - a pinwall reminder later today → **Open** (the board);
  - the list with the most open items ("3 items left") → **Open**;
  - tonight's meal (dinner first, as the old "Tonight" line chose) → **Open**.
  Tapping a row opens its tab. Zero states: **All caught up** (the house has
  chores, expenses or list items, but nothing is on you; the house's list and
  meal rows still show under it) and **Not set up yet** (nothing recorded).
  Skeleton while the caches answer; a load error offers Retry.
- Count tiles: `PinwallStatRowStyle.inline` became `tile` (value + caption,
  the same pair the board's index card shows): chores on you / your balance
  / items left.
- `PinwallSection` lost its collapsed "At a glance" summary and the
  "Tonight" row (both now in Needs you).
- Home order: Needs you → `HubQuickStart` → `PinwallSection` →
  `ActivityWall`. The scroll view ends with FAB height + `lg` of clearance
  (`_kFabClearance`).
- Chores nav badge now counts only the caller's due and overdue chores (the
  same number as Needs you), not every due chore in the household.
- Strings: 15 added; 8 orphaned ones removed (`pinwallSnapshot`,
  `hubStatsActiveList(s)`, `hubStatsOpen`, `hubStatsAllDone`,
  `hubStatsOverdue`, and stage 2's `hubStatsDueCount`,
  `hubBalanceYouAreOwed`). de/es/fr/nl machine-translated: **TODO
  translate**.

**Deviations**
- No **Swap** action: mitlist has no chore swap or trade anywhere (no
  endpoint, no UI). Chore rows offer Done; skip and the rest stay on the
  Chores tab, one tap away.
- No row for "someone says they paid you, confirm it" (pending settlements
  awaiting the caller). It belongs in Needs you, but the Money tab cannot
  yet be opened on its Settlements tab; follow-up.
- The Money nav badge still counts every suggested payment in the household.

**Verified**
- Tests: `test/widgets/hub/needs_you_section_test.dart` (populated rows and
  tiles; the 5-row and 3-chore caps; All caught up; Not set up yet; a pending
  settlement hides the money row; Done → `completeOfflineFirst`; Settle →
  dialog → `recordSettlementOfflineFirst`; on 360×800 the overdue chore, the
  balance tile and items left sit above the fold), `test/utils/
  home_summary_test.dart`, `test/repositories/
  list_repository_unsynced_items_test.dart`, the hub flow test in
  `frontend_flows_test.dart` (Needs you above the pinwall, no "At a glance").
- **Not done**: the PR screenshot of a populated Home at 360×800 needs a
  device or emulator run against a real household.

### Stage 5 — 2026-10-05 (uncommitted)

**Built**
- `widgets/hub/onboarding_card.dart` rewritten; the public name
  `HubQuickStart` stays. An `AppCard` "Get the house going" with a segmented
  progress bar and "N of 5 done". Rows: circle check, imperative title, one
  line on what it gets you, chevron. Hierarchy by fill only (done = filled
  primary, next = outlined primary, rest = neutral outline); no rotation, no
  low alpha. Steps: Household created (pre-ticked) · Invite someone · Create
  a list · Add a chore · Track an expense, each launching the real action
  through `hub_create_actions.dart`.
- The intent answer (stage 6) moves its step to the first open position;
  done steps keep their place.
- The header chevron folds the card into a one-line "Quick start · 2 of 5"
  bar; no permanent dismiss; the card hides itself at 5/5.
- State is per household in SharedPreferences
  (`hub_quick_start_{collapsed,invited,intent}:<groupId>`,
  `hubQuickStartPrefsProvider`). No server-side member preference store
  exists (STOP condition not hit). Sign-out clears every
  `hub_quick_start_` key. The global `hub_quick_start_dismissed`, its
  provider, the You-screen restore row and their strings are gone.
- "Invite someone" ticks when a second member exists **or** the person
  opened the invite flow from the checklist: whether anyone joins is out of
  their hands. The solo card keeps asking until someone does.
- `HubSoloInviteCard`: while the household has exactly one member (hidden
  when the count is unknown), "You're the only one here", the seats (empty
  ones dashed; `InviteSeats` gained `emptyColor` for dark mode), **Share
  invite link** (new `InviteHouseholdSheet.shareLink`: mints a code and
  opens the system share sheet, same premium gate as the sheet) and **Show
  code** (the invite sheet). Independent of checklist progress.
- Home order: Needs you → checklist → solo card → Pinwall → Activity.
- Strings: 14 added, 5 orphaned removed (`hubQuickStartDismissedToast`,
  `accountShowQuickStart`, `accountQuickStartRestored`,
  `hubOnboardingDismiss`, `hubOnboardingInvite`). **TODO translate.**
- Not done here: the joiner variant of the checklist is stage 7.

**Verified**: `test/hub_quick_start_test.dart` rewritten (1 of 5 for a new
household, ticking, the invited flag, intent order, fold and unfold stored
per household, another household's fold not leaking, retiring at 5/5,
waiting for caches; solo card with a finished checklist, gone at two
members, quiet with an unknown count). Hub, account and flow tests green.

### Stage 8 — 2026-10-05 (uncommitted; built, **sending off until the privacy policy says so**)

- **Privacy blocker found**: `PRIVACY.md:27` and `landing/src/pages/privacy.astro:33`
  promise "no analytics … no usage profiles" (the binding German
  `datenschutz.astro` very likely too). So the client only sends when built
  with `--dart-define=MITLIST_PRODUCT_EVENTS=true`; no build sets it. Before
  turning it on: update all three legal pages (draft wording below), decide
  the TDDDG §25 question (the install id and the first-item marker are
  stored on the device: opt-in toggle, or keep the id in memory only), and
  add a retention job if the policy promises a period.
  - Draft principles bullet: "The apps and the web app carry no advertising
    trackers and no third-party analytics. To see where new households get
    stuck, the app sends a small set of usage events to our own servers (for
    example 'tour skipped on page 2', 'household created', 'chore marked done
    from Home')."
  - Draft table row: "Usage events | Event name from a fixed list, time, a
    random app-install id created on the device, once signed in your account
    id and household, and short codes such as a page number | Sent only to
    our servers, never to third parties; no IP address, device details or
    household content; used in aggregate to improve onboarding; deleted with
    your account; kept up to 12 months". Basis: Art. 6(1)(f) GDPR.
- Backend: migration `000078_add_product_events` (no IP, user agent or free
  text; user_id or install_id required); `POST /v1/events` (public, optional
  session via new `OptionalAuth` middleware, ≤20 events, name allowlist,
  props ≤6 short identifiers, per-sender burst limit on top of the global
  limit, `group_id` kept only for members, role creator/invitee); account
  deletion deletes the user's events.
- Activation (weekly `activation-report` job, Mondays 08:00 UTC, log line
  "weekly household activation"): households created 14–7 days ago where
  ≥2 distinct members each, within 7 days, completed a chore, added a list
  item (check-offs record no actor), added an expense or recorded a
  settlement. Precursor: the creator did ≥3 of those in the first hour.
  Computed from existing tables, not the new events.
- App: `lib/services/product_events.dart` (never throws or blocks, batches,
  queues up to 60, install id in SharedPreferences, inert when disabled).
  Emitted: `welcome_shown`, `tour_started/skipped/completed`,
  `signup_completed` (once the emailed code is accepted), `household_created/joined`,
  `first_item_added` (first list item, chore or expense added on this
  install in a household created or joined on this install),
  `home_needs_you_action`, `intent_answered` (stage 6). Not yet:
  `checklist_step_done`, and Google/Apple sign-ups emit no
  `signup_completed`.
- `plans/048-usability-script.md`: the five paired sessions as a moderator
  script.
- **Deploy**: apply `000078` by hand (prod does not migrate on start), deploy
  the API (the endpoint is harmless unused), update the legal pages, then
  and only then build with the define.

### Stage 6 — 2026-10-05 (uncommitted)

**Email verification (Decision 8): REJECTED by the founder, 2026-10-05**
- Step 6 was first built to the founder's 30-day rule: an unconfirmed email
  account could sign in and use the app for 30 days after it was created,
  Home showed a "Confirm your email" banner with the code field inline, and
  past the window the app held the person on `/verify`. The founder then
  cancelled the grace the same day and it was reverted on both sides: the
  server's grace window and `verify_by`, the banner, the
  `EmailConfirmationInterceptor` and its provider, the `/verify` hold, the
  store-purchase guard, their 7 strings and their tests are gone. Email
  verification blocks as it did before stage 6: the server refuses
  unverified accounts.
- What remains from step 6: sign-up has no confirm-password field;
  `AppInput`'s eye toggle has a tooltip and a screen-reader label ("Show
  password" / "Hide password"); notification emails go only to confirmed
  addresses (the backend filter in `ListMemberEmailsByGroup` is kept).
- Sign-up registers, then asks for the emailed code on the same screen;
  `signup_completed` is sent once the code is accepted.

**First run**
- Tour: 3 pages (Lists, Money, Chores); Why and Recipes are gone, the
  account choice (`tour_account_choice.dart`, was `tour_finish_page.dart`)
  sits under the sample chores on page 3, and Skip on any earlier page goes
  straight to sign-up (login when the server has no passwords).
- Join and create on one screen: the invite-code field is on the first beat
  (paste-aware, Paste and Scan buttons), "Create a household" second.
  Joining with a code goes straight Home.
- Currency is guessed from the device and shown as "Currency: EUR" with a
  "Change" link; no separate question.
- Invite beat: "Later" skips it; copying or sharing the link turns it into
  "Continue" and ticks the checklist's "Invite someone".
- The "three things to know" recap is replaced by "What do you want to sort
  out first?" (Shopping lists / Splitting costs / Chores / Just looking),
  stored per household for the checklist and sent as `intent_answered`.
- Sign-up: no confirm-password field; `AppInput`'s built-in eye toggle now
  has a tooltip and screen-reader label ("Show password"/"Hide password").
  Google/Apple stay first (the email form is folded behind a button when a
  provider is on offer).
- Screen count for a creator who skips the tour: welcome → tour page 1 →
  sign-up → join/create → name → invite (or Later) → intent → Home, i.e.
  **7 screens before Home** (6 without the tour's first page), down from
  about 13. With Google/Apple the sign-up form is one tap. The emailed code
  is asked for on the sign-up screen itself (the form gives way to the code
  field), so the count holds with verification blocking again.
- 50 strings added across stages 6 and 6b, 29 orphaned ones removed; the
  revert removed the grace's 7 (`verifyBanner*`, `verifyRequiredBody`,
  `errorConfirmEmailFirst`). **TODO translate.**

**Verified**: `onboarding_screen_test` (join/create on one screen, pasted
link → join → Home, create → currency line → Later → intent stored,
copy → Continue + invited, Just looking stores nothing),
`signup_password_test` (one password field with the eye toggle, policy
cases, a valid registration shows the code step on the same screen and
never tries to sign in), `tour_screen_test` (three pages, account choice
on page 3, Skip → sign-up). The grace's own tests went with it. Backend
`go test ./...` green after the revert.

**Known holes**: the email-squatting and past-the-window holes listed here
while the grace existed lapsed with its revert: an unconfirmed account
cannot sign in at all, as before stage 6.

### Stage 7 — 2026-10-05 (uncommitted)

**Backend**
- Migration `000079_add_invite_created_by`: `group_invites.created_by`
  (nullable, `ON DELETE SET NULL`). New codes record who minted them;
  older codes have no inviter.
- `GET /api/v1/invites/{code}/preview`, public: `household_name`,
  `inviter_name` (first name, omitted when unknown or no longer in the
  household), `member_count`, `status` (`valid` / `expired`). No ids,
  emails or the code in the body; `Cache-Control: no-store`; 20 requests a
  minute per IP on top of the global limiter; unknown or malformed codes
  are a 404. Household and inviter names on a signed-out page were
  accepted by the founder (open question 3).
- Activity feed: `member_joined` entries come from `group_memberships`
  (title = first name, `entity_type: member`); the creator's founding
  membership is left out. `member:joined` was already published on SSE.

**App**
- Welcome (`/welcome?invite=CODE`): once the public preview answers, the
  pinned note reads "Sam invited you" / "to Flat 3B · 3 people"
  (`GroupService.previewInvitePublic`, `publicInvitePreviewProvider`, null
  on any failure). Without an inviter: "You're invited" / "Join Flat 3B to
  share lists, chores and money."; expired: "This invite has expired" /
  "Ask whoever sent it for a new link."; while loading or after a failure,
  the old generic copy. The code chips and the two buttons stay (Create
  account to join / Sign in to join; Google and Apple are on the screens
  they lead to).
- After sign-up (code accepted), sign-in or Google/Apple, the invite is
  the pending destination, so the invitee lands on `/join/CODE` and never
  sees `/onboarding`.
- Join landing success: the household name, its members as initials
  circles (up to five, then "+N"; former members skipped; best effort via
  `listMembers`) and **Open {household}**, which resets the shell's
  remembered tab and goes to Home. All three join paths (link, code on the
  first-run screen, the join sheet) mark the household as joined.
- Joiner checklist (`onboarding_card.dart`): ✓ Joined {household} · Tick
  something off a list · Take or complete a chore · Check your balance,
  when the person joined and the household already has lists, chores or
  expenses; joining an empty household shows the creator's steps. Steps
  tick from markers recorded where the thing happens: ticking a list item
  (list detail), completing a chore (Chores tab, Needs you), opening Money.
  **Deviation**: the plan's "`member_count > 1` at join time" became
  "joined on this device and the household has data", which needs no
  extra state and covers the same case.
- Needs you for a joiner with nothing on them, in a household in use:
  "Nothing on you yet" / "Here's what the house is working on." with up to
  two housemates' due or overdue chores, read-only ("· Not your turn"),
  then the house's list and meal rows. A joiner into an empty household
  sees "Not set up yet", like its creator.
- Home listens on the SSE stream for `member:joined`, `member:left` and
  `member:removed` in the current household: it refreshes the household
  cache (the member count behind the solo invite card and the checklist's
  invite step) and the activity feed in place through the
  `HubRepository`'s watch, without the skeleton. The pinwall section holds
  the stream's connection; Home only listens.
- Activity wall: `member_joined` reads "{name} joined · {when}", the same
  shape as the other activity lines.
- 18 strings added. **TODO translate.**
- Step 6: the Chores tab's "Nothing on you right now" is computed from the
  caller's own assignments, so it only shows when true. That a weekly
  chore created before the join takes the joiner into its rotation is
  covered by stage 1's service tests; not run against a real Postgres
  (there is none on the dev machine).

**Verified**
- `test/join_landing_screen_test.dart`: members as initials (former member
  skipped, every name read out), five faces and "+2", a failed roster
  still lets them in, **Open My House** → Home with the remembered tab
  reset and the joined marker stored.
- `test/welcome_screen_test.dart`: preview with an inviter, without one,
  expired, failed lookup.
- `test/hub_quick_start_test.dart`: joined + data → the four joiner steps,
  the markers ticking them to 3 of 4 and then retiring the card; joined +
  empty household → creator steps; another household's join does not
  leak.
- `test/widgets/hub/needs_you_section_test.dart`: the fresh joiner state
  (two housemates' chores, most overdue first, no actions); once something
  is on them, the usual rows; an empty household → "Not set up yet".
- `test/frontend_flows_test.dart`: an integration walk with mocked
  services and the app's own redirect rules: `/join/sunny-taco` signed out
  → welcome "Sam invited you" → Create account to join → sign-up → code →
  join landing (never `/onboarding`) → Accept → members → Open Flat 3B →
  Home with "Nothing on you yet" and the joiner checklist at 1 of 4. A
  second test: a `member:joined` event refreshes the member count (the
  solo card goes) and the feed ("Sam joined · today") without the
  skeleton; another household's event is ignored.
- The long-deferred "guest continue with invite" case in
  `welcome_screen_test.dart` is **re-deferred**: since 2026-07 it asserts
  that the invite landing offers no guest door, and it passes. Whether an
  invitee may join as a guest is still a product question; the test pins
  today's answer.
- Full `flutter test --no-pub`: PASSED passed, SKIPPED skipped, 0 failed.
  `cached_groups_provider_test` now uses an in-memory database: it opened
  the app's on-disk drift database, and its test process exited uncleanly
  about half the time (also seen in the earlier stages' runs).
  `dart analyze lib/`: only the known info in `storage/app_database.dart`
  (`test/` has 7 infos, all in files no stage touched). Backend
  `go build ./... && go vet ./... && go test ./...` green.

### Deploy steps (stages 1, 7 and 8)

Prod does not run migrations on start. In this order:
1. Apply `000078_add_product_events` (stage 8) and
   `000079_add_invite_created_by` (stage 7) by hand, **before** deploying
   the API image: the new API reads and writes `group_invites.created_by`,
   so an image ahead of `000079` breaks inviting and joining.
2. Deploy the API image.
3. Once it is live, run the stage-1 backfill
   `backend/cmd/rebuild-chore-rotations`, dry run first (steps under
   stage 1 above).
4. Product events stay off (no build sets `MITLIST_PRODUCT_EVENTS`) until
   the privacy policy is updated and the TDDDG question is decided
   (stage 8).

## Open questions for the founder

1. Where does the "users were lost" feedback live? It is not in the request
   tracker (Mitlist app has four requests, none about confusion). If there
   are store reviews, emails or chat logs, their wording should inform the
   copy in stages 4–6.
2. Decision 8 (non-blocking email verification): confirm, since it touches
   abuse protection for guests/invites.
   **Answered 2026-10-05: no; verification stays blocking.** The founder
   first chose a 30-day grace (an unconfirmed email account could sign in
   and use the app for 30 days after it was created, then be blocked until
   it confirmed), and stage 6 built it; the founder cancelled it later the
   same day, and it was reverted. Decision 8 is rejected. The finding
   stands: the server refuses unverified accounts everywhere (`Login`,
   `validateCurrentUser`, and `requireActiveVerifiedUser` in the list,
   chore, pinwall, attachment and template services), so a non-blocking
   email step would be a server policy change, not app work alone.
3. Stage 7 preview endpoint exposing household + inviter name to anyone with
   the code: acceptable?
   **Answered 2026-10-05: yes.** The preview may show the household name and
   the inviter's name (stage 7).
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
