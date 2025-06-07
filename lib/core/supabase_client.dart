import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient instance;

  // Add static constant fields for URL and Anon Key
  static const String supabaseUrl = 'https://hbsmqklbrlqogibvqbkm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhic21xa2xicmxxb2dpYnZxYmttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc3MzE4ODIsImV4cCI6MjA2MzMwNzg4Mn0.S496YKHogXBYaFzKlj1kSPFtOCSyfMtAkH7Iw43ITDc';

  SupabaseService._internal() {
    instance = Supabase.instance.client;
  }

  factory SupabaseService() {
    return _instance;
  }

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: true,
        storageOptions: const StorageClientOptions(
          retryAttempts: 3,
        ),
      );
    } catch (e) {
      print('Error initializing Supabase: $e');
      rethrow;
    }
  }
}
