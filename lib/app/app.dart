import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class GymFlowApp extends StatelessWidget {
  const GymFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GymFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
