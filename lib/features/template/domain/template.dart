import 'package:freezed_annotation/freezed_annotation.dart';

part 'template.freezed.dart';

@freezed
class Template with _$Template {
  const factory Template({
    required String sourcePath,
    required String fileName,
    required int fileSizeBytes,
    required DateTime importedAt,
    String? title,
    String? author,
    int? pageCount,
    int? wordCount,
  }) = _Template;
}
