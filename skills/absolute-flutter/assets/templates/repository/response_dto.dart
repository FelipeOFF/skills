// lib/model/api/common/response_dto.dart
//
// The generic JSON envelope reused by EVERY repo. The backend wraps all bodies
// in { timestamp, status, data, error, metadata }; this centralizes that wire
// format in one place. genericArgumentFactories tells Freezed/json_serializable
// to thread a `T Function(Object?)` into fromJson so each repo supplies its own
// inner decoder. Run build_runner to emit the parts.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'response_dto.freezed.dart';
part 'response_dto.g.dart';

@Freezed(genericArgumentFactories: true)
class ResponseDTO<T> with _$ResponseDTO<T> {
  const factory ResponseDTO({
    DateTime? timestamp,
    dynamic status,
    T? data,
    ErrorDTO? error,
    dynamic metadata,
  }) = _ResponseDTO;

  // fromJsonT is the inner decoder the repo passes in, e.g.
  // (json) => ExampleDto.fromJson(safeMapOf(json)).
  factory ResponseDTO.fromJson(Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$ResponseDTOFromJson<T>(json, fromJsonT);
}

@freezed
class ErrorDTO with _$ErrorDTO {
  const factory ErrorDTO({
    String? code,
    String? message,
  }) = _ErrorDTO;

  factory ErrorDTO.fromJson(Map<String, dynamic> json) => _$ErrorDTOFromJson(json);
}
