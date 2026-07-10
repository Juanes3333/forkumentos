// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Document {
  List<DocumentPage> get pages => throw _privateConstructorUsedError;
  Set<DocumentOmission> get omissions => throw _privateConstructorUsedError;

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentCopyWith<Document> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentCopyWith<$Res> {
  factory $DocumentCopyWith(Document value, $Res Function(Document) then) =
      _$DocumentCopyWithImpl<$Res, Document>;
  @useResult
  $Res call({List<DocumentPage> pages, Set<DocumentOmission> omissions});
}

/// @nodoc
class _$DocumentCopyWithImpl<$Res, $Val extends Document>
    implements $DocumentCopyWith<$Res> {
  _$DocumentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? pages = null, Object? omissions = null}) {
    return _then(
      _value.copyWith(
            pages: null == pages
                ? _value.pages
                : pages // ignore: cast_nullable_to_non_nullable
                      as List<DocumentPage>,
            omissions: null == omissions
                ? _value.omissions
                : omissions // ignore: cast_nullable_to_non_nullable
                      as Set<DocumentOmission>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentImplCopyWith<$Res>
    implements $DocumentCopyWith<$Res> {
  factory _$$DocumentImplCopyWith(
    _$DocumentImpl value,
    $Res Function(_$DocumentImpl) then,
  ) = __$$DocumentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<DocumentPage> pages, Set<DocumentOmission> omissions});
}

/// @nodoc
class __$$DocumentImplCopyWithImpl<$Res>
    extends _$DocumentCopyWithImpl<$Res, _$DocumentImpl>
    implements _$$DocumentImplCopyWith<$Res> {
  __$$DocumentImplCopyWithImpl(
    _$DocumentImpl _value,
    $Res Function(_$DocumentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? pages = null, Object? omissions = null}) {
    return _then(
      _$DocumentImpl(
        pages: null == pages
            ? _value._pages
            : pages // ignore: cast_nullable_to_non_nullable
                  as List<DocumentPage>,
        omissions: null == omissions
            ? _value._omissions
            : omissions // ignore: cast_nullable_to_non_nullable
                  as Set<DocumentOmission>,
      ),
    );
  }
}

/// @nodoc

class _$DocumentImpl implements _Document {
  const _$DocumentImpl({
    required final List<DocumentPage> pages,
    required final Set<DocumentOmission> omissions,
  }) : _pages = pages,
       _omissions = omissions;

  final List<DocumentPage> _pages;
  @override
  List<DocumentPage> get pages {
    if (_pages is EqualUnmodifiableListView) return _pages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pages);
  }

  final Set<DocumentOmission> _omissions;
  @override
  Set<DocumentOmission> get omissions {
    if (_omissions is EqualUnmodifiableSetView) return _omissions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_omissions);
  }

  @override
  String toString() {
    return 'Document(pages: $pages, omissions: $omissions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentImpl &&
            const DeepCollectionEquality().equals(other._pages, _pages) &&
            const DeepCollectionEquality().equals(
              other._omissions,
              _omissions,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_pages),
    const DeepCollectionEquality().hash(_omissions),
  );

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentImplCopyWith<_$DocumentImpl> get copyWith =>
      __$$DocumentImplCopyWithImpl<_$DocumentImpl>(this, _$identity);
}

abstract class _Document implements Document {
  const factory _Document({
    required final List<DocumentPage> pages,
    required final Set<DocumentOmission> omissions,
  }) = _$DocumentImpl;

