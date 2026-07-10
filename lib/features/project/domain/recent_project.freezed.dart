// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recent_project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecentProject _$RecentProjectFromJson(Map<String, dynamic> json) {
  return _RecentProject.fromJson(json);
}

/// @nodoc
mixin _$RecentProject {
  String get filePath => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  DateTime get lastOpenedAt => throw _privateConstructorUsedError;

  /// Serializes this RecentProject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecentProject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecentProjectCopyWith<RecentProject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecentProjectCopyWith<$Res> {
  factory $RecentProjectCopyWith(
    RecentProject value,
    $Res Function(RecentProject) then,
  ) = _$RecentProjectCopyWithImpl<$Res, RecentProject>;
  @useResult
  $Res call({String filePath, String name, DateTime lastOpenedAt});
}

/// @nodoc
class _$RecentProjectCopyWithImpl<$Res, $Val extends RecentProject>
    implements $RecentProjectCopyWith<$Res> {
  _$RecentProjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecentProject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filePath = null,
    Object? name = null,
    Object? lastOpenedAt = null,
  }) {
    return _then(
      _value.copyWith(
            filePath: null == filePath
                ? _value.filePath
                : filePath // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            lastOpenedAt: null == lastOpenedAt
                ? _value.lastOpenedAt
                : lastOpenedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecentProjectImplCopyWith<$Res>
    implements $RecentProjectCopyWith<$Res> {
  factory _$$RecentProjectImplCopyWith(
    _$RecentProjectImpl value,
    $Res Function(_$RecentProjectImpl) then,
  ) = __$$RecentProjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String filePath, String name, DateTime lastOpenedAt});
}

/// @nodoc
class __$$RecentProjectImplCopyWithImpl<$Res>
    extends _$RecentProjectCopyWithImpl<$Res, _$RecentProjectImpl>
    implements _$$RecentProjectImplCopyWith<$Res> {
  __$$RecentProjectImplCopyWithImpl(
    _$RecentProjectImpl _value,
    $Res Function(_$RecentProjectImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecentProject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filePath = null,
    Object? name = null,
    Object? lastOpenedAt = null,
  }) {
    return _then(
      _$RecentProjectImpl(
        filePath: null == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        lastOpenedAt: null == lastOpenedAt
            ? _value.lastOpenedAt
            : lastOpenedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecentProjectImpl implements _RecentProject {
  const _$RecentProjectImpl({
    required this.filePath,
    required this.name,
    required this.lastOpenedAt,
  });

  factory _$RecentProjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecentProjectImplFromJson(json);

  @override
  final String filePath;
  @override
  final String name;
  @override
  final DateTime lastOpenedAt;

  @override
  String toString() {
    return 'RecentProject(filePath: $filePath, name: $name, lastOpenedAt: $lastOpenedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecentProjectImpl &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.lastOpenedAt, lastOpenedAt) ||
                other.lastOpenedAt == lastOpenedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, filePath, name, lastOpenedAt);

  /// Create a copy of RecentProject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecentProjectImplCopyWith<_$RecentProjectImpl> get copyWith =>
      __$$RecentProjectImplCopyWithImpl<_$RecentProjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecentProjectImplToJson(this);
  }
}

abstract class _RecentProject implements RecentProject {
  const factory _RecentProject({
    required final String filePath,
    required final String name,
    required final DateTime lastOpenedAt,
  }) = _$RecentProjectImpl;

  factory _RecentProject.fromJson(Map<String, dynamic> json) =
      _$RecentProjectImpl.fromJson;

  @override
  String get filePath;
  @override
  String get name;
  @override
  DateTime get lastOpenedAt;

  /// Create a copy of RecentProject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecentProjectImplCopyWith<_$RecentProjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
