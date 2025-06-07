import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user_model.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<User> getUserProfile(String userId) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).single();

      return User.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? email,
    String? avatarUrl,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (fullName != null) {
        updateData['full_name'] = fullName;
      }
      if (email != null) {
        updateData['email'] = email;
      }
      if (avatarUrl != null) {
        updateData['avatar_url'] = avatarUrl;
      }

      final response = await _supabase
          .from('users')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(response));
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> updatePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // First verify current password
      final response = await _supabase.auth.signInWithPassword(
        email: (await getUserProfile(userId)).email,
        password: currentPassword,
      );

      if (response.user == null) {
        throw Exception('Current password is incorrect');
      }

      // Update password
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      print('Error updating password: $e');
      rethrow;
    }
  }

  Future<String> uploadAvatar(String userId, Uint8List imageBytes) async {
    try {
      final fileName = 'avatar_$userId.jpg';
      final filePath = 'avatars/$fileName';

      // Upload image to storage
      await _supabase.storage.from('avatars').uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get public URL
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

      // Update user profile with new avatar URL
      await updateProfile(userId: userId, avatarUrl: imageUrl);

      return imageUrl;
    } catch (e) {
      print('Error uploading avatar: $e');
      rethrow;
    }
  }

  Future<void> deleteAvatar(String userId) async {
    try {
      final user = await getUserProfile(userId);
      if (user.avatarUrl != null) {
        // Extract file path from URL
        final uri = Uri.parse(user.avatarUrl!);
        final filePath = uri.path.split('/').last;

        // Delete from storage
        await _supabase.storage.from('avatars').remove([filePath]);

        // Update user profile
        await updateProfile(userId: userId, avatarUrl: null);
      }
    } catch (e) {
      print('Error deleting avatar: $e');
      rethrow;
    }
  }
}
