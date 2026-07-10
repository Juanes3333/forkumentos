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
  List<DocumentBlock> get blocks => throw _privateConstructorUsedError;

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
    List<DocumentBlock> blocks,
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
    Object? blocks = null,
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
            blocks: null == blocks
                ? _value.blocks
                : blocks // ignore: cast_nullable_to_non_nullable
                      as List<DocumentBlock>,
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
    List<DocumentBlock> blocks,
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
    Object? blocks = null,
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
        blocks: null == blocks
            ? _value._blocks
            : blocks // ignore: cast_nullable_to_non_nullable
                  as List<DocumentBlock>,
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
    required final List<DocumentBlock> blocks,
  }) : _blocks = blocks;

  @override
  final int number;
  @override
  final double widthPoints;
  @override
  final double heightPoints;
  @override
  final DocumentMargins margins;
  final List<DocumentBlock> _blocks;
  @override
  List<DocumentBlock> get blocks {
    if (_blocks is EqualUnmodifiableListView) return _blocks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blocks);
  }

  @override
  String toString() {
    return 'DocumentPage(number: $number, widthPoints: $widthPoints, heightPoints: $heightPoints, margins: $margins, blocks: $blocks)';
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
            const DeepCollectionEquality().equals(other._blocks, _blocks));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    number,
    widthPoints,
    heightPoints,
    margins,
    const DeepCollectionEquality().hash(_blocks),
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
    required final List<DocumentBlock> blocks,
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
  List<DocumentBlock> get blocks;

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
mixin _$DocumentBlock {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(DocumentParagraph paragraph) paragraph,
    required TResult Function(DocumentTable table) table,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(DocumentParagraph paragraph)? paragraph,
    TResult? Function(DocumentTable table)? table,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(DocumentParagraph paragraph)? paragraph,
    TResult Function(DocumentTable table)? table,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DocumentParagraphBlock value) paragraph,
    required TResult Function(DocumentTableBlock value) table,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DocumentParagraphBlock value)? paragraph,
    TResult? Function(DocumentTableBlock value)? table,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DocumentParagraphBlock value)? paragraph,
    TResult Function(DocumentTableBlock value)? table,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentBlockCopyWith<$Res> {
  factory $DocumentBlockCopyWith(
    DocumentBlock value,
    $Res Function(DocumentBlock) then,
  ) = _$DocumentBlockCopyWithImpl<$Res, DocumentBlock>;
}

/// @nodoc
class _$DocumentBlockCopyWithImpl<$Res, $Val extends DocumentBlock>
    implements $DocumentBlockCopyWith<$Res> {
  _$DocumentBlockCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$DocumentParagraphBlockImplCopyWith<$Res> {
  factory _$$DocumentParagraphBlockImplCopyWith(
    _$DocumentParagraphBlockImpl value,
    $Res Function(_$DocumentParagraphBlockImpl) then,
  ) = __$$DocumentParagraphBlockImplCopyWithImpl<$Res>;
  @useResult
  $Res call({DocumentParagraph paragraph});

  $DocumentParagraphCopyWith<$Res> get paragraph;
}

/// @nodoc
class __$$DocumentParagraphBlockImplCopyWithImpl<$Res>
    extends _$DocumentBlockCopyWithImpl<$Res, _$DocumentParagraphBlockImpl>
    implements _$$DocumentParagraphBlockImplCopyWith<$Res> {
  __$$DocumentParagraphBlockImplCopyWithImpl(
    _$DocumentParagraphBlockImpl _value,
    $Res Function(_$DocumentParagraphBlockImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? paragraph = null}) {
    return _then(
      _$DocumentParagraphBlockImpl(
        null == paragraph
            ? _value.paragraph
            : paragraph // ignore: cast_nullable_to_non_nullable
                  as DocumentParagraph,
      ),
    );
  }

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DocumentParagraphCopyWith<$Res> get paragraph {
    return $DocumentParagraphCopyWith<$Res>(_value.paragraph, (value) {
      return _then(_value.copyWith(paragraph: value));
    });
  }
}

/// @nodoc

class _$DocumentParagraphBlockImpl implements DocumentParagraphBlock {
  const _$DocumentParagraphBlockImpl(this.paragraph);

  @override
  final DocumentParagraph paragraph;

  @override
  String toString() {
    return 'DocumentBlock.paragraph(paragraph: $paragraph)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentParagraphBlockImpl &&
            (identical(other.paragraph, paragraph) ||
                other.paragraph == paragraph));
  }

  @override
  int get hashCode => Object.hash(runtimeType, paragraph);

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentParagraphBlockImplCopyWith<_$DocumentParagraphBlockImpl>
  get copyWith =>
      __$$DocumentParagraphBlockImplCopyWithImpl<_$DocumentParagraphBlockImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(DocumentParagraph paragraph) paragraph,
    required TResult Function(DocumentTable table) table,
  }) {
    return paragraph(this.paragraph);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(DocumentParagraph paragraph)? paragraph,
    TResult? Function(DocumentTable table)? table,
  }) {
    return paragraph?.call(this.paragraph);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(DocumentParagraph paragraph)? paragraph,
    TResult Function(DocumentTable table)? table,
    required TResult orElse(),
  }) {
    if (paragraph != null) {
      return paragraph(this.paragraph);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DocumentParagraphBlock value) paragraph,
    required TResult Function(DocumentTableBlock value) table,
  }) {
    return paragraph(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DocumentParagraphBlock value)? paragraph,
    TResult? Function(DocumentTableBlock value)? table,
  }) {
    return paragraph?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DocumentParagraphBlock value)? paragraph,
    TResult Function(DocumentTableBlock value)? table,
    required TResult orElse(),
  }) {
    if (paragraph != null) {
      return paragraph(this);
    }
    return orElse();
  }
}

