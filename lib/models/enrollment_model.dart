import 'package:freezed_annotation/freezed_annotation.dart';

import 'course_model.dart';

part 'enrollment_model.freezed.dart';
part 'enrollment_model.g.dart';

@freezed
class Enrollment with _$Enrollment {
  const factory Enrollment({
    required String id,
    required String studentId,
    required String courseId,
    @JsonKey(name: 'enrolled_at') required DateTime enrolledAt,
    @JsonKey(name: 'course') required Course course,
  }) = _Enrollment;

  factory Enrollment.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentFromJson(json);
}
