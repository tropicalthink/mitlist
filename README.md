# mitlist

**The shared household. Free. Open source. Your server.**

Lists, chores, money, meal plans — all in one place. Built for flatmates who want less friction and more clarity. Try it as a guest, no sign-up. No ads. No tracking.

---

## Why mitlist

You're already paying rent. Why pay another subscription just to split expenses or track chores?

### vs Paid alternatives

| | mitlist | Splitwise Pro | Flatastic | Bring! |
|---|---|---|---|---|
| **Expense splitting** (equal, exact, %, shares) | ✅ | ✅ | ❌ | ❌ |
| **Settlement tracking** | ✅ | ✅ | ❌ | ❌ |
| **Recurring expenses** | ✅ | ✅ | ❌ | ❌ |
| **Chores** (rotating, cron, subtasks) | ✅ | ❌ | ✅ | ❌ |
| **Shopping lists** (shared, cost tracking) | ✅ | ❌ | ✅ | ✅ |
| **Meal plans + recipes** | ✅ | ❌ | ❌ | ❌ |
| **Calendar** (all-in-one) | ✅ | ❌ | ❌ | ❌ |
| **Offline mode** | ✅ | ❌ | ❌ | ❌ |
| **Data export** | ✅ | Pro only | ❌ | ❌ |
| **Native mobile app** | ✅ iOS + Android | ✅ | ✅ | ✅ |
| **Self-hostable** | ✅ | ❌ | ❌ | ❌ |
| **Open source** | ✅ | ❌ | ❌ | ❌ |
| **Price** | **Free** | €5/mo | €4/mo | €2.50/mo |

### vs Open source alternatives

