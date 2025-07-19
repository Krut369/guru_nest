class CourseLearning {
  final String id;
  final String courseId;
  final String description;

  CourseLearning({
    required this.id,
    required this.courseId,
    required this.description,
  });

  factory CourseLearning.fromJson(Map<String, dynamic> json) {
    return CourseLearning(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'description': description,
    };
  }
}
