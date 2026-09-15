import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android manifest and the Apple app-site-association file each claim
/// the https://app.mitlist.me paths that open the app instead of a browser.
/// A path present in one and missing in the other silently opens the web app
/// on that platform, so the two lists are checked against each other here.
void main() {
  test('App Link and Universal Link paths agree', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final androidPrefixes = RegExp(
      r'android:host="app\.mitlist\.me"\s+android:pathPrefix="([^"]+)"',
    ).allMatches(manifest).map((m) => m.group(1)!).toSet();

    final aasa = jsonDecode(
      File('web/.well-known/apple-app-site-association').readAsStringSync(),
    ) as Map<String, dynamic>;
    final details =
        (aasa['applinks'] as Map<String, dynamic>)['details'] as List<dynamic>;
    final applePaths =
        (details.single as Map<String, dynamic>)['paths'] as List<dynamic>;
    // "/lists" and "/lists/*" both fold to the Android prefix "/lists".
    final appleRoots = applePaths
        .map((p) => (p as String).replaceFirst(RegExp(r'/\*$'), ''))
        .toSet();

    expect(androidPrefixes, isNotEmpty);
    expect(appleRoots, equals(androidPrefixes));
  });

  test('onboarding email destinations are claimed', () {
    // Mirrors CTAPath and every Tip.Path in
    // backend/internal/onboarding/steps.go, folded to their first segment.
    const emailPaths = [
      '/home',
      '/lists',
      '/money',
      '/chores',
      '/recipes',
      '/calendar',
      '/you',
      '/scanner',
    ];
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final path in emailPaths) {
      expect(
        manifest,
        contains('android:pathPrefix="$path"'),
        reason: '$path is a tips-email button and must open the app',
      );
    }
  });
}
