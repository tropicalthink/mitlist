# Plan 046: Rank grocery suggestions with one shared household prior

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless a reviewer dispatched you and said they maintain it.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat f8302b4e..HEAD -- \
>   frontend/lib/services/household_prior_service.dart \
>   frontend/lib/services/restock_service.dart \
>   frontend/lib/services/scan/grocery_suggestion_service.dart \
>   frontend/lib/services/scan/household_suggestion_engine.dart \
>   frontend/lib/providers/grocery_provider.dart \
>   frontend/lib/storage/app_database.dart \
>   frontend/lib/repositories/list_repository.dart \
>   frontend/lib/screens/lists/list_detail_controller.dart \
>   frontend/lib/screens/recipes/recipe_creation_screen.dart \
>   frontend/lib/screens/lists/products_screen.dart \
>   frontend/lib/sheets/chore_creation_sheet.dart \
>   frontend/lib/widgets/grocery_suggestion_field.dart \
>   frontend/test/services/household_prior_service_test.dart \
>   frontend/test/services/restock_service_test.dart \
>   frontend/test/services/grocery_suggestion_service_test.dart \
>   frontend/test/services/grocery_suggestion_perf_test.dart \
>   frontend/test/services/household_suggestion_engine_test.dart \
>   frontend/test/services/local_item_promotion_service_test.dart \
>   frontend/test/storage/household_prior_queries_test.dart \
>   frontend/test/screens/lists/list_detail_controller_test.dart \
>   frontend/test/widgets/grocery_suggestion_field_test.dart \
>   frontend/test/sheets/chore_creation_sheet_test.dart \
>   frontend/test/providers/grocery_provider_test.dart \
>   frontend/test/frontend_flows_test.dart
> ```
>
> Also run `git status --short` and record pre-existing working-tree changes.
> Preserve them. Only a change newly introduced by this plan outside the Scope
> list is a STOP condition. If an in-scope file changed after `f8302b4e`, compare
> the current-state evidence below with live code; a material mismatch is a STOP.

## Revision history

- **v4 (2026-08-12)** — implemented and verified. Added the flow-test fake
  compatibility path discovered by the full-suite compile gate.
- **v3 (2026-08-12)** — makes candidate retrieval, feature ownership, context
  modes, co-occurrence statistics, cache verification, and final composer
  ordering executable. It also finds and closes a second hard gate in
  `HouseholdSuggestionEngine`, which otherwise reorders the service's results by
  prefix and silently undoes the intended crossing in the main composer.
- **v2 (2026-08-11)** — replaced v1's arithmetically inert tier blend with
  continuous features; added co-occurrence plumbing, exact pinning, DI, bounded
  history, and removed the speculative asset/popularity features.
- **v1** — rejected. Its maximum prior delta was `0.434`, below the `0.45`
  prefix-to-fuzzy tier gap, so tiers could never cross.

## Status

- **Priority**: P2
- **Effort**: M–L
- **Risk**: MEDIUM (ranking changes on every autocomplete surface and the
  zero-query restock surfaces)
- **Depends on**: none
- **Category**: intelligence / UX
- **Planned at**: commit `f8302b4e`, 2026-08-12
- **Implementation**: DONE, 2026-08-12

## Why this matters

mitlist already stores household purchase history and bought-together counts,
but its two proactive grocery surfaces use those signals behind hard gates. The
autocomplete only uses purchase count inside lexical tiers, while the running-
low strip discards anything not already overdue and anything with fewer than
three purchases. The result is locally correct but not household-predictive.

This plan creates one cached household-prior service, uses it as a real ranking
signal in autocomplete and restock, preserves exact matches, and keeps retrieval
bounded and offline. It adds query methods only: no table, migration, network
call, asset, fitted model, or inference runtime.

## Current state and failure mechanism

### The autocomplete comparator is a hard tier gate

`frontend/lib/services/scan/grocery_suggestion_service.dart:192-205` sorts by
`tier` before purchase frequency:

```dart
if (a.tier != b.tier) return a.tier.compareTo(b.tier);
final fa = freq[a.suggestion.canonicalItemId] ?? 0;
```

Prefix is tier 0, fuzzy tier 1, and semantic tier 2. A familiar lower-tier item
can never outrank a prefix result.

### Retrieval itself is gated before ranking

Changing the comparator alone is insufficient. The service runs fuzzy retrieval
only when prefix results have not filled `limit`
(`grocery_suggestion_service.dart:146`) and semantic retrieval only under the
same condition (`:171`). With eight prefix candidates and `limit: 8`, the
household's fuzzy or semantic staple never becomes a candidate.

### Candidate evidence is discarded

- Prefix rows collapse to canonical IDs at `:97-101`, losing `aliasText`.
- Fuzzy similarity exists only temporarily in `bestSim` at `:149-159`.
- Semantic cosine is discarded when matches are mapped to IDs at `:177-183`.
- `seenIds` prevents a later channel from enriching a candidate already found
  through an earlier channel.

Consequently the current representation cannot support continuous lexical
features or a reliable full-alias exact-match rule.

### The main composer adds a second hard gate

Even if `GrocerySuggestionService` returns the right order,
`frontend/lib/services/scan/household_suggestion_engine.dart:116-127` sorts the
merged list by `_queryRank` first, and `_queryRank` at `:141-148` puts names that
start with the query ahead of everything else. That would move a weak prefix
back above the familiar fuzzy result in the actual composer. Service-only tests
would miss this regression.

### The current household signal and restock rules are weak

- `_purchaseFreq` at `grocery_suggestion_service.dart:56-70` is a raw count.
- Its source, `getGroupPurchaseHistory` at
  `storage/app_database.dart:2098-2108`, returns only the newest 500 rows.
- `restock_service.dart:79` drops items with fewer than three purchases.
- `restock_service.dart:86` drops items that are not yet overdue.

### Co-occurrence cannot be used as currently plumbed

`getTopCooccurrences` (`app_database.dart:2122-2134`) requires one item ID and is
capped at ten rows. `GrocerySuggestionService.suggest` has no list context, and
`RestockService.due` accepts current names rather than canonical IDs. A new
group-wide bounded query and optional canonical context are required.

### Callers have different semantics

| Surface | Current call | Decision in this plan |
|---|---|---|
| List composer | `list_detail_controller.dart:1062` | shopping prior + open canonical list context; lexical-only for non-shopping lists |
| Recipe ingredient | `recipe_creation_screen.dart:1153` | prior enabled, no list context in v1 |
| Product editor | shared field from `products_screen.dart:445` | prior enabled, no list context |
| Chore supply | shared field from `chore_creation_sheet.dart:777` | prior enabled, no list context; supplies are groceries/household products, not chore-title text |
| Global running-low strip | `runningLowProvider` | prior enabled, no particular list context |

Recipe submission resolves canonical ingredient links later at
`recipe_creation_screen.dart:426-458`; those IDs do not exist at suggestion
time. Do not pretend recipe autocomplete can supply them without adding new
editable state. It is context-free in this plan.

### Existing performance test has no timing budget

`frontend/test/services/grocery_suggestion_perf_test.dart` verifies returned
results and the SQLite prefix query plan; it contains no stopwatch threshold.
"No budget increase" is therefore not a machine-checkable gate. v3 verifies
the architectural properties directly: one-character lookup performs no global
alias/FTS/fuzzy reads, and repeated calls reuse the cached base context.

## Commands you will need

Run commands from `frontend/` unless shown otherwise.

| Purpose | Command | Expected on success |
|---|---|---|
| Prior unit tests | `flutter test test/services/household_prior_service_test.dart` | all pass |
| Query tests | `flutter test test/storage/household_prior_queries_test.dart` | all pass |
| Suggestion tests | `flutter test test/services/grocery_suggestion_service_test.dart test/services/grocery_suggestion_perf_test.dart test/services/household_suggestion_engine_test.dart` | all pass |
| Restock tests | `flutter test test/services/restock_service_test.dart` | all pass |
| Controller/widget tests | `flutter test test/screens/lists/list_detail_controller_test.dart test/widgets/grocery_suggestion_field_test.dart test/sheets/chore_creation_sheet_test.dart test/providers/grocery_provider_test.dart` | all pass |
| Analyze | `dart analyze lib/` | exit 0, no issues |
| Full suite | `flutter test` | all tests pass |

## Scope

Only the following files may be modified or created by this plan:

```text
frontend/lib/services/household_prior_service.dart                 (new)
frontend/lib/services/restock_service.dart
frontend/lib/services/scan/grocery_suggestion_service.dart
frontend/lib/services/scan/household_suggestion_engine.dart
frontend/lib/providers/grocery_provider.dart
frontend/lib/storage/app_database.dart                             (query methods only)
frontend/lib/repositories/list_repository.dart                     (list-type read only)
frontend/lib/screens/lists/list_detail_controller.dart
frontend/lib/screens/recipes/recipe_creation_screen.dart
frontend/lib/screens/lists/products_screen.dart
frontend/lib/sheets/chore_creation_sheet.dart
frontend/lib/widgets/grocery_suggestion_field.dart
frontend/test/services/household_prior_service_test.dart           (new)
frontend/test/services/restock_service_test.dart
frontend/test/services/grocery_suggestion_service_test.dart
frontend/test/services/grocery_suggestion_perf_test.dart
frontend/test/services/household_suggestion_engine_test.dart
frontend/test/services/local_item_promotion_service_test.dart       (constructor update only)
frontend/test/storage/household_prior_queries_test.dart             (new)
frontend/test/screens/lists/list_detail_controller_test.dart
frontend/test/widgets/grocery_suggestion_field_test.dart
frontend/test/sheets/chore_creation_sheet_test.dart
frontend/test/providers/grocery_provider_test.dart                  (new)
frontend/test/frontend_flows_test.dart                              (fake compatibility)
plans/046-shared-household-prior.md                                 (this plan)
plans/README.md
```

Explicitly out of scope:

- Any `Table` class, `schemaVersion`, generated Drift file, or migration.
- `string_sim.dart`: consume its existing `normaliseText`, `stringSimilarity`,
  and `editDistance`; do not change global normalization semantics here.
- `running_low_strip.dart`: `reason` is data-only in v1; no UI redesign.
- An impressions table, fitted weights, remote configuration, or weights asset.
- Popularity, meal-plan lookahead, in-store add-item UI, and multi-item text
  entry.
- Diacritic/punctuation folding and the inaccurate `CalibratedScorer`
  "no app release" docstring; both are separate cleanup work.

## Git workflow

- Use branch `advisor/046-shared-household-prior` if a branch is requested.
- Match the repository's conventional commit style, e.g.
  `feat: implement Firebase App Check for enhanced security and abuse prevention`.
- Do not commit unrelated pre-existing work. Do not push or open a PR unless the
  operator requests it.

## Design

### 1. Separate household features, lexical evidence, and scoring

Create `frontend/lib/services/household_prior_service.dart` with these roles:

```dart
class HouseholdPriorDefaults {
  // Immutable bias, seven weights, tau, shrinkageK, restockFloor.
}

