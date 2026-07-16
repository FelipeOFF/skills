// lib/model/api/example/example_dto.dart
//
// The DTO is the cross-layer return type — a generated Freezed class, not a
// hand-written domain model. The "mapper" is the Freezed fromJson/toJson PLUS an
// occasional toEntity()/toDomain() method ON the DTO. There is NO separate
// mapper-class layer; do not generate one. Run build_runner to emit the
// .freezed.dart / .g.dart parts.
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app/domain/example/entities/example_entity.dart';

part 'example_dto.freezed.dart';
part 'example_dto.g.dart';

@freezed
class ExampleDto with _$ExampleDto {
  // The private named constructor (`._`) is REQUIRED to add methods (toEntity)
  // to a Freezed class. Omit it and toEntity won't compile.
  const ExampleDto._();

  const factory ExampleDto({
    String? id,
    String? name,
    double? amount,
    bool? active,
  }) = _ExampleDto;

  factory ExampleDto.fromJson(Map<String, dynamic> json) => _$ExampleDtoFromJson(json);

  // The "mapper": DTO -> domain entity, inlined as a method. Use this when a
  // call site needs a pure domain entity rather than the wire DTO.
  ExampleEntity toEntity() => ExampleEntity(
        id: id,
        name: name,
        amount: amount,
        active: active,
      );
}
