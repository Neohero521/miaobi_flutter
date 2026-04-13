import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import '../features/writing/presentation/providers/settings_provider.dart';
import '../features/novels/presentation/pages/novel_list_screen.dart';
import '../features/settings/presentation/pages/settings_screen.dart';

class MiaoBiApp extends ConsumerWidget {
  const MiaoBiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final isDark = settingsAsync.valueOrNull?.isDarkMode ?? false;

    return MaterialApp(
      title: '妙笔',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(isDark: false),
      darkTheme: buildAppTheme(isDark: true),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const NovelListScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