abstract class DocumentParagraphBlock implements DocumentBlock {
  const factory DocumentParagraphBlock(final DocumentParagraph paragraph) =
      _$DocumentParagraphBlockImpl;

  DocumentParagraph get paragraph;

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentParagraphBlockImplCopyWith<_$DocumentParagraphBlockImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DocumentTableBlockImplCopyWith<$Res> {
  factory _$$DocumentTableBlockImplCopyWith(
    _$DocumentTableBlockImpl value,
    $Res Function(_$DocumentTableBlockImpl) then,
  ) = __$$DocumentTableBlockImplCopyWithImpl<$Res>;
  @useResult
  $Res call({DocumentTable table});

  $DocumentTableCopyWith<$Res> get table;
}

/// @nodoc
class __$$DocumentTableBlockImplCopyWithImpl<$Res>
    extends _$DocumentBlockCopyWithImpl<$Res, _$DocumentTableBlockImpl>
    implements _$$DocumentTableBlockImplCopyWith<$Res> {
  __$$DocumentTableBlockImplCopyWithImpl(
    _$DocumentTableBlockImpl _value,
    $Res Function(_$DocumentTableBlockImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? table = null}) {
    return _then(
      _$DocumentTableBlockImpl(
        null == table
            ? _value.table
            : table // ignore: cast_nullable_to_non_nullable
                  as DocumentTable,
      ),
    );
  }

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DocumentTableCopyWith<$Res> get table {
    return $DocumentTableCopyWith<$Res>(_value.table, (value) {
      return _then(_value.copyWith(table: value));
    });
  }
}

/// @nodoc

class _$DocumentTableBlockImpl implements DocumentTableBlock {
  const _$DocumentTableBlockImpl(this.table);

  @override
  final DocumentTable table;

  @override
  String toString() {
    return 'DocumentBlock.table(table: $table)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentTableBlockImpl &&
            (identical(other.table, table) || other.table == table));
  }

  @override
  int get hashCode => Object.hash(runtimeType, table);

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentTableBlockImplCopyWith<_$DocumentTableBlockImpl> get copyWith =>
      __$$DocumentTableBlockImplCopyWithImpl<_$DocumentTableBlockImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(DocumentParagraph paragraph) paragraph,
    required TResult Function(DocumentTable table) table,
  }) {
    return table(this.table);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(DocumentParagraph paragraph)? paragraph,
    TResult? Function(DocumentTable table)? table,
  }) {
    return table?.call(this.table);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(DocumentParagraph paragraph)? paragraph,
    TResult Function(DocumentTable table)? table,
    required TResult orElse(),
  }) {
    if (table != null) {
      return table(this.table);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DocumentParagraphBlock value) paragraph,
    required TResult Function(DocumentTableBlock value) table,
  }) {
    return table(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DocumentParagraphBlock value)? paragraph,
    TResult? Function(DocumentTableBlock value)? table,
  }) {
    return table?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DocumentParagraphBlock value)? paragraph,
    TResult Function(DocumentTableBlock value)? table,
    required TResult orElse(),
  }) {
    if (table != null) {
      return table(this);
    }
    return orElse();
  }
}

abstract class DocumentTableBlock implements DocumentBlock {
  const factory DocumentTableBlock(final DocumentTable table) =
      _$DocumentTableBlockImpl;

  DocumentTable get table;

  /// Create a copy of DocumentBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentTableBlockImplCopyWith<_$DocumentTableBlockImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DocumentTable {
  List<DocumentTableRow> get rows => throw _privateConstructorUsedError;

