// lib/model/api/common/page_dto.dart
//
// The generic paginated envelope. Sits INSIDE ResponseDTO for list endpoints:
// ResponseDTO<PageDto<ExampleDto>>. Like ResponseDTO it uses
// genericArgumentFactories so each repo supplies the element decoder. Run
// build_runner to emit the parts.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'page_dto.freezed.dart';
part 'page_dto.g.dart';

@Freezed(genericArgumentFactories: true)
class PageDto<T> with _$PageDto<T> {
  const factory PageDto({
    @Default(<dynamic>[]) List<T> content,
    int? page,
    int? size,
    int? totalElements,
    int? totalPages,
    bool? last,
  }) = _PageDto;

  // fromJsonT decodes each element of `content`, e.g.
  // (e) => ExampleDto.fromJson(e.asSafeMap).
  factory PageDto.fromJson(Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$PageDtoFromJson<T>(json, fromJsonT);
}
