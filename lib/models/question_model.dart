class Question {
  final String id;
  final String quizId;
  final String questionText;
  final String? questionType;
  final DateTime? createdAt;

  Question({
    required this.id,
    required this.quizId,
    required this.questionText,
    this.questionType,
    this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id']?.toString() ?? '',
      quizId: json['quiz_id']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? '',
      questionType: json['question_type']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'question_text': questionText,
      'question_type': questionType,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
