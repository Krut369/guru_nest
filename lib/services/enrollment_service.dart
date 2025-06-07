import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/enrollment_model.dart';

class EnrollmentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Enrollment>> getEnrollments(String studentId) async {
    try {
      final response = await _supabase
          .from('enrollments')
          .select('''
            id,
            student_id,
            course_id,
            enrolled_at,
            course:course_id (
              id,
              title,
              description,
              image_url,
              teacher_id,
              price,
              created_at,
              is_premium,
              rating
            )
          ''')
          .eq('student_id', studentId)
          .order('enrolled_at', ascending: false);

      return (response as List)
          .map((json) => Enrollment.fromJson({
                'id': json['id'],
                'studentId': json['student_id'],
                'courseId': json['course_id'],
                'enrolled_at': json['enrolled_at'],
                'course': json['course'],
              }))
          .toList();
    } catch (e) {
      print('Error fetching enrollments: $e');
      rethrow;
    }
  }

  Future<Enrollment> enrollInCourse(String studentId, String courseId) async {
    try {
      final response = await _supabase.from('enrollments').insert({
        'student_id': studentId,
        'course_id': courseId,
        'enrolled_at': DateTime.now().toIso8601String(),
      }).select('''
            id,
            student_id,
            course_id,
            enrolled_at,
            course:course_id (
              id,
              title,
              description,
              image_url,
              teacher_id,
              price,
              created_at,
              is_premium,
              rating
            )
          ''').single();

      return Enrollment.fromJson({
        'id': response['id'],
        'studentId': response['student_id'],
        'courseId': response['course_id'],
        'enrolled_at': response['enrolled_at'],
        'course': response['course'],
      });
    } catch (e) {
      print('Error enrolling in course: $e');
      rethrow;
    }
  }

  Future<void> unenrollFromCourse(String studentId, String courseId) async {
    try {
      await _supabase.from('enrollments').delete().match({
        'student_id': studentId,
        'course_id': courseId,
      });
    } catch (e) {
      print('Error unenrolling from course: $e');
      rethrow;
    }
  }

  Future<bool> isEnrolled(String studentId, String courseId) async {
    try {
      final response = await _supabase
          .from('enrollments')
          .select()
          .eq('student_id', studentId)
          .eq('course_id', courseId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking enrollment status: $e');
      rethrow;
    }
  }
}
