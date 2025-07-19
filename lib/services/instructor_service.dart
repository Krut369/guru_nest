import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user_model.dart';

class InstructorService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch comprehensive instructor details by ID
  Future<Map<String, dynamic>> getInstructorDetails(String instructorId) async {
    try {
      // Fetch basic instructor profile
      final instructorData = await _supabase
          .from('users')
          .select()
          .eq('id', instructorId)
          .eq('role', 'teacher')
          .single();

      final instructor = User.fromJson(instructorData);

      // Fetch instructor's courses
      final coursesData = await _supabase
          .from('courses')
          .select('''
            id,
            title,
            description,
            image_url,
            price,
            is_premium,
            rating,
            created_at,
            enrollments!course_id (count)
          ''')
          .eq('teacher_id', instructorId)
          .order('created_at', ascending: false);

      // Calculate instructor statistics
      final totalCourses = coursesData.length;
      final totalStudents = coursesData.fold<int>(0, (sum, course) {
        final enrollments = course['enrollments'] as List?;
        if (enrollments != null && enrollments.isNotEmpty) {
          return sum + (enrollments.first['count'] as int? ?? 0);
        }
        return sum;
      });

      final averageRating = coursesData.isNotEmpty
          ? coursesData
                  .map(
                      (course) => (course['rating'] as num?)?.toDouble() ?? 0.0)
                  .reduce((a, b) => a + b) /
              coursesData.length
          : 0.0;

      // Fetch instructor's recent activity (last 5 courses)
      final recentCourses = coursesData.take(5).toList();

      // Calculate instructor experience (days since first course)
      DateTime? firstCourseDate;
      if (coursesData.isNotEmpty) {
        final dates = coursesData
            .map((course) => DateTime.parse(course['created_at']))
            .toList();
        dates.sort();
        firstCourseDate = dates.first;
      }

      final experienceDays = firstCourseDate != null
          ? DateTime.now().difference(firstCourseDate).inDays
          : 0;

      return {
        'instructor': instructor,
        'totalCourses': totalCourses,
        'totalStudents': totalStudents,
        'averageRating': averageRating,
        'recentCourses': recentCourses,
        'experienceDays': experienceDays,
        'firstCourseDate': firstCourseDate?.toIso8601String(),
      };
    } catch (e) {
      print('Error fetching instructor details: $e');
      rethrow;
    }
  }

  /// Fetch instructor's course statistics
  Future<Map<String, dynamic>> getInstructorStats(String instructorId) async {
    try {
      // Get total courses
      final coursesCount = await _supabase
          .from('courses')
          .select('id')
          .eq('teacher_id', instructorId)
          .count()
          .then((response) => response.count ?? 0);

      // Get total students across all courses
      final enrollmentsData = await _supabase
          .from('enrollments')
          .select('course_id')
          .inFilter('course_id', await _getInstructorCourseIds(instructorId));

      final uniqueStudents =
          enrollmentsData.map((e) => e['course_id'] as String).toSet().length;

      // Get average rating
      final coursesData = await _supabase
          .from('courses')
          .select('rating')
          .eq('teacher_id', instructorId)
          .not('rating', 'is', null);

      final averageRating = coursesData.isNotEmpty
          ? coursesData
                  .map(
                      (course) => (course['rating'] as num?)?.toDouble() ?? 0.0)
                  .reduce((a, b) => a + b) /
              coursesData.length
          : 0.0;

      return {
        'totalCourses': coursesCount,
        'totalStudents': uniqueStudents,
        'averageRating': averageRating,
        'totalEnrollments': enrollmentsData.length,
      };
    } catch (e) {
      print('Error fetching instructor stats: $e');
      rethrow;
    }
  }

  /// Get instructor's course IDs
  Future<List<String>> _getInstructorCourseIds(String instructorId) async {
    try {
      final courses = await _supabase
          .from('courses')
          .select('id')
          .eq('teacher_id', instructorId);

      return courses.map((course) => course['id'] as String).toList();
    } catch (e) {
      print('Error fetching instructor course IDs: $e');
      return [];
    }
  }

  /// Fetch instructor's top performing courses
  Future<List<Map<String, dynamic>>> getTopCourses(String instructorId) async {
    try {
      final coursesData = await _supabase
          .from('courses')
          .select('''
            id,
            title,
            description,
            image_url,
            price,
            rating,
            enrollments!course_id (count)
          ''')
          .eq('teacher_id', instructorId)
          .order('rating', ascending: false)
          .limit(3);

      return List<Map<String, dynamic>>.from(coursesData);
    } catch (e) {
      print('Error fetching top courses: $e');
      return [];
    }
  }
}
