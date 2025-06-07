// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      password: json['password'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      createdAt: DateTime.parse(json['created_at'] as String),
      bio: json['bio'] as String?,
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'full_name': instance.fullName,
      'email': instance.email,
      'password': instance.password,
      'avatar_url': instance.avatarUrl,
      'role': _$UserRoleEnumMap[instance.role]!,
      'created_at': instance.createdAt.toIso8601String(),
      'bio': instance.bio,
    };

const _$UserRoleEnumMap = {
  UserRole.student: 'student',
  UserRole.teacher: 'teacher',
};
