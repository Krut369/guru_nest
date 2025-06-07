class QuizOption {
  final String id;
  final String questionId;
  final String optionText;
  final bool isCorrect;
  final DateTime? createdAt;

  QuizOption({
    required this.id,
    required this.questionId,
    required this.optionText,
    required this.isCorrect,
    this.createdAt,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      optionText: json['option_text']?.toString() ?? '',
      isCorrect: json['is_correct'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'option_text': optionText,
      'is_correct': isCorrect,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
