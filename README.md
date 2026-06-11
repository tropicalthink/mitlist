# mitlist

**The shared household. Free. Open source. Your server.**

Lists, chores, money, meal plans — all in one place. Built for flatmates who want less friction and more clarity. No accounts required. No ads. No tracking.

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

**mitlist is the only one that combines money, chores, shopping, and meals in a single native mobile app — and the only one with offline-first support and an AI scanner.**

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
| **Splitwise** | Bank/credit card import, multi-currency with exchange rates, debt simplification algorithm, receipt photos per expense, comments/activity feed per expense, email notifications. 10+ years of polish. |
| **Paprika** | Best-in-class recipe clipping (dedicated site parsers, not just AI), cook mode (full-screen step-by-step with timers), pantry management, nutritional auto-calculation, grocery aisle ordering. The gold standard for recipes. |
| **Tody** | Gamification (streaks, effort levels), room-by-room chore views, visual progress. Makes chores feel like a game. |
| **Bring! / AnyList** | Real-time list sync (instant, not polling), barcode scanning with product database, store aisle organization, Apple Watch + Siri integration. |

---

## Self-host in 5 minutes

```bash
git clone https://git.vinylnostalgia.com/mo/mitlist.git
cd mitlist
cp backend/.env.example backend/.env  # edit with your settings
docker compose --profile prod up -d
```

That's it. PostgreSQL, Redis, and the Go API start automatically. Point the Flutter app at your server and you're done.

See [backend/README.md](backend/README.md) for detailed configuration.

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
- **Offline-first** — Works without internet. Syncs when you're back online.
- **Scanner** — OCR recipes, receipts, and lists from photos.
- **Notifications** — Push (web) + in-app notifications for chores, expenses, and reminders.
- **Multi-household** — Switch between households. One account, many groups.

---

## Your data, your rules

- **No account required** — Your server, your data. Connect the app directly to your instance.
- **Export everything** — Download expenses as CSV or JSON anytime from the app.
- **No lock-in** — Delete your account and your data is gone from the server. Export first if you want it.
- **No telemetry** — We don't collect usage data, analytics, or crash reports from self-hosted instances.

---

## Download

| Platform | Link |
|----------|------|
| iOS | [App Store](#) |
| Android | [Google Play](#) |
| Web | [mitlist.app](#) |
| Self-host | `docker compose --profile prod up -d` |

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