| | mitlist | [Grocy](https://grocy.info) | [Homechart](https://homechart.app) | [IHateMoney](https://ihatemoney.org) | [Actual Budget](https://actualbudget.org) |
|---|---|---|---|---|---|
| **Expense splitting** | ✅ | ❌ | ✅ | ✅ | ❌ ¹ |
| **Chore rotation** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Shopping lists** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Meal plans + recipes** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Unified calendar** | ✅ | ❌ | ✅ | ❌ | ❌ |
| **AI scanner (OCR)** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Offline-first** | ✅ | ❌ | ❌ | ❌ | ✅ |
| **Native mobile app** | ✅ Flutter | ❌ PWA only | ❌ Web only | ❌ Web only | ❌ Desktop/web |
| **Multi-household** | ✅ | ❌ | ✅ | ✅ | ❌ ¹ |
| **Data export** | ✅ CSV, JSON | ✅ API | ✅ | ✅ JSON | ✅ |
| **Docker compose** | ✅ 5 min | ✅ | ✅ | ✅ | ✅ |
| **License** | AGPL-3.0 | MIT | AGPL-3.0 | BSD | MIT |
| **GitHub stars** | – | 9.1k | 238 | 1.4k | 26.9k |

¹ Actual Budget is personal finance (envelope budgeting), not shared household expense splitting.

**mitlist's bet: it's the only one of these that combines money, chores, shopping, and meals in a single offline-first mobile app — with an AI scanner and real-time sync — and self-hosts in one `docker compose`. The trade-off is that it's younger and you have to run it yourself (see [Where mitlist is still rough](#where-mitlist-is-still-rough)).**

### What each does better than us

#### Open source

| App | Does better |
|-----|-------------|
| **Actual Budget** | Bank sync (Plaid/GoCardless), envelope budgeting, spending reports, net worth tracking, scheduled transactions, CRDT-based sync. The gold standard for personal finance. |
| **Grocy** | Inventory/pantry tracking with expiry dates, barcode scanning with product lookup (Open Food Facts), recipe ingredient scaling, equipment management, keyboard shortcuts, plugins ecosystem. Unmatched for kitchen inventory. |
| **Homechart** | Budget categories per group, store/shop integration, multilingual (8 languages), extended/blended family features. |
| **IHateMoney** | Extreme simplicity. No accounts needed for invitees — just share a link. Battle-tested since 2011. If you ONLY need expense splitting, it's lighter. |

#### Closed source

| App | Does better |
|-----|-------------|
| **Splitwise** | Bank/credit card import, per-expense comment threads, and a longer track record of edge cases. (mitlist now matches it on opt-in live FX rates, per-expense receipt photos, and email notifications.) |
| **Paprika** | Best-in-class recipe clipping (dedicated site parsers, not just AI), cook mode (full-screen step-by-step with timers), pantry management, nutritional auto-calculation, grocery aisle ordering. The gold standard for recipes. |
| **Tody** | Gamification (streaks, effort levels), room-by-room chore views, visual progress. Makes chores feel like a game. |
| **Bring! / AnyList** | Barcode scanning with a product database, store aisle organization, Apple Watch + Siri integration, and a polished published app you can install today. |

---

## Self-host in 5 minutes

```bash
git clone https://git.vinylnostalgia.com/mo/mitlist.git
cd mitlist
cp backend/.env.example backend/.env
```

Open `backend/.env` and set **strong, unique** credentials before starting:

```bash
# Generate strong passwords (run these and paste the output into .env)
openssl rand -base64 24   # use for POSTGRES_PASSWORD
openssl rand -base64 24   # use for REDIS_PASSWORD
```

Set in `backend/.env`:

```
POSTGRES_PASSWORD=<strong random value>   # REQUIRED — no default
REDIS_PASSWORD=<strong random value>      # strongly recommended
POSTGRES_USER=mitlist
POSTGRES_DB=mitlist
```

Also fill in `SECRET_KEY`, `SESSION_SECRET_KEY`, and any OAuth/API keys you need.

Then start:

```bash
docker compose --profile prod up -d
```

PostgreSQL, Redis, and the Go API start automatically. The database schema is
created on first boot (`RUN_MIGRATIONS_ON_STARTUP=true` — idempotent, safe to
leave on). Point the Flutter app at your server and you're done.

> **Security note**: DB and Redis ports are bound to `127.0.0.1` only and are
> not reachable from the public network. If you point `DATABASE_URL` at a remote
> Postgres over a public network, set `DB_SSLMODE=require` in your `.env`.

See [backend/README.md](backend/README.md) for full configuration reference.

---

## Tech stack

| Layer | Tech |
|-------|------|
| Mobile app | Flutter (iOS + Android) |
| Web app | Flutter Web PWA |
| Backend | Go (chi router, pgx, Redis) |
| Database | PostgreSQL 16 |
| Cache | Redis 7 |
| File storage | S3 / Cloudflare R2 |

---

## Features

- **Expense splitting** — Equal, exact amounts, percentages, or shares. Settlement tracking with reimbursement suggestions.
- **Chore rotation** — Round-robin, fixed assignment, or cron schedules. Subtasks, skip reasons, undo, reschedule.
- **Shopping lists** — Shared lists with item claiming, cost tracking, and automatic expense generation.
- **Meal plans + recipes** — Weekly planner, recipe clipping via AI, auto-generate shopping lists from meal plans.
- **Pinwall** — Corkboard-style household notices with reminders and entity linking.
- **Calendar** — Unified view of chores, meal plans, expenses, and reminders.
- **Offline-first** — Works without internet. Edits queue in an outbox and sync when you're back online; live updates stream over SSE when connected.
- **Scanner** — OCR recipes, receipts, and lists from photos, with an on-device grocery classifier.
- **Notifications** — Push to mobile (FCM) and web (VAPID), plus in-app notifications for chores, expenses, and reminders.
- **Multi-currency** — Record expenses in any currency; balances settle in the group's base currency. Enter the FX rate by hand, or enable an opt-in live rate feed that prefills it.
- **Multi-household** — Switch between households. One account, many groups.
- **Accounts** — Guest mode to start instantly, or sign in with email/password, Google, or Apple.
- **5 languages** — English, German, Spanish, French, Dutch.

---

## Your data, your rules

- **Your server, your data** — Connect the app directly to your instance. Guest mode means you can start without handing over an email.
- **Export everything** — Download expenses as CSV or JSON anytime from the app.
- **No lock-in** — Delete your account and your data is gone from the server. Export first if you want it.
- **No telemetry** — We don't collect usage data, analytics, or crash reports from self-hosted instances.

---

## Download

Store builds aren't published yet — the way to run mitlist today is to self-host the backend and build the Flutter app yourself (or open the web PWA against your instance).

| Platform | Status |
|----------|--------|
| iOS | Not on the App Store yet — build from source |
| Android | Not on Google Play yet — build from source |
| Web | Flutter Web PWA — build and serve, or point at your instance |
| Self-host | `docker compose --profile prod up -d` |

---

## Where mitlist is still rough

Being honest about what the comparison tables don't show:

- **No published apps.** There are no store listings or hosted instance yet. You self-host and build the client. Fine for tinkerers, not yet for your non-technical flatmate.
- **Live FX is opt-in.** A self-hosted instance can enable a live rate feed (`FX_RATE_API_URL`) that prefills each expense's exchange rate; without it, you enter the rate by hand. The prefilled rate is advisory, not a bank-grade per-expense rate lock.
- **No bank import.** Expenses are entered by hand (or scanned via OCR), with optional receipt photos attached per expense. No Plaid/GoCardless bank or card sync.
- **No pantry/inventory tracking.** Unlike Grocy, mitlist doesn't track what's in your fridge or expiry dates.
- **No barcode product lookup.** The scanner reads text; it won't resolve a barcode to a product database.
- **No per-expense comments.** There's a household activity feed, but you can't comment on or discuss an individual expense in-app yet.
- **Recipe clipping is AI-only.** No dedicated per-site parsers like Paprika, so import quality varies by source.
- **Younger and less battle-tested.** Splitwise, IHateMoney, and Actual Budget have years of edge cases worked out. mitlist doesn't yet.

If any of these are dealbreakers, one of the apps above will serve you better — and that's fine.

---

## Contributing

See [AGENTS.md](AGENTS.md) for architecture and development guidelines.

```bash
# Frontend
cd frontend
flutter pub get
flutter run

# Backend
docker compose up -d    # postgres + redis only (no profile)
cd backend
cp .env.example .env    # see comments inside for secret generation
go run ./cmd/migrate up
go run ./cmd/api
```

---

## License

AGPL-3.0 — Free forever. Share your improvements.
