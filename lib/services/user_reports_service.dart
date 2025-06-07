import 'package:supabase_flutter/supabase_flutter.dart';

class UserReportsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getUserReport(String userId) async {
    try {
      // Try to get existing report
      final response = await _supabase
          .from('user_reports')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // If no report exists, create a new one with default values
      if (response == null) {
        final defaultReport = {
          'user_id': userId,
          'total_courses_enrolled': 0,
          'total_lessons_accessed': 0,
          'total_materials_accessed': 0,
          'average_quiz_score': 0.0,
          'last_quiz_taken': null,
          'total_quizzes': 0,
        };

        await _supabase.from('user_reports').insert(defaultReport);
        return defaultReport;
      }

      return response;
    } catch (e) {
      print('Error fetching user report: $e');
      rethrow;
    }
  }

  Future<void> updateUserReport({
    required String userId,
    int? totalCoursesEnrolled,
    int? totalLessonsAccessed,
    int? totalMaterialsAccessed,
    double? averageQuizScore,
    DateTime? lastQuizTaken,
    int? totalQuizzes,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (totalCoursesEnrolled != null) {
        updateData['total_courses_enrolled'] = totalCoursesEnrolled;
      }
      if (totalLessonsAccessed != null) {
        updateData['total_lessons_accessed'] = totalLessonsAccessed;
      }
      if (totalMaterialsAccessed != null) {
        updateData['total_materials_accessed'] = totalMaterialsAccessed;
      }
      if (averageQuizScore != null) {
        updateData['average_quiz_score'] = averageQuizScore;
      }
      if (lastQuizTaken != null) {
        updateData['last_quiz_taken'] = lastQuizTaken.toIso8601String();
      }
      if (totalQuizzes != null) {
        updateData['total_quizzes'] = totalQuizzes;
      }

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        ...updateData,
      }).select();
    } catch (e) {
      print('Error updating user report: $e');
      rethrow;
    }
  }

  Future<void> incrementCoursesEnrolled(String userId) async {
    try {
      await _supabase.rpc('increment_courses_enrolled', params: {
        'user_id': userId,
      });
    } catch (e) {
      print('Error incrementing courses enrolled: $e');
      rethrow;
    }
  }

  Future<void> incrementLessonsAccessed(String userId) async {
    try {
      await _supabase.rpc('increment_lessons_accessed', params: {
        'user_id': userId,
      });
    } catch (e) {
      print('Error incrementing lessons accessed: $e');
      rethrow;
    }
  }

  Future<void> incrementMaterialsAccessed(String userId) async {
    try {
      await _supabase.rpc('increment_materials_accessed', params: {
        'user_id': userId,
      });
    } catch (e) {
      print('Error incrementing materials accessed: $e');
      rethrow;
    }
  }

  Future<void> updateQuizScore(String userId, double score) async {
    try {
      // First, try to get the current report
      final currentReport = await getUserReport(userId);
      final currentScore = currentReport['average_quiz_score'] ?? 0.0;
      final currentCount = currentReport['total_quizzes'] ?? 0;

      // Calculate new average
      double newScore;
      int newCount;
      if (currentCount == 0) {
        newScore = score;
        newCount = 1;
      } else {
        newScore = ((currentScore * currentCount) + score) / (currentCount + 1);
        newCount = currentCount + 1;
      }

      // Update the report
      await updateUserReport(
        userId: userId,
        averageQuizScore: newScore,
        lastQuizTaken: DateTime.now(),
        totalQuizzes: newCount,
      );
    } catch (e) {
      print('Error updating quiz score: $e');
      rethrow;
    }
  }
}
