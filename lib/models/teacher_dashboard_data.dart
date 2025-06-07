class TeacherDashboardData {
  final int totalStudents;
  final int totalCourses;
  final int totalQuizzes;
  final int totalMaterials;
  final int totalCategories;
  final List<RecentActivity> recentActivities;
  final List<CourseStats> courseStats;

  TeacherDashboardData({
    required this.totalStudents,
    required this.totalCourses,
    required this.totalQuizzes,
    required this.totalMaterials,
    required this.totalCategories,
    required this.recentActivities,
    required this.courseStats,
  });

  factory TeacherDashboardData.fromJson(Map<String, dynamic> json) {
    return TeacherDashboardData(
      totalStudents: json['total_students'] ?? 0,
      totalCourses: json['total_courses'] ?? 0,
      totalQuizzes: json['total_quizzes'] ?? 0,
      totalMaterials: json['total_materials'] ?? 0,
      totalCategories: json['total_categories'] ?? 0,
      recentActivities: (json['recent_activities'] as List?)
              ?.map((e) => RecentActivity.fromJson(e))
              .toList() ??
          [],
      courseStats: (json['course_stats'] as List?)
              ?.map((e) => CourseStats.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class RecentActivity {
  final String id;
  final String type;
  final String description;
  final DateTime timestamp;

  RecentActivity({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class CourseStats {
  final String courseId;
  final String courseName;
  final int enrolledStudents;
  final double averageScore;
  final int totalQuizzes;

  CourseStats({
    required this.courseId,
    required this.courseName,
    required this.enrolledStudents,
    required this.averageScore,
    required this.totalQuizzes,
  });

  factory CourseStats.fromJson(Map<String, dynamic> json) {
    return CourseStats(
      courseId: json['course_id'],
      courseName: json['course_name'],
      enrolledStudents: json['enrolled_students'] ?? 0,
      averageScore: (json['average_score'] ?? 0.0).toDouble(),
      totalQuizzes: json['total_quizzes'] ?? 0,
    );
  }
}