  @override
  List<DocumentPage> get pages;
  @override
  Set<DocumentOmission> get omissions;

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentImplCopyWith<_$DocumentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DocumentPage {
  int get number => throw _privateConstructorUsedError;
  double get widthPoints => throw _privateConstructorUsedError;
  double get heightPoints => throw _privateConstructorUsedError;
  DocumentMargins get margins => throw _privateConstructorUsedError;
  List<DocumentParagraph> get paragraphs => throw _privateConstructorUsedError;

  /// Create a copy of DocumentPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentPageCopyWith<DocumentPage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentPageCopyWith<$Res> {
  factory $DocumentPageCopyWith(
    DocumentPage value,
    $Res Function(DocumentPage) then,
  ) = _$DocumentPageCopyWithImpl<$Res, DocumentPage>;
  @useResult
  $Res call({
    int number,
    double widthPoints,
    double heightPoints,
    DocumentMargins margins,
    List<DocumentParagraph> paragraphs,
  });

  $DocumentMarginsCopyWith<$Res> get margins;
}

/// @nodoc
class _$DocumentPageCopyWithImpl<$Res, $Val extends DocumentPage>
    implements $DocumentPageCopyWith<$Res> {
  _$DocumentPageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? number = null,
    Object? widthPoints = null,
    Object? heightPoints = null,
    Object? margins = null,
    Object? paragraphs = null,
  }) {
    return _then(
      _value.copyWith(
            number: null == number
                ? _value.number
                : number // ignore: cast_nullable_to_non_nullable
                      as int,
            widthPoints: null == widthPoints
                ? _value.widthPoints
                : widthPoints // ignore: cast_nullable_to_non_nullable
                      as double,
            heightPoints: null == heightPoints
                ? _value.heightPoints
                : heightPoints // ignore: cast_nullable_to_non_nullable
                      as double,
            margins: null == margins
                ? _value.margins
                : margins // ignore: cast_nullable_to_non_nullable
                      as DocumentMargins,
            paragraphs: null == paragraphs
                ? _value.paragraphs
                : paragraphs // ignore: cast_nullable_to_non_nullable
                      as List<DocumentParagraph>,
          )
          as $Val,
    );
  }

  /// Create a copy of DocumentPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DocumentMarginsCopyWith<$Res> get margins {
    return $DocumentMarginsCopyWith<$Res>(_value.margins, (value) {
      return _then(_value.copyWith(margins: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DocumentPageImplCopyWith<$Res>
    implements $DocumentPageCopyWith<$Res> {
  factory _$$DocumentPageImplCopyWith(
    _$DocumentPageImpl value,
    $Res Function(_$DocumentPageImpl) then,
  ) = __$$DocumentPageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int number,
    double widthPoints,
    double heightPoints,
    DocumentMargins margins,
    List<DocumentParagraph> paragraphs,
  });

  @override
  $DocumentMarginsCopyWith<$Res> get margins;
}

/// @nodoc
class __$$DocumentPageImplCopyWithImpl<$Res>
    extends _$DocumentPageCopyWithImpl<$Res, _$DocumentPageImpl>
    implements _$$DocumentPageImplCopyWith<$Res> {
  __$$DocumentPageImplCopyWithImpl(
    _$DocumentPageImpl _value,
    $Res Function(_$DocumentPageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? number = null,
    Object? widthPoints = null,
    Object? heightPoints = null,
    Object? margins = null,
    Object? paragraphs = null,
  }) {
    return _then(
      _$DocumentPageImpl(
        number: null == number
            ? _value.number
            : number // ignore: cast_nullable_to_non_nullable
                  as int,
        widthPoints: null == widthPoints
            ? _value.widthPoints
            : widthPoints // ignore: cast_nullable_to_non_nullable
                  as double,
        heightPoints: null == heightPoints
            ? _value.heightPoints
            : heightPoints // ignore: cast_nullable_to_non_nullable
                  as double,
        margins: null == margins
            ? _value.margins
            : margins // ignore: cast_nullable_to_non_nullable
                  as DocumentMargins,
        paragraphs: null == paragraphs
            ? _value._paragraphs
            : paragraphs // ignore: cast_nullable_to_non_nullable
                  as List<DocumentParagraph>,
      ),
    );
  }
}

/// @nodoc

class _$DocumentPageImpl implements _DocumentPage {
  const _$DocumentPageImpl({
    required this.number,
    required this.widthPoints,
    required this.heightPoints,
    required this.margins,
    required final List<DocumentParagraph> paragraphs,
  }) : _paragraphs = paragraphs;

  @override
  final int number;
  @override
  final double widthPoints;
  @override
  final double heightPoints;
  @override
  final DocumentMargins margins;
  final List<DocumentParagraph> _paragraphs;
  @override
  List<DocumentParagraph> get paragraphs {
    if (_paragraphs is EqualUnmodifiableListView) return _paragraphs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_paragraphs);
  }

  @override
  String toString() {
    return 'DocumentPage(number: $number, widthPoints: $widthPoints, heightPoints: $heightPoints, margins: $margins, paragraphs: $paragraphs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentPageImpl &&
            (identical(other.number, number) || other.number == number) &&
            (identical(other.widthPoints, widthPoints) ||
                other.widthPoints == widthPoints) &&
            (identical(other.heightPoints, heightPoints) ||
                other.heightPoints == heightPoints) &&
            (identical(other.margins, margins) || other.margins == margins) &&
            const DeepCollectionEquality().equals(
              other._paragraphs,
              _paragraphs,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    number,
    widthPoints,
    heightPoints,
    margins,
    const DeepCollectionEquality().hash(_paragraphs),
  );

  /// Create a copy of DocumentPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentPageImplCopyWith<_$DocumentPageImpl> get copyWith =>
      __$$DocumentPageImplCopyWithImpl<_$DocumentPageImpl>(this, _$identity);
}

abstract class _DocumentPage implements DocumentPage {
  const factory _DocumentPage({
    required final int number,
    required final double widthPoints,
    required final double heightPoints,
    required final DocumentMargins margins,
    required final List<DocumentParagraph> paragraphs,
  }) = _$DocumentPageImpl;

  @override
  int get number;
  @override
  double get widthPoints;
  @override
  double get heightPoints;
  @override
  DocumentMargins get margins;
  @override
  List<DocumentParagraph> get paragraphs;

  /// Create a copy of DocumentPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentPageImplCopyWith<_$DocumentPageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DocumentMargins {
  double get topPoints => throw _privateConstructorUsedError;
  double get rightPoints => throw _privateConstructorUsedError;
  double get bottomPoints => throw _privateConstructorUsedError;
  double get leftPoints => throw _privateConstructorUsedError;

  /// Create a copy of DocumentMargins
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentMarginsCopyWith<DocumentMargins> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentMarginsCopyWith<$Res> {
  factory $DocumentMarginsCopyWith(
    DocumentMargins value,
    $Res Function(DocumentMargins) then,
  ) = _$DocumentMarginsCopyWithImpl<$Res, DocumentMargins>;
  @useResult
  $Res call({
    double topPoints,
    double rightPoints,
    double bottomPoints,
    double leftPoints,
  });
}

/// @nodoc
class _$DocumentMarginsCopyWithImpl<$Res, $Val extends DocumentMargins>
    implements $DocumentMarginsCopyWith<$Res> {
  _$DocumentMarginsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentMargins
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topPoints = null,
    Object? rightPoints = null,
    Object? bottomPoints = null,
    Object? leftPoints = null,
  }) {
    return _then(
      _value.copyWith(
            topPoints: null == topPoints
                ? _value.topPoints
                : topPoints // ignore: cast_nullable_to_non_nullable
                      as double,
            rightPoints: null == rightPoints
                ? _value.rightPoints
                : rightPoints // ignore: cast_nullable_to_non_nullable
                      as double,
            bottomPoints: null == bottomPoints
                ? _value.bottomPoints
                : bottomPoints // ignore: cast_nullable_to_non_nullable
                      as double,
            leftPoints: null == leftPoints
                ? _value.leftPoints
                : leftPoints // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentMarginsImplCopyWith<$Res>
    implements $DocumentMarginsCopyWith<$Res> {
  factory _$$DocumentMarginsImplCopyWith(
    _$DocumentMarginsImpl value,
    $Res Function(_$DocumentMarginsImpl) then,
  ) = __$$DocumentMarginsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double topPoints,
    double rightPoints,
    double bottomPoints,
    double leftPoints,
  });
}

/// @nodoc
class __$$DocumentMarginsImplCopyWithImpl<$Res>
    extends _$DocumentMarginsCopyWithImpl<$Res, _$DocumentMarginsImpl>
    implements _$$DocumentMarginsImplCopyWith<$Res> {
  __$$DocumentMarginsImplCopyWithImpl(
    _$DocumentMarginsImpl _value,
    $Res Function(_$DocumentMarginsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentMargins
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topPoints = null,
    Object? rightPoints = null,
    Object? bottomPoints = null,
    Object? leftPoints = null,
  }) {
    return _then(
      _$DocumentMarginsImpl(
        topPoints: null == topPoints
            ? _value.topPoints
            : topPoints // ignore: cast_nullable_to_non_nullable
                  as double,
        rightPoints: null == rightPoints
            ? _value.rightPoints
            : rightPoints // ignore: cast_nullable_to_non_nullable
                  as double,
        bottomPoints: null == bottomPoints
            ? _value.bottomPoints
            : bottomPoints // ignore: cast_nullable_to_non_nullable
                  as double,
        leftPoints: null == leftPoints
            ? _value.leftPoints
            : leftPoints // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$DocumentMarginsImpl implements _DocumentMargins {
  const _$DocumentMarginsImpl({
    required this.topPoints,
    required this.rightPoints,
    required this.bottomPoints,
    required this.leftPoints,
  });

  @override
  final double topPoints;
  @override
  final double rightPoints;
  @override
  final double bottomPoints;
  @override
  final double leftPoints;

  @override
  String toString() {
    return 'DocumentMargins(topPoints: $topPoints, rightPoints: $rightPoints, bottomPoints: $bottomPoints, leftPoints: $leftPoints)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentMarginsImpl &&
            (identical(other.topPoints, topPoints) ||
                other.topPoints == topPoints) &&
            (identical(other.rightPoints, rightPoints) ||
                other.rightPoints == rightPoints) &&
            (identical(other.bottomPoints, bottomPoints) ||
                other.bottomPoints == bottomPoints) &&
            (identical(other.leftPoints, leftPoints) ||
                other.leftPoints == leftPoints));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    topPoints,
    rightPoints,
    bottomPoints,
    leftPoints,
  );

  /// Create a copy of DocumentMargins
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentMarginsImplCopyWith<_$DocumentMarginsImpl> get copyWith =>
      __$$DocumentMarginsImplCopyWithImpl<_$DocumentMarginsImpl>(
        this,
        _$identity,
      );
}

abstract class _DocumentMargins implements DocumentMargins {
  const factory _DocumentMargins({
    required final double topPoints,
    required final double rightPoints,
    required final double bottomPoints,
    required final double leftPoints,
  }) = _$DocumentMarginsImpl;

  @override
  double get topPoints;
  @override
  double get rightPoints;
  @override
  double get bottomPoints;
  @override
  double get leftPoints;

  /// Create a copy of DocumentMargins
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentMarginsImplCopyWith<_$DocumentMarginsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DocumentParagraph {
  List<DocumentRun> get runs => throw _privateConstructorUsedError;

  /// Create a copy of DocumentParagraph
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentParagraphCopyWith<DocumentParagraph> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentParagraphCopyWith<$Res> {
  factory $DocumentParagraphCopyWith(
    DocumentParagraph value,
    $Res Function(DocumentParagraph) then,
  ) = _$DocumentParagraphCopyWithImpl<$Res, DocumentParagraph>;
  @useResult
  $Res call({List<DocumentRun> runs});
}

/// @nodoc
class _$DocumentParagraphCopyWithImpl<$Res, $Val extends DocumentParagraph>
    implements $DocumentParagraphCopyWith<$Res> {
  _$DocumentParagraphCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentParagraph
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? runs = null}) {
    return _then(
      _value.copyWith(
            runs: null == runs
                ? _value.runs
                : runs // ignore: cast_nullable_to_non_nullable
                      as List<DocumentRun>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentParagraphImplCopyWith<$Res>
    implements $DocumentParagraphCopyWith<$Res> {
  factory _$$DocumentParagraphImplCopyWith(
    _$DocumentParagraphImpl value,
    $Res Function(_$DocumentParagraphImpl) then,
  ) = __$$DocumentParagraphImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<DocumentRun> runs});
}

/// @nodoc
class __$$DocumentParagraphImplCopyWithImpl<$Res>
    extends _$DocumentParagraphCopyWithImpl<$Res, _$DocumentParagraphImpl>
    implements _$$DocumentParagraphImplCopyWith<$Res> {
  __$$DocumentParagraphImplCopyWithImpl(
    _$DocumentParagraphImpl _value,
    $Res Function(_$DocumentParagraphImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentParagraph
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? runs = null}) {
    return _then(
      _$DocumentParagraphImpl(
        runs: null == runs
            ? _value._runs
            : runs // ignore: cast_nullable_to_non_nullable
                  as List<DocumentRun>,
      ),
    );
  }
}

/// @nodoc

class _$DocumentParagraphImpl implements _DocumentParagraph {
  const _$DocumentParagraphImpl({required final List<DocumentRun> runs})
    : _runs = runs;

  final List<DocumentRun> _runs;
  @override
  List<DocumentRun> get runs {
    if (_runs is EqualUnmodifiableListView) return _runs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_runs);
  }

  @override
  String toString() {
    return 'DocumentParagraph(runs: $runs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentParagraphImpl &&
            const DeepCollectionEquality().equals(other._runs, _runs));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_runs));

  /// Create a copy of DocumentParagraph
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentParagraphImplCopyWith<_$DocumentParagraphImpl> get copyWith =>
      __$$DocumentParagraphImplCopyWithImpl<_$DocumentParagraphImpl>(
        this,
        _$identity,
      );
}

abstract class _DocumentParagraph implements DocumentParagraph {
  const factory _DocumentParagraph({required final List<DocumentRun> runs}) =
      _$DocumentParagraphImpl;

  @override
  List<DocumentRun> get runs;

  /// Create a copy of DocumentParagraph
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentParagraphImplCopyWith<_$DocumentParagraphImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DocumentRun {
  String get text => throw _privateConstructorUsedError;
  bool get isBold => throw _privateConstructorUsedError;
  bool get isItalic => throw _privateConstructorUsedError;
  bool get isUnderlined => throw _privateConstructorUsedError;

  /// Create a copy of DocumentRun
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentRunCopyWith<DocumentRun> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentRunCopyWith<$Res> {
  factory $DocumentRunCopyWith(
    DocumentRun value,
    $Res Function(DocumentRun) then,
  ) = _$DocumentRunCopyWithImpl<$Res, DocumentRun>;
  @useResult
  $Res call({String text, bool isBold, bool isItalic, bool isUnderlined});
}

/// @nodoc
class _$DocumentRunCopyWithImpl<$Res, $Val extends DocumentRun>
    implements $DocumentRunCopyWith<$Res> {
  _$DocumentRunCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentRun
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? isBold = null,
    Object? isItalic = null,
    Object? isUnderlined = null,
  }) {
    return _then(
      _value.copyWith(
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            isBold: null == isBold
                ? _value.isBold
                : isBold // ignore: cast_nullable_to_non_nullable
                      as bool,
            isItalic: null == isItalic
                ? _value.isItalic
                : isItalic // ignore: cast_nullable_to_non_nullable
                      as bool,
            isUnderlined: null == isUnderlined
                ? _value.isUnderlined
                : isUnderlined // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentRunImplCopyWith<$Res>
    implements $DocumentRunCopyWith<$Res> {
  factory _$$DocumentRunImplCopyWith(
    _$DocumentRunImpl value,
    $Res Function(_$DocumentRunImpl) then,
  ) = __$$DocumentRunImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String text, bool isBold, bool isItalic, bool isUnderlined});
}

/// @nodoc
class __$$DocumentRunImplCopyWithImpl<$Res>
    extends _$DocumentRunCopyWithImpl<$Res, _$DocumentRunImpl>
    implements _$$DocumentRunImplCopyWith<$Res> {
  __$$DocumentRunImplCopyWithImpl(
    _$DocumentRunImpl _value,
    $Res Function(_$DocumentRunImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentRun
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? isBold = null,
    Object? isItalic = null,
    Object? isUnderlined = null,
  }) {
    return _then(
      _$DocumentRunImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        isBold: null == isBold
            ? _value.isBold
            : isBold // ignore: cast_nullable_to_non_nullable
                  as bool,
        isItalic: null == isItalic
            ? _value.isItalic
            : isItalic // ignore: cast_nullable_to_non_nullable
                  as bool,
        isUnderlined: null == isUnderlined
            ? _value.isUnderlined
            : isUnderlined // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$DocumentRunImpl implements _DocumentRun {
  const _$DocumentRunImpl({
    required this.text,
    required this.isBold,
    required this.isItalic,
    required this.isUnderlined,
  });

  @override
  final String text;
  @override
  final bool isBold;
  @override
  final bool isItalic;
  @override
  final bool isUnderlined;

  @override
  String toString() {
    return 'DocumentRun(text: $text, isBold: $isBold, isItalic: $isItalic, isUnderlined: $isUnderlined)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentRunImpl &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.isBold, isBold) || other.isBold == isBold) &&
            (identical(other.isItalic, isItalic) ||
                other.isItalic == isItalic) &&
            (identical(other.isUnderlined, isUnderlined) ||
                other.isUnderlined == isUnderlined));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, text, isBold, isItalic, isUnderlined);

  /// Create a copy of DocumentRun
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentRunImplCopyWith<_$DocumentRunImpl> get copyWith =>
      __$$DocumentRunImplCopyWithImpl<_$DocumentRunImpl>(this, _$identity);
}

abstract class _DocumentRun implements DocumentRun {
  const factory _DocumentRun({
    required final String text,
    required final bool isBold,
    required final bool isItalic,
    required final bool isUnderlined,
  }) = _$DocumentRunImpl;

  @override
  String get text;
  @override
  bool get isBold;
  @override
  bool get isItalic;
  @override
  bool get isUnderlined;

  /// Create a copy of DocumentRun
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentRunImplCopyWith<_$DocumentRunImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
