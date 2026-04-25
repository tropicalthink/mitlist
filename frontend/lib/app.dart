import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme.dart';
import 'router.dart';

class MitlistApp extends ConsumerWidget {
  const MitlistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'mitlist',
      debugShowCheckedModeBanner: false,
      theme: MitlistTheme.light,
      darkTheme: MitlistTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
