// lib/model/example/res/example_response_dto.dart
//
// A RESPONSE DTO — the shape the app RECEIVES. Lives under model/<concern>/res/.
// Demonstrates the two shapes a response carries beyond scalars:
//   1. a NESTED object DTO   (ExampleDetailDto field)
//   2. a LIST of child DTOs  (List<ExampleItemDto> items)
// plus a @JsonValue enum and a @TimestampSerializer custom converter on a date.
//
// Rename anchors: Example / ExampleResponseDto / ExampleItemDto /
// ExampleDetailDto / ExampleStatus -> your concern.
//
// build_runner emits the .freezed.dart / .g.dart siblings. For nested freezed
// DTOs to serialize, build.yaml MUST set json_serializable.explicit_to_json:
// true — otherwise nested toJson silently emits "Instance of '...'" (see
// 02-dart-conventions.md). Response fields are all nullable: the wire may omit
// any of them, and a null-tolerant model never throws on decode.

import 'package:app/common/helper/timestamp_serializer.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'example_response_dto.freezed.dart';
part 'example_response_dto.g.dart';

enum ExampleStatus {
  @JsonValue('ACTIVE')
  active,
  @JsonValue('ARCHIVED')
  archived,
  @JsonValue('PENDING')
  pending,
}

@freezed
class ExampleResponseDto with _$ExampleResponseDto {
  const factory ExampleResponseDto({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'title') String? title,
    @JsonKey(name: 'status') ExampleStatus? status,
    @JsonKey(name: 'createdAt') @TimestampSerializer() DateTime? createdAt,
    // Nested object DTO — decoded recursively by json_serializable.
    @JsonKey(name: 'detail') ExampleDetailDto? detail,
    // List of child DTOs — each element decoded via ExampleItemDto.fromJson.
    @JsonKey(name: 'items') List<ExampleItemDto>? items,
  }) = _ExampleResponseDto;

  factory ExampleResponseDto.fromJson(Map<String, dynamic> json) => _$ExampleResponseDtoFromJson(json);
}

@freezed
class ExampleDetailDto with _$ExampleDetailDto {
  const factory ExampleDetailDto({
    @JsonKey(name: 'summary') String? summary,
    @JsonKey(name: 'amount') double? amount,
  }) = _ExampleDetailDto;

  factory ExampleDetailDto.fromJson(Map<String, dynamic> json) => _$ExampleDetailDtoFromJson(json);
}

@freezed
class ExampleItemDto with _$ExampleItemDto {
  const factory ExampleItemDto({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'label') String? label,
    @JsonKey(name: 'position') int? position,
  }) = _ExampleItemDto;

  factory ExampleItemDto.fromJson(Map<String, dynamic> json) => _$ExampleItemDtoFromJson(json);
}
