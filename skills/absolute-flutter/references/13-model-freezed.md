# 13 — Model: data classes with freezed + json_serializable

The data MODEL layer. Every wire DTO and every domain entity is an **immutable**
data class. DTOs are `@freezed` + `json_serializable` — you hand-write a thin
annotated source and `build_runner` emits the `copyWith`/`==`/`hashCode`/JSON
machinery. Domain entities are plain immutable classes with no JSON. The mapper
from DTO to entity is a `toEntity()` method or an extension — there is **no
separate mapper-class layer**.

This is the SUGGESTED canonical way to model data in this skill. Read
`_conventions.md` first; it is the binding contract this doc obeys.

## When to use

Reach for this reference when the task is any of:

- Model a request body the app SENDS (`model/<concern>/req/`).
- Model a response the app RECEIVES (`model/<concern>/res/`), including nested
  objects and lists of child DTOs.
- Add a `@JsonValue` enum for a wire field.
- Model a one-of-N value as a sealed/union type with `.when`/`.map`/`switch`.
- Add a custom `JsonConverter` for a type freezed cannot map on its own.
- Define a plain domain entity and the `toEntity()` mapper that produces it.

It pairs with `05-repository.md` (repos return these DTOs and decode the
envelope), `10-extensions.md` (mappers and enum labels live in extensions), and
`02-dart-conventions.md` (the codegen toolchain, part files, analyzer exclusion).

## Pattern (the why)

- **Why freezed.** A `@freezed` class is immutable by construction and gets, for
  free: a `copyWith` that preserves unset fields, structural `==`/`hashCode`
  (value equality, not identity), a readable `toString`, sealed unions with
  exhaustive `.when`/`.map`, and — paired with `json_serializable` — `fromJson`/
  `toJson`. You hand-write only the field list; the boilerplate is generated and
  cannot drift out of sync with the fields.
- **DTO vs domain entity split.** A **DTO** mirrors the wire: all fields
  nullable, `@JsonKey(name:)` on each, `fromJson`/`toJson`. A **domain entity**
  is what use cases and UI reason about: non-nullable, validated, named for the
  domain — and has NO JSON, because it never touches the network. The entity is
  a stable type the backend cannot break by renaming a key. The DTO is the
  common return type (see `05-repository.md`); add an entity only when the domain
  shape genuinely differs from the wire shape or needs non-null guarantees — not
  for ceremony.
- **The `@freezed` + const factory + `fromJson` idiom.** A DTO is one
  `@freezed class X with _$X`, one `const factory X({ ... }) = _X;` listing the
  fields, and `factory X.fromJson(...)` as the **last** factory. `@JsonKey(name:
  'wireKey')` on each field pins the wire contract while letting the Dart name
  refactor freely — spell it out even when it already matches. To add a METHOD
  (e.g. `toEntity()`) to a frozen class you must add a private `const X._();`
  constructor; otherwise put behavior in an extension.
- **Part files are generated, committed, never edited.** Each source emits two
  siblings: `<name>.freezed.dart` (the `_$X` mixin: `copyWith`/`==`/`hashCode`/
  union plumbing) and `<name>.g.dart` (the `_$XFromJson`/`_$XToJson`). They carry
  `// GENERATED CODE - DO NOT MODIFY BY HAND`, are git-tracked, and are excluded
  from the analyzer (`lib/**.freezed.dart`, `lib/**.g.dart`). Never hand-edit —
  rerun `build_runner`. Full toolchain rationale is in `02-dart-conventions.md`.
- **`req/` vs `res/` folder split.** Request DTOs (what you send) live under
  `model/<concern>/req/`; response DTOs (what you receive) under
  `model/<concern>/res/`. Shared API envelopes (`ResponseDTO<T>`, `PageDto<T>`)
  live under `model/api/common/`. The split makes the direction of every type
  obvious at the import.
- **Sealed/union models for one-of-N.** When a value is genuinely several
  disjoint shapes (a status outcome, a polymorphic payload), model it as a
  freezed union: multiple named const factories. The generated class is sealed,
  so a Dart 3 `switch` or `.when`/`.map` is **exhaustive** — the compiler forces
  every variant to be handled, and adding a variant breaks every consumer until
  updated. Do NOT use a union for a plain record-like DTO (single factory).
