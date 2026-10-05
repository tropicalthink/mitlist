# Plan 048 usability script: "do new people know what to do?"

Five moderated sessions, 30–40 minutes each, run **before stage 6 ships** if
at all possible. Each session has two participants in the same room or on a
call: a **creator** who starts a household, and an **invitee** who only ever
receives the invite link. They use separate phones. Nobody on the team helps
them unless they are stuck for more than two minutes on one task.

The questions come from plans/048 ("Stage 8: Measurement"). The point is to
check the plan's assumptions with real first-time users: that Home's "Needs
you" card answers "what do I do today", that Quick add and the checklist
make the first steps obvious, and that an invitee understands what they
joined.

## Recruiting

- Five pairs who share, or have shared, a household: flatmates, couples,
  families. At least two pairs with someone over 40, at least one pair where
  neither works in tech.
- Neither person has used mitlist before. Ask them to bring their own phones
  (Android or iOS).
- Offer a small thank-you; say up front the session is about the app, not
  about them.

## Before each session (moderator, ~10 minutes)

1. Install the current build on both phones (TestFlight / Play internal
   testing), or have the store links ready. Do not sign in.
2. Make sure both phones can receive email (sign-up confirmation) and that the
   creator can share a link to the invitee (WhatsApp, SMS, AirDrop: whatever
   they would really use).
3. Start screen recording on both phones if they agree; otherwise one note
   taker per phone.
4. Have the note sheet below open, one per participant.

## Opening (2 minutes, read aloud)

> Thanks for helping. We're testing the app, not you; if something is
> confusing, that's exactly what we need to hear. Please think out loud: say
> what you're looking at, what you expect, and what surprises you. I'll stay
> quiet most of the time and I can't answer questions about how it works, but
> you can always say "I'd give up here." You can stop at any time.
> Is it OK if we record the screens? The recordings stay with the team and are
> deleted once we've written up our notes.

## Tasks

Give one task at a time. Read it exactly as written. Do not name buttons,
tabs or features. Note the time to the first meaningful tap and whether they
succeed without help.

### 1. First impression (creator only, ~5 minutes)

> "You and [invitee's name] have just decided to try this app for your
> household. Open it. What's the first thing you'd do?"

Let them go until they reach Home with a household, or stall.

- **Success**: reaches Home with a household they named, without help.
- **Watch for**: do they read or skip the tour; where they hesitate in sign-up
  and email confirmation; whether they understand "household"; what they
  expect after creating it.

### 2. "What do I need to do today?" (creator, ~3 minutes)

First, quietly give the creator something to find: before the session the
moderator adds, from a second account in the same household, one overdue chore
assigned to the creator and one expense the creator owes part of. (Or, if
that is not possible, ask the creator to add a chore due today first.)

> "Imagine it's tomorrow morning. Where would you look to see what you need
> to do today?"

- **Success**: points at Home's "Needs you" card within about 10 seconds and
  can say what is on it.
- **Watch for**: do they look in tabs instead (Chores, Money); do they
  understand "Needs you"; do they see the count tiles.

### 3. Add something weekly (creator, ~5 minutes)

> "You take the bins out every Tuesday. Add that, and then tell me what you
> think happens next."

- **Success**: creates a weekly chore (via Quick add, the checklist, a
  suggestion chip or the Chores tab) and can say roughly who will be asked to
  do it and when.
- **Watch for**: which entry point they choose; whether they expect it to
  rotate between people; whether they expect a reminder.

### 4. Get your housemate set up (creator → invitee, ~7 minutes)

> "Now get [invitee's name] into your household, the way you normally would
> send them something."

Hand the invitee their phone only when the link arrives.

- **Success (creator)**: finds the invite and sends the link through their
  own messaging app.
- **Watch for**: where they look for "invite"; whether the code or the link
  makes more sense to them.

### 5. Joining with only the link (invitee, ~8 minutes)

The invitee has seen none of the above. Give them only:

> "[Creator's name] sent you this. Go ahead."

When they land in the household (or stall), ask:

> "In your own words: what did this app seem to be for? And what would you do
> next?"

- **Success**: joins the right household, reaches Home without help, and
  describes the app as something for sharing household lists, chores and/or
  money.
- **Watch for**: do they understand whose household they are joining; do they
  get stuck on account creation; is Home meaningful for someone who joined a
  household that already has things in it; do they notice the chore from
  task 3 in their own rotation.

## Closing questions (both, 5 minutes)

1. "What was the most confusing moment?"
2. "Was anything there that you didn't expect or didn't need?"
3. "Would you keep using this together? What would stop you?"
4. (Invitee) "Before you joined, what did you think the link was?"

## Note sheet (one per participant)

| Task | Time to first meaningful tap | Succeeded without help? (Y / with hint / N) | Where they went first | Quotes | Moderator notes |
|------|-----|-----|-----|-----|-----|
| 1 First impression | | | | | |
| 2 What to do today | | | | | |
| 3 Weekly item | | | | | |
| 4 Invite | | | | | |
| 5 Join via link | | | | | |

Also note: device and OS, whether they skipped the tour (and on which page),
and anything they said they would give up on.

## After all five sessions

1. Within a day of each session, the moderator writes a half-page summary:
   tasks failed or helped, top three confusions, best quotes.
2. After the fifth, tally success per task across the 10 participants. A task
   that fewer than 4 of 5 relevant participants complete without help is a
   problem worth fixing before stage 6 ships.
3. Compare the qualitative findings with the product events
   (`product_events` table: where the funnel drops between `welcome_shown`,
   `tour_*`, `signup_completed` and `household_created` / `household_joined`)
   and the weekly activation number logged by the `activation-report` job.
4. Add the findings to plans/048's implementation record and turn concrete
   fixes into tasks.
5. Delete the screen recordings once the notes are written up.
