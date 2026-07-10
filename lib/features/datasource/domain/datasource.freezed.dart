// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'datasource.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Datasource {
  String get sourcePath => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;
  int get fileSizeBytes => throw _privateConstructorUsedError;
  DateTime get importedAt => throw _privateConstructorUsedError;
  DatasourceFormat get format => throw _privateConstructorUsedError;
  List<String> get headers => throw _privateConstructorUsedError;
  List<String?> get previewRow => throw _privateConstructorUsedError;
  int get rowCount => throw _privateConstructorUsedError;
  List<int> get emptyColumnIndexes => throw _privateConstructorUsedError;

  /// Create a copy of Datasource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DatasourceCopyWith<Datasource> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DatasourceCopyWith<$Res> {
  factory $DatasourceCopyWith(
    Datasource value,
    $Res Function(Datasource) then,
  ) = _$DatasourceCopyWithImpl<$Res, Datasource>;
  @useResult
  $Res call({
    String sourcePath,
    String fileName,
    int fileSizeBytes,
    DateTime importedAt,
    DatasourceFormat format,
    List<String> headers,
    List<String?> previewRow,
    int rowCount,
    List<int> emptyColumnIndexes,
  });
}

/// @nodoc
class _$DatasourceCopyWithImpl<$Res, $Val extends Datasource>
    implements $DatasourceCopyWith<$Res> {
  _$DatasourceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Datasource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sourcePath = null,
    Object? fileName = null,
    Object? fileSizeBytes = null,
    Object? importedAt = null,
    Object? format = null,
    Object? headers = null,
    Object? previewRow = null,
    Object? rowCount = null,
    Object? emptyColumnIndexes = null,
  }) {
    return _then(
      _value.copyWith(
            sourcePath: null == sourcePath
                ? _value.sourcePath
                : sourcePath // ignore: cast_nullable_to_non_nullable
                      as String,
            fileName: null == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                      as String,
            fileSizeBytes: null == fileSizeBytes
                ? _value.fileSizeBytes
                : fileSizeBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            importedAt: null == importedAt
                ? _value.importedAt
                : importedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            format: null == format
                ? _value.format
                : format // ignore: cast_nullable_to_non_nullable
                      as DatasourceFormat,
            headers: null == headers
                ? _value.headers
                : headers // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            previewRow: null == previewRow
                ? _value.previewRow
                : previewRow // ignore: cast_nullable_to_non_nullable
                      as List<String?>,
            rowCount: null == rowCount
                ? _value.rowCount
                : rowCount // ignore: cast_nullable_to_non_nullable
                      as int,
            emptyColumnIndexes: null == emptyColumnIndexes
                ? _value.emptyColumnIndexes
                : emptyColumnIndexes // ignore: cast_nullable_to_non_nullable
                      as List<int>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DatasourceImplCopyWith<$Res>
    implements $DatasourceCopyWith<$Res> {
  factory _$$DatasourceImplCopyWith(
    _$DatasourceImpl value,
    $Res Function(_$DatasourceImpl) then,
  ) = __$$DatasourceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sourcePath,
    String fileName,
    int fileSizeBytes,
    DateTime importedAt,
    DatasourceFormat format,
    List<String> headers,
    List<String?> previewRow,
    int rowCount,
    List<int> emptyColumnIndexes,
  });
}

/// @nodoc
class __$$DatasourceImplCopyWithImpl<$Res>
    extends _$DatasourceCopyWithImpl<$Res, _$DatasourceImpl>
    implements _$$DatasourceImplCopyWith<$Res> {
  __$$DatasourceImplCopyWithImpl(
    _$DatasourceImpl _value,
    $Res Function(_$DatasourceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Datasource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sourcePath = null,
    Object? fileName = null,
    Object? fileSizeBytes = null,
    Object? importedAt = null,
    Object? format = null,
    Object? headers = null,
    Object? previewRow = null,
    Object? rowCount = null,
    Object? emptyColumnIndexes = null,
  }) {
    return _then(
      _$DatasourceImpl(
        sourcePath: null == sourcePath
            ? _value.sourcePath
            : sourcePath // ignore: cast_nullable_to_non_nullable
                  as String,
        fileName: null == fileName
            ? _value.fileName
            : fileName // ignore: cast_nullable_to_non_nullable
                  as String,
        fileSizeBytes: null == fileSizeBytes
            ? _value.fileSizeBytes
            : fileSizeBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        importedAt: null == importedAt
            ? _value.importedAt
            : importedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        format: null == format
            ? _value.format
            : format // ignore: cast_nullable_to_non_nullable
                  as DatasourceFormat,
        headers: null == headers
            ? _value._headers
            : headers // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        previewRow: null == previewRow
            ? _value._previewRow
            : previewRow // ignore: cast_nullable_to_non_nullable
                  as List<String?>,
        rowCount: null == rowCount
            ? _value.rowCount
            : rowCount // ignore: cast_nullable_to_non_nullable
                  as int,
        emptyColumnIndexes: null == emptyColumnIndexes
            ? _value._emptyColumnIndexes
            : emptyColumnIndexes // ignore: cast_nullable_to_non_nullable
                  as List<int>,
      ),
    );
  }
}

/// @nodoc

class _$DatasourceImpl implements _Datasource {
  const _$DatasourceImpl({
    required this.sourcePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.importedAt,
    required this.format,
    required final List<String> headers,
    required final List<String?> previewRow,
    required this.rowCount,
    required final List<int> emptyColumnIndexes,
  }) : _headers = headers,
       _previewRow = previewRow,
       _emptyColumnIndexes = emptyColumnIndexes;

  @override
  final String sourcePath;
  @override
  final String fileName;
  @override
  final int fileSizeBytes;
  @override
  final DateTime importedAt;
  @override
  final DatasourceFormat format;
  final List<String> _headers;
  @override
  List<String> get headers {
    if (_headers is EqualUnmodifiableListView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_headers);
  }

  final List<String?> _previewRow;
  @override
  List<String?> get previewRow {
    if (_previewRow is EqualUnmodifiableListView) return _previewRow;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_previewRow);
  }

  @override
  final int rowCount;
  final List<int> _emptyColumnIndexes;
  @override
  List<int> get emptyColumnIndexes {
    if (_emptyColumnIndexes is EqualUnmodifiableListView)
      return _emptyColumnIndexes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_emptyColumnIndexes);
  }

  @override
  String toString() {
    return 'Datasource(sourcePath: $sourcePath, fileName: $fileName, fileSizeBytes: $fileSizeBytes, importedAt: $importedAt, format: $format, headers: $headers, previewRow: $previewRow, rowCount: $rowCount, emptyColumnIndexes: $emptyColumnIndexes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DatasourceImpl &&
            (identical(other.sourcePath, sourcePath) ||
                other.sourcePath == sourcePath) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.fileSizeBytes, fileSizeBytes) ||
                other.fileSizeBytes == fileSizeBytes) &&
            (identical(other.importedAt, importedAt) ||
                other.importedAt == importedAt) &&
            (identical(other.format, format) || other.format == format) &&
            const DeepCollectionEquality().equals(other._headers, _headers) &&
            const DeepCollectionEquality().equals(
              other._previewRow,
              _previewRow,
            ) &&
            (identical(other.rowCount, rowCount) ||
                other.rowCount == rowCount) &&
            const DeepCollectionEquality().equals(
              other._emptyColumnIndexes,
              _emptyColumnIndexes,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    sourcePath,
    fileName,
    fileSizeBytes,
    importedAt,
    format,
    const DeepCollectionEquality().hash(_headers),
    const DeepCollectionEquality().hash(_previewRow),
    rowCount,
    const DeepCollectionEquality().hash(_emptyColumnIndexes),
  );

  /// Create a copy of Datasource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DatasourceImplCopyWith<_$DatasourceImpl> get copyWith =>
      __$$DatasourceImplCopyWithImpl<_$DatasourceImpl>(this, _$identity);
}

abstract class _Datasource implements Datasource {
  const factory _Datasource({
    required final String sourcePath,
    required final String fileName,
    required final int fileSizeBytes,
    required final DateTime importedAt,
    required final DatasourceFormat format,
    required final List<String> headers,
    required final List<String?> previewRow,
    required final int rowCount,
    required final List<int> emptyColumnIndexes,
  }) = _$DatasourceImpl;

  @override
  String get sourcePath;
  @override
  String get fileName;
  @override
  int get fileSizeBytes;
  @override
  DateTime get importedAt;
  @override
  DatasourceFormat get format;
  @override
  List<String> get headers;
  @override
  List<String?> get previewRow;
  @override
  int get rowCount;
  @override
  List<int> get emptyColumnIndexes;

  /// Create a copy of Datasource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DatasourceImplCopyWith<_$DatasourceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
