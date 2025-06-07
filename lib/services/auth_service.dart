import 'dart:async'; // Import for StreamTransformer
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart' as app;

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _userKey = 'current_user';
  app.User? _currentUser;

  AuthService() {
    loadSavedUser();
  }

  // Get current user
  app.User? get currentUser => _currentUser;

  // Add this method
  Future<app.User?> initialize() async {
    await loadSavedUser();
    return _currentUser;
  }

  // Sign in with email and password
  Future<app.User> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      // Direct database query for login
      final response = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .eq('password', password)
          .single();

      final user = app.User.fromJson(response);
      await _saveUser(user);
      return user;
    } catch (e) {
      if (e.toString().contains('No rows found') ||
          e.toString().contains('multiple (or no) rows returned')) {
        throw Exception('Invalid email or password. Please try again.');
      }
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _clearUser();
  }

  Future<app.User?> signUp({
    required String email,
    required String password,
    required String fullName,
    required app.UserRole role,
  }) async {
    try {
      // Create user record in your users table
      final userData = {
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role.toString().split('.').last,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _supabase.from('users').insert(userData).select().single();

      final user = app.User.fromJson(response);
      await _saveUser(user);
      return user;
    } catch (e) {
      if (e.toString().contains('duplicate key')) {
        throw Exception('Email already exists');
      }
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  Future<void> _saveUser(app.User user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    final userJson = jsonEncode(user.toJson());
    await prefs.setString(_userKey, userJson);
  }

  Future<void> _clearUser() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  Future<void> loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);

      if (userJson != null) {
        final userData = jsonDecode(userJson);
        _currentUser = app.User.fromJson(userData);
      }
    } catch (e) {
      await _clearUser();
    }
  }

  // Method to get stored user details
  Future<Map<String, String?>> getStoredUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('user_email'),
      'name': prefs.getString('user_name'),
    };
  }

  // Dispose method to cancel stream subscriptions if needed (for more complex scenarios)
  // void dispose() {
  //   _authStateChangesController.close();
  // }
}
