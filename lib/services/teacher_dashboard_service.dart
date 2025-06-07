import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/teacher_dashboard_data.dart';
import '../models/user_model.dart';

class TeacherDashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SharedPreferences _prefs;

  TeacherDashboardService(this._prefs);

  Future<TeacherDashboardData> getDashboardData() async {
    try {
      // Get user data from shared preferences
      final userJson = _prefs.getString('current_user');
      if (userJson == null) {
        throw Exception('User not authenticated');
      }

      final userData = jsonDecode(userJson);
      final user = User.fromJson(userData);
      final userId = user.id;

      // Get total students (users with role 'student')
      final studentsCount = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'student')
          .count()
          .then((response) => response.count ?? 0);

      // Get total courses
      final coursesCount = await _supabase
          .from('courses')
          .select('id')
          .eq('teacher_id', userId)
          .count()
          .then((response) => response.count ?? 0);

      // Get total quizzes
      final teacherCourses =
          await _supabase.from('courses').select('id').eq('teacher_id', userId);

      final courseIds =
          teacherCourses.map((course) => course['id'] as String).toList();

      final quizzesCount = await _supabase
          .from('quizzes')
          .select('id')
          .inFilter('course_id', courseIds)
          .count()
          .then((response) => response.count ?? 0);

      // Get total materials
      final teacherLessons = await _supabase
          .from('lessons')
          .select('id')
          .inFilter('course_id', courseIds);

      final lessonIds =
          teacherLessons.map((lesson) => lesson['id'] as String).toList();

      final materialsCount = await _supabase
          .from('materials')
          .select('id')
          .inFilter('lesson_id', lessonIds)
          .count()
          .then((response) => response.count ?? 0);

      // Get total categories created by this teacher
      final categoriesCount = await _supabase
          .from('categories')
          .select('id')
          .eq('teacher_id', userId)
          .count()
          .then((response) => response.count ?? 0);

      // Get recent activities (combine enrollments, quiz results, and course progress)
      final recentEnrollments = await _supabase
          .from('enrollments')
          .select('''
            id,
            enrolled_at,
            courses!inner (
              title
            )
          ''')
          .eq('courses.teacher_id', userId)
          .order('enrolled_at', ascending: false)
          .limit(5);

      final recentQuizResults = await _supabase
          .from('quiz_results')
          .select('''
            id,
            taken_at,
            score,
            quizzes!inner (
              title,
              courses!inner (
                teacher_id
              )
            )
          ''')
          .eq('quizzes.courses.teacher_id', userId)
          .order('taken_at', ascending: false)
          .limit(5);

      final activities = [
        ...recentEnrollments.map((e) => RecentActivity(
              id: e['id'],
              type: 'enrollment',
              description: 'New student enrolled in ${e['courses']['title']}',
              timestamp: DateTime.parse(e['enrolled_at']),
            )),
        ...recentQuizResults.map((q) => RecentActivity(
              id: q['id'],
              type: 'quiz',
              description:
                  'Quiz "${q['quizzes']['title']}" completed with score ${q['score']}%',
              timestamp: DateTime.parse(q['taken_at']),
            )),
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Get course statistics
      final coursesResponse = await _supabase.from('courses').select('''
            id,
            title,
            enrollments (count),
            lessons (count),
            quizzes (
              id,
              quiz_results (
                score
              )
            )
          ''').eq('teacher_id', userId);

      final courseStats = coursesResponse.map((course) {
        // Calculate average score from all quiz results in all quizzes
        final allQuizScores = (course['quizzes'] as List).expand((quiz) {
          return (quiz['quiz_results'] as List)
              .map((result) => (result['score'] as num?)?.toDouble() ?? 0.0);
        }).toList();

        final averageScore = allQuizScores.isEmpty
            ? 0.0
            : allQuizScores.reduce((a, b) => a + b) / allQuizScores.length;

        final enrolledStudentsRaw = course['enrollments']?[0]?['count'];
        final totalQuizzesRaw = course['lessons']?[0]?['count'];

        return CourseStats(
          courseId: course['id'],
          courseName: course['title'],
          enrolledStudents: (enrolledStudentsRaw is int)
              ? enrolledStudentsRaw
              : (enrolledStudentsRaw is double)
                  ? enrolledStudentsRaw.toInt()
                  : int.tryParse(enrolledStudentsRaw?.toString() ?? '0') ?? 0,
          totalQuizzes: (totalQuizzesRaw is int)
              ? totalQuizzesRaw
              : (totalQuizzesRaw is double)
                  ? totalQuizzesRaw.toInt()
                  : int.tryParse(totalQuizzesRaw?.toString() ?? '0') ?? 0,
          averageScore: averageScore,
        );
      }).toList();

      return TeacherDashboardData(
        totalStudents: studentsCount,
        totalCourses: coursesCount,
        totalQuizzes: quizzesCount,
        totalMaterials: materialsCount,
        totalCategories: categoriesCount,
        recentActivities:
            activities.take(5).toList(), // Keep only the 5 most recent
        courseStats: courseStats,
      );
    } catch (e) {
      throw Exception('Failed to fetch dashboard data: $e');
    }
  }
}
