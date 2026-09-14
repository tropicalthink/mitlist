# mitlist documentation

This directory is the source for the launch documentation planned for
`docs.mitlist.me`. Product instructions must match the five app locales (English,
German, Spanish, French, and Dutch); infrastructure and contributor material may
launch in English first.

## Launch information architecture

- Getting started: accounts, households, invitations, roles
- Lists: shared lists, claims, shopping trips, stores, prices
- Chores: schedules, rotation, supplies, reminders
- Money: expenses, split modes, currencies, settlements, recurring expenses
- Meals: recipes, imports, servings, meal plans, generated shopping lists
- Calendar and pinwall: aggregate events, reminders, linked household items
- Mobile scanner: iOS/Android support, review flow, on-device processing
- Notifications: inbox, push, email, per-household preferences
- Billing: four-person free limit, Premium, moving household coverage
- Your data: export, account deletion, household deletion, retention
- Mobile beta: TestFlight and Google Play access
- Troubleshooting and known public-beta limitations
- Self-hosting: install, configure, back up, restore, upgrade, monitor
- API, Home Assistant, contributing, and security reporting

## Publishing rules

1. Prefer source-backed behavior over aspirational copy.
2. Mark platform differences explicitly. Scanning is mobile-only.
3. Do not promise complete offline behavior during public beta.
4. Never publish secrets, host addresses, credentials, or sensitive topology.
5. Changes to pricing, retention, providers, or contact addresses must also
   update `landing/src/data/site.ts`, the legal pages, `PRIVACY.md`, and README.
