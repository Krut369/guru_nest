class CourseInclude {
  final String id;
  final String courseId;
  final String? icon;
  final String? title;

  CourseInclude({
    required this.id,
    required this.courseId,
    this.icon,
    this.title,
  });

  factory CourseInclude.fromJson(Map<String, dynamic> json) {
    return CourseInclude(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      icon: json['icon'] as String?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'icon': icon,
      'title': title,
    };
  }
}