class HouseholdPriorContext {
  // Repertoire IDs, recent timestamps, cadence tails, lifetime counts,
  // bounded co-occurrence rows, totals, and vocabulary size.
}

class HouseholdPriorFeatures {
  final double familiarity;
  final double dueWeighted;
  final double cooccurrence;
  final double dayOfWeek;
}

class GroceryRankingFeatures {
  final double lexPrefix;
  final double lexSim;
  final double lexSemantic;
  final HouseholdPriorFeatures prior;
}

class HouseholdRankingScorer {
  double score(GroceryRankingFeatures features); // sigmoid(w·f + bias)
}

class ScoredPriorItem {
  final String canonicalItemId;
  final double score;
  final HouseholdPriorFeatures features;
  final int estimatedIntervalDays;
  final int daysSince;
}

class HouseholdPriorService {
  HouseholdPriorService(this._db, {DateTime Function()? clock});
  Future<HouseholdPriorContext> baseContext(String groupId); // cached 300s
  HouseholdPriorFeatures featuresFor(
    String canonicalItemId,
    HouseholdPriorContext context, {
    List<String> listContextIds = const [],
  });
  double priorOnlyScore(HouseholdPriorFeatures features); // lexical features = 0
  List<ScoredPriorItem> top(
    HouseholdPriorContext context, {
    List<String> listContextIds = const [],
    int limit = 8,
    double? floor,
  });
}
```

The prior service owns DB reads, cache, household feature math, defaults, and
the pure scorer. `GrocerySuggestionService` owns candidate retrieval and lexical
evidence, then combines that evidence with `featuresFor`. `RestockService` calls
`top`, which evaluates the same scorer with all lexical features zero. Do not
give the prior service a `score(id, context)` method that ambiguously claims to
compute lexical features it cannot see.

### 2. Fixed feature layout and attainable scenario invariants

The complete score is:

```text
score = sigmoid(bias
  + 1.8 * lexPrefix
  + 1.6 * lexSim
  + 0.9 * lexSemantic
  + 1.5 * familiarity
  + 1.5 * dueWeighted
  + 1.2 * cooccurrence
  + 0.5 * dayOfWeek)

