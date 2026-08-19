import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/services/app_services.dart';
import 'app_shell.dart';
import '../features/privacy/presentation/account_deletion_entry_screen.dart';
import '../features/privacy/presentation/legal_document_screen.dart';

String initialAppRoute(Uri uri) {
  const publicRoutes = {'/privacy', '/terms', '/delete-account'};
  return publicRoutes.contains(uri.path) ? uri.path : '/';
}

class ComboReelApp extends StatelessWidget {
  ComboReelApp({super.key, AppServices? services})
    : services = services ?? AppServices.offline();

  final AppServices services;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ComboReel',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    initialRoute: initialAppRoute(Uri.base),
    onGenerateRoute: (settings) {
      final Widget page = switch (settings.name) {
        '/privacy' => const LegalDocumentScreen(
          document: LegalDocument.privacy,
        ),
        '/terms' => const LegalDocumentScreen(document: LegalDocument.terms),
        '/delete-account' => AccountDeletionEntryScreen(
          authRepository: services.authRepository,
          privacyRepository: services.privacyRepository,
          backendConfigured: services.backendConfigured,
        ),
        _ => AppShell(services: services),
      };
      return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
    },
  );
}
