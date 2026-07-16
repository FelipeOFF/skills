// lib/model/example/req/example_request_dto.dart
//
// A REQUEST body DTO — the shape the app SENDS to the backend. Lives under
// model/<concern>/req/. Freezed + json_serializable: hand-write this thin
// source, run build_runner to emit example_request_dto.freezed.dart /
// .g.dart (committed, never hand-edited, analyzer-excluded — see
// 02-dart-conventions.md).
//
// Rename anchors: Example / ExampleRequestDto / ExampleScope -> your concern.
//
// Notes on the idiom:
//  - @JsonKey(name: 'wireName') maps a camelCase Dart field to the exact wire
//    key. Spell it out even when it already matches — the backend key is the
//    contract, the Dart name is ours to refactor freely.
//  - Request fields are typically nullable (omit-on-null) OR have @Default so
//    the body always serializes a value. Pick per field: required-ish inputs
//    get @Default; optional filters stay nullable.
//  - fromJson is ALWAYS the last factory. A request DTO still gets toJson (from
//    json_serializable) — that is what the repo serializes into the body.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'example_request_dto.freezed.dart';
part 'example_request_dto.g.dart';

enum ExampleScope {
  @JsonValue('ALL')
  all,
  @JsonValue('MINE')
  mine,
}

@freezed
class ExampleRequestDto with _$ExampleRequestDto {
  const factory ExampleRequestDto({
    @JsonKey(name: 'query') String? query,
    @JsonKey(name: 'page') @Default(0) int page,
    @JsonKey(name: 'size') @Default(20) int size,
    @JsonKey(name: 'scope') ExampleScope? scope,
  }) = _ExampleRequestDto;

  factory ExampleRequestDto.fromJson(Map<String, dynamic> json) => _$ExampleRequestDtoFromJson(json);
}
