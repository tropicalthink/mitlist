# UX Final Audit

## CRITICAL

### UX-1: List detail screen shows mock data
**File**: `frontend/lib/screens/lists/list_detail_screen.dart`
**Description**: The list detail screen (viewing items in a shopping/todo list) uses hardcoded mock data. Users in production will see fake items that cannot be edited or saved. This is the core feature of the app and is broken.
**Fix**: Wire all API calls (list items, create item, update item, delete item, reorder).

### UX-2: Unused screens not registered in router
**Files**: `frontend/lib/screens/vault/`, `frontend/lib/screens/living_things/`, `frontend/lib/screens/recipes/`
**Description**: Vault, Living Things, and Recipes screens exist in the codebase but are not registered in the router (`router.dart`). Users cannot access these features even though the backend fully supports them.

### UX-3: No empty state guidance on first use
**File**: `frontend/lib/screens/home/groups_list_screen.dart`
**Description**: When a new user has no groups, the empty state shows "No groups yet" but doesn't clearly explain how to create or join a group. The FAB buttons (join QR, create) are present but their purpose isn't obvious.

## HIGH

### UX-4: Loading states flash briefly
**Files**: All screens with skeleton loading
**Description**: When data loads quickly (<200ms), the skeleton loading state flashes briefly before content appears. This creates visual flicker. Should use a minimum display time or debounce.

### UX-5: Error messages are generic
**File**: `frontend/lib/services/api_client.dart` and all service `_handleError` methods
**Description**: Error responses like "Invalid request" and "An unexpected error occurred" don't tell the user what to do. For validation errors, the backend returns field-level errors but the frontend discards this information.

### UX-6: No confirmation for destructive actions
**Files**: Delete list, delete expense, remove member, leave group
**Description**: Destructive actions like deleting a group, removing a member, or deleting an expense have no confirmation dialog. A single tap can cause irreversible data loss.

### UX-7: Chore skip/complete not user-scoped
**File**: `frontend/lib/screens/chores/chores_screen.dart`
**Description**: Any group member can complete or skip any chore assignment. A user can complete a chore assigned to someone else. This should either be restricted or clarified in the UI.

## MEDIUM

### UX-8: No character limits shown on input fields
**Description**: Name fields, list names, and descriptions have no visible character limits. Backend may truncate silently.

### UX-9: Password policy not shown during registration
**File**: `frontend/lib/screens/auth/signup_screen.dart`
**Description**: Password minimum length requirement (6 chars) is not shown on the signup form. Users only discover it when they get a validation error.

### UX-10: No pull-to-refresh on account screen
**File**: `frontend/lib/screens/you/account_screen.dart`
**Description**: The account screen fetches data on load but has no pull-to-refresh mechanism.

### UX-11: Settings changes give no feedback
**File**: `frontend/lib/screens/you/account_screen.dart`
**Description**: Toggling notification preferences or changing settings provides no success/error feedback. Users don't know if their change was saved.

### UX-12: Splash/welcome screen auto-advances too quickly
**File**: `frontend/lib/screens/auth/welcome_screen.dart`
**Description**: The auto-advancing PageView on the welcome screen may advance before the user has finished reading.

## LOW

### UX-13: No haptic feedback on non-list interactions
**Description**: Haptic feedback is used on list items only. Other interactions (button taps, toggles) don't use haptics.

### UX-14: Integer-only amount fields
**File**: `frontend/lib/models/finance_models.dart`
**Description**: Amounts are integers (cents), but most users expect decimal money values ($10.50 vs 1050). The input field should accept decimal and convert to cents internally.

### UX-15: No onboarding for existing users
**File**: `frontend/lib/screens/auth/onboarding_screen.dart`
**Description**: Onboarding only shows on first registration. If a user logs out and logs back in, they skip onboarding entirely. Welcome screen doesn't re-introduce features.
