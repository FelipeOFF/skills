// example_dto.dart — freezed + json_serializable DTO skeleton.
//
// Rename anchors: Example / ExampleDto / ExampleType -> your entity name.
// Generated siblings (created by build_runner, committed, never hand-edited):
//   example_dto.freezed.dart   — the _$ExampleDto mixin + copyWith/==/hashCode
//   example_dto.g.dart         — the _$ExampleDtoFromJson / _$ExampleDtoToJson
//
// Member order inside the file (keep it): imports -> part -> top-level enums ->
// @freezed class (factory ctors first, fromJson LAST) -> extensions.

import 'package:app/common/helper/timestamp_serializer.dart';
import 'package:app/model/api/common/profile_dto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'example_dto.freezed.dart';
part 'example_dto.g.dart';

enum ExampleType {
  @JsonValue(0)
  alpha,
  @JsonValue(1)
  beta,
}

@freezed
class ExampleDto with _$ExampleDto {
  const factory ExampleDto({
    required int id,
    required String title,
    @TimestampSerializer() required DateTime createdAt,
    required ExampleType type,
    double? amount,
    ProfileDto? profile,
  }) = _ExampleDto;

  // Named convenience factory: map another DTO into this one. Stays a factory,
  // not a method, so the frozen class keeps no behavior.
  factory ExampleDto.fromProfile({required ProfileDto profile}) => _ExampleDto(
    id: profile.id ?? 0,
    title: profile.name ?? '',
    createdAt: DateTime.now(),
    type: ExampleType.alpha,
  );

  // fromJson is ALWAYS the last factory. Required for json_serializable.
  factory ExampleDto.fromJson(Map json) => _$ExampleDtoFromJson(json);
}

// Derived getters and cross-DTO mappers live in an extension, never on the
// frozen class — that keeps the generated mixin clean and avoids the freezed
// private-constructor error.
extension ExampleDtoX on ExampleDto {
  bool get isValid => id > 0 && title.isNotEmpty;
}
