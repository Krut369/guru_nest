class LessonMaterial {
  final String id;
  final String lessonId;
  final String title;
  final String type;
  final String fileUrl;
  final DateTime uploadedAt;

  LessonMaterial({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.type,
    required this.fileUrl,
    required this.uploadedAt,
  });

  factory LessonMaterial.fromJson(Map<String, dynamic> json) {
    return LessonMaterial(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      fileUrl: json['file_url'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'title': title,
      'type': type,
      'file_url': fileUrl,
      'uploaded_at': uploadedAt.toUtc().toIso8601String(),
    };
  }
}