bias = -2.2
```

Feature definitions:

| Feature | Definition | Range |
|---|---|---|
| `lexPrefix` | normalized query is a whole-string prefix of any retrieved alias or shipped canonical name | `{0,1}` |
| `lexSim` | maximum `stringSimilarity` against all retrieved aliases and all four shipped canonical names | `[0,1]` |
| `lexSemantic` | warm embedder cosine, clamped to `[0,1]`; zero when cold/absent | `[0,1]` |
| `familiarity` | recency-decayed purchase count, saturated | `[0,1)` |
| `dueWeighted` | posterior dueness × familiarity | `[0,1)` |
| `cooccurrence` | maximum smoothed lift against open canonical context | `[0,1]` |
| `dayOfWeek` | above-chance recent purchase affinity for today's weekday | `[0,1]` |

Do **not** assert the incomplete v2 inequality that ignored semantic weight.
Instead, `HouseholdPriorDefaults` validates length, finiteness, and nonnegative
weights, then asserts two concrete attainable scenarios using the real scorer:

1. A familiar fuzzy item
   `[0, .70, 0, .95, .70, .80, .50]` scores above an unfamiliar non-exact
   prefix `[1, .75, 0, 0, 0, 0, 0]` (approximately `.931 > .690`).
2. With identical prior features and equal `lexSim`, the candidate with
   `lexPrefix = 1` scores above the candidate with `lexPrefix = 0`.

Exact matches are not part of either invariant because they are pinned before
blended ranking. Tests must exercise the actual scorer, not duplicate its math.

### 3. Household feature math

Use a central immutable defaults object:

- `tau = 60 days`
- `shrinkageK = 3`
- household cadence fallback `14 days`
- cache TTL `300 seconds`
- restock floor `0.15`

All elapsed durations clamp future timestamps to zero days.

**Familiarity** uses only purchases in the recent window:

```text
x = Σ exp(-ageDays / 60)
familiarity = x / (x + 1)
```

The history accessor returns a recent-plus-cadence union. Split it in memory by
the same `since = clock() - 4 * tau`: only rows at/after `since` contribute to
familiarity/day-of-week, while the full deduplicated union contributes to
cadence and last-purchase calculations.

**Dueness** uses up to the latest ten timestamps per item, including an older
tail outside the familiarity window so quarterly purchases retain cadence:

```text
observed = median(consecutive positive gaps)       // when at least two events
w = number of observed gaps
mHat = (w * observed + 3 * householdMedian) / (w + 3)
r = max(daysSinceLastPurchase, 0) / max(mHat, 1 day)
dueness = r / (1 + r)
dueWeighted = dueness * familiarity
```

For one purchase, `w = 0` and `mHat` is the household median/fallback. Ignore
zero/negative duplicate gaps. The household median uses the per-item observed
medians for items with at least one positive gap.

**Day of week** uses recent purchases only and the device-local weekday:

```text
p = (purchasesOnTodayWeekday + 1) / (recentItemPurchases + 7)
dayOfWeek = clamp(p / (1/7) - 1, 0, 2) / 2
```

**Co-occurrence** uses lifetime aggregates because the stored pair count is
lifetime. Define every variable explicitly:

- `c_ij`: stored pair count for candidate `i` and context item `j`.
- `c_i`, `c_j`: lifetime purchase-event counts for items `i` and `j` from the
  grouped count query.
- `N`: sum of lifetime counts for all canonical items in the household.
- `V`: number of distinct canonical items with at least one lifetime purchase.

For each distinct context ID other than `i`, consider only an observed pair
with `c_ij > 0`; a missing or cap-truncated pair contributes exactly zero rather
than receiving an artificial positive lift from add-one denominators:

```text
lift(i,j) = log(((c_ij + 1) / (c_j + V)) /
                ((c_i + 1) / (N + V)))
