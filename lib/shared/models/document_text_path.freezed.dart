// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document_text_path.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DocumentTextPath {
  List<DocumentPathStep> get steps => throw _privateConstructorUsedError;
  DocumentTextRegion get region => throw _privateConstructorUsedError;

  /// Create a copy of DocumentTextPath
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentTextPathCopyWith<DocumentTextPath> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentTextPathCopyWith<$Res> {
  factory $DocumentTextPathCopyWith(
    DocumentTextPath value,
    $Res Function(DocumentTextPath) then,
  ) = _$DocumentTextPathCopyWithImpl<$Res, DocumentTextPath>;
  @useResult
  $Res call({List<DocumentPathStep> steps, DocumentTextRegion region});
}

/// @nodoc
class _$DocumentTextPathCopyWithImpl<$Res, $Val extends DocumentTextPath>
    implements $DocumentTextPathCopyWith<$Res> {
  _$DocumentTextPathCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentTextPath
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? steps = null, Object? region = null}) {
    return _then(
      _value.copyWith(
            steps: null == steps
                ? _value.steps
                : steps // ignore: cast_nullable_to_non_nullable
                      as List<DocumentPathStep>,
            region: null == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                      as DocumentTextRegion,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentTextPathImplCopyWith<$Res>
    implements $DocumentTextPathCopyWith<$Res> {
  factory _$$DocumentTextPathImplCopyWith(
    _$DocumentTextPathImpl value,
    $Res Function(_$DocumentTextPathImpl) then,
  ) = __$$DocumentTextPathImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<DocumentPathStep> steps, DocumentTextRegion region});
}

/// @nodoc
class __$$DocumentTextPathImplCopyWithImpl<$Res>
    extends _$DocumentTextPathCopyWithImpl<$Res, _$DocumentTextPathImpl>
    implements _$$DocumentTextPathImplCopyWith<$Res> {
  __$$DocumentTextPathImplCopyWithImpl(
    _$DocumentTextPathImpl _value,
    $Res Function(_$DocumentTextPathImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentTextPath
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? steps = null, Object? region = null}) {
    return _then(
      _$DocumentTextPathImpl(
        steps: null == steps
            ? _value._steps
            : steps // ignore: cast_nullable_to_non_nullable
                  as List<DocumentPathStep>,
        region: null == region
            ? _value.region
            : region // ignore: cast_nullable_to_non_nullable
                  as DocumentTextRegion,
      ),
    );
  }
}

/// @nodoc

class _$DocumentTextPathImpl implements _DocumentTextPath {
  const _$DocumentTextPathImpl({
    required final List<DocumentPathStep> steps,
    this.region = DocumentTextRegion.body,
  }) : _steps = steps;

  final List<DocumentPathStep> _steps;
  @override
  List<DocumentPathStep> get steps {
    if (_steps is EqualUnmodifiableListView) return _steps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_steps);
  }

  @override
  @JsonKey()
  final DocumentTextRegion region;

  @override
  String toString() {
    return 'DocumentTextPath(steps: $steps, region: $region)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentTextPathImpl &&
            const DeepCollectionEquality().equals(other._steps, _steps) &&
            (identical(other.region, region) || other.region == region));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_steps),
    region,
  );

  /// Create a copy of DocumentTextPath
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentTextPathImplCopyWith<_$DocumentTextPathImpl> get copyWith =>
      __$$DocumentTextPathImplCopyWithImpl<_$DocumentTextPathImpl>(
        this,
        _$identity,
      );
}

abstract class _DocumentTextPath implements DocumentTextPath {
  const factory _DocumentTextPath({
    required final List<DocumentPathStep> steps,
    final DocumentTextRegion region,
  }) = _$DocumentTextPathImpl;

  @override
  List<DocumentPathStep> get steps;
  @override
  DocumentTextRegion get region;

