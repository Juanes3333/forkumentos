// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_template.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ProjectTemplate {
  String get id => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;

  /// Ruta del DOCX en la caché del proyecto (solo en ejecución).
  String? get embeddedPath => throw _privateConstructorUsedError;

  /// Mapeo de esta plantilla en el formato de `mappings.json`.
  List<Map<String, dynamic>> get assignments =>
      throw _privateConstructorUsedError;

  /// Create a copy of ProjectTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProjectTemplateCopyWith<ProjectTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectTemplateCopyWith<$Res> {
  factory $ProjectTemplateCopyWith(
    ProjectTemplate value,
    $Res Function(ProjectTemplate) then,
  ) = _$ProjectTemplateCopyWithImpl<$Res, ProjectTemplate>;
  @useResult
  $Res call({
    String id,
    String fileName,
    String? embeddedPath,
    List<Map<String, dynamic>> assignments,
  });
}

/// @nodoc
class _$ProjectTemplateCopyWithImpl<$Res, $Val extends ProjectTemplate>
    implements $ProjectTemplateCopyWith<$Res> {
  _$ProjectTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProjectTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileName = null,
    Object? embeddedPath = freezed,
    Object? assignments = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            fileName: null == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                      as String,
            embeddedPath: freezed == embeddedPath
                ? _value.embeddedPath
                : embeddedPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            assignments: null == assignments
                ? _value.assignments
                : assignments // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, dynamic>>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProjectTemplateImplCopyWith<$Res>
    implements $ProjectTemplateCopyWith<$Res> {
  factory _$$ProjectTemplateImplCopyWith(
    _$ProjectTemplateImpl value,
    $Res Function(_$ProjectTemplateImpl) then,
  ) = __$$ProjectTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String fileName,
    String? embeddedPath,
    List<Map<String, dynamic>> assignments,
  });
}

/// @nodoc
class __$$ProjectTemplateImplCopyWithImpl<$Res>
    extends _$ProjectTemplateCopyWithImpl<$Res, _$ProjectTemplateImpl>
    implements _$$ProjectTemplateImplCopyWith<$Res> {
  __$$ProjectTemplateImplCopyWithImpl(
    _$ProjectTemplateImpl _value,
    $Res Function(_$ProjectTemplateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProjectTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileName = null,
    Object? embeddedPath = freezed,
    Object? assignments = null,
  }) {
    return _then(
      _$ProjectTemplateImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        fileName: null == fileName
            ? _value.fileName
            : fileName // ignore: cast_nullable_to_non_nullable
                  as String,
        embeddedPath: freezed == embeddedPath
            ? _value.embeddedPath
            : embeddedPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        assignments: null == assignments
            ? _value._assignments
            : assignments // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, dynamic>>,
      ),
    );
  }
}

/// @nodoc

class _$ProjectTemplateImpl implements _ProjectTemplate {
  const _$ProjectTemplateImpl({
    required this.id,
    required this.fileName,
    this.embeddedPath,
    final List<Map<String, dynamic>> assignments = const [],
  }) : _assignments = assignments;

  @override
  final String id;
  @override
  final String fileName;

  /// Ruta del DOCX en la caché del proyecto (solo en ejecución).
  @override
  final String? embeddedPath;

  /// Mapeo de esta plantilla en el formato de `mappings.json`.
  final List<Map<String, dynamic>> _assignments;

  /// Mapeo de esta plantilla en el formato de `mappings.json`.
  @override
  @JsonKey()
  List<Map<String, dynamic>> get assignments {
    if (_assignments is EqualUnmodifiableListView) return _assignments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assignments);
  }

  @override
  String toString() {
    return 'ProjectTemplate(id: $id, fileName: $fileName, embeddedPath: $embeddedPath, assignments: $assignments)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.embeddedPath, embeddedPath) ||
                other.embeddedPath == embeddedPath) &&
            const DeepCollectionEquality().equals(
              other._assignments,
              _assignments,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    fileName,
    embeddedPath,
    const DeepCollectionEquality().hash(_assignments),
  );

  /// Create a copy of ProjectTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectTemplateImplCopyWith<_$ProjectTemplateImpl> get copyWith =>
      __$$ProjectTemplateImplCopyWithImpl<_$ProjectTemplateImpl>(
        this,
        _$identity,
      );
}

abstract class _ProjectTemplate implements ProjectTemplate {
  const factory _ProjectTemplate({
    required final String id,
    required final String fileName,
    final String? embeddedPath,
    final List<Map<String, dynamic>> assignments,
  }) = _$ProjectTemplateImpl;

  @override
  String get id;
  @override
  String get fileName;

  /// Ruta del DOCX en la caché del proyecto (solo en ejecución).
  @override
  String? get embeddedPath;

  /// Mapeo de esta plantilla en el formato de `mappings.json`.
  @override
  List<Map<String, dynamic>> get assignments;

  /// Create a copy of ProjectTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectTemplateImplCopyWith<_$ProjectTemplateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
