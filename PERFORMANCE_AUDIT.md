# Performance Audit

## HIGH

### PERF-1: N+1 query pattern in chore rotation state rebuild
**File**: `internal/services/chore_service.go:360-397`
**Description**: `RebuildMemberOrdersForGroup` loops over all chores and calls `GetRotationState` and `UpdateRotationState` per chore. With 100 chores and 20 members, this generates 200+ individual queries instead of batch operations.

### PERF-2: List items reorder updates items one at a time
**File**: `internal/services/list_service.go:277-282`
**Description**: `ReorderItems` sends individual `UPDATE` queries per item. With 100 items, this is 100 individual round trips. Should use a batch update or `UPDATE ... CASE WHEN`.

### PERF-3: Full membership list loaded for all queries
**File**: `internal/services/chore_service.go:79-82`
**Description**: `CreateChore` calls `ListMembershipsByGroup` which loads all members. For groups with 100+ members, this adds unnecessary overhead on every chore creation.

## MEDIUM

### PERF-4: No pagination limit on some list endpoints
**File**: `internal/api/handlers/common.go:92-97`
**Description**: Pagination defaults to 50, max 500. For large lists, loading 500 items at once may be slow. Consider 50-100 as a better default.

### PERF-5: No Redis caching for frequently accessed data
**Description**: Groups, memberships, and user profiles are fetched from the database on every request. Adding a Redis cache layer with TTL would reduce database load significantly.

### PERF-6: All API responses include full user objects
**Description**: Many endpoints return full `User` model objects where a subset of fields would suffice. This increases response size and serialization overhead.

### PERF-7: Flutter app blocks on service initialization
**File**: `frontend/lib/providers/` (all service providers)
**Description**: All services use `FutureProvider` with `create()` that resolves asynchronously. Screens that `await ref.read(serviceProviderAsync.future)` block rendering until the service is ready.

## LOW

### PERF-8: No image optimization
**Description**: No image resizing, lazy loading, or progressive JPEG. Avatar images are loaded at full resolution.

### PERF-9: No bundle size optimization
**Description**: The Flutter app includes `retrofit` and `build_runner` dependencies that are declared but unused. These add to bundle size.

### PERF-10: Prometheus metrics endpoint available
**File**: `internal/api/handlers/metrics.go`
**Description**: Prometheus metrics are mounted but not authenticated. In production, this could leak request volume information.
