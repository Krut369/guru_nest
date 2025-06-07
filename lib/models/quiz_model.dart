class Quiz {
  final String id;
  final String? courseId;
  final String title;
  final String? description;

  Quiz({
    required this.id,
    this.courseId,
    required this.title,
    this.description,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id']?.toString() ?? '',
      courseId: json['course_id']?.toString(),
      title: json['title'] ?? '',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
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

class GeneratedQuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;

  GeneratedQuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory GeneratedQuizQuestion.fromJson(Map<String, dynamic> json) {
    return GeneratedQuizQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }
}
