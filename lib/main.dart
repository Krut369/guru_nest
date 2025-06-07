import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/routes.dart';
import 'core/supabase_client.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.initialize();
  } catch (e) {
    print('Error initializing Supabase: $e');
    return;
  }

  // Initialize global security to block screenshots

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyApp());
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
    );
  }
}