- **Enums carry the wire value via `@JsonValue`.** A plain enum with `@JsonValue`
  on each constant maps the wire string/int <-> constant for free when used as a
  field type. An enhanced enum can also hold a payload. Keep presentation
  (labels, icons) OFF the enum — that goes in an `extension XOnEnum` (see
  `10-extensions.md`).
- **Custom `JsonConverter` for what freezed can't map.** When a field needs
  non-trivial decoding (a timestamp string with timezone normalization, an enum
  keyed by a non-standard value), write a `class XSerializer implements
  JsonConverter<DartType, WireType>` in `common/helper/` and annotate the field
  with `@XSerializer()`. The existing `json_converter.dart` template
  (`assets/templates/config/`) is the canonical shape — reuse it.
- **The `toEntity()` mapper is the boundary.** DTO -> entity mapping is either a
  `toEntity()` method on the DTO (needs `const X._();`) or an `extension
  XDtoMapper on XDto { ExampleEntity toEntity() => ... }`. Both are "the mapper";
  there is NO `AbstractMapper`/mapper-class layer (vestigial — see
  `05-repository.md`). The mapper resolves nullable wire fields into non-nullable
  domain fields: supply defaults, drop nulls, fail soft. Cross-DTO and
  DTO->entity mapping live in extensions by convention (`10-extensions.md`).

## Folder placement

```
lib/
  model/
    api/
      common/
        response_dto.dart            # generic envelope ResponseDTO<T> (05-repository.md)
        page_dto.dart                # generic paginated PageDto<T>   (05-repository.md)
    example/
      example_status.dart            # @JsonValue enum(s) for the concern
      example_entity.dart            # plain immutable domain entity (no JSON)
      example_mapper_ext.dart        # extension XDtoMapper: DTO -> entity
      req/
        example_request_dto.dart     # request body the app SENDS
      res/
        example_response_dto.dart    # response the app RECEIVES (nested + lists)
        example_result.dart          # sealed/union model
  common/helper/
    timestamp_serializer.dart        # custom JsonConverter (assets/templates/config/)
```

Each DTO source has `<name>.freezed.dart` + `<name>.g.dart` siblings emitted by
`build_runner` next to it — committed, analyzer-excluded, never hand-edited.

## Templates

Copy from `assets/templates/model/` and rename the anchors (`Example`, `Item`)
to the real concern. The first two below are EXISTING templates elsewhere —
reuse them, do not recreate.

| File | What it is |
|---|---|
| [`config/example_dto.dart`](../assets/templates/config/example_dto.dart) | The baseline freezed + json DTO (enum field, named convenience factory, derived-getter extension). Start here for a plain DTO. EXISTING — reuse. |
| [`config/json_converter.dart`](../assets/templates/config/json_converter.dart) | Custom `JsonConverter` (String <-> DateTime). Copy into `common/helper/` and apply with `@XSerializer()`. EXISTING — reuse. |
| [`model/example_request_dto.dart`](../assets/templates/model/example_request_dto.dart) | A REQUEST body DTO: `@JsonKey` fields, `@Default` vs nullable, a `@JsonValue` enum. Lives under `req/`. |
| [`model/example_response_dto.dart`](../assets/templates/model/example_response_dto.dart) | A RESPONSE DTO with a NESTED object DTO + a `List<ChildDto>` + enum + converter on a date. Lives under `res/`. |
| [`model/example_sealed_model.dart`](../assets/templates/model/example_sealed_model.dart) | A freezed UNION: multiple const factories + a `fromStatus` mapping + a consumer using exhaustive `switch` and `.when`. |
| [`model/example_enum.dart`](../assets/templates/model/example_enum.dart) | `@JsonValue` enums — a plain one and an enhanced one with a payload + null-tolerant lookup. |
| [`model/example_entity.dart`](../assets/templates/model/example_entity.dart) | A plain immutable DOMAIN ENTITY (no freezed/JSON) — the target of `toEntity()`. |
| [`model/example_mapper_ext.dart`](../assets/templates/model/example_mapper_ext.dart) | `extension ExampleResponseDtoMapper on ExampleResponseDto { ExampleEntity toEntity() => ... }` — the DTO->entity boundary. |

