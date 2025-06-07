import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

enum UserRole { student, teacher }

@freezed
class User with _$User {
  const factory User({
    required String id,
    @JsonKey(name: 'full_name') required String fullName,
    required String email,
    String? password,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'role') required UserRole role,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

// Extension to add toJson method
extension UserExtension on User {
  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'password': password,
        'avatar_url': avatarUrl,
        'role': role.toString().split('.').last,
        'created_at': createdAt.toIso8601String(),
      };
}