  /// Create a copy of DocumentTable
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentTableCopyWith<DocumentTable> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentTableCopyWith<$Res> {
  factory $DocumentTableCopyWith(
    DocumentTable value,
    $Res Function(DocumentTable) then,
  ) = _$DocumentTableCopyWithImpl<$Res, DocumentTable>;
  @useResult
  $Res call({List<DocumentTableRow> rows});
}

/// @nodoc
class _$DocumentTableCopyWithImpl<$Res, $Val extends DocumentTable>
    implements $DocumentTableCopyWith<$Res> {
  _$DocumentTableCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentTable
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? rows = null}) {
    return _then(
      _value.copyWith(
            rows: null == rows
                ? _value.rows
                : rows // ignore: cast_nullable_to_non_nullable
                      as List<DocumentTableRow>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentTableImplCopyWith<$Res>
    implements $DocumentTableCopyWith<$Res> {
  factory _$$DocumentTableImplCopyWith(
    _$DocumentTableImpl value,
    $Res Function(_$DocumentTableImpl) then,
  ) = __$$DocumentTableImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<DocumentTableRow> rows});
}

/// @nodoc
class __$$DocumentTableImplCopyWithImpl<$Res>
    extends _$DocumentTableCopyWithImpl<$Res, _$DocumentTableImpl>
    implements _$$DocumentTableImplCopyWith<$Res> {
  __$$DocumentTableImplCopyWithImpl(
    _$DocumentTableImpl _value,
    $Res Function(_$DocumentTableImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentTable
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? rows = null}) {
    return _then(
      _$DocumentTableImpl(
        rows: null == rows
            ? _value._rows
            : rows // ignore: cast_nullable_to_non_nullable
                  as List<DocumentTableRow>,
      ),
    );
  }
}

/// @nodoc

class _$DocumentTableImpl implements _DocumentTable {
  const _$DocumentTableImpl({required final List<DocumentTableRow> rows})
    : _rows = rows;

  final List<DocumentTableRow> _rows;
  @override
  List<DocumentTableRow> get rows {
    if (_rows is EqualUnmodifiableListView) return _rows;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rows);
  }

  @override
  String toString() {
    return 'DocumentTable(rows: $rows)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentTableImpl &&
            const DeepCollectionEquality().equals(other._rows, _rows));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_rows));

  /// Create a copy of DocumentTable
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentTableImplCopyWith<_$DocumentTableImpl> get copyWith =>
      __$$DocumentTableImplCopyWithImpl<_$DocumentTableImpl>(this, _$identity);
}

abstract class _DocumentTable implements DocumentTable {
  const factory _DocumentTable({required final List<DocumentTableRow> rows}) =
      _$DocumentTableImpl;

  @override
  List<DocumentTableRow> get rows;

  /// Create a copy of DocumentTable
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentTableImplCopyWith<_$DocumentTableImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DocumentTableRow {
  List<DocumentTableCell> get cells => throw _privateConstructorUsedError;

  /// Create a copy of DocumentTableRow
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentTableRowCopyWith<DocumentTableRow> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentTableRowCopyWith<$Res> {
  factory $DocumentTableRowCopyWith(
    DocumentTableRow value,
    $Res Function(DocumentTableRow) then,
  ) = _$DocumentTableRowCopyWithImpl<$Res, DocumentTableRow>;
  @useResult
  $Res call({List<DocumentTableCell> cells});
}

/// @nodoc
class _$DocumentTableRowCopyWithImpl<$Res, $Val extends DocumentTableRow>
    implements $DocumentTableRowCopyWith<$Res> {
  _$DocumentTableRowCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentTableRow
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? cells = null}) {
    return _then(
      _value.copyWith(
            cells: null == cells
                ? _value.cells
                : cells // ignore: cast_nullable_to_non_nullable
                      as List<DocumentTableCell>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentTableRowImplCopyWith<$Res>
    implements $DocumentTableRowCopyWith<$Res> {
  factory _$$DocumentTableRowImplCopyWith(
    _$DocumentTableRowImpl value,
    $Res Function(_$DocumentTableRowImpl) then,
  ) = __$$DocumentTableRowImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<DocumentTableCell> cells});
}

/// @nodoc
class __$$DocumentTableRowImplCopyWithImpl<$Res>
    extends _$DocumentTableRowCopyWithImpl<$Res, _$DocumentTableRowImpl>
    implements _$$DocumentTableRowImplCopyWith<$Res> {
  __$$DocumentTableRowImplCopyWithImpl(
    _$DocumentTableRowImpl _value,
    $Res Function(_$DocumentTableRowImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentTableRow
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? cells = null}) {
    return _then(
      _$DocumentTableRowImpl(
        cells: null == cells
            ? _value._cells
            : cells // ignore: cast_nullable_to_non_nullable
                  as List<DocumentTableCell>,
      ),
    );
  }
}

/// @nodoc

class _$DocumentTableRowImpl implements _DocumentTableRow {
  const _$DocumentTableRowImpl({required final List<DocumentTableCell> cells})
    : _cells = cells;

  final List<DocumentTableCell> _cells;
  @override
  List<DocumentTableCell> get cells {
    if (_cells is EqualUnmodifiableListView) return _cells;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_cells);
  }

  @override
  String toString() {
    return 'DocumentTableRow(cells: $cells)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentTableRowImpl &&
            const DeepCollectionEquality().equals(other._cells, _cells));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_cells));

  /// Create a copy of DocumentTableRow
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentTableRowImplCopyWith<_$DocumentTableRowImpl> get copyWith =>
      __$$DocumentTableRowImplCopyWithImpl<_$DocumentTableRowImpl>(
        this,
        _$identity,
      );
}

