// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Project _$ProjectFromJson(Map<String, dynamic> json) {
  return _Project.fromJson(json);
}

/// @nodoc
mixin _$Project {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get mappingAssignments =>
      throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get filePath => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isDirty => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get embeddedTemplatePath => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get embeddedDatasourcePath => throw _privateConstructorUsedError;

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProjectCopyWith<Project> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectCopyWith<$Res> {
  factory $ProjectCopyWith(Project value, $Res Function(Project) then) =
      _$ProjectCopyWithImpl<$Res, Project>;
  @useResult
  $Res call({
    String id,
    String name,
    DateTime createdAt,
    DateTime updatedAt,
    List<Map<String, dynamic>> mappingAssignments,
    @JsonKey(includeFromJson: false, includeToJson: false) String? filePath,
    @JsonKey(includeFromJson: false, includeToJson: false) bool isDirty,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? embeddedTemplatePath,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? embeddedDatasourcePath,
  });
}

/// @nodoc
class _$ProjectCopyWithImpl<$Res, $Val extends Project>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? mappingAssignments = null,
    Object? filePath = freezed,
    Object? isDirty = null,
    Object? embeddedTemplatePath = freezed,
    Object? embeddedDatasourcePath = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            mappingAssignments: null == mappingAssignments
                ? _value.mappingAssignments
                : mappingAssignments // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, dynamic>>,
            filePath: freezed == filePath
                ? _value.filePath
                : filePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            isDirty: null == isDirty
                ? _value.isDirty
                : isDirty // ignore: cast_nullable_to_non_nullable
                      as bool,
            embeddedTemplatePath: freezed == embeddedTemplatePath
                ? _value.embeddedTemplatePath
                : embeddedTemplatePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            embeddedDatasourcePath: freezed == embeddedDatasourcePath
                ? _value.embeddedDatasourcePath
                : embeddedDatasourcePath // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProjectImplCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$$ProjectImplCopyWith(
    _$ProjectImpl value,
    $Res Function(_$ProjectImpl) then,
  ) = __$$ProjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    DateTime createdAt,
    DateTime updatedAt,
    List<Map<String, dynamic>> mappingAssignments,
    @JsonKey(includeFromJson: false, includeToJson: false) String? filePath,
    @JsonKey(includeFromJson: false, includeToJson: false) bool isDirty,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? embeddedTemplatePath,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? embeddedDatasourcePath,
  });
}

/// @nodoc
class __$$ProjectImplCopyWithImpl<$Res>
    extends _$ProjectCopyWithImpl<$Res, _$ProjectImpl>
    implements _$$ProjectImplCopyWith<$Res> {
  __$$ProjectImplCopyWithImpl(
    _$ProjectImpl _value,
    $Res Function(_$ProjectImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? mappingAssignments = null,
    Object? filePath = freezed,
    Object? isDirty = null,
    Object? embeddedTemplatePath = freezed,
    Object? embeddedDatasourcePath = freezed,
  }) {
    return _then(
      _$ProjectImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        mappingAssignments: null == mappingAssignments
            ? _value._mappingAssignments
            : mappingAssignments // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, dynamic>>,
        filePath: freezed == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        isDirty: null == isDirty
            ? _value.isDirty
            : isDirty // ignore: cast_nullable_to_non_nullable
                  as bool,
        embeddedTemplatePath: freezed == embeddedTemplatePath
            ? _value.embeddedTemplatePath
            : embeddedTemplatePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        embeddedDatasourcePath: freezed == embeddedDatasourcePath
            ? _value.embeddedDatasourcePath
            : embeddedDatasourcePath // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProjectImpl implements _Project {
  const _$ProjectImpl({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    final List<Map<String, dynamic>> mappingAssignments =
        const <Map<String, dynamic>>[],
    @JsonKey(includeFromJson: false, includeToJson: false) this.filePath,
    @JsonKey(includeFromJson: false, includeToJson: false) this.isDirty = false,
    @JsonKey(includeFromJson: false, includeToJson: false)
    this.embeddedTemplatePath,
    @JsonKey(includeFromJson: false, includeToJson: false)
    this.embeddedDatasourcePath,
  }) : _mappingAssignments = mappingAssignments;

  factory _$ProjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final List<Map<String, dynamic>> _mappingAssignments;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get mappingAssignments {
    if (_mappingAssignments is EqualUnmodifiableListView)
      return _mappingAssignments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mappingAssignments);
  }

  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? filePath;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isDirty;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? embeddedTemplatePath;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? embeddedDatasourcePath;

  @override
  String toString() {
    return 'Project(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, mappingAssignments: $mappingAssignments, filePath: $filePath, isDirty: $isDirty, embeddedTemplatePath: $embeddedTemplatePath, embeddedDatasourcePath: $embeddedDatasourcePath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(
              other._mappingAssignments,
              _mappingAssignments,
            ) &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.isDirty, isDirty) || other.isDirty == isDirty) &&
            (identical(other.embeddedTemplatePath, embeddedTemplatePath) ||
                other.embeddedTemplatePath == embeddedTemplatePath) &&
            (identical(other.embeddedDatasourcePath, embeddedDatasourcePath) ||
                other.embeddedDatasourcePath == embeddedDatasourcePath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_mappingAssignments),
    filePath,
    isDirty,
    embeddedTemplatePath,
    embeddedDatasourcePath,
  );

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectImplCopyWith<_$ProjectImpl> get copyWith =>
      __$$ProjectImplCopyWithImpl<_$ProjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProjectImplToJson(this);
  }
}

abstract class _Project implements Project {
  const factory _Project({
    required final String id,
    required final String name,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final List<Map<String, dynamic>> mappingAssignments,
    @JsonKey(includeFromJson: false, includeToJson: false)
    final String? filePath,
    @JsonKey(includeFromJson: false, includeToJson: false) final bool isDirty,
    @JsonKey(includeFromJson: false, includeToJson: false)
    final String? embeddedTemplatePath,
    @JsonKey(includeFromJson: false, includeToJson: false)
    final String? embeddedDatasourcePath,
  }) = _$ProjectImpl;

  factory _Project.fromJson(Map<String, dynamic> json) = _$ProjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  List<Map<String, dynamic>> get mappingAssignments;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get filePath;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isDirty;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get embeddedTemplatePath;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get embeddedDatasourcePath;

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectImplCopyWith<_$ProjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
