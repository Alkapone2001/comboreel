import 'package:flutter/material.dart';

import 'app/comboreel_app.dart';
import 'core/services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.bootstrap();
  runApp(ComboReelApp(services: services));
}