  /// Create a copy of DocumentTextPath
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentTextPathImplCopyWith<_$DocumentTextPathImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DocumentPathStep {
  int get blockIndex => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int blockIndex) rootBlock,
    required TResult Function(int rowIndex, int cellIndex, int blockIndex)
    cellBlock,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int blockIndex)? rootBlock,
    TResult? Function(int rowIndex, int cellIndex, int blockIndex)? cellBlock,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int blockIndex)? rootBlock,
    TResult Function(int rowIndex, int cellIndex, int blockIndex)? cellBlock,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RootDocumentBlockStep value) rootBlock,
    required TResult Function(DocumentTableCellBlockStep value) cellBlock,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RootDocumentBlockStep value)? rootBlock,
    TResult? Function(DocumentTableCellBlockStep value)? cellBlock,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RootDocumentBlockStep value)? rootBlock,
    TResult Function(DocumentTableCellBlockStep value)? cellBlock,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of DocumentPathStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentPathStepCopyWith<DocumentPathStep> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentPathStepCopyWith<$Res> {
  factory $DocumentPathStepCopyWith(
    DocumentPathStep value,
    $Res Function(DocumentPathStep) then,
  ) = _$DocumentPathStepCopyWithImpl<$Res, DocumentPathStep>;
  @useResult
  $Res call({int blockIndex});
}

/// @nodoc
class _$DocumentPathStepCopyWithImpl<$Res, $Val extends DocumentPathStep>
    implements $DocumentPathStepCopyWith<$Res> {
  _$DocumentPathStepCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentPathStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? blockIndex = null}) {
    return _then(
      _value.copyWith(
            blockIndex: null == blockIndex
                ? _value.blockIndex
                : blockIndex // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RootDocumentBlockStepImplCopyWith<$Res>
    implements $DocumentPathStepCopyWith<$Res> {
  factory _$$RootDocumentBlockStepImplCopyWith(
    _$RootDocumentBlockStepImpl value,
    $Res Function(_$RootDocumentBlockStepImpl) then,
  ) = __$$RootDocumentBlockStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int blockIndex});
}

/// @nodoc
class __$$RootDocumentBlockStepImplCopyWithImpl<$Res>
    extends _$DocumentPathStepCopyWithImpl<$Res, _$RootDocumentBlockStepImpl>
    implements _$$RootDocumentBlockStepImplCopyWith<$Res> {
  __$$RootDocumentBlockStepImplCopyWithImpl(
    _$RootDocumentBlockStepImpl _value,
    $Res Function(_$RootDocumentBlockStepImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentPathStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? blockIndex = null}) {
    return _then(
      _$RootDocumentBlockStepImpl(
        blockIndex: null == blockIndex
            ? _value.blockIndex
            : blockIndex // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$RootDocumentBlockStepImpl implements RootDocumentBlockStep {
  const _$RootDocumentBlockStepImpl({required this.blockIndex});

  @override
  final int blockIndex;

  @override
  String toString() {
    return 'DocumentPathStep.rootBlock(blockIndex: $blockIndex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RootDocumentBlockStepImpl &&
            (identical(other.blockIndex, blockIndex) ||
                other.blockIndex == blockIndex));
  }

  @override
  int get hashCode => Object.hash(runtimeType, blockIndex);

  /// Create a copy of DocumentPathStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RootDocumentBlockStepImplCopyWith<_$RootDocumentBlockStepImpl>
  get copyWith =>
      __$$RootDocumentBlockStepImplCopyWithImpl<_$RootDocumentBlockStepImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int blockIndex) rootBlock,
    required TResult Function(int rowIndex, int cellIndex, int blockIndex)
    cellBlock,
  }) {
    return rootBlock(blockIndex);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int blockIndex)? rootBlock,
    TResult? Function(int rowIndex, int cellIndex, int blockIndex)? cellBlock,
  }) {
    return rootBlock?.call(blockIndex);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int blockIndex)? rootBlock,
    TResult Function(int rowIndex, int cellIndex, int blockIndex)? cellBlock,
    required TResult orElse(),
  }) {
    if (rootBlock != null) {
      return rootBlock(blockIndex);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RootDocumentBlockStep value) rootBlock,
    required TResult Function(DocumentTableCellBlockStep value) cellBlock,
  }) {
    return rootBlock(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RootDocumentBlockStep value)? rootBlock,
    TResult? Function(DocumentTableCellBlockStep value)? cellBlock,
  }) {
    return rootBlock?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RootDocumentBlockStep value)? rootBlock,
    TResult Function(DocumentTableCellBlockStep value)? cellBlock,
    required TResult orElse(),
  }) {
    if (rootBlock != null) {
      return rootBlock(this);
    }
    return orElse();
  }
}

abstract class RootDocumentBlockStep implements DocumentPathStep {
  const factory RootDocumentBlockStep({required final int blockIndex}) =
      _$RootDocumentBlockStepImpl;

  @override
  int get blockIndex;

