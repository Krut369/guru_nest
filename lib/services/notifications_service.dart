import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get notifications for a user
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllNotificationsAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  // Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  // Create a new notification
  Future<bool> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'related_id': relatedId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }

  // Get notification types with icons and colors
  static Map<String, Map<String, dynamic>> getNotificationTypes() {
    return {
      'course_enrollment': {
        'icon': 'school',
        'color': '#2196F3',
        'title': 'Course Enrollment',
      },
      'quiz_result': {
        'icon': 'quiz',
        'color': '#FF9800',
        'title': 'Quiz Result',
      },
      'lesson_completed': {
        'icon': 'check_circle',
        'color': '#4CAF50',
        'title': 'Lesson Completed',
      },
      'achievement': {
        'icon': 'emoji_events',
        'color': '#FFD700',
        'title': 'Achievement',
      },
      'system': {
        'icon': 'info',
        'color': '#9E9E9E',
        'title': 'System',
      },
      'message': {
        'icon': 'message',
        'color': '#E91E63',
        'title': 'Message',
      },
    };
  }
}
