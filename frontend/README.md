# mitlist — Frontend

Shared household coordination app. Flutter (Dart, Riverpod, go_router, Drift).

## Setup

```bash
cd frontend
flutter pub get
```

## Running

```bash
flutter run                    # Run on connected device/emulator
flutter run --release          # Release build
```

## Testing

```bash
dart analyze lib/              # Static analysis
flutter test                   # Run all tests
flutter test --coverage        # With coverage
```

### Test patterns

The test suite at `test/frontend_flows_test.dart` uses mocked services via Riverpod provider overrides:

```dart
await _pumpScreen(
  tester,
  child: const ChoresScreen(),
  overrides: [
    groupServiceProviderAsync.overrideWith((ref) async => fakeGroupService),
    choreServiceProviderAsync.overrideWith((ref) async => fakeChoreService),
  ],
);
```

For screens with animations (shimmer, Lottie), use `_pumpAfter()` instead of `pumpAndSettle()`:

```dart
Future<void> _pumpAfter(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) await tester.pump(const Duration(milliseconds: 300));
}
```

### Architecture

```
lib/
  main.dart                     # Entry point
  app.dart                      # MaterialApp.router, offline banner, error reporter
  router.dart                   # GoRouter config (ShellRoute for bottom nav)
  models/                       # Data classes with fromJson/toJson
  services/                     # Dio API clients
  providers/                    # Riverpod providers
  repositories/                 # Drift + remote (offline-first)
  screens/                      # One subfolder per feature
  sheets/                       # Bottom sheet forms
  widgets/                      # Design system components
    hub/                        # Hub screen sub-widgets
  theme/                        # Design tokens
  utils/                        # Shared helpers
  config/                       # API config, timeouts
```

### Key Libraries

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Declarative routing |
| `drift` | Local SQLite caching |
| `dio` | HTTP client |
| `intl` | Date/number formatting |
| `lottie` | Animated illustrations |
| `qr_flutter` | QR code display |
| `confetti` | Celebration effects |

### Design Tokens

- `mitlistColors` — Full palette in `theme/colors.dart`
- `mitlistSpacing` — Spacing scale in `theme/spacing.dart`
- `mitlistTypography` — Text styles in `theme/typography.dart`
- `mitlistAnimations` — Duration/easing constants in `theme/animations.dart`
- `mitlistShadows` — Shadow presets in `theme/shadows.dart`
- `mitlistTheme` — Light/dark ThemeData in `theme/theme.dart`

Always use these tokens instead of hardcoded values. See `AGENTS.md` for anti-patterns.