  /// Create a copy of DocumentPathStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RootDocumentBlockStepImplCopyWith<_$RootDocumentBlockStepImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DocumentTableCellBlockStepImplCopyWith<$Res>
    implements $DocumentPathStepCopyWith<$Res> {
  factory _$$DocumentTableCellBlockStepImplCopyWith(
    _$DocumentTableCellBlockStepImpl value,
    $Res Function(_$DocumentTableCellBlockStepImpl) then,
  ) = __$$DocumentTableCellBlockStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int rowIndex, int cellIndex, int blockIndex});
}

/// @nodoc
class __$$DocumentTableCellBlockStepImplCopyWithImpl<$Res>
    extends
        _$DocumentPathStepCopyWithImpl<$Res, _$DocumentTableCellBlockStepImpl>
    implements _$$DocumentTableCellBlockStepImplCopyWith<$Res> {
  __$$DocumentTableCellBlockStepImplCopyWithImpl(
    _$DocumentTableCellBlockStepImpl _value,
    $Res Function(_$DocumentTableCellBlockStepImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentPathStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rowIndex = null,
    Object? cellIndex = null,
    Object? blockIndex = null,
  }) {
    return _then(
      _$DocumentTableCellBlockStepImpl(
        rowIndex: null == rowIndex
            ? _value.rowIndex
            : rowIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        cellIndex: null == cellIndex
            ? _value.cellIndex
            : cellIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        blockIndex: null == blockIndex
            ? _value.blockIndex
            : blockIndex // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$DocumentTableCellBlockStepImpl implements DocumentTableCellBlockStep {
  const _$DocumentTableCellBlockStepImpl({
    required this.rowIndex,
    required this.cellIndex,
    required this.blockIndex,
  });

  @override
  final int rowIndex;
  @override
  final int cellIndex;
  @override
  final int blockIndex;

  @override
  String toString() {
    return 'DocumentPathStep.cellBlock(rowIndex: $rowIndex, cellIndex: $cellIndex, blockIndex: $blockIndex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentTableCellBlockStepImpl &&
            (identical(other.rowIndex, rowIndex) ||
                other.rowIndex == rowIndex) &&
            (identical(other.cellIndex, cellIndex) ||
                other.cellIndex == cellIndex) &&
            (identical(other.blockIndex, blockIndex) ||
                other.blockIndex == blockIndex));
  }

  @override
  int get hashCode => Object.hash(runtimeType, rowIndex, cellIndex, blockIndex);

  /// Create a copy of DocumentPathStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentTableCellBlockStepImplCopyWith<_$DocumentTableCellBlockStepImpl>
  get copyWith =>
      __$$DocumentTableCellBlockStepImplCopyWithImpl<
        _$DocumentTableCellBlockStepImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int blockIndex) rootBlock,
    required TResult Function(int rowIndex, int cellIndex, int blockIndex)
    cellBlock,
  }) {
    return cellBlock(rowIndex, cellIndex, blockIndex);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int blockIndex)? rootBlock,
    TResult? Function(int rowIndex, int cellIndex, int blockIndex)? cellBlock,
  }) {
    return cellBlock?.call(rowIndex, cellIndex, blockIndex);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int blockIndex)? rootBlock,
    TResult Function(int rowIndex, int cellIndex, int blockIndex)? cellBlock,
    required TResult orElse(),
  }) {
    if (cellBlock != null) {
      return cellBlock(rowIndex, cellIndex, blockIndex);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RootDocumentBlockStep value) rootBlock,
    required TResult Function(DocumentTableCellBlockStep value) cellBlock,
  }) {
    return cellBlock(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RootDocumentBlockStep value)? rootBlock,
    TResult? Function(DocumentTableCellBlockStep value)? cellBlock,
  }) {
    return cellBlock?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RootDocumentBlockStep value)? rootBlock,
    TResult Function(DocumentTableCellBlockStep value)? cellBlock,
    required TResult orElse(),
  }) {
    if (cellBlock != null) {
      return cellBlock(this);
    }
    return orElse();
  }
}

abstract class DocumentTableCellBlockStep implements DocumentPathStep {
  const factory DocumentTableCellBlockStep({
    required final int rowIndex,
    required final int cellIndex,
    required final int blockIndex,
  }) = _$DocumentTableCellBlockStepImpl;

  int get rowIndex;
  int get cellIndex;
  @override
  int get blockIndex;

  /// Create a copy of DocumentPathStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentTableCellBlockStepImplCopyWith<_$DocumentTableCellBlockStepImpl>
  get copyWith => throw _privateConstructorUsedError;
}
