import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class GoalsService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // Get user goals
  Future<List<Map<String, dynamic>>> getUserGoals(String userId) async {
    try {
      final goals = await _supabase
          .from('user_goals')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(goals);
    } catch (e) {
      print('Error fetching user goals: $e');
      return [];
    }
  }

  // Create a new goal
  Future<bool> createGoal(String userId, Map<String, dynamic> goalData) async {
    try {
      await _supabase.from('user_goals').insert({
        'user_id': userId,
        'title': goalData['title'],
        'description': goalData['description'],
        'target_value': goalData['target_value'],
        'current_value': goalData['current_value'] ?? 0,
        'goal_type': goalData['goal_type'],
        'timeframe': goalData['timeframe'], // 'daily', 'weekly', 'monthly'
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating goal: $e');
      return false;
    }
  }

  // Update goal progress
  Future<bool> updateGoalProgress(String goalId, double currentValue) async {
    try {
      await _supabase
          .from('user_goals')
          .update({'current_value': currentValue}).eq('id', goalId);
      return true;
    } catch (e) {
      print('Error updating goal progress: $e');
      return false;
    }
  }

  // Delete a goal
  Future<bool> deleteGoal(String goalId) async {
    try {
      await _supabase.from('user_goals').delete().eq('id', goalId);
      return true;
    } catch (e) {
      print('Error deleting goal: $e');
      return false;
    }
  }

  // Get default goals for new users
  List<Map<String, dynamic>> getDefaultGoals() {
    return [
      {
        'title': 'Learning Streak',
        'description': 'Maintain a daily learning streak',
        'target_value': 7.0,
        'goal_type': 'streak',
        'timeframe': 'weekly',
        'icon': 'local_fire_department',
        'color': 'orange',
      },
      {
        'title': 'Lesson Completion',
        'description': 'Complete lessons this week',
        'target_value': 5.0,
        'goal_type': 'lessons',
        'timeframe': 'weekly',
        'icon': 'menu_book',
        'color': 'green',
      },
      {
        'title': 'Quiz Performance',
        'description': 'Achieve high quiz scores',
        'target_value': 85.0,
        'goal_type': 'quiz_score',
        'timeframe': 'weekly',
        'icon': 'quiz',
        'color': 'red',
      },
      {
        'title': 'Course Progress',
        'description': 'Make progress in your courses',
        'target_value': 3.0,
        'goal_type': 'courses',
        'timeframe': 'weekly',
        'icon': 'school',
        'color': 'blue',
      },
    ];
  }

  // Calculate goal progress based on current analytics
  Map<String, double> calculateGoalProgress(
      Map<String, dynamic> analyticsData) {
    final userReport = analyticsData['user_report'] as Map<String, dynamic>;
    final lessonProgress =
        analyticsData['lesson_progress'] as List<dynamic>? ?? [];

    return {
      'streak': (userReport['learning_streak'] ?? 0).toDouble(),
      'lessons': lessonProgress.length.toDouble(),
      'quiz_score': (userReport['average_quiz_score'] ?? 0.0).toDouble(),
      'courses': (userReport['total_courses_enrolled'] ?? 0).toDouble(),
    };
  }
}
