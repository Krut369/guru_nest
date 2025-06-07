// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CourseImpl _$$CourseImplFromJson(Map<String, dynamic> json) => _$CourseImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String?,
      categoryId: json['category_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      price: json['price'] == null ? 0.0 : _priceFromJson(json['price']),
      rating: json['rating'] == null ? 0.0 : _ratingFromJson(json['rating']),
      enrollments: json['enrollments'] == null
          ? 0
          : _enrollmentsFromJson(json['enrollments']),
      createdAt: DateTime.parse(json['created_at'] as String),
      teacher: _userFromJson(json['teacher'] as Map<String, dynamic>?),
    );

Map<String, dynamic> _$$CourseImplToJson(_$CourseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'image_url': instance.imageUrl,
      'category_id': instance.categoryId,
      'teacher_id': instance.teacherId,
      'is_premium': instance.isPremium,
      'price': instance.price,
      'rating': instance.rating,
      'enrollments': instance.enrollments,
      'created_at': instance.createdAt.toIso8601String(),
      'teacher': _userToJson(instance.teacher),
    };
