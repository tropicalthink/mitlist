# Mitlist for Home Assistant

Mitlist is a household coordination service for shopping lists, chores,
recipes, meal plans, expenses, and reminders. This custom integration exposes
each configured household as native Home Assistant todo and calendar entities,
plus counters, due-state, live update, and connection entities.

## Installation

For a tagged release, add `https://github.com/mitlist/mitlist` to HACS as an
**Integration** custom repository and install Mitlist. You can also copy
`custom_components/mitlist` into Home Assistant's `config/custom_components`
directory and restart Home Assistant. Add **Mitlist** from Settings → Devices
& services. In Mitlist, open **You → Integrations → Home Assistant**, create a
connection, and copy the one-time integration token. Use that token and the API URL (normally
`https://api.mitlist.me`).

Release archives are built from this directory as `mitlist.zip`; HACS never
downloads the Flutter or Go application sources.

The options dialog selects households, domains, polling interval, and SSE live
updates. Tokens are kept in the config entry and are sent only over HTTPS when
SSL verification is enabled.

## Data updates

Mitlist opens one durable Server-Sent Events stream per selected household.
Event cursors survive Home Assistant restarts, so retained events are replayed
after a disconnect. Each event schedules a coordinator refresh. A configurable
five-minute poll is the default safety net when the stream is unavailable.

## Actions

The `mitlist` action namespace includes list, item, chore, recipe, meal-plan,
expense, settlement, notification, and `refresh` actions. Every action accepts
an optional `entry_id` when more than one Mitlist account is configured.

## Known limitations

- Recipes belong to the connected Mitlist account rather than a household, so
  recipe actions still require a selected household for credential scoping.
- The integration is targeting Home Assistant's Platinum engineering rules;
  it has not been reviewed or awarded a tier by the Home Assistant project.

## Troubleshooting

If entities stop updating, download diagnostics from the integration page and
check the connection sensor. An `auth_failed` state means the integration token
was revoked; create a replacement token in Mitlist and use the integration's
reauthentication flow. A `disconnected` state falls back to polling and normally
recovers without intervention.

## Removal

Remove the integration from Settings → Devices & services. This removes its
entities and local options; it does not delete Mitlist data.

## Development

Install `requirements_test.txt`, then run:

```bash
ruff format --check custom_components tests
ruff check custom_components tests
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 PYTHONPATH=. pytest -q tests
```