cooccurrence = clamp(max lift(i,j), 0, 3) / 3
```

Index pair rows under a canonical `(min(id), max(id))` key, matching
`incrementCooccurrence`, so lookup is direction-independent.

Return zero when context is empty, `N == 0`, `V == 0`, or either marginal count
is absent/zero (a partially synced pair row must not manufacture affinity).
Deduplicate context IDs. The lifetime pair and marginal statistics must not be
mixed with the 240-day counts.

### 4. Bounded, deterministic DB accessors

Add query methods only to `AppDatabase`:

1. `Future<List<PurchaseHistoryTableData>>
   getGroupPurchaseHistoryForPrior(groupId, {required DateTime since,
   int recentLimit = 5000, int cadencePerItemLimit = 10})` returns the union of:
   - newest `recentLimit` rows at/after `since`, ordered by `purchasedAt DESC,
     id DESC`, and
   - latest `cadencePerItemLimit` rows per canonical item regardless of age,
     using `ROW_NUMBER() OVER (PARTITION BY canonical_item_id ORDER BY
     purchased_at DESC, id DESC)`.
   Deduplicate the union by purchase ID. This preserves a bounded recent window
   for decay while retaining sparse/quarterly cadence.
2. `Future<Map<String, int>> getGroupPurchaseCountsForPrior(groupId)` returns
   lifetime grouped counts by non-null canonical ID. Derive `N` and `V` in memory.
3. `Future<List<ItemCooccurrenceTableData>>
   getGroupCooccurrences(groupId, {int limit = 2000})` is explicitly a bounded
   strongest-pair query, **not** "all rows": order by `count DESC`,
   `lastSeenAt DESC`, `itemAId ASC`, `itemBId ASC`, then limit.
4. `Future<String?> getListType(listId)` returns the cached `ListsTable.type`;
   expose it through `ListRepository.getListType` alongside existing
   `getGroupId`.

The existing `getGroupPurchaseHistory` and `getTopCooccurrences` remain
unchanged for their current consumers. Tests must cover household isolation,
recent cutoff, the older per-item cadence tail, deduplication, deterministic
co-occurrence ordering/cap, lifetime counts, and cached list-type lookup.

### 5. Explicit suggestion contexts

Define in `grocery_suggestion_service.dart`:

```dart
enum GrocerySuggestionContext {
  shoppingList,
  nonShoppingList,
  recipe,
  product,
  choreSupply,
}
```

Prior features are enabled for every value except `nonShoppingList`. Only
`shoppingList` accepts the one-character repertoire path. Context IDs affect
co-occurrence only when the prior is enabled.

Make the service contract explicit:

```dart
Future<List<GrocerySuggestion>> suggest(
  String query,
  String groupId, {
  required GrocerySuggestionContext suggestionContext,
  List<String> listContextIds = const [],
  int limit = 8,
});
```

For `nonShoppingList`, use constant-zero prior features and do not load a base
context merely to produce lexical-only ranking.

Plumb modes as follows:

- `ListDetailController` reads cached type through `ListRepository.getListType`
  during load, overwrites it with `service.getList(listId).type` after refresh,
  and maps exactly `'shopping'` to `shoppingList`; null/anything else maps to
  `nonShoppingList`. It passes distinct, unchecked `_items[].canonicalItemId`
  values to autocomplete and composer restock.
- A non-shopping list does not request composer restock suggestions; explicitly
  clear the restock source to prevent stale shopping chips after a type/load
  change.
- Recipe passes `recipe` and an empty list context.
- Make `GrocerySuggestionField.suggestionContext` required. Products passes
  `product`; chore supplies pass `choreSupply`.
- `runningLowProvider` continues to call Restock without list context.

### 6. Bounded candidate union for queries of two or more characters

Replace `_RankedSuggestion` with an internal evidence record such as:

```dart
class _CandidateEvidence {
  final String canonicalItemId;
  final Set<String> matchedAliases;
  double lexPrefix;
  double lexSim;
  double lexSemantic;
  bool isExact;
  final int firstSeen;
}
```

For every normalized query of length at least two:

1. Always run the bounded top exact-alias lookup (`findAlias`), whole-prefix,
   word-prefix, and indexed fuzzy retrieval; do not condition fuzzy on
   `ranked.length < limit`. Prefix results may add further exact collisions.
2. If the embedder is warm, always request semantic candidates; do not condition
   it on prefix count. If cold, retain the existing non-blocking warm-up.
3. The top exact-alias lookup returns at most one row. Bound the remaining
   channels independently using the existing shapes: whole prefix
   `limit * 6`, word prefix `limit * 8`, fuzzy prefilter at 400 followed by the
   best `limit * 8` above `_fuzzyFloor`, semantic `limit * 4` above
   `_semanticFloor`.
4. Merge by canonical ID. Preserve every retrieved alias needed for exact/
   similarity evidence and take `max` for all numeric features. A later channel
   enriches an existing candidate rather than being skipped by `seenIds`.
5. Batch-load canonical rows once, enrich `lexPrefix`/`lexSim` against all four
   non-empty canonical names, and drop IDs that do not resolve.
6. Compute prior features once per candidate from one cached base context.
7. Apply the final user-facing `limit` only after exact pinning and blended sort.

Stable ties use `firstSeen`, then canonical ID. This is a bounded candidate
union followed by reranking—not household-first retrieval for longer queries,
which could inject textually unrelated familiar items.

### 7. Exact matches are pinned

Before blended ranking, extract candidates where `normaliseText(query)` equals
any retrieved alias or any shipped canonical name. Sort exact candidates among
themselves by prior-only score descending, then stable tie-break, and prepend
them. A non-exact candidate can never outrank them.

The shipped graph includes canonical names as aliases (the current service
already relies on that seed convention when labeling multilingual matches), so
the exact-alias channel retrieves a full canonical-name query. The guarantee is
over candidates in the bounded union; do not add an unindexed scan over the
canonical table.

Accepted limitation: `normaliseText` lowercases, trims, and collapses whitespace
but does not fold diacritics or punctuation. Do not expand this plan into a
resolver-wide normalization change.

### 8. One-character and restock behavior

For a one-character `shoppingList` query, skip exact-alias, whole-prefix,
word-prefix, fuzzy, and semantic retrieval. Start from IDs in the household repertoire,
batch-load their canonical rows, keep candidates whose normalized canonical
name in any shipped language starts with the character, and rank using
`lexPrefix`, `lexSim`, and the prior. Empty query remains `[]` in autocomplete;
the composer uses Restock for its zero-query suggestions.

The two-character UI guards in Recipe Creation and `GrocerySuggestionField`
remain. Therefore one-character behavior is deliberately limited to the main
shopping-list composer.

`RestockService.due`:

- injects the shared prior service;
- accepts optional `listContextIds`;
- removes the fewer-than-three-purchases and overdue-only gates;
- ranks the full repertoire with lexical features zero and floor `0.15`;
- filters current names as today;
- resolves canonical display names in one batch;
- returns posterior `mHat.round()` (minimum 1) as `intervalDays`, including for
  one-purchase items, and preserves `daysSince` for existing UI copy.

Add `RestockReason { due, usual, goesWith }`, selected deterministically from
the largest weighted prior contribution (`dueWeighted`, `familiarity` plus
`dayOfWeek`, or `cooccurrence`; ties use `usual`). This is data-only in v1.

### 9. Cache and DI

Add one `householdPriorServiceProvider` and inject the same instance into
`GrocerySuggestionService` and `RestockService`. Both constructors require it;
update direct construction tests. Provide a `@visibleForTesting` getter on both
consumers so a provider test can assert instance identity without reflection.

Cache `baseContext` per group for 300 seconds. Cache the in-flight future as
well as the completed context so concurrent first calls do not duplicate reads.
Do not cache list-context-derived co-occurrence. Accept 300 seconds of stale
purchase data; do not couple `ListRepository` writes to this service.

Stamp the TTL when a load succeeds. On a failed load, remove that group's
in-flight/cache entry so the next call can retry rather than reusing a failed
future.

The injectable clock controls decay and cache expiry. Tests assert:

- two calls inside the TTL return the identical context;
- concurrent first calls share one load;
- advancing the fake clock beyond the TTL produces a new context;
- group IDs have independent cache entries.

## Implementation steps

### Step 1: Add bounded query methods and their tests

Add the four methods in Design §4 to `app_database.dart`, the list-type wrapper
to `list_repository.dart`, and
`test/storage/household_prior_queries_test.dart`. Do not touch table declarations
or generated files.

**Verify**: `flutter test test/storage/household_prior_queries_test.dart` → all
tests pass, including old cadence tail and deterministic pair cap.

### Step 2: Add the prior feature service and pure scorer

Create `household_prior_service.dart` exactly along the ownership boundary in
Design §1. Implement the recent/cadence/lifetime feature math, bounded pair map,
attainable scenario assertions, clock seam, and per-group in-flight TTL cache.

**Verify**: `flutter test test/services/household_prior_service_test.dart` →
decay, n=1/2/10 shrinkage, duplicate gaps, quarterly cadence, abandonment,
weekday chance, lift variables, empty context, both scoring scenarios, and all
cache cases pass.

### Step 3: Wire one shared provider instance

Add `householdPriorServiceProvider` in `grocery_provider.dart`, inject it into
both consumers, update direct test construction, and add
`test/providers/grocery_provider_test.dart` asserting both consumers expose the
identical prior service instance.

**Verify**:

```bash
flutter test test/providers/grocery_provider_test.dart \
  test/services/local_item_promotion_service_test.dart
