// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mapping_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MappingState {
  List<FieldAssignment> get assignments => throw _privateConstructorUsedError;
  int get currentFieldIndex => throw _privateConstructorUsedError;
  int? get hoveredFieldIndex => throw _privateConstructorUsedError;

  /// Create a copy of MappingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MappingStateCopyWith<MappingState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MappingStateCopyWith<$Res> {
  factory $MappingStateCopyWith(
    MappingState value,
    $Res Function(MappingState) then,
  ) = _$MappingStateCopyWithImpl<$Res, MappingState>;
  @useResult
  $Res call({
    List<FieldAssignment> assignments,
    int currentFieldIndex,
    int? hoveredFieldIndex,
  });
}

/// @nodoc
class _$MappingStateCopyWithImpl<$Res, $Val extends MappingState>
    implements $MappingStateCopyWith<$Res> {
  _$MappingStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MappingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? assignments = null,
    Object? currentFieldIndex = null,
    Object? hoveredFieldIndex = freezed,
  }) {
    return _then(
      _value.copyWith(
            assignments: null == assignments
                ? _value.assignments
                : assignments // ignore: cast_nullable_to_non_nullable
                      as List<FieldAssignment>,
            currentFieldIndex: null == currentFieldIndex
                ? _value.currentFieldIndex
                : currentFieldIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            hoveredFieldIndex: freezed == hoveredFieldIndex
                ? _value.hoveredFieldIndex
                : hoveredFieldIndex // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MappingStateImplCopyWith<$Res>
    implements $MappingStateCopyWith<$Res> {
  factory _$$MappingStateImplCopyWith(
    _$MappingStateImpl value,
    $Res Function(_$MappingStateImpl) then,
  ) = __$$MappingStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<FieldAssignment> assignments,
    int currentFieldIndex,
    int? hoveredFieldIndex,
  });
}

/// @nodoc
class __$$MappingStateImplCopyWithImpl<$Res>
    extends _$MappingStateCopyWithImpl<$Res, _$MappingStateImpl>
    implements _$$MappingStateImplCopyWith<$Res> {
  __$$MappingStateImplCopyWithImpl(
    _$MappingStateImpl _value,
    $Res Function(_$MappingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MappingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? assignments = null,
    Object? currentFieldIndex = null,
    Object? hoveredFieldIndex = freezed,
  }) {
    return _then(
      _$MappingStateImpl(
        assignments: null == assignments
            ? _value._assignments
            : assignments // ignore: cast_nullable_to_non_nullable
                  as List<FieldAssignment>,
        currentFieldIndex: null == currentFieldIndex
            ? _value.currentFieldIndex
            : currentFieldIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        hoveredFieldIndex: freezed == hoveredFieldIndex
            ? _value.hoveredFieldIndex
            : hoveredFieldIndex // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc

class _$MappingStateImpl implements _MappingState {
  const _$MappingStateImpl({
    required final List<FieldAssignment> assignments,
    this.currentFieldIndex = 0,
    this.hoveredFieldIndex,
  }) : _assignments = assignments;

  final List<FieldAssignment> _assignments;
  @override
  List<FieldAssignment> get assignments {
    if (_assignments is EqualUnmodifiableListView) return _assignments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assignments);
  }

  @override
  @JsonKey()
  final int currentFieldIndex;
  @override
  final int? hoveredFieldIndex;

  @override
  String toString() {
    return 'MappingState(assignments: $assignments, currentFieldIndex: $currentFieldIndex, hoveredFieldIndex: $hoveredFieldIndex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MappingStateImpl &&
            const DeepCollectionEquality().equals(
              other._assignments,
              _assignments,
            ) &&
            (identical(other.currentFieldIndex, currentFieldIndex) ||
                other.currentFieldIndex == currentFieldIndex) &&
            (identical(other.hoveredFieldIndex, hoveredFieldIndex) ||
                other.hoveredFieldIndex == hoveredFieldIndex));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_assignments),
    currentFieldIndex,
    hoveredFieldIndex,
  );

  /// Create a copy of MappingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MappingStateImplCopyWith<_$MappingStateImpl> get copyWith =>
      __$$MappingStateImplCopyWithImpl<_$MappingStateImpl>(this, _$identity);
}

abstract class _MappingState implements MappingState {
  const factory _MappingState({
    required final List<FieldAssignment> assignments,
    final int currentFieldIndex,
    final int? hoveredFieldIndex,
  }) = _$MappingStateImpl;

  @override
  List<FieldAssignment> get assignments;
  @override
  int get currentFieldIndex;
  @override
  int? get hoveredFieldIndex;

  /// Create a copy of MappingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MappingStateImplCopyWith<_$MappingStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
