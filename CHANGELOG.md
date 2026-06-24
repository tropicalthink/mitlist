# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project aims to
follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-XX-XX

### Added

- Shared shopping lists with offline-first sync (outbox + Drift), item embeddings, and OCR scanner
- Meal planning and pinwall (framed cork board with real-time SSE presence and shared notes)
- Household calendar
- Expense splitting: equal, exact, percentage, and shares modes with settlement tracking
- Chore rotation: round-robin, fixed-assignee, and cron-scheduled chores with subtask support
- Multi-household support; users may belong to multiple households
- Multi-currency support with unified currency formatting
- Grocery intelligence pipeline: on-device OCR ensemble + household-specific item prior
- Five languages (i18n): English, German, French, Spanish, Arabic
- Backend crash reporting via Sentry/GlitchTip (opt-in, env-driven)
- Frontend crash reporting via sentry_flutter (opt-in)

### Changed

- Production docker-compose secured by default: DB and Redis credentials are
  env-driven, ports are loopback-bound
- Backend integration availability (SMTP, Sentry) logged at startup via
  `LogIntegrationStatus`

### Fixed

- Offline banner correctly localizes conflict state
- Email status gated on credentials rather than defaulted SMTP host
- Pending offline items restored in original insertion order
