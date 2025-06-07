class Answer {
  final int id;
  final int questionId;
  final String text;
  final bool isCorrect;
  final DateTime createdAt;

  Answer({
    required this.id,
    required this.questionId,
    required this.text,
    required this.isCorrect,
    required this.createdAt,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json['id'],
      questionId: json['question_id'],
      text: json['text'],
      isCorrect: json['is_correct'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'text': text,
      'is_correct': isCorrect,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