abstract class _DocumentTableRow implements DocumentTableRow {
  const factory _DocumentTableRow({
    required final List<DocumentTableCell> cells,
  }) = _$DocumentTableRowImpl;

  @override
  List<DocumentTableCell> get cells;

  /// Create a copy of DocumentTableRow
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentTableRowImplCopyWith<_$DocumentTableRowImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DocumentTableCell {
  List<DocumentBlock> get blocks => throw _privateConstructorUsedError;

  /// Create a copy of DocumentTableCell
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentTableCellCopyWith<DocumentTableCell> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentTableCellCopyWith<$Res> {
  factory $DocumentTableCellCopyWith(
    DocumentTableCell value,
    $Res Function(DocumentTableCell) then,
  ) = _$DocumentTableCellCopyWithImpl<$Res, DocumentTableCell>;
  @useResult
  $Res call({List<DocumentBlock> blocks});
}

/// @nodoc
class _$DocumentTableCellCopyWithImpl<$Res, $Val extends DocumentTableCell>
    implements $DocumentTableCellCopyWith<$Res> {
  _$DocumentTableCellCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentTableCell
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? blocks = null}) {
    return _then(
      _value.copyWith(
            blocks: null == blocks
                ? _value.blocks
                : blocks // ignore: cast_nullable_to_non_nullable
                      as List<DocumentBlock>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentTableCellImplCopyWith<$Res>
    implements $DocumentTableCellCopyWith<$Res> {
  factory _$$DocumentTableCellImplCopyWith(
    _$DocumentTableCellImpl value,
    $Res Function(_$DocumentTableCellImpl) then,
  ) = __$$DocumentTableCellImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<DocumentBlock> blocks});
}

/// @nodoc
class __$$DocumentTableCellImplCopyWithImpl<$Res>
    extends _$DocumentTableCellCopyWithImpl<$Res, _$DocumentTableCellImpl>
    implements _$$DocumentTableCellImplCopyWith<$Res> {
  __$$DocumentTableCellImplCopyWithImpl(
    _$DocumentTableCellImpl _value,
    $Res Function(_$DocumentTableCellImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentTableCell
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? blocks = null}) {
    return _then(
      _$DocumentTableCellImpl(
        blocks: null == blocks
            ? _value._blocks
            : blocks // ignore: cast_nullable_to_non_nullable
                  as List<DocumentBlock>,
      ),
    );
  }
}

/// @nodoc

class _$DocumentTableCellImpl implements _DocumentTableCell {
  const _$DocumentTableCellImpl({required final List<DocumentBlock> blocks})
    : _blocks = blocks;

  final List<DocumentBlock> _blocks;
  @override
  List<DocumentBlock> get blocks {
    if (_blocks is EqualUnmodifiableListView) return _blocks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blocks);
  }

  @override
  String toString() {
    return 'DocumentTableCell(blocks: $blocks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentTableCellImpl &&
            const DeepCollectionEquality().equals(other._blocks, _blocks));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_blocks));

  /// Create a copy of DocumentTableCell
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentTableCellImplCopyWith<_$DocumentTableCellImpl> get copyWith =>
      __$$DocumentTableCellImplCopyWithImpl<_$DocumentTableCellImpl>(
        this,
        _$identity,
      );
}

abstract class _DocumentTableCell implements DocumentTableCell {
  const factory _DocumentTableCell({
    required final List<DocumentBlock> blocks,
  }) = _$DocumentTableCellImpl;

  @override
  List<DocumentBlock> get blocks;

  /// Create a copy of DocumentTableCell
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentTableCellImplCopyWith<_$DocumentTableCellImpl> get copyWith =>
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