```

Both pass.

### Step 4: Replace autocomplete retrieval and ranking

In `grocery_suggestion_service.dart`, add the required context enum, candidate
evidence union, exact extraction, continuous ranking, and one-character
shopping-repertoire path. Remove `_purchaseFreq`, tier fields/comments, and the
private duplicate similarity implementation in favor of `string_sim.dart`
helpers, while preserving `labelForSelection` behavior with `editDistance`.

**Verify**:

```bash
flutter test test/services/grocery_suggestion_service_test.dart \
  test/services/grocery_suggestion_perf_test.dart
```

All tests pass. The perf test uses a counting `AppDatabase` subclass plus a
counting fake embedder to prove a one-character call makes zero exact-alias,
prefix, word-prefix, fuzzy, and embedder-nearest calls; repeated calls reuse the
base context. Keep the existing full-seed query-plan assertion.

### Step 5: Prove retrieval crossing, lexical ordering, and exact pinning

Add service regressions:

- Seed at least `limit` clean prefix candidates plus one heavily familiar fuzzy
  candidate. The fuzzy item is still retrieved and ranks first. This must fail
  if either the retrieval gate or tier comparator returns.
- With equal prior, prefix ranks ahead of fuzzy.
- A candidate found through prefix and semantic channels retains both feature
  values after merge.
- Full alias (`Pringles` → `potato_chips`) and full canonical name pin first
  against a heavily familiar competitor.
- A cold/absent embedder remains fail-soft and does not block lexical results.

**Verify**: `flutter test test/services/grocery_suggestion_service_test.dart` →
all named regressions pass.

### Step 6: Stop the composer engine from undoing service order

For non-empty queries, remove `_queryRank` as a hard prefix sort. Preserve
catalog order by source priority then `sourceIndex`; catalog remains ahead of
bundled/product fallbacks, and merged identity behavior remains unchanged. For
empty queries, retain restock-first behavior.

Add a regression in `household_suggestion_engine_test.dart`: catalog source
order `[familiar fuzzy, weak prefix]` must remain in that order even though only
the second display name starts with the query. Keep merge and empty-restock
tests green.

**Verify**: `flutter test test/services/household_suggestion_engine_test.dart` →
all pass.

### Step 7: Wire context modes and canonical list context

- Add cached/remote list type state to `ListDetailController` as specified in
  Design §5.
- Pass only unchecked canonical IDs to shopping autocomplete and composer
  restock; deduplicate them.
- Skip and clear composer restock for non-shopping or unknown list types.
- Pass `recipe` with empty context from Recipe Creation.
- Make the shared field context required; pass `product` and `choreSupply` from
  its two production call sites.

Add controller tests proving shopping mode/context propagation, checked/null ID
exclusion, and non-shopping lexical-only/no-restock behavior. Widget/sheet tests
must prove their explicit modes still select suggestions.

**Verify**:

```bash
flutter test test/screens/lists/list_detail_controller_test.dart \
  test/widgets/grocery_suggestion_field_test.dart \
  test/sheets/chore_creation_sheet_test.dart
