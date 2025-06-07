// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Course _$CourseFromJson(Map<String, dynamic> json) {
  return _Course.fromJson(json);
}

/// @nodoc
mixin _$Course {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'category_id')
  String? get categoryId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String? get teacherId => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_premium')
  bool get isPremium => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _priceFromJson)
  double get price => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _ratingFromJson)
  double get rating => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _enrollmentsFromJson)
  int get enrollments => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _userFromJson, toJson: _userToJson)
  User? get teacher => throw _privateConstructorUsedError;

  /// Serializes this Course to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseCopyWith<Course> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseCopyWith<$Res> {
  factory $CourseCopyWith(Course value, $Res Function(Course) then) =
      _$CourseCopyWithImpl<$Res, Course>;
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      @JsonKey(name: 'image_url') String? imageUrl,
      @JsonKey(name: 'category_id') String? categoryId,
      @JsonKey(name: 'teacher_id') String? teacherId,
      @JsonKey(name: 'is_premium') bool isPremium,
      @JsonKey(fromJson: _priceFromJson) double price,
      @JsonKey(fromJson: _ratingFromJson) double rating,
      @JsonKey(fromJson: _enrollmentsFromJson) int enrollments,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(fromJson: _userFromJson, toJson: _userToJson) User? teacher});

  $UserCopyWith<$Res>? get teacher;
}

/// @nodoc
class _$CourseCopyWithImpl<$Res, $Val extends Course>
    implements $CourseCopyWith<$Res> {
  _$CourseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? imageUrl = freezed,
    Object? categoryId = freezed,
    Object? teacherId = freezed,
    Object? isPremium = null,
    Object? price = null,
    Object? rating = null,
    Object? enrollments = null,
    Object? createdAt = null,
    Object? teacher = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      teacherId: freezed == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String?,
      isPremium: null == isPremium
          ? _value.isPremium
          : isPremium // ignore: cast_nullable_to_non_nullable
              as bool,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      enrollments: null == enrollments
          ? _value.enrollments
          : enrollments // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      teacher: freezed == teacher
          ? _value.teacher
          : teacher // ignore: cast_nullable_to_non_nullable
              as User?,
    ) as $Val);
  }

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserCopyWith<$Res>? get teacher {
    if (_value.teacher == null) {
      return null;
    }

    return $UserCopyWith<$Res>(_value.teacher!, (value) {
      return _then(_value.copyWith(teacher: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CourseImplCopyWith<$Res> implements $CourseCopyWith<$Res> {
  factory _$$CourseImplCopyWith(
          _$CourseImpl value, $Res Function(_$CourseImpl) then) =
      __$$CourseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      @JsonKey(name: 'image_url') String? imageUrl,
      @JsonKey(name: 'category_id') String? categoryId,
      @JsonKey(name: 'teacher_id') String? teacherId,
      @JsonKey(name: 'is_premium') bool isPremium,
      @JsonKey(fromJson: _priceFromJson) double price,
      @JsonKey(fromJson: _ratingFromJson) double rating,
      @JsonKey(fromJson: _enrollmentsFromJson) int enrollments,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(fromJson: _userFromJson, toJson: _userToJson) User? teacher});

  @override
  $UserCopyWith<$Res>? get teacher;
}

/// @nodoc
class __$$CourseImplCopyWithImpl<$Res>
    extends _$CourseCopyWithImpl<$Res, _$CourseImpl>
    implements _$$CourseImplCopyWith<$Res> {
  __$$CourseImplCopyWithImpl(
      _$CourseImpl _value, $Res Function(_$CourseImpl) _then)
      : super(_value, _then);

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? imageUrl = freezed,
    Object? categoryId = freezed,
    Object? teacherId = freezed,
    Object? isPremium = null,
    Object? price = null,
    Object? rating = null,
    Object? enrollments = null,
    Object? createdAt = null,
    Object? teacher = freezed,
  }) {
    return _then(_$CourseImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      teacherId: freezed == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String?,
      isPremium: null == isPremium
          ? _value.isPremium
          : isPremium // ignore: cast_nullable_to_non_nullable
              as bool,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      enrollments: null == enrollments
          ? _value.enrollments
          : enrollments // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      teacher: freezed == teacher
          ? _value.teacher
          : teacher // ignore: cast_nullable_to_non_nullable
              as User?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CourseImpl implements _Course {
  const _$CourseImpl(
      {required this.id,
      required this.title,
      required this.description,
      @JsonKey(name: 'image_url') required this.imageUrl,
      @JsonKey(name: 'category_id') required this.categoryId,
      @JsonKey(name: 'teacher_id') required this.teacherId,
      @JsonKey(name: 'is_premium') this.isPremium = false,
      @JsonKey(fromJson: _priceFromJson) this.price = 0.0,
      @JsonKey(fromJson: _ratingFromJson) this.rating = 0.0,
      @JsonKey(fromJson: _enrollmentsFromJson) this.enrollments = 0,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(fromJson: _userFromJson, toJson: _userToJson)
      required this.teacher});

  factory _$CourseImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @override
  @JsonKey(name: 'category_id')
  final String? categoryId;
  @override
  @JsonKey(name: 'teacher_id')
  final String? teacherId;
  @override
  @JsonKey(name: 'is_premium')
  final bool isPremium;
  @override
  @JsonKey(fromJson: _priceFromJson)
  final double price;
  @override
  @JsonKey(fromJson: _ratingFromJson)
  final double rating;
  @override
  @JsonKey(fromJson: _enrollmentsFromJson)
  final int enrollments;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(fromJson: _userFromJson, toJson: _userToJson)
  final User? teacher;

  @override
  String toString() {
    return 'Course(id: $id, title: $title, description: $description, imageUrl: $imageUrl, categoryId: $categoryId, teacherId: $teacherId, isPremium: $isPremium, price: $price, rating: $rating, enrollments: $enrollments, createdAt: $createdAt, teacher: $teacher)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId) &&
            (identical(other.isPremium, isPremium) ||
                other.isPremium == isPremium) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.enrollments, enrollments) ||
                other.enrollments == enrollments) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.teacher, teacher) || other.teacher == teacher));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      description,
      imageUrl,
      categoryId,
      teacherId,
      isPremium,
      price,
      rating,
      enrollments,
      createdAt,
      teacher);

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseImplCopyWith<_$CourseImpl> get copyWith =>
      __$$CourseImplCopyWithImpl<_$CourseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseImplToJson(
      this,
    );
  }
}

