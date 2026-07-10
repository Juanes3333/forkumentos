// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'text_occurrence.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TextOccurrence {
  DocumentTextPath get path => throw _privateConstructorUsedError;
  int get startOffset => throw _privateConstructorUsedError;
  int get endOffset => throw _privateConstructorUsedError;
  String get matchedText => throw _privateConstructorUsedError;

  /// Create a copy of TextOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TextOccurrenceCopyWith<TextOccurrence> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TextOccurrenceCopyWith<$Res> {
  factory $TextOccurrenceCopyWith(
    TextOccurrence value,
    $Res Function(TextOccurrence) then,
  ) = _$TextOccurrenceCopyWithImpl<$Res, TextOccurrence>;
  @useResult
  $Res call({
    DocumentTextPath path,
    int startOffset,
    int endOffset,
    String matchedText,
  });

  $DocumentTextPathCopyWith<$Res> get path;
}

/// @nodoc
class _$TextOccurrenceCopyWithImpl<$Res, $Val extends TextOccurrence>
    implements $TextOccurrenceCopyWith<$Res> {
  _$TextOccurrenceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TextOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? startOffset = null,
    Object? endOffset = null,
    Object? matchedText = null,
  }) {
    return _then(
      _value.copyWith(
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as DocumentTextPath,
            startOffset: null == startOffset
                ? _value.startOffset
                : startOffset // ignore: cast_nullable_to_non_nullable
                      as int,
            endOffset: null == endOffset
                ? _value.endOffset
                : endOffset // ignore: cast_nullable_to_non_nullable
                      as int,
            matchedText: null == matchedText
                ? _value.matchedText
                : matchedText // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }

  /// Create a copy of TextOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DocumentTextPathCopyWith<$Res> get path {
    return $DocumentTextPathCopyWith<$Res>(_value.path, (value) {
      return _then(_value.copyWith(path: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TextOccurrenceImplCopyWith<$Res>
    implements $TextOccurrenceCopyWith<$Res> {
  factory _$$TextOccurrenceImplCopyWith(
    _$TextOccurrenceImpl value,
    $Res Function(_$TextOccurrenceImpl) then,
  ) = __$$TextOccurrenceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DocumentTextPath path,
    int startOffset,
    int endOffset,
    String matchedText,
  });

  @override
  $DocumentTextPathCopyWith<$Res> get path;
}

/// @nodoc
class __$$TextOccurrenceImplCopyWithImpl<$Res>
    extends _$TextOccurrenceCopyWithImpl<$Res, _$TextOccurrenceImpl>
    implements _$$TextOccurrenceImplCopyWith<$Res> {
  __$$TextOccurrenceImplCopyWithImpl(
    _$TextOccurrenceImpl _value,
    $Res Function(_$TextOccurrenceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TextOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? startOffset = null,
    Object? endOffset = null,
    Object? matchedText = null,
  }) {
    return _then(
      _$TextOccurrenceImpl(
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as DocumentTextPath,
        startOffset: null == startOffset
            ? _value.startOffset
            : startOffset // ignore: cast_nullable_to_non_nullable
                  as int,
        endOffset: null == endOffset
            ? _value.endOffset
            : endOffset // ignore: cast_nullable_to_non_nullable
                  as int,
        matchedText: null == matchedText
            ? _value.matchedText
            : matchedText // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$TextOccurrenceImpl implements _TextOccurrence {
  const _$TextOccurrenceImpl({
    required this.path,
    required this.startOffset,
    required this.endOffset,
    required this.matchedText,
  });

  @override
  final DocumentTextPath path;
  @override
  final int startOffset;
  @override
  final int endOffset;
  @override
  final String matchedText;

  @override
  String toString() {
    return 'TextOccurrence(path: $path, startOffset: $startOffset, endOffset: $endOffset, matchedText: $matchedText)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TextOccurrenceImpl &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.startOffset, startOffset) ||
                other.startOffset == startOffset) &&
            (identical(other.endOffset, endOffset) ||
                other.endOffset == endOffset) &&
            (identical(other.matchedText, matchedText) ||
                other.matchedText == matchedText));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, path, startOffset, endOffset, matchedText);

  /// Create a copy of TextOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TextOccurrenceImplCopyWith<_$TextOccurrenceImpl> get copyWith =>
      __$$TextOccurrenceImplCopyWithImpl<_$TextOccurrenceImpl>(
        this,
        _$identity,
      );
}

abstract class _TextOccurrence implements TextOccurrence {
  const factory _TextOccurrence({
    required final DocumentTextPath path,
    required final int startOffset,
    required final int endOffset,
    required final String matchedText,
  }) = _$TextOccurrenceImpl;

  @override
  DocumentTextPath get path;
  @override
  int get startOffset;
  @override
  int get endOffset;
  @override
  String get matchedText;

  /// Create a copy of TextOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TextOccurrenceImplCopyWith<_$TextOccurrenceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
