import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_preview/device_preview.dart'; // ✅ Import for Device Preview

import 'core/routes.dart';
import 'core/supabase_client.dart';
import 'core/theme/app_theme.dart';

import 'package:screen_protector/screen_protector.dart'; // ✅ Import for screen protection

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.initialize();
  } catch (e) {
    print('Error initializing Supabase: $e');
    return;
  }

  // ✅ Prevent screenshots only
  await _protectScreen();

  // ✅ Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ✅ Wrap your app with DevicePreview
  runApp(
    DevicePreview(
      // enabled: !bool.fromEnvironment('dart.vm.product'), // only in debug mode
      builder: (context) => const MyApp(), // your app
    ),
  );
}

// ✅ Prevent screenshots (recording not supported)
Future<void> _protectScreen() async {
  try {
    await ScreenProtector.preventScreenshotOn();
  } catch (e) {
    print('Error enabling screen protection: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Guru Nest',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,

      // ✅ These two lines integrate DevicePreview settings
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}
