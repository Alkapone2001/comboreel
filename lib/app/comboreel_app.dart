import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_screen.dart';

class ComboReelApp extends StatelessWidget {
  const ComboReelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ComboReel',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: const HomeScreen(),
  );
}