```

All pass.

### Step 8: Replace Restock hard gates with prior ranking

Implement Design §8 in `restock_service.dart`; update tests for one/two purchase
items, before-due staples, abandonment, context-driven `goesWith`, current-name
filtering, posterior interval, deterministic order, and limit.

**Verify**: `flutter test test/services/restock_service_test.dart` → all pass.

### Step 9: Run complete gates and inspect scope

From `frontend/`:

```bash
dart analyze lib/
flutter test
```

Both exit 0. Then inspect committed, staged, and unstaged paths against the
start-of-work status snapshot. No newly changed path may fall outside Scope.
On a full-seed development profile, type several two-plus-character queries
rapidly and confirm suggestions keep up with the existing 180 ms composer
debounce; a visible regression is a STOP condition.

## Test plan summary

- `household_prior_queries_test.dart`: query contract, isolation, cutoff,
  cadence tail, dedup, grouped marginals, deterministic bounded pairs, list type.
- `household_prior_service_test.dart`: all pure feature math, scenario
  invariants, quarterly/abandoned items, cache and concurrency.
- `grocery_suggestion_service_test.dart`: bounded candidate union, evidence
  merge, crossing, equal-prior lexical order, exact alias/name, fail-soft embedder.
- `grocery_suggestion_perf_test.dart`: zero global retrieval for one character,
  cache reuse, existing full-seed index plan.
- `household_suggestion_engine_test.dart`: final composer preserves catalog
  ranking and still merges sources/restock correctly.
- `restock_service_test.dart`: new repertoire semantics and reasons.
- Controller/widget/provider tests: modes, canonical context, shared DI identity.

## Done criteria

All must hold:

- [x] `cd frontend && dart analyze lib/` exits 0 with no issues.
- [x] `cd frontend && flutter test` exits 0 with all tests passing.
- [x] The `limit`-saturated crossing regression passes.
- [x] The final `HouseholdSuggestionEngine` preservation regression passes.
- [x] Exact full alias and canonical-name pin tests pass.
- [x] One-character counting test observes zero exact-alias, prefix,
  word-prefix, fuzzy, and embedder-nearest calls.
- [x] Cache identity, concurrent-load, expiry, and group-isolation tests pass.
- [x] `rg -n "_purchaseFreq|Tiers never cross|ranked.length < limit" frontend/lib/services/scan/grocery_suggestion_service.dart` returns no matches.
- [x] `rg -n "_queryRank" frontend/lib/services/scan/household_suggestion_engine.dart` returns no matches.
- [x] `git diff f8302b4e -- frontend/lib/storage/app_database.dart` shows query
  methods only: no `Table` class or `schemaVersion` change.
- [x] No generated Drift file or migration changed.
- [x] Every path newly changed after the recorded start snapshot is in Scope.
- [x] `plans/README.md` row 046 is updated to `DONE` only after all gates pass.

## STOP conditions

Stop and report rather than improvising if:

- Saturating prefix retrieval still prevents the familiar fuzzy candidate from
  entering the union.
- The crossing scenario can pass only with weights that fail equal-prior lexical
  ordering, or exact pinning cannot remain absolute.
- Making the main service rank correctly still results in a different order at
  the final composer after the engine regression is added.
- Correct co-occurrence requires mixing lifetime pair counts with windowed
  marginals, or the grouped lifetime count query cannot be implemented without
  schema work.
- The SQLite runtime used by supported targets cannot execute the window
  function for the per-item cadence tail. Report the target/runtime evidence;
  do not replace it with an N+1 query loop.
- Any `Table`, `schemaVersion`, generated Drift file, or migration must change.
- A one-character query invokes exact-alias, global alias/FTS/fuzzy, or semantic
  retrieval.
- The bounded multi-channel union makes two-plus-character composer suggestions
  visibly lag behind the existing 180 ms debounce in a full-seed manual check.
- A test or analyze gate fails twice after a reasonable in-scope correction.
- A newly required file is outside Scope.

## Maintenance notes and accepted v1 decisions

- Weights and constants are hand-set because no impression/outcome dataset
  exists. The attainable scenario tests are behavioral guardrails, not evidence
  of calibration. Fitting requires a separate collection and evaluation plan.
- The 240-day window is for familiarity/weekday behavior; the bounded latest-ten
  tail per item exists specifically so cadence is not limited to 240 days.
- Queries of length two or more use bounded multi-channel union plus blending.
  Household-first retrieval is reserved for one character to avoid unrelated
  familiar results on longer input.
- Non-shopping lists are lexical-only. Recipe, product, shopping-list, and chore-
  supply contexts retain the household prior. This is explicit and reviewable,
  not inferred from absent context IDs.
- The strongest 2,000 co-occurrence pairs are cached for five minutes. If real
  households exceed this materially, measure truncation before increasing the
  cap or designing pagination/aggregation.
- `familiarity` and `dueWeighted` are correlated by construction. If weights are
  later fitted, regularize or collapse them.
