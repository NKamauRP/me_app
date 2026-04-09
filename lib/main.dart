import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'core/services/audio_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/theme_service.dart';
import 'db/app_database.dart';
import 'features/mind/providers/mind_me_provider.dart';
import 'screens/splash_screen.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  AiService.initializePlugin(); // configures FlutterGemma before runApp
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ThemeService.instance.initialize();
      await AudioService.instance.initialize();
      await NotificationService.instance.initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AudioService.instance.stop();
    } else if (state == AppLifecycleState.resumed) {
      AudioService.instance.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(
          value: ThemeService.instance,
        ),
        ChangeNotifierProvider(
          create: (_) => MindMeProvider(database: AppDatabase.instance),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

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
