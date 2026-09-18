# This README explains how to submit mitlist to the app stores.

## Prerequisites

1. Apple Developer account ($99/year)
2. Google Play Console account ($25 one-time)
3. App-specific passwords or API keys for both stores

## iOS — App Store

1. Configure signing in Xcode (`frontend/ios/Runner.xcworkspace`)
2. Update `app_identifier` in `store/fastlane/Appfile`
3. Update `apple_id` in `store/fastlane/Appfile`  
4. Generate screenshots:
   ```bash
   cd frontend
   flutter run --release  # Run on a simulator at iPhone 16 Pro Max resolution
   # Screenshot each screen (cmd+s) and save to store/fastlane/screenshots/
   ```
5. Submit:
   ```bash
   cd store/fastlane
   fastlane ios beta   # TestFlight
   fastlane ios release  # App Store
   ```

## Android — Google Play

1. Generate a signed app bundle:
   ```bash
   cd frontend
   flutter build appbundle --release
   ```
2. Upload `frontend/build/app/outputs/bundle/release/app-release.aab` to Google Play Console
3. Fill in the store listing with content from `store/google_play_full.txt`

## Store assets

- App icon: `store/icons/app-store-1024.png` (App Store, 1024x1024) and `store/icons/google-play-512.png` (Play, 512x512).
  Both are the website header mark. Regenerate every icon (landing favicon, Flutter launcher sources, store PNGs) with
  `cd landing && node scripts/brand-icons.mjs`, then `cd frontend && dart run flutter_launcher_icons`.
- Feature graphic (Play Store): 1024x500px, PNG, no alpha
- Screenshots: minimum 1080x1920px per `store/screenshot_spec.txt`
