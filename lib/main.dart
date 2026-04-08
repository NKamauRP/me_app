import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/services/audio_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/theme_service.dart';
import 'db/app_database.dart';
import 'features/mind/providers/mind_me_provider.dart';
import 'screens/splash_screen.dart';
import 'services/gemma_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.instance.initialize();
  await AudioService.instance.initialize();
  await NotificationService.instance.initialize();
  await GemmaService.instance.initialise();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(
          value: ThemeService.instance,
        ),
        ChangeNotifierProvider(
          create: (_) => MindMeProvider(database: AppDatabase.instance),
        ),
      ],
      child: const MeApp(),
    ),
  );
}

class MeApp extends StatelessWidget {
  const MeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        return MaterialApp(
          title: 'ME',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeFor(themeService.currentTheme),
          themeAnimationCurve: Curves.easeOutCubic,
          themeAnimationDuration: const Duration(milliseconds: 420),
          home: const SplashScreen(),
        );
      },
    );
  }
}
