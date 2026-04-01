import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'db/app_database.dart';
import 'features/mind/providers/mind_me_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (_) => MindMeProvider(database: AppDatabase.instance),
      child: const MeApp(),
    ),
  );
}

class MeApp extends StatelessWidget {
  const MeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ME',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