abstract class _Course implements Course {
  const factory _Course(
      {required final String id,
      required final String title,
      required final String description,
      @JsonKey(name: 'image_url') required final String? imageUrl,
      @JsonKey(name: 'category_id') required final String? categoryId,
      @JsonKey(name: 'teacher_id') required final String? teacherId,
      @JsonKey(name: 'is_premium') final bool isPremium,
      @JsonKey(fromJson: _priceFromJson) final double price,
      @JsonKey(fromJson: _ratingFromJson) final double rating,
      @JsonKey(fromJson: _enrollmentsFromJson) final int enrollments,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(fromJson: _userFromJson, toJson: _userToJson)
      required final User? teacher}) = _$CourseImpl;

  factory _Course.fromJson(Map<String, dynamic> json) = _$CourseImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;
  @override
  @JsonKey(name: 'category_id')
  String? get categoryId;
  @override
  @JsonKey(name: 'teacher_id')
  String? get teacherId;
  @override
  @JsonKey(name: 'is_premium')
  bool get isPremium;
  @override
  @JsonKey(fromJson: _priceFromJson)
  double get price;
  @override
  @JsonKey(fromJson: _ratingFromJson)
  double get rating;
  @override
  @JsonKey(fromJson: _enrollmentsFromJson)
  int get enrollments;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(fromJson: _userFromJson, toJson: _userToJson)
  User? get teacher;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseImplCopyWith<_$CourseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
