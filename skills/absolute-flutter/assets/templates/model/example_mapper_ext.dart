// lib/model/example/example_mapper_ext.dart
//
// The DTO -> domain ENTITY mapper, as an EXTENSION on the response DTO. This is
// the boundary where wire types become domain types. Two equally valid homes for
// it (pick one, be consistent):
//   A) an `extension XDtoMapper on ExampleResponseDto` (this file) — keeps the
//      frozen DTO clean, no private `._()` ctor needed;
//   B) a `toEntity()` METHOD on the DTO itself (requires `const Dto._();`, see
//      assets/templates/repository/example_dto.dart).
// Both are "the mapper" — there is NO separate mapper-class layer (see
// 05-repository.md). Cross-DTO and DTO->entity mapping lives in extensions by
// convention (see 10-extensions.md).
//
// Rename anchors: Example / ExampleResponseDto / ExampleItemDto / ExampleEntity
// -> your concern.
//
// The mapper resolves the DTO's all-nullable wire fields into the entity's
// non-nullable domain fields: supply defaults, drop nulls from lists, and fail
// soft rather than throw. This is exactly the value an entity adds over passing
// the raw DTO around.

import 'package:app/model/example/example_entity.dart';
import 'package:app/model/example/example_status.dart';
import 'package:app/model/example/res/example_response_dto.dart';

extension ExampleResponseDtoMapper on ExampleResponseDto {
  ExampleEntity toEntity() => ExampleEntity(
        id: id ?? '',
        title: title ?? '',
        status: status ?? ExampleStatus.pending,
        amount: detail?.amount,
      );
}

extension ExampleItemListMapper on List<ExampleItemDto>? {
  // Null-tolerant list mapping: a null or missing wire list becomes [].
  List<String> toLabels() => (this ?? const <ExampleItemDto>[]).map((item) => item.label ?? '').toList();
}
