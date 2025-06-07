class Quiz {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final DateTime? createdAt;

  Quiz({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.createdAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'],
      courseId: json['course_id'],
      title: json['title'],
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class QuizResult {
  final String id;
  final String quizId;
  final String studentId;
  final double? score;
  final DateTime takenAt;

  QuizResult({
    required this.id,
    required this.quizId,
    required this.studentId,
    this.score,
    required this.takenAt,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      id: json['id'],
      quizId: json['quiz_id'],
      studentId: json['student_id'],
      score: json['score']?.toDouble(),
      takenAt: DateTime.parse(json['taken_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'student_id': studentId,
      'score': score,
      'taken_at': takenAt.toIso8601String(),
    };
  }
}
