# Lottie Animations

Drop `.json` Lottie animation files here, then reference them in `AppEmptyState` via
`lottieAsset: 'assets/animations/lottie/your-file.json'`.

## Recommended free animations (lottiefiles.com)

Search LottieFiles for these free animation packs:

| Feature      | Search term         | Suggested style     |
|-------------|---------------------|---------------------|
| Chores       | cleaning, broom     | Outline, playful    |
| Lists        | checklist, notepad  | Line-art, minimal   |
| Recipes      | cooking, food       | Warm, sketch        |
| Money        | piggy bank, wallet  | Flat, friendly      |
| Calendar     | calendar, planner   | Doodle, simple      |
| Notifications| bell, inbox         | Minimal, subtle     |
| Onboarding   | house, home         | Warm, welcoming     |
| Success      | checkmark, confetti | Playful, celebratory|
| Loading      | spinner, dots       | Brand-colored       |
| Error/404    | magnifying glass    | Humorous, cute      |

## Tips

- Use `AppEmptyState(lottieAsset: '...', animatedIcon: false)` — Lottie takes priority
  over the static icon when both are provided.
- Keep files under 50 KB for fast loading on mobile.
- The `lottie` package is already included in `pubspec.yaml`.
- If no `.json` files are present, the app falls back to `BobbingIcon` wrapping a
  static `AppIcon` — set `animatedIcon: true` on `AppEmptyState` for a built-in
  floating animation.
