import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class UserReportService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // Initialize or update user report when user performs actions
  Future<void> updateUserReport(String userId) async {
    try {
      print('Updating user report for user: $userId');

      // Calculate metrics from various tables
      final metrics = await _calculateUserMetrics(userId);

      // Check if user report exists
      final existingReport = await _supabase
          .from('user_reports')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingReport != null) {
        // Update existing report
        await _supabase.from('user_reports').update({
          'total_courses_enrolled': metrics['total_courses_enrolled'],
          'total_lessons_accessed': metrics['total_lessons_accessed'],
          'total_materials_accessed': metrics['total_materials_accessed'],
          'average_quiz_score': metrics['average_quiz_score'],
          'last_quiz_taken': metrics['last_quiz_taken'],
          'total_quizzes': metrics['total_quizzes'],
          'learning_streak': metrics['learning_streak'],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
        print('User report updated successfully');
      } else {
        // Create new report
        await _supabase.from('user_reports').insert({
          'user_id': userId,
          'total_courses_enrolled': metrics['total_courses_enrolled'],
          'total_lessons_accessed': metrics['total_lessons_accessed'],
          'total_materials_accessed': metrics['total_materials_accessed'],
          'average_quiz_score': metrics['average_quiz_score'],
          'last_quiz_taken': metrics['last_quiz_taken'],
          'total_quizzes': metrics['total_quizzes'],
          'learning_streak': metrics['learning_streak'],
        });
        print('New user report created successfully');
      }
    } catch (e) {
      print('Error updating user report: $e');
      throw Exception('Failed to update user report: $e');
    }
  }

  // Update specific metrics when user performs specific actions
  Future<void> updateOnEnrollment(String userId) async {
    try {
      final enrollments = await _supabase
          .from('enrollments')
          .select('id')
          .eq('student_id', userId);

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'total_courses_enrolled': enrollments.length,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('Error updating enrollment count: $e');
    }
  }

  Future<void> updateOnLessonAccess(String userId) async {
    try {
      final lessonAccess = await _supabase
          .from('lesson_access')
          .select('id')
          .eq('student_id', userId);

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'total_lessons_accessed': lessonAccess.length,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('Error updating lesson access count: $e');
    }
  }

  Future<void> updateOnMaterialAccess(String userId) async {
    try {
      final materialAccess = await _supabase
          .from('material_access')
          .select('id')
          .eq('student_id', userId);

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'total_materials_accessed': materialAccess.length,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('Error updating material access count: $e');
    }
  }

  Future<void> updateOnQuizCompletion(String userId, double score) async {
    try {
      final quizResults = await _supabase
          .from('quiz_results')
          .select('score, taken_at')
          .eq('student_id', userId)
          .order('taken_at', ascending: false);

      final totalQuizzes = quizResults.length;
      final averageScore = totalQuizzes > 0
          ? quizResults
                  .map((r) => r['score'] as double)
                  .reduce((a, b) => a + b) /
              totalQuizzes
          : 0.0;
      final lastQuizTaken =
          totalQuizzes > 0 ? quizResults.first['taken_at'] : null;

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'average_quiz_score': averageScore,
        'last_quiz_taken': lastQuizTaken,
        'total_quizzes': totalQuizzes,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('Error updating quiz metrics: $e');
    }
  }

  Future<void> updateLearningStreak(String userId) async {
    try {
      final learningStreak = await _calculateLearningStreak(userId);

      await _supabase.from('user_reports').upsert({
        'user_id': userId,
        'learning_streak': learningStreak,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('Error updating learning streak: $e');
    }
  }

  // Calculate all user metrics from database
  Future<Map<String, dynamic>> _calculateUserMetrics(String userId) async {
    // Calculate total courses enrolled
    int totalCoursesEnrolled = 0;
    try {
      final enrollments = await _supabase
          .from('enrollments')
          .select('id')
          .eq('student_id', userId);
      totalCoursesEnrolled = enrollments.length;
    } catch (e) {
      print('Error counting enrollments: $e');
    }

    // Calculate total lessons accessed
    int totalLessonsAccessed = 0;
    try {
      final lessonAccess = await _supabase
          .from('lesson_access')
          .select('id')
          .eq('student_id', userId);
      totalLessonsAccessed = lessonAccess.length;
    } catch (e) {
      print('Error counting lesson access: $e');
    }

    // Calculate total materials accessed
    int totalMaterialsAccessed = 0;
    try {
      final materialAccess = await _supabase
          .from('material_access')
          .select('id')
          .eq('student_id', userId);
      totalMaterialsAccessed = materialAccess.length;
    } catch (e) {
      print('Error counting material access: $e');
    }

    // Calculate quiz metrics
    double averageQuizScore = 0.0;
    int totalQuizzes = 0;
    String? lastQuizTaken;
    try {
      final quizResults = await _supabase
          .from('quiz_results')
          .select('score, taken_at')
          .eq('student_id', userId)
          .order('taken_at', ascending: false);

      totalQuizzes = quizResults.length;
      if (totalQuizzes > 0) {
        final scores = quizResults.map((r) => r['score'] as double).toList();
        averageQuizScore = scores.reduce((a, b) => a + b) / scores.length;
        lastQuizTaken = quizResults.first['taken_at'] as String;
      }
    } catch (e) {
      print('Error calculating quiz statistics: $e');
    }

    // Calculate learning streak
    int learningStreak = 0;
    try {
      learningStreak = await _calculateLearningStreak(userId);
    } catch (e) {
      print('Error calculating learning streak: $e');
    }

    return {
      'total_courses_enrolled': totalCoursesEnrolled,
      'total_lessons_accessed': totalLessonsAccessed,
      'total_materials_accessed': totalMaterialsAccessed,
      'average_quiz_score': averageQuizScore,
      'last_quiz_taken': lastQuizTaken,
      'total_quizzes': totalQuizzes,
      'learning_streak': learningStreak,
    };
  }

  // Calculate learning streak based on consecutive days of activity
  Future<int> _calculateLearningStreak(String userId) async {
    try {
      // Get all activity dates from lesson_access, material_access, and quiz_results
      final lessonDates = await _supabase
          .from('lesson_access')
          .select('accessed_at')
          .eq('student_id', userId);

      final materialDates = await _supabase
          .from('material_access')
          .select('accessed_at')
          .eq('student_id', userId);

      final quizDates = await _supabase
          .from('quiz_results')
          .select('taken_at')
          .eq('student_id', userId);

      // Combine all activity dates
      final allDates = <DateTime>{};

      for (final lesson in lessonDates) {
        allDates.add(DateTime.parse(lesson['accessed_at']).toLocal());
      }

      for (final material in materialDates) {
        allDates.add(DateTime.parse(material['accessed_at']).toLocal());
      }

      for (final quiz in quizDates) {
        allDates.add(DateTime.parse(quiz['taken_at']).toLocal());
      }

      // Convert to date-only strings and get unique dates
      final uniqueDates = allDates
          .map((date) => DateTime(date.year, date.month, date.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Sort descending

      if (uniqueDates.isEmpty) return 0;

      // Calculate consecutive days from today
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      int streak = 0;
      DateTime currentDate = todayDate;

      for (final activityDate in uniqueDates) {
        if (currentDate.difference(activityDate).inDays <= 1) {
          streak++;
          currentDate = activityDate;
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      print('Error calculating learning streak: $e');
      return 0;
    }
  }

  // Get user report
  Future<Map<String, dynamic>?> getUserReport(String userId) async {
    try {
      final response = await _supabase
          .from('user_reports')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching user report: $e');
      return null;
    }
  }

  // Initialize user report for new users
  Future<void> initializeUserReport(String userId) async {
    try {
      await _supabase.from('user_reports').insert({
        'user_id': userId,
        'total_courses_enrolled': 0,
        'total_lessons_accessed': 0,
        'total_materials_accessed': 0,
        'average_quiz_score': 0.0,
        'last_quiz_taken': null,
        'total_quizzes': 0,
        'learning_streak': 0,
      });
      print('User report initialized for user: $userId');
    } catch (e) {
      print('Error initializing user report: $e');
    }
  }
}