For the shared `ResponseDTO<T>` / `PageDto<T>` envelopes and the `toEntity()`-as-
method variant, see `05-repository.md` (templates under
`assets/templates/repository/`).

## Step-by-step to apply

1. **Pick the direction and folder.** Sending a body → `model/<concern>/req/`.
   Receiving → `model/<concern>/res/`. Copy the matching request/response
   template and rename `Example` throughout (class names, file names, fields).
2. **Declare the fields.** One `const factory X({ ... }) = _X;`. Put
   `@JsonKey(name: 'wireKey')` on every field. Response fields are all nullable;
   request fields are nullable (omit-on-null) or `@Default(...)` (always sent).
   `fromJson` is the LAST factory.
3. **Model enums and unions as needed.** Wire-mapped enum → `@JsonValue` on each
   constant (`example_enum.dart`). One-of-N value → a freezed union with named
   const factories (`example_sealed_model.dart`). Keep enum presentation in an
   extension, not on the enum.
4. **Add a converter only when freezed can't map the type.** Copy
   `config/json_converter.dart` into `common/helper/`, rename, set the
   `<DartType, WireType>` arguments, annotate the field with `@XSerializer()`.
5. **Add a domain entity + mapper only if warranted.** If the UI/use case needs
   non-nullable, validated, or reshaped fields, copy `example_entity.dart` and
   `example_mapper_ext.dart`; the mapper supplies defaults for the DTO's nullable
   fields. Otherwise return the DTO directly (see `05-repository.md`).
6. **Codegen.** Run
   `dart run build_runner build --delete-conflicting-outputs`
   to emit every touched DTO's `.freezed.dart` / `.g.dart`. Commit the generated
   siblings; never hand-edit them.
7. **Verify.** `flutter analyze` (generated files are analyzer-excluded, so a
   lint error is in YOUR source). Confirm nested DTOs round-trip — if a nested
   `toJson` emits `Instance of '...'`, `explicit_to_json` is off (see Gotchas).

## Gotchas

- **`fromJson` is always the last factory.** Member order inside a freezed file:
  imports → `part` → top-level enums → `@freezed class` (field factory first,
  named convenience factories next, `fromJson` LAST) → extensions. Enforced by
  convention and the `02-dart-conventions.md` member-order rule.
- **Adding a method needs the private ctor.** `toEntity()` (or any method) on a
  frozen class requires a `const X._();` private constructor in the class. Omit
  it and the method won't compile. Prefer an `extension` to avoid needing it.
- **Nested freezed DTOs need `explicit_to_json: true`.** Without it (set in
  `build.yaml`), a nested DTO's `toJson` silently emits `Instance of '...'`
  instead of a map. The `config/build.yaml` template already sets it.
- **`any_map: true` changes the fromJson signature.** With it set, generated
  `fromJson` accepts `Map` (untyped), so write `factory X.fromJson(Map json)` or
  `Map<String, dynamic>` per the project's `build.yaml` — match the existing DTOs
  in the repo.
- **Union `fromJson` is `runtimeType`-discriminated.** A freezed union's
  generated `fromJson` keys off a `runtimeType` field in the JSON; renaming or
  adding a named factory changes that wire discriminator. When the backend sends
  a flat status string instead, write a hand `fromStatus`/`fromString` factory
  (as in `example_sealed_model.dart`) rather than relying on the discriminator.
- **`@JsonValue` is the wire value, not the Dart name.** The enum constant name
  is yours to refactor; the `@JsonValue('WIRE')` is the contract. An unmapped
  incoming value throws on decode — guard with a fallback lookup or a nullable
  field where the backend may add values.
- **Keep presentation off the model.** Labels, icons, formatting → an
  `extension XOnEnum` / `extension XDtoX` (see `10-extensions.md`), never on the
  frozen class or the enum. Frozen classes stay pure data.
- **Generated files are committed but analyzer-excluded.** `*.freezed.dart` /
  `*.g.dart` are git-tracked (so CI builds without running codegen) yet excluded
  from the analyzer and never hand-edited. After ANY field change, rerun
  `dart run build_runner build --delete-conflicting-outputs`.
- **One concern, one folder, snake_case files.** `example_response_dto.dart`,
  not `ExampleResponseDTO.dart`. Types are `PascalCase`, files `snake_case`,
  imports always `package:app/...` (never relative).
