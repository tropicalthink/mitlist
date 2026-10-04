# Widget contracts: golden fixtures

Shared test data for the home screen widgets (plan
`plans/047-home-widgets.md`, contracts C1, C2 and C4). Every implementation
that reads or writes these formats tests against the files here:

| File | Contract | Checked by |
|---|---|---|
| `snapshot_v1.json` | C1 snapshot, with every optional field set | Go (`services/widget_service_test.go`: the server's JSON has the same keys), Dart, Kotlin and Swift parsers |
| `pending_ops_v1.jsonl` | C2 queue: one op of each type and state | Dart importer, Kotlin and Swift queue readers |
| `overlay_expected_v1.json` | C2 overlay: what a widget shows for household `1111…`, list `2222…2222` after applying the queue to the snapshot | Kotlin and Swift overlay tests |

Change a fixture only together with the contract in the plan, and keep all
four test suites passing.
