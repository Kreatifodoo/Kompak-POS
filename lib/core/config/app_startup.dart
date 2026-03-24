import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../utils/logger.dart';

// Conditional import — workmanager only on mobile
import 'app_startup_mobile.dart' if (dart.library.html) 'app_startup_web.dart'
    as platform_startup;

Future<void> appStartup() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.info('Starting Kompak POS...');

  // Initialize background sync (mobile only, no-op on web)
  await platform_startup.initBackgroundSync();

  AppLogger.info('App startup complete (web: $kIsWeb)');
}
