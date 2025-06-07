// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enrollment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EnrollmentImpl _$$EnrollmentImplFromJson(Map<String, dynamic> json) =>
    _$EnrollmentImpl(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      courseId: json['courseId'] as String,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      course: Course.fromJson(json['course'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$EnrollmentImplToJson(_$EnrollmentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'studentId': instance.studentId,
      'courseId': instance.courseId,
      'enrolled_at': instance.enrolledAt.toIso8601String(),
      'course': instance.course,
    };
