import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../core/theme/app_theme.dart';

class AnalyticsService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // Test Supabase connection
  Future<bool> testConnection() async {
    try {
      print('Testing Supabase connection...');
      final response =
          await _supabase.from('user_reports').select('count').limit(1);
      print('Supabase connection successful');
      return true;
    } catch (e) {
      print('Supabase connection failed: $e');
      return false;
    }
  }

  // Get comprehensive analytics for a student
  Future<Map<String, dynamic>> getStudentAnalytics(String userId) async {
    try {
      print('Starting analytics fetch for user: $userId');

      // Get user report
      final userReport = await _getUserReport(userId);
      print('User report loaded: ${userReport.length} fields');

      // Get course enrollment data
      List<dynamic> enrollments = [];
      try {
        print('Fetching enrollments...');
        enrollments = await _supabase.from('enrollments').select('''
            enrolled_at,
            courses (
              title,
              category_id,
              price
            )
          ''').eq('student_id', userId).order('enrolled_at', ascending: false);
        print('Enrollments loaded: ${enrollments.length} records');
      } catch (e) {
        print('Error fetching enrollments: $e');
        enrollments = [];
      }

      // Get quiz performance data
      List<dynamic> quizResults = [];
      try {
        print('Fetching quiz results...');
        quizResults = await _supabase.from('quiz_results').select('''
            score,
            taken_at,
            quizzes (
              title,
              courses (
                title
              )
            )
          ''').eq('student_id', userId).order('taken_at', ascending: false);
        print('Quiz results loaded: ${quizResults.length} records');
      } catch (e) {
        print('Error fetching quiz results: $e');
        quizResults = [];
      }

      // Get lesson access data (check if table exists)
      List<dynamic> lessonAccess = [];
      try {
        print('Fetching lesson access...');
        lessonAccess = await _supabase.from('lesson_access').select('''
            accessed_at,
            lessons (
              title,
              courses (
                title
              )
            )
          ''').eq('student_id', userId).order('accessed_at', ascending: false);
        print('Lesson access loaded: ${lessonAccess.length} records');
      } catch (e) {
        print('Lesson access table not found, skipping: $e');
        lessonAccess = [];
      }

      // Get material access data (check if table exists)
      List<dynamic> materialAccess = [];
      try {
        print('Fetching material access...');
        materialAccess = await _supabase.from('material_access').select('''
            accessed_at,
            materials (
              title,
              type,
              lessons (
                title,
                courses (
                  title
                )
              )
            )
          ''').eq('student_id', userId).order('accessed_at', ascending: false);
        print('Material access loaded: ${materialAccess.length} records');
      } catch (e) {
        print('Material access table not found, skipping: $e');
        materialAccess = [];
      }

      // Get lesson progress data
      List<dynamic> lessonProgress = [];
      try {
        print('Fetching lesson progress...');
        lessonProgress = await _supabase
            .from('lesson_progress')
            .select('''
            completed_at,
            is_completed,
            lessons (
              title,
              courses (
                title
              )
            )
          ''')
            .eq('student_id', userId)
            .eq('is_completed', true)
            .order('completed_at', ascending: false);
        print('Lesson progress loaded: ${lessonProgress.length} records');
      } catch (e) {
        print('Error fetching lesson progress: $e');
        lessonProgress = [];
      }

      // Calculate additional metrics
      print('Calculating metrics...');
      final totalSpent = _calculateTotalSpent(enrollments);
      final averageQuizScore = _calculateAverageQuizScore(quizResults);
      final recentActivity = _getRecentActivity(
          enrollments, quizResults, lessonAccess, materialAccess);
      final categoryBreakdown = _getCategoryBreakdown(enrollments);

      final result = {
        'user_report': userReport,
        'total_spent': totalSpent,
        'average_quiz_score': averageQuizScore,
        'recent_activity': recentActivity,
        'category_breakdown': categoryBreakdown,
        'enrollments': enrollments,
        'quiz_results': quizResults,
        'lesson_access': lessonAccess,
        'material_access': materialAccess,
        'lesson_progress': lessonProgress,
      };

      print(
          'Analytics data prepared successfully with ${result.length} sections');
      return result;
    } catch (e) {
      print('Error getting student analytics: $e');
      print('Stack trace: ${StackTrace.current}');
      // Return default data instead of throwing
      return _getDefaultAnalyticsData(userId);
    }
  }

  // Get comprehensive analytics for a teacher
  Future<Map<String, dynamic>> getTeacherAnalytics(String teacherId) async {
    try {
      print('=== Starting getTeacherAnalytics for teacherId: $teacherId ===');

      // Get teacher's courses with enrollment count from the courses table
      List<dynamic> courses = [];
      try {
        print('Fetching courses for teacher: $teacherId');
        courses = await _supabase
            .from('courses')
            .select('''
              id,
              title,
              category_id,
              price,
              enrollments,
              created_at
            ''')
            .eq('teacher_id', teacherId)
            .order('created_at', ascending: false);
        print('Successfully fetched ${courses.length} courses for teacher');
        print('Course details: ${courses.map((c) => {
              'id': c['id'],
              'title': c['title'],
              'enrollments': c['enrollments']
            }).toList()}');
      } catch (e) {
        print('Error fetching teacher courses: $e');
        print('Stack trace: ${StackTrace.current}');
        courses = [];
      }

      // Calculate total students from the enrollments table
      int totalStudents = 0;
      try {
        if (courses.isNotEmpty) {
          final courseIds = courses.map((c) => c['id']).toList();
          print('Fetching enrollments for course IDs: $courseIds');

          // Get all enrollments for the teacher's courses
          final enrollments = await _supabase
              .from('enrollments')
              .select('student_id')
              .inFilter('course_id', courseIds);

          // Count unique students
          totalStudents =
              enrollments.map((e) => e['student_id']).toSet().length;
          print('Found $totalStudents unique students across all courses');
          print(
              'Enrollment details: ${enrollments.map((e) => e['student_id']).toList()}');
        } else {
          print('No courses found, total students = 0');
        }
      } catch (e) {
        print('Error calculating total students: $e');
        print('Stack trace: ${StackTrace.current}');
        totalStudents = 0;
      }

      // Calculate total revenue from course prices and enrollment counts
      double totalRevenue = 0.0;
      try {
        for (final course in courses) {
          final price = (course['price'] ?? 0.0) as double;
          final enrollmentCount = (course['enrollments'] ?? 0) as int;
          totalRevenue += price * enrollmentCount;
        }
        print('Calculated total revenue: $totalRevenue');
      } catch (e) {
        print('Error calculating total revenue: $e');
        totalRevenue = 0.0;
      }

      // Get recent activities from enrollments table
      List<dynamic> recentActivities = [];
      try {
        if (courses.isNotEmpty) {
          final courseIds = courses.map((c) => c['id']).toList();
          final recentEnrollments = await _supabase
              .from('enrollments')
              .select('''
                enrolled_at,
                courses!inner (
                  title,
                  teacher_id
                )
              ''')
              .inFilter('course_id', courseIds)
              .order('enrolled_at', ascending: false)
              .limit(5);

          recentActivities = recentEnrollments
              .map((enrollment) => {
                    'type': 'enrollment',
                    'title':
                        'New student enrolled in ${enrollment['courses']?['title'] ?? 'Unknown Course'}',
                    'timestamp': enrollment['enrolled_at'],
                    'icon': Icons.person_add,
                    'color': AppTheme.primaryBlue,
                  })
              .toList();

          print('Found ${recentActivities.length} recent activities');
        }
      } catch (e) {
        print('Error fetching recent activities: $e');
        recentActivities = [];
      }

      final result = {
        'total_courses': courses.length,
        'total_students': totalStudents,
        'total_revenue': totalRevenue,
        'course_performance': {},
        'student_engagement': {
          'total_students': totalStudents,
          'active_students': totalStudents,
          'total_lesson_access': 0,
          'total_material_access': 0,
          'total_quiz_attempts': 0,
          'engagement_rate': 0.0,
        },
        'recent_activities': recentActivities,
        'category_distribution': {},
        'courses': courses,
      };

      print('=== Analytics result for teacher $teacherId ===');
      print('Total courses: ${result['total_courses']}');
      print('Total students: ${result['total_students']}');
      print('Total revenue: ${result['total_revenue']}');
      print('=== End analytics ===');

      return result;
    } catch (e) {
      print('Error getting teacher analytics: $e');
      print('Stack trace: ${StackTrace.current}');
      return _getDefaultTeacherAnalyticsData();
    }
  }

  // Get platform-wide analytics (for admin)
  Future<Map<String, dynamic>> getPlatformAnalytics() async {
    try {
      // Get total users
      int totalUsers = 0;
      try {
        final response = await _supabase.from('users').select('id').count();
        totalUsers = response.count ?? 0;
      } catch (e) {
        print('Error fetching total users: $e');
        totalUsers = 0;
      }

      // Get total courses
      int totalCourses = 0;
      try {
        final response = await _supabase.from('courses').select('id').count();
        totalCourses = response.count ?? 0;
      } catch (e) {
        print('Error fetching total courses: $e');
        totalCourses = 0;
      }

      // Get total enrollments
      int totalEnrollments = 0;
      try {
        final response =
            await _supabase.from('enrollments').select('id').count();
        totalEnrollments = response.count ?? 0;
      } catch (e) {
        print('Error fetching total enrollments: $e');
        totalEnrollments = 0;
      }

      // Get total revenue
      double totalRevenue = 0.0;
      try {
        final enrollments = await _supabase.from('enrollments').select('''
              courses (
                price
              )
            ''');
        if (enrollments.isNotEmpty) {
          totalRevenue = enrollments
              .map((e) => (e['courses']?['price'] ?? 0.0) as double)
              .reduce((a, b) => a + b);
        }
      } catch (e) {
        print('Error calculating total revenue: $e');
        totalRevenue = 0.0;
      }

      // Get user growth trend
      final userGrowth = await _getUserGrowthTrend();

      // Get course popularity
      final coursePopularity = await _getCoursePopularity();

      return {
        'total_users': totalUsers,
        'total_courses': totalCourses,
        'total_enrollments': totalEnrollments,
        'total_revenue': totalRevenue,
        'user_growth': userGrowth,
        'course_popularity': coursePopularity,
      };
    } catch (e) {
      print('Error getting platform analytics: $e');
      return _getDefaultPlatformAnalyticsData();
    }
  }

  // Helper methods
  Future<Map<String, dynamic>> _getUserReport(String userId) async {
    try {
      print('Calculating real analytics data from database for user: $userId');

      // Calculate total courses enrolled directly from enrollments table
      int totalCoursesEnrolled = 0;
      try {
        final enrollments = await _supabase
            .from('enrollments')
            .select('id')
            .eq('student_id', userId);
        totalCoursesEnrolled = enrollments.length;
        print('Found $totalCoursesEnrolled course enrollments');
      } catch (e) {
        print('Error counting enrollments: $e');
      }

      // Calculate total lessons accessed directly from lesson_access table (if exists)
      int totalLessonsAccessed = 0;
      try {
        final lessonAccess = await _supabase
            .from('lesson_access')
            .select('id')
            .eq('student_id', userId);
        totalLessonsAccessed = lessonAccess.length;
        print('Found $totalLessonsAccessed lesson accesses');
      } catch (e) {
        print(
            'Lesson access table not found, using lesson progress instead: $e');
        // Fallback to lesson progress for lesson count
        try {
          final lessonProgress = await _supabase
              .from('lesson_progress')
              .select('id')
              .eq('student_id', userId)
              .eq('is_completed', true);
          totalLessonsAccessed = lessonProgress.length;
          print('Found $totalLessonsAccessed completed lessons as fallback');
        } catch (e2) {
          print('Error counting lesson progress: $e2');
        }
      }

      // Calculate total lessons completed from lesson_progress table
      int totalLessonsCompleted = 0;
      try {
        final lessonProgress = await _supabase
            .from('lesson_progress')
            .select('id')
            .eq('student_id', userId)
            .eq('is_completed', true);
        totalLessonsCompleted = lessonProgress.length;
        print('Found $totalLessonsCompleted completed lessons');
      } catch (e) {
        print('Error counting completed lessons: $e');
      }

      // Calculate total materials accessed directly from material_access table (if exists)
      int totalMaterialsAccessed = 0;
      try {
        final materialAccess = await _supabase
            .from('material_access')
            .select('id')
            .eq('student_id', userId);
        totalMaterialsAccessed = materialAccess.length;
        print('Found $totalMaterialsAccessed material accesses');
      } catch (e) {
        print('Material access table not found, skipping: $e');
      }

      // Calculate detailed quiz statistics directly from quiz_results table
      double averageQuizScore = 0.0;
      int totalQuizzes = 0;
      int highestQuizScore = 0;
      int lowestQuizScore = 100;
      String? lastQuizTaken;
      String? bestQuizTitle;
      String? worstQuizTitle;

      try {
        final quizResults = await _supabase.from('quiz_results').select('''
              score, 
              taken_at,
              quizzes (
                title
              )
            ''').eq('student_id', userId).order('taken_at', ascending: false);

        totalQuizzes = quizResults.length;
        if (totalQuizzes > 0) {
          // Handle both int and double score types
          final scores = quizResults.map((r) {
            final score = r['score'];
            if (score is int) {
              return score.toDouble();
            } else if (score is double) {
              return score;
            } else {
              return 0.0; // Default fallback
            }
          }).toList();

          averageQuizScore = scores.reduce((a, b) => a + b) / scores.length;
          lastQuizTaken = quizResults.first['taken_at'] as String;

          // Find highest and lowest scores
          for (int i = 0; i < quizResults.length; i++) {
            final score = quizResults[i]['score'];
            double scoreValue;

            if (score is int) {
              scoreValue = score.toDouble();
            } else if (score is double) {
              scoreValue = score;
            } else {
              scoreValue = 0.0;
            }

            if (scoreValue > highestQuizScore) {
              highestQuizScore = scoreValue.toInt();
              bestQuizTitle = quizResults[i]['quizzes']?['title'] as String?;
            }
            if (scoreValue < lowestQuizScore) {
              lowestQuizScore = scoreValue.toInt();
              worstQuizTitle = quizResults[i]['quizzes']?['title'] as String?;
            }
          }
        }
        print(
            'Found $totalQuizzes quiz results with average score: $averageQuizScore');
        print(
            'Highest score: $highestQuizScore% (${bestQuizTitle ?? 'Unknown'})');
        print(
            'Lowest score: $lowestQuizScore% (${worstQuizTitle ?? 'Unknown'})');
      } catch (e) {
        print('Error calculating quiz statistics: $e');
      }

      // Calculate learning streak directly from activity tables
      int learningStreak = 0;
      try {
        // First try to get from user_reports table
        final userReport = await _supabase
            .from('user_reports')
            .select('learning_streak')
            .eq('user_id', userId)
            .maybeSingle();

        if (userReport != null) {
          learningStreak = userReport['learning_streak'] ?? 0;
          print('Got learning streak from user_reports: $learningStreak');
        } else {
          // Fallback to calculating from activity tables
          learningStreak = await _calculateLearningStreak(userId);
          print('Calculated learning streak from activity: $learningStreak');
        }
      } catch (e) {
        print('Error getting learning streak: $e');
        // Fallback to calculating from activity tables
        learningStreak = await _calculateLearningStreak(userId);
      }

      // Calculate unread messages directly from messages table (using actual schema)
      int unreadMessages = 0;
      try {
        // Skip unread messages for now as the messages table structure is different
        // The messages table has conversation_id instead of recipient_id
        print('Skipping unread messages count - table structure differs');
      } catch (e) {
        print('Error counting unread messages: $e');
      }

      // Return real calculated data directly from database
      final realUserReport = {
        'user_id': userId,
        'total_courses_enrolled': totalCoursesEnrolled,
        'total_lessons_accessed': totalLessonsAccessed,
        'total_lessons_completed': totalLessonsCompleted,
        'total_materials_accessed': totalMaterialsAccessed,
        'average_quiz_score': averageQuizScore,
        'highest_quiz_score': highestQuizScore,
        'lowest_quiz_score': lowestQuizScore,
        'best_quiz_title': bestQuizTitle,
        'worst_quiz_title': worstQuizTitle,
        'last_quiz_taken': lastQuizTaken,
        'total_quizzes': totalQuizzes,
        'learning_streak': learningStreak,
        'unread_messages': unreadMessages,
      };

      // Calculate real totals from database for progress targets
      int totalAvailableCourses = 0;
      int totalAvailableLessons = 0;
      int totalAvailableQuizzes = 0;

      try {
        // Get total available courses
        final allCourses = await _supabase.from('courses').select('id').count();
        totalAvailableCourses = allCourses.count ?? 0;

        // Get total available lessons
        final allLessons = await _supabase.from('lessons').select('id').count();
        totalAvailableLessons = allLessons.count ?? 0;

        // Get total available quizzes
        final allQuizzes = await _supabase.from('quizzes').select('id').count();
        totalAvailableQuizzes = allQuizzes.count ?? 0;

        print(
            'Database totals - Courses: $totalAvailableCourses, Lessons: $totalAvailableLessons, Quizzes: $totalAvailableQuizzes');
      } catch (e) {
        print('Error fetching database totals: $e');
      }

      // Add database totals to the report
      realUserReport['total_available_courses'] = totalAvailableCourses;
      realUserReport['total_available_lessons'] = totalAvailableLessons;
      realUserReport['total_available_quizzes'] = totalAvailableQuizzes;

      print('Real analytics data calculated successfully from database');
      return realUserReport;
    } catch (e) {
      print('Error calculating analytics data from database: $e');
      print('Creating default analytics data for: $userId');
      // Return default data only if there's a serious error
      return {
        'user_id': userId,
        'total_courses_enrolled': 0,
        'total_lessons_accessed': 0,
        'total_lessons_completed': 0,
        'total_materials_accessed': 0,
        'average_quiz_score': 0.0,
        'highest_quiz_score': 0,
        'lowest_quiz_score': 100,
        'best_quiz_title': null,
        'worst_quiz_title': null,
        'last_quiz_taken': null,
        'total_quizzes': 0,
        'learning_streak': 0,
        'unread_messages': 0,
        'total_available_courses': 0,
        'total_available_lessons': 0,
        'total_available_quizzes': 0,
      };
    }
  }

  Map<String, dynamic> _getDefaultAnalyticsData(String userId) {
    return {
      'user_report': {
        'user_id': userId,
        'total_courses_enrolled': 0,
        'total_lessons_accessed': 0,
        'total_lessons_completed': 0,
        'total_materials_accessed': 0,
        'average_quiz_score': 0.0,
        'highest_quiz_score': 0,
        'lowest_quiz_score': 100,
        'best_quiz_title': null,
        'worst_quiz_title': null,
        'last_quiz_taken': null,
        'total_quizzes': 0,
        'learning_streak': 0,
        'unread_messages': 0,
        'total_available_courses': 0,
        'total_available_lessons': 0,
        'total_available_quizzes': 0,
      },
      'total_spent': 0.0,
      'average_quiz_score': 0.0,
      'recent_activity': [],
      'category_breakdown': {},
      'enrollments': [],
      'quiz_results': [],
      'lesson_access': [],
      'material_access': [],
    };
  }

  Map<String, dynamic> _getDefaultTeacherAnalyticsData() {
    return {
      'total_courses': 0,
      'total_students': 0,
      'total_revenue': 0.0,
      'course_performance': {},
      'student_engagement': {
        'total_students': 0,
        'active_students': 0,
        'total_lesson_access': 0,
        'total_material_access': 0,
        'total_quiz_attempts': 0,
        'engagement_rate': 0.0,
      },
      'recent_activities': [],
      'category_distribution': {},
      'courses': [],
    };
  }

  Map<String, dynamic> _getDefaultPlatformAnalyticsData() {
    return {
      'total_users': 0,
      'total_courses': 0,
      'total_enrollments': 0,
      'total_revenue': 0.0,
      'user_growth': [],
      'course_popularity': [],
    };
  }

  List<Map<String, dynamic>> _getRecentActivity(
    List<dynamic> enrollments,
    List<dynamic> quizResults,
    List<dynamic> lessonAccess,
    List<dynamic> materialAccess,
  ) {
    final activities = <Map<String, dynamic>>[];

    try {
      // Add enrollments
      for (final enrollment in enrollments) {
        activities.add({
          'type': 'enrollment',
          'title':
              'Enrolled in ${enrollment['courses']?['title'] ?? 'Unknown Course'}',
          'timestamp': enrollment['enrolled_at'],
          'icon': Icons.school,
          'color': AppTheme.primaryBlue,
        });
      }

      // Add quiz results
      for (final result in quizResults) {
        activities.add({
          'type': 'quiz',
          'title':
              'Quiz: ${result['quizzes']?['title'] ?? 'Unknown Quiz'} - ${result['score']}%',
          'timestamp': result['taken_at'],
          'icon': Icons.quiz,
          'color': AppTheme.successGreen,
        });
      }

      // Add lesson access
      for (final access in lessonAccess) {
        activities.add({
          'type': 'lesson',
          'title':
              'Accessed: ${access['lessons']?['title'] ?? 'Unknown Lesson'}',
          'timestamp': access['accessed_at'],
          'icon': Icons.menu_book,
          'color': AppTheme.warningOrange,
        });
      }

      // Add material access
      for (final access in materialAccess) {
        activities.add({
          'type': 'material',
          'title':
              'Downloaded: ${access['materials']?['title'] ?? 'Unknown Material'}',
          'timestamp': access['accessed_at'],
          'icon': Icons.attach_file,
          'color': AppTheme.errorRed,
        });
      }

      // Sort by timestamp (most recent first)
      activities.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    } catch (e) {
      print('Error processing recent activity: $e');
    }

    return activities.take(10).toList(); // Return last 10 activities
  }

  Map<String, int> _getCategoryBreakdown(List<dynamic> enrollments) {
    final categories = <String, int>{};

    try {
      for (final enrollment in enrollments) {
        final category =
            enrollment['courses']?['category_id'] ?? 'Uncategorized';
        categories[category] = (categories[category] ?? 0) + 1;
      }
    } catch (e) {
      print('Error processing category breakdown: $e');
    }

    return categories;
  }

  double _calculateTotalSpent(List<dynamic> enrollments) {
    if (enrollments.isEmpty) return 0.0;

    try {
      return enrollments
          .map((e) => (e['courses']?['price'] ?? 0.0) as double)
          .reduce((a, b) => a + b);
    } catch (e) {
      print('Error calculating total spent: $e');
      return 0.0;
    }
  }

  double _calculateAverageQuizScore(List<dynamic> quizResults) {
    if (quizResults.isEmpty) return 0.0;

    try {
      final scores = quizResults.map((r) {
        final score = r['score'];
        if (score is int) {
          return score.toDouble();
        } else if (score is double) {
          return score;
        } else {
          return 0.0; // Default fallback
        }
      }).toList();
      return scores.reduce((a, b) => a + b) / scores.length;
    } catch (e) {
      print('Error calculating average quiz score: $e');
      return 0.0;
    }
  }

  double _calculateTeacherRevenue(List<dynamic> courses) {
    double totalRevenue = 0.0;

    try {
      for (final course in courses) {
        final enrollmentCount = course['enrollments']?[0]?['count'] ?? 0;
        final price = (course['price'] ?? 0.0) as double;
        totalRevenue += enrollmentCount * price;
      }
    } catch (e) {
      print('Error calculating teacher revenue: $e');
      totalRevenue = 0.0;
    }

    return totalRevenue;
  }

  Map<String, dynamic> _calculateCoursePerformance(List<dynamic> courses) {
    final performance = <String, dynamic>{};

    try {
      for (final course in courses) {
        final courseId = course['id'] as String;
        final quizResults = course['quizzes'] as List? ?? [];

        double totalScore = 0.0;
        int totalAttempts = 0;

        for (final quiz in quizResults) {
          final results = quiz['quiz_results'] as List? ?? [];
          for (final result in results) {
            totalScore += result['score'] as double? ?? 0.0;
            totalAttempts++;
          }
        }

        final averageScore =
            totalAttempts > 0 ? totalScore / totalAttempts : 0.0;

        performance[courseId] = {
          'title': course['title'] ?? 'Unknown Course',
          'enrollments': course['enrollments']?[0]?['count'] ?? 0,
          'lessons': course['lessons']?[0]?['count'] ?? 0,
          'materials': course['materials']?[0]?['count'] ?? 0,
          'average_quiz_score': averageScore,
          'total_quiz_attempts': totalAttempts,
        };
      }
    } catch (e) {
      print('Error calculating course performance: $e');
    }

    return performance;
  }

  Future<Map<String, dynamic>> _getStudentEngagement(String teacherId) async {
    try {
      // Get all students enrolled in teacher's courses
      final enrollments = await _supabase.from('enrollments').select('''
            student_id,
            courses!inner (
              teacher_id
            )
          ''').eq('courses.teacher_id', teacherId);

      final studentIds =
          enrollments.map((e) => e['student_id'] as String).toSet();

      // Get engagement metrics for these students
      int lessonAccess = 0;
      int materialAccess = 0;
      int quizAttempts = 0;

      try {
        lessonAccess = await _supabase
            .from('lesson_access')
            .select('student_id')
            .inFilter('student_id', studentIds.toList())
            .then((response) => response.length);
      } catch (e) {
        print('Error fetching lesson access for engagement: $e');
      }

      try {
        materialAccess = await _supabase
            .from('material_access')
            .select('student_id')
            .inFilter('student_id', studentIds.toList())
            .then((response) => response.length);
      } catch (e) {
        print('Error fetching material access for engagement: $e');
      }

      try {
        quizAttempts = await _supabase
            .from('quiz_results')
            .select('student_id')
            .inFilter('student_id', studentIds.toList())
            .then((response) => response.length);
      } catch (e) {
        print('Error fetching quiz attempts for engagement: $e');
      }

      return {
        'total_students': studentIds.length,
        'active_students': studentIds.length, // Simplified for now
        'total_lesson_access': lessonAccess,
        'total_material_access': materialAccess,
        'total_quiz_attempts': quizAttempts,
        'engagement_rate': studentIds.isNotEmpty
            ? (lessonAccess + materialAccess + quizAttempts) / studentIds.length
            : 0.0,
      };
    } catch (e) {
      print('Error getting student engagement: $e');
      return {
        'total_students': 0,
        'active_students': 0,
        'total_lesson_access': 0,
        'total_material_access': 0,
        'total_quiz_attempts': 0,
        'engagement_rate': 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _getTeacherRecentActivities(
      String teacherId) async {
    final activities = <Map<String, dynamic>>[];

    try {
      // Get recent enrollments
      List<dynamic> recentEnrollments = [];
      try {
        recentEnrollments = await _supabase
            .from('enrollments')
            .select('''
              enrolled_at,
              courses!inner (
                title,
                teacher_id
              )
            ''')
            .eq('courses.teacher_id', teacherId)
            .order('enrolled_at', ascending: false)
            .limit(5);
      } catch (e) {
        print('Error fetching recent enrollments: $e');
      }

      for (final enrollment in recentEnrollments) {
        activities.add({
          'type': 'enrollment',
          'title':
              'New student enrolled in ${enrollment['courses']?['title'] ?? 'Unknown Course'}',
          'timestamp': enrollment['enrolled_at'],
          'icon': Icons.person_add,
          'color': AppTheme.primaryBlue,
        });
      }

      // Get recent quiz results
      List<dynamic> recentQuizResults = [];
      try {
        recentQuizResults = await _supabase
            .from('quiz_results')
            .select('''
              score,
              taken_at,
              quizzes!inner (
                title,
                courses!inner (
                  teacher_id
                )
              )
            ''')
            .eq('quizzes.courses.teacher_id', teacherId)
            .order('taken_at', ascending: false)
            .limit(5);
      } catch (e) {
        print('Error fetching recent quiz results: $e');
      }

      for (final result in recentQuizResults) {
        activities.add({
          'type': 'quiz',
          'title':
              'Quiz "${result['quizzes']?['title'] ?? 'Unknown Quiz'}" completed with ${result['score']}%',
          'timestamp': result['taken_at'],
          'icon': Icons.quiz,
          'color': AppTheme.successGreen,
        });
      }

      // Sort by timestamp
      activities.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    } catch (e) {
      print('Error processing teacher recent activities: $e');
    }

    return activities.take(10).toList();
  }

  Map<String, int> _getCategoryDistribution(List<dynamic> courses) {
    final categories = <String, int>{};

    try {
      for (final course in courses) {
        final category = course['category'] ?? 'Uncategorized';
        categories[category] = (categories[category] ?? 0) + 1;
      }
    } catch (e) {
      print('Error processing category distribution: $e');
    }

    return categories;
  }

  Future<List<Map<String, dynamic>>> _getUserGrowthTrend() async {
    // This would typically query user creation dates
    // For now, return mock data
    return [
      {'date': '2024-01-01', 'users': 100},
      {'date': '2024-01-02', 'users': 105},
      {'date': '2024-01-03', 'users': 110},
      // Add more data points as needed
    ];
  }

  Future<List<Map<String, dynamic>>> _getCoursePopularity() async {
    try {
      final popularCourses = await _supabase.from('courses').select('''
            title,
            enrollments (count)
          ''').order('enrollments.count', ascending: false).limit(10);

      return popularCourses
          .map((course) => {
                'title': course['title'] ?? 'Unknown Course',
                'enrollments': course['enrollments']?[0]?['count'] ?? 0,
              })
          .toList();
    } catch (e) {
      print('Error fetching course popularity: $e');
      return [];
    }
  }

  // Calculate learning streak (consecutive days of activity)
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
        print('Lesson access table not found for streak calculation: $e');
        lessonDates = [];
      }

      try {
        materialDates = await _supabase
            .from('material_access')
            .select('accessed_at')
            .eq('student_id', userId);
        print('Found ${materialDates.length} material access records');
      } catch (e) {
        print('Material access table not found for streak calculation: $e');
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
}
