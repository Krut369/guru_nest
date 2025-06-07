class Lesson {
  final String id;
  final String courseId;
  final String title;
  final String? content;
  final int lessonOrder;

  Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    this.content,
    this.lessonOrder = 1,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      lessonOrder: json['lesson_order'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'content': content,
      'lesson_order': lessonOrder,
    };
  }
}
