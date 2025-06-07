import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class UserReportsService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // Update user report when material is accessed
  Future<bool> updateUserReportOnMaterialAccess(String userId) async {
    try {
      print('Updating user report for material access: $userId');

      // Calculate new learning streak
      final newStreak = await _calculateLearningStreak(userId);

      // Get current material access count
      final currentReport = await _getCurrentUserReport(userId);
      final currentMaterialAccess =
          currentReport['total_materials_accessed'] ?? 0;

      // Update the user_reports table
      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'learning_streak': newStreak,
        'total_materials_accessed': currentMaterialAccess + 1,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print(
          'Updated learning streak to: $newStreak, total materials accessed: ${currentMaterialAccess + 1}');
      return true;
    } catch (e) {
      print('Error updating user report on material access: $e');
      return false;
    }
  }

  // Update user report when lesson is accessed
  Future<bool> updateUserReportOnLessonAccess(String userId) async {
    try {
      print('Updating user report for lesson access: $userId');

      // Calculate new learning streak
      final newStreak = await _calculateLearningStreak(userId);

      // Get current lesson access count
      final currentReport = await _getCurrentUserReport(userId);
      final currentLessonAccess = currentReport['total_lessons_accessed'] ?? 0;

      // Update the user_reports table
      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'learning_streak': newStreak,
        'total_lessons_accessed': currentLessonAccess + 1,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print(
          'Updated learning streak to: $newStreak, total lessons accessed: ${currentLessonAccess + 1}');
      return true;
    } catch (e) {
      print('Error updating user report on lesson access: $e');
      return false;
    }
  }

  // Update user report when material is completed
  Future<bool> updateUserReportOnMaterialCompletion(String userId) async {
    try {
      print('Updating user report for material completion: $userId');

      // Calculate new learning streak
      final newStreak = await _calculateLearningStreak(userId);

      // Update the user_reports table
      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'learning_streak': newStreak,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('Updated learning streak to: $newStreak');
      return true;
    } catch (e) {
      print('Error updating user report on material completion: $e');
      return false;
    }
  }

  // Update user report when lesson is completed
  Future<bool> updateUserReportOnLessonCompletion(String userId) async {
    try {
      print('Updating user report for lesson completion: $userId');

      // Calculate new learning streak
      final newStreak = await _calculateLearningStreak(userId);

      // Update the user_reports table
      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'learning_streak': newStreak,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('Updated learning streak to: $newStreak');
      return true;
    } catch (e) {
      print('Error updating user report on lesson completion: $e');
      return false;
    }
  }

  // Update user report when quiz is completed
  Future<bool> updateUserReportOnQuizCompletion(
      String userId, double quizScore) async {
    try {
      print(
          'Updating user report for quiz completion: $userId, score: $quizScore');

      // Calculate new learning streak
      final newStreak = await _calculateLearningStreak(userId);

      // Get current quiz statistics
      final currentReport = await _getCurrentUserReport(userId);
      final currentTotalQuizzes = currentReport['total_quizzes'] ?? 0;
      final currentAverageScore = currentReport['average_quiz_score'] ?? 0.0;

      // Calculate new average score
      final newTotalQuizzes = currentTotalQuizzes + 1;
      final newAverageScore =
          ((currentAverageScore * currentTotalQuizzes) + quizScore) /
              newTotalQuizzes;

      // Update the user_reports table
      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'learning_streak': newStreak,
        'total_quizzes': newTotalQuizzes,
        'average_quiz_score': newAverageScore,
        'last_quiz_taken': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print(
          'Updated learning streak to: $newStreak, total quizzes: $newTotalQuizzes, average score: $newAverageScore');
      return true;
    } catch (e) {
      print('Error updating user report on quiz completion: $e');
      return false;
    }
  }

  // Update user report when course is enrolled
  Future<bool> updateUserReportOnCourseEnrollment(String userId) async {
    try {
      print('Updating user report for course enrollment: $userId');

      // Get current enrollment count
      final currentReport = await _getCurrentUserReport(userId);
      final currentEnrollments = currentReport['total_courses_enrolled'] ?? 0;

      // Update the user_reports table
      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'total_courses_enrolled': currentEnrollments + 1,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('Updated total courses enrolled to: ${currentEnrollments + 1}');
      return true;
    } catch (e) {
      print('Error updating user report on course enrollment: $e');
      return false;
    }
  }

  // Get current user report
  Future<Map<String, dynamic>> _getCurrentUserReport(String userId) async {
    try {
      final result = await _supabase
          .from('user_reports')
          .select('*')
          .eq('user_id', userId)
          .single();

      return result;
    } catch (e) {
      print('Error getting current user report: $e');
      return {};
    }
  }

  // Calculate learning streak (same logic as analytics service)
  Future<int> _calculateLearningStreak(String userId) async {
    try {
      print('Calculating learning streak for user: $userId');

      // Get all activity dates from lesson_access, material_access, quiz_results, and lesson_progress
      List<dynamic> lessonDates = [];
      List<dynamic> materialDates = [];
      List<dynamic> quizDates = [];
      List<dynamic> completedLessonDates = [];

      try {
        lessonDates = await _supabase
            .from('lesson_access')
            .select('accessed_at')
            .eq('student_id', userId);
        print('Found ${lessonDates.length} lesson access records');
      } catch (e) {
        print('Error fetching lesson access for streak: $e');
        lessonDates = [];
      }

      try {
        materialDates = await _supabase
            .from('material_access')
            .select('accessed_at')
            .eq('student_id', userId);
        print('Found ${materialDates.length} material access records');
      } catch (e) {
        print('Error fetching material access for streak: $e');
        materialDates = [];
      }

      try {
        quizDates = await _supabase
            .from('quiz_results')
            .select('taken_at')
            .eq('student_id', userId);
        print('Found ${quizDates.length} quiz result records');
      } catch (e) {
        print('Error fetching quiz results for streak: $e');
        quizDates = [];
      }

      try {
        completedLessonDates = await _supabase
            .from('lesson_progress')
            .select('completed_at')
            .eq('student_id', userId)
            .eq('is_completed', true);
        print('Found ${completedLessonDates.length} completed lesson records');
      } catch (e) {
        print('Error fetching completed lessons for streak: $e');
        completedLessonDates = [];
      }

      // Combine all dates and extract just the date part
      final allDates = <String>{};

      for (final lesson in lessonDates) {
        final date = (lesson['accessed_at'] as String).split('T')[0];
        allDates.add(date);
      }

      for (final material in materialDates) {
        final date = (material['accessed_at'] as String).split('T')[0];
        allDates.add(date);
      }

      for (final quiz in quizDates) {
        final date = (quiz['taken_at'] as String).split('T')[0];
        allDates.add(date);
      }

      for (final completedLesson in completedLessonDates) {
        final date = (completedLesson['completed_at'] as String).split('T')[0];
        allDates.add(date);
      }

      print('Total unique activity dates: ${allDates.length}');

      if (allDates.isEmpty) {
        print('No activity dates found, streak = 0');
        return 0;
      }

      // Sort dates in descending order (most recent first)
      final sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));
      print('Most recent activity date: ${sortedDates.first}');

      // Get today's date in YYYY-MM-DD format
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];
      print('Today: $todayStr');

      // Calculate consecutive days starting from the most recent activity
      int streak = 0;
      DateTime currentDate = DateTime.parse(sortedDates.first);

      // Check if the most recent activity is today or yesterday
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = yesterday.toIso8601String().split('T')[0];

      if (sortedDates.first == todayStr) {
        // User was active today, start counting from today
        streak = 1;
        currentDate = today;
      } else if (sortedDates.first == yesterdayStr) {
        // User was active yesterday, start counting from yesterday
        streak = 1;
        currentDate = yesterday;
      } else {
        // User hasn't been active recently, no current streak
        print('No recent activity (today or yesterday), streak = 0');
        return 0;
      }

      // Count consecutive days backwards from the most recent activity
      for (int i = 1; i < sortedDates.length; i++) {
        final previousDate = DateTime.parse(sortedDates[i]);
        final expectedDate = currentDate.subtract(const Duration(days: 1));

        // Check if the previous activity was exactly one day before
        if (previousDate.year == expectedDate.year &&
            previousDate.month == expectedDate.month &&
            previousDate.day == expectedDate.day) {
          streak++;
          currentDate = previousDate;
        } else {
          // Gap found, break the streak
          break;
        }
      }

      print('Calculated streak: $streak days');
      return streak;
    } catch (e) {
      print('Error calculating learning streak: $e');
      print('Stack trace: ${StackTrace.current}');
      return 0;
    }
  }

  // Initialize user report if it doesn't exist
  Future<bool> initializeUserReport(String userId) async {
    try {
      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'total_courses_enrolled': 0,
        'total_lessons_accessed': 0,
        'total_materials_accessed': 0,
        'average_quiz_score': 0.0,
        'total_quizzes': 0,
        'learning_streak': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('Initialized user report for: $userId');
      return true;
    } catch (e) {
      print('Error initializing user report: $e');
      return false;
    }
  }

  // Get user report (for compatibility with existing code)
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
          'learning_streak': 0,
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

  // Update user report (for compatibility with existing code)
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
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating user report: $e');
      rethrow;
    }
  }

  // Increment courses enrolled (for compatibility with existing code)
  Future<void> incrementCoursesEnrolled(String userId) async {
    try {
      final currentReport = await _getCurrentUserReport(userId);
      final currentEnrollments = currentReport['total_courses_enrolled'] ?? 0;

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'total_courses_enrolled': currentEnrollments + 1,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error incrementing courses enrolled: $e');
      rethrow;
    }
  }

  // Increment lessons accessed (for compatibility with existing code)
  Future<void> incrementLessonsAccessed(String userId) async {
    try {
      final currentReport = await _getCurrentUserReport(userId);
      final currentLessonAccess = currentReport['total_lessons_accessed'] ?? 0;

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'total_lessons_accessed': currentLessonAccess + 1,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error incrementing lessons accessed: $e');
      rethrow;
    }
  }

  // Increment materials accessed (for compatibility with existing code)
  Future<void> incrementMaterialsAccessed(String userId) async {
    try {
      final currentReport = await _getCurrentUserReport(userId);
      final currentMaterialAccess =
          currentReport['total_materials_accessed'] ?? 0;

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'total_materials_accessed': currentMaterialAccess + 1,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error incrementing materials accessed: $e');
      rethrow;
    }
  }

  // Update quiz score (for compatibility with existing code)
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

  // Manually refresh learning streak (for testing and debugging)
  Future<bool> refreshLearningStreak(String userId) async {
    try {
      print('Manually refreshing learning streak for user: $userId');

      // Calculate new learning streak
      final newStreak = await _calculateLearningStreak(userId);

      // Update the user_reports table
      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'learning_streak': newStreak,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Learning streak refreshed to: $newStreak days');
      return true;
    } catch (e) {
      print('❌ Error refreshing learning streak: $e');
      return false;
    }
  }

  // Get current learning streak from user_reports table
  Future<int> getCurrentLearningStreak(String userId) async {
    try {
      final response = await _supabase
          .from('user_reports')
          .select('learning_streak')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['learning_streak'] ?? 0;
    } catch (e) {
      print('Error getting current learning streak: $e');
      return 0;
    }
  }
}
