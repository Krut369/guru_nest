import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_model.dart'; // Import the User model

part 'course_model.freezed.dart';
part 'course_model.g.dart';

@freezed
class Course with _$Course {
  const factory Course({
    required String id,
    required String title,
    required String description,
    @JsonKey(name: 'image_url') required String? imageUrl,
    @JsonKey(name: 'category_id') required String? categoryId,
    @JsonKey(name: 'teacher_id') required String? teacherId,
    @JsonKey(name: 'is_premium') @Default(false) required bool isPremium,
    @JsonKey(fromJson: _priceFromJson) @Default(0.0) required double price,
    @JsonKey(fromJson: _ratingFromJson) @Default(0.0) required double rating,
    @JsonKey(fromJson: _enrollmentsFromJson)
    @Default(0)
    required int enrollments,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(fromJson: _userFromJson, toJson: _userToJson)
    required User? teacher,
  }) = _Course;

  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);
}

double _priceFromJson(dynamic value) {
  if (value == null) return 0.0;
  if (value is String) return double.parse(value);
  if (value is num) return value.toDouble();
  return 0.0;
}

double _ratingFromJson(dynamic value) {
  if (value == null) return 0.0;
  if (value is String) return double.parse(value);
  if (value is num) return value.toDouble();
  return 0.0;
}

int _enrollmentsFromJson(dynamic value) {
  if (value == null) return 0;
  if (value is String) return int.parse(value);
  if (value is num) return value.toInt();
  return 0;
}

User? _userFromJson(Map<String, dynamic>? json) =>
    json == null ? null : User.fromJson(json);

Map<String, dynamic>? _userToJson(User? user) => user?.toJson();
