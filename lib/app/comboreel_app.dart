import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/services/app_services.dart';
import 'app_shell.dart';

class ComboReelApp extends StatelessWidget {
  const ComboReelApp({super.key, this.services = const AppServices.offline()});

  final AppServices services;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ComboReel',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: AppShell(services: services),
  );
}
