import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'user_reports_service.dart';

class LessonProgressService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  final UserReportsService _userReportsService = UserReportsService();

  // Mark a lesson as completed for a student
  Future<void> markLessonCompleted(String studentId, String lessonId) async {
    try {
      print('=== START: Marking lesson as completed ===');
      print('Student ID: $studentId');
      print('Lesson ID: $lessonId');

      // Skip the database function and go directly to insert
      print('Using direct insert method...');
      await _insertLessonProgress(studentId, lessonId);

      // Verify that the entry was actually created
      print('Verifying entry was created...');
      final isCompleted = await isLessonCompleted(studentId, lessonId);
      print('Verification result: $isCompleted');

      if (!isCompleted) {
        print('❌ Verification failed - lesson not marked as completed');
        throw Exception(
            'Failed to mark lesson as completed - verification failed');
      }

      // Update user reports with new learning streak
      print('Updating user reports...');
      await _userReportsService.updateUserReportOnLessonCompletion(studentId);

      print('✅ Lesson marked as completed successfully and verified');
      print('✅ User reports updated with new learning streak');
      print('=== END: Marking lesson as completed ===');
    } catch (e) {
      print('❌ Error marking lesson as completed: $e');
      throw Exception('Failed to mark lesson as completed: $e');
    }
  }

  // Insert lesson progress directly (simplified method)
  Future<void> _insertLessonProgress(String studentId, String lessonId) async {
    try {
      print('--- START: Direct insert ---');
      print('Student ID: $studentId');
      print('Lesson ID: $lessonId');

      final now = DateTime.now().toIso8601String();
      final data = {
        'student_id': studentId,
        'lesson_id': lessonId,
        'is_completed': true,
        'completed_at': now,
        // Removed updated_at since it doesn't exist in the table
      };

      print('Data to insert: $data');

      // Try simple insert first
      try {
        print('Attempting simple insert...');
        final insertResponse =
            await _supabase.from('lesson_progress').insert(data).select();

        print('Simple insert response: $insertResponse');
        print('Simple insert successful!');
        return;
      } catch (insertError) {
        print('Simple insert failed: $insertError');
        print('Trying upsert instead...');
      }

      // If simple insert fails, try upsert
      final upsertResponse = await _supabase
          .from('lesson_progress')
          .upsert(data, onConflict: 'student_id,lesson_id')
          .select();

      print('Upsert response: $upsertResponse');

      if (upsertResponse.isEmpty) {
        throw Exception('No response from upsert operation');
      }

      print('✅ Lesson progress inserted successfully via upsert');
      print('--- END: Direct insert ---');
    } catch (e) {
      print('❌ Error inserting lesson progress: $e');
      throw Exception('Failed to insert lesson progress: $e');
    }
  }

  // Check if a lesson is completed for a student
  Future<bool> isLessonCompleted(String studentId, String lessonId) async {
    try {
      final result =
          await _supabase.rpc('get_lesson_completion_status', params: {
        'student_uuid': studentId,
        'lesson_uuid': lessonId,
      });

      return result as bool? ?? false;
    } catch (e) {
      print('Error checking lesson completion status: $e');
      // Fallback: query directly
      return await _checkLessonCompletionDirectly(studentId, lessonId);
    }
  }

  // Check lesson completion directly (fallback method)
  Future<bool> _checkLessonCompletionDirectly(
      String studentId, String lessonId) async {
    try {
      final response = await _supabase
          .from('lesson_progress')
          .select('is_completed')
          .eq('student_id', studentId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      return response?['is_completed'] as bool? ?? false;
    } catch (e) {
      print('Error checking lesson completion directly: $e');
      return false;
    }
  }

  // Get lesson completion details including timestamp
  Future<Map<String, dynamic>?> getLessonCompletionDetails(
      String studentId, String lessonId) async {
    try {
      final response = await _supabase
          .from('lesson_progress')
          .select('is_completed, completed_at')
          .eq('student_id', studentId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error getting lesson completion details: $e');
      return null;
    }
  }

  // Get all completed lessons for a student
  Future<List<Map<String, dynamic>>> getCompletedLessons(
      String studentId) async {
    try {
      final result =
          await _supabase.rpc('get_student_completed_lessons', params: {
        'student_uuid': studentId,
      });

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Error getting completed lessons: $e');
      // Fallback: query directly
      return await _getCompletedLessonsDirectly(studentId);
    }
  }

  // Get completed lessons directly (fallback method)
  Future<List<Map<String, dynamic>>> _getCompletedLessonsDirectly(
      String studentId) async {
    try {
      final response = await _supabase
          .from('lesson_progress')
          .select('''
            lesson_id,
            completed_at,
            lessons (
              title,
              description,
              courses (
                title
              )
            )
          ''')
          .eq('student_id', studentId)
          .eq('is_completed', true)
          .order('completed_at', ascending: false);

      return response
          .map((item) => {
                'lesson_id': item['lesson_id'],
                'lesson_title': item['lessons']?['title'] ?? 'Unknown Lesson',
                'lesson_description': item['lessons']?['description'],
                'completed_at': item['completed_at'],
                'course_title':
                    item['lessons']?['courses']?['title'] ?? 'Unknown Course',
              })
          .toList();
    } catch (e) {
      print('Error getting completed lessons directly: $e');
      return [];
    }
  }

  // Get course completion percentage for a student
  Future<double> getCourseCompletionPercentage(
      String studentId, String courseId) async {
    try {
      final result =
          await _supabase.rpc('get_course_completion_percentage', params: {
        'student_uuid': studentId,
        'course_uuid': courseId,
      });

      return (result as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print('Error getting course completion percentage: $e');
      // Fallback: calculate manually
      return await _calculateCourseCompletionPercentage(studentId, courseId);
    }
  }

  // Calculate course completion percentage manually (fallback method)
  Future<double> _calculateCourseCompletionPercentage(
      String studentId, String courseId) async {
    try {
      // Get total lessons in the course
      final totalLessonsResponse = await _supabase
          .from('lessons')
          .select('id')
          .eq('course_id', courseId);

      final totalLessons = totalLessonsResponse.length;

      if (totalLessons == 0) return 0.0;

      // Get completed lessons for this student in this course
      final completedLessonsResponse = await _supabase
          .from('lesson_progress')
          .select('''
            lesson_id,
            lessons!inner (
              course_id
            )
          ''')
          .eq('student_id', studentId)
          .eq('is_completed', true)
          .eq('lessons.course_id', courseId);

      final completedLessons = completedLessonsResponse.length;

      return (completedLessons / totalLessons) * 100;
    } catch (e) {
      print('Error calculating course completion percentage: $e');
      return 0.0;
    }
  }

  // Get overall student progress
  Future<Map<String, dynamic>> getStudentOverallProgress(
      String studentId) async {
    try {
      final result =
          await _supabase.rpc('get_student_overall_progress', params: {
        'student_uuid': studentId,
      });

      if (result is List && result.isNotEmpty) {
        final progress = result.first as Map<String, dynamic>;
        return {
          'total_courses': progress['total_courses'] ?? 0,
          'total_lessons': progress['total_lessons'] ?? 0,
          'completed_lessons': progress['completed_lessons'] ?? 0,
          'overall_completion_percentage':
              (progress['overall_completion_percentage'] as num?)?.toDouble() ??
                  0.0,
        };
      }

      return {
        'total_courses': 0,
        'total_lessons': 0,
        'completed_lessons': 0,
        'overall_completion_percentage': 0.0,
      };
    } catch (e) {
      print('Error getting student overall progress: $e');
      // Fallback: calculate manually
      return await _calculateStudentOverallProgress(studentId);
    }
  }

  // Calculate student overall progress manually (fallback method)
  Future<Map<String, dynamic>> _calculateStudentOverallProgress(
      String studentId) async {
    try {
      // Get total courses enrolled
      final enrollmentsResponse = await _supabase
          .from('enrollments')
          .select('course_id')
          .eq('student_id', studentId);

      final totalCourses =
          enrollmentsResponse.map((e) => e['course_id']).toSet().length;

      // Get total lessons across all enrolled courses
      final courseIds = enrollmentsResponse.map((e) => e['course_id']).toList();
      int totalLessons = 0;

      if (courseIds.isNotEmpty) {
        final lessonsResponse = await _supabase
            .from('lessons')
            .select('id')
            .inFilter('course_id', courseIds);

        totalLessons = lessonsResponse.length;
      }

      // Get completed lessons
      final completedLessonsResponse = await _supabase
          .from('lesson_progress')
          .select('id')
          .eq('student_id', studentId)
          .eq('is_completed', true);

      final completedLessons = completedLessonsResponse.length;

      // Calculate overall percentage
      final overallPercentage =
          totalLessons > 0 ? (completedLessons / totalLessons) * 100 : 0.0;

      return {
        'total_courses': totalCourses,
        'total_lessons': totalLessons,
        'completed_lessons': completedLessons,
        'overall_completion_percentage': overallPercentage,
      };
    } catch (e) {
      print('Error calculating student overall progress: $e');
      return {
        'total_courses': 0,
        'total_lessons': 0,
        'completed_lessons': 0,
        'overall_completion_percentage': 0.0,
      };
    }
  }

  // Get lesson progress for a specific course
  Future<List<Map<String, dynamic>>> getCourseLessonProgress(
      String studentId, String courseId) async {
    try {
      // Get all lessons in the course
      final lessonsResponse = await _supabase
          .from('lessons')
          .select('id, title, description, order_index')
          .eq('course_id', courseId)
          .order('order_index');

      final lessons = lessonsResponse;
      final progressList = <Map<String, dynamic>>[];

      for (final lesson in lessons) {
        final isCompleted = await isLessonCompleted(studentId, lesson['id']);

        progressList.add({
          'lesson_id': lesson['id'],
          'lesson_title': lesson['title'],
          'lesson_description': lesson['description'],
          'order_index': lesson['order_index'],
          'is_completed': isCompleted,
        });
      }

      return progressList;
    } catch (e) {
      print('Error getting course lesson progress: $e');
      return [];
    }
  }

  // Get recent lesson completions
  Future<List<Map<String, dynamic>>> getRecentCompletions(String studentId,
      {int limit = 10}) async {
    try {
      final response = await _supabase
          .from('lesson_progress')
          .select('''
            completed_at,
            lessons (
              title,
              description,
              courses (
                title
              )
            )
          ''')
          .eq('student_id', studentId)
          .eq('is_completed', true)
          .order('completed_at', ascending: false)
          .limit(limit);

      return response
          .map((item) => {
                'completed_at': item['completed_at'],
                'lesson_title': item['lessons']?['title'] ?? 'Unknown Lesson',
                'lesson_description': item['lessons']?['description'],
                'course_title':
                    item['lessons']?['courses']?['title'] ?? 'Unknown Course',
              })
          .toList();
    } catch (e) {
      print('Error getting recent completions: $e');
      return [];
    }
  }

  // Get lesson details by ID
  Future<Map<String, dynamic>?> getLessonDetails(String lessonId) async {
    try {
      final response = await _supabase.from('lessons').select('''
            id,
            title,
            description,
            order_index,
            courses (
              id,
              title
            )
          ''').eq('id', lessonId).maybeSingle();

      return response;
    } catch (e) {
      print('Error getting lesson details: $e');
      return null;
    }
  }

  // Get student's learning statistics
  Future<Map<String, dynamic>> getStudentLearningStats(String studentId) async {
    try {
      // Get total completed lessons
      final completedLessonsResponse = await _supabase
          .from('lesson_progress')
          .select('id')
          .eq('student_id', studentId)
          .eq('is_completed', true);

      final totalCompleted = completedLessonsResponse.length;

      // Get lessons completed this week
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final thisWeekResponse = await _supabase
          .from('lesson_progress')
          .select('id')
          .eq('student_id', studentId)
          .eq('is_completed', true)
          .gte('completed_at', weekAgo.toIso8601String());

      final thisWeekCompleted = thisWeekResponse.length;

      // Get lessons completed this month
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      final thisMonthResponse = await _supabase
          .from('lesson_progress')
          .select('id')
          .eq('student_id', studentId)
          .eq('is_completed', true)
          .gte('completed_at', monthAgo.toIso8601String());

      final thisMonthCompleted = thisMonthResponse.length;

      return {
        'total_completed': totalCompleted,
        'this_week_completed': thisWeekCompleted,
        'this_month_completed': thisMonthCompleted,
        'average_per_week': totalCompleted > 0
            ? (totalCompleted / 4).toStringAsFixed(1)
            : '0.0', // Assuming 4 weeks average
      };
    } catch (e) {
      print('Error getting student learning stats: $e');
      return {
        'total_completed': 0,
        'this_week_completed': 0,
        'this_month_completed': 0,
        'average_per_week': '0.0',
      };
    }
  }

  // Debug method to check table structure
  Future<void> debugCheckTableStructure() async {
    try {
      print('=== DEBUG: Checking table structure ===');

      // Try to get table info
      final tableInfo =
          await _supabase.from('lesson_progress').select('*').limit(1);

      print('Table exists and is accessible');
      print(
          'Sample row structure: ${tableInfo.isNotEmpty ? tableInfo.first.keys.toList() : 'No data'}');

      // Check if we can insert a test record
      print('Testing insert capability...');
      final testData = {
        'student_id': '00000000-0000-0000-0000-000000000000', // Test UUID
        'lesson_id': '00000000-0000-0000-0000-000000000000', // Test UUID
        'is_completed': true,
        'completed_at': DateTime.now().toIso8601String(),
        // Removed updated_at since it doesn't exist in the table
      };

      print('Test data: $testData');

      try {
        final testInsert =
            await _supabase.from('lesson_progress').insert(testData).select();
        print('✅ Test insert successful: $testInsert');

        // Clean up test data
        await _supabase
            .from('lesson_progress')
            .delete()
            .eq('student_id', '00000000-0000-0000-0000-000000000000');
        print('✅ Test data cleaned up');
      } catch (testError) {
        print('❌ Test insert failed: $testError');
      }

      print('=== END DEBUG ===');
    } catch (e) {
      print('❌ Error checking table structure: $e');
    }
  }

  // Debug method to check lesson progress entry
  Future<Map<String, dynamic>?> debugCheckLessonProgress(
      String studentId, String lessonId) async {
    try {
      print(
          'Debug: Checking lesson progress for student $studentId, lesson $lessonId');

      final response = await _supabase
          .from('lesson_progress')
          .select('*')
          .eq('student_id', studentId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      print('Debug: Lesson progress entry: $response');
      return response;
    } catch (e) {
      print('Debug: Error checking lesson progress: $e');
      return null;
    }
  }

  // Get all lesson progress entries for a student (debug method)
  Future<List<Map<String, dynamic>>> debugGetAllLessonProgress(
      String studentId) async {
    try {
      print('Debug: Getting all lesson progress for student $studentId');

      final response = await _supabase
          .from('lesson_progress')
          .select('''
            *,
            lessons (
              title,
              courses (
                title
              )
            )
          ''')
          .eq('student_id', studentId)
          .order('completed_at', ascending: false);

      print('Debug: All lesson progress entries: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Debug: Error getting all lesson progress: $e');
      return [];
    }
  }
}
