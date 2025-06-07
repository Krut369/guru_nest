import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/routes.dart';
import 'core/supabase_client.dart';
import 'core/theme/app_theme.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Supabase with error handling
    try {
      await SupabaseService.initialize();
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      // Continue running the app even if Supabase fails
    }

    runApp(
      kDebugMode
          ? DevicePreview(
              enabled: true,
              tools: const [
                ...DevicePreview.defaultTools,
              ],
              builder: (context) => const MyApp(),
            )
          : const MyApp(),
    );
  } catch (e, stackTrace) {
    debugPrint('Error in main: $e');
    debugPrint('Stack trace: $stackTrace');
    // Show error UI
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Guru Nest',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}
