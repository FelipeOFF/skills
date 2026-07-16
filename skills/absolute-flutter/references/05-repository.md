# 05 — Repository: interface + impl, envelope decode, DTO mappers

The data-access layer. One concern = one folder holding an `I`-prefixed
interface beside its impl. The impl calls an injected transport client, decodes
the JSON envelope at the boundary, and returns generated DTOs. Mapping to a
domain entity, when needed, is a `toEntity()` method on the DTO — there is no
separate mapper-class layer.

Read `_conventions.md` first; it is the binding contract this doc obeys.

## When to use

Reach for this reference when the task is any of:

- Add a repository for a new concern (a new backend resource the app reads/writes).
- Add a method to an existing repository.
- Wire a new DTO + its envelope decode, or add a `toEntity()` mapper.
- Register a repo in DI.

It pairs with `04-usecases.md` (the use case calls the repo and owns the
`Either`/error funnel) and `06-gateway-backend.md` (the `LoggedClient` and
`Endpoints` the repo depends on). For a full feature slice you will touch all
three — read them only as you reach that part of the work.

## Pattern (the why)

- **Two files per concern, side by side.** `i_<name>_repository.dart` (abstract
  contract) and `<name>_repository.dart` (impl) both live in
  `lib/repository/<concern>/`. The contract sits physically next to the impl
  rather than in `domain/` — lower navigation cost. The domain boundary is
  enforced by the *types* (DTO/entity), not by folder location.
- **Interface naming.** Interface is `I`-prefixed (`IExampleRepository`); impl
  drops the `I` (`ExampleRepository`). Use `implements IFoo` for new code
  (`extends IFoo` exists in older HTTP repos; the generator accepts either).
- **Constructor injection only.** Deps are private final fields set by a
  positional constructor — `ExampleRepository(this._client)`. No service-locator
  calls inside the repo body; GetIt resolves deps at the binding site.
- **The repo orchestrates a transport client, not a raw gateway.** The canonical
  dependency is `LoggedClient` (an authed Dio-style client). A method body is
  `await _client.<verb>(Endpoints.x, ...)` then decode the envelope.
- **Envelope decode AT the repo boundary.** Every remote call wraps the raw body
  in `ResponseDTO<T>.fromJson(map, innerDecoder)` and returns `.data` (with a
  `const` fallback on read paths). Paginated lists wrap once more in
  `PageDto<T>`. Centralizing the wire format means one place to change if the
  envelope changes; each repo only supplies the inner `T.fromJson`.
- **The DTO is the return type — the "mapper" lives on it.** Repos return the
  generated Freezed `*Dto` directly. The mapper is the Freezed
  `fromJson`/`toJson` plus an occasional `toEntity()` method on the DTO. This
  trades a duplicated domain model for velocity. Where a real domain entity is
  required, the DTO's `toEntity()` produces it. **Do not generate a separate
  `AbstractMapper`/mapper-class layer — it is vestigial and unused.**
- **Errors flow up, not handled here.** Repos stay thin: exceptions propagate to
  the use case, whose single `try/catch` maps them to `AppError` and returns
  `Either<AppError, T>` via dartz (see `04-usecases.md`). Repos do NOT expose the
  HTTP `Response` or `Dio` types, and do not catch in the common case.
- **`safeMapOf` / `.asSafeMap` guard.** A null-safe cast wraps every
  `response.data` before `fromJson`, so a null/malformed body becomes `{}`
  instead of throwing.

## Folder placement

```
lib/
  repository/
    example/
      i_example_repository.dart     # abstract interface (I-prefixed)
      example_repository.dart       # impl, implements/extends the interface
  model/
    api/
      common/
        response_dto.dart           # generic envelope ResponseDTO<T>
        page_dto.dart               # generic paginated PageDto<T>
      example/
        example_dto.dart            # Freezed DTO: fromJson/toJson + toEntity()
        req/list_examples_req.dart  # request params (toJson / .value)
  domain/
    example/entities/example_entity.dart  # domain entity (target of toEntity())
  di/
    repository/repository_binding.dart    # central GetIt registration
    abstract_binding.dart                 # AbstractBinding base (binding(GetIt))
  service/
    client/logged_client.dart             # authed HTTP client injected into repos
    endpoint/endpoints.dart               # const endpoint path strings
  common/util/safe_map.dart               # safeMapOf / asSafeMap null-safe cast
```

## Templates

Copy from `assets/templates/repository/` and rename the anchors (`Example`,
`Item`, `User`, `Feature`) to the real concern. Do not regenerate from scratch.

| File | What it is |
|---|---|
| [`i_example_repository.dart`](../assets/templates/repository/i_example_repository.dart) | The `I`-prefixed abstract contract. Imports only the DTOs/params it exposes. |
| [`example_repository.dart`](../assets/templates/repository/example_repository.dart) | The impl: injected `LoggedClient`, envelope decode, read + paginated + mutation method shapes. |
| [`example_dto.dart`](../assets/templates/repository/example_dto.dart) | Freezed DTO with `fromJson`/`toJson` and the `toEntity()` mapper inlined on the DTO. |
| [`response_dto.dart`](../assets/templates/repository/response_dto.dart) | Generic `ResponseDTO<T>` envelope (+ `ErrorDTO`). `genericArgumentFactories`. Shared by every repo. |
| [`page_dto.dart`](../assets/templates/repository/page_dto.dart) | Generic `PageDto<T>` paginated envelope. Sits inside `ResponseDTO` for list endpoints. |
| [`safe_map.dart`](../assets/templates/repository/safe_map.dart) | `safeMapOf(...)` + `.asSafeMap` null-safe map cast used before every `fromJson`. |
| [`repository_binding.dart`](../assets/templates/repository/repository_binding.dart) | Central GetIt registration with the load-bearing `//REPOSITORY_BINDING` codegen anchor. |

`response_dto.dart`, `page_dto.dart`, and `safe_map.dart` are shared
infrastructure — copy them ONCE per app, not per concern.

## Step-by-step to apply

1. **Scaffold the folder.** Create `lib/repository/<concern>/` with the
   interface and impl from the two repo templates. Rename `Example` to the
   concern noun throughout (class names, file names, method names).
2. **Define the contract.** In `i_<concern>_repository.dart`, declare each
   method as `Future<ReturnDto> verbNoun(Param p)`. Reads return the DTO (or the
   `ResponseDTO<PageDto<Dto>>` envelope for lists); mutations return
   `Future<void>` / `Future<bool>`. Import only the DTOs and request params.
3. **Write the impl.** `implements IFoo`, inject `LoggedClient` via the
   positional constructor. Each body: call `_client.<verb>(Endpoints.x, ...)`,
   then `ResponseDTO<Dto>.fromJson(safeMapOf(response.data), (json) => Dto.fromJson(safeMapOf(json)))`
   and return `.data ?? const Dto()` on reads. Wrap lists in `PageDto`.
4. **Ensure the DTO exists.** Copy `example_dto.dart`, rename, declare the wire
   fields (all nullable), and add `toEntity()` only if a call site needs the
   domain entity. Keep the `const Dto._();` private constructor — it is required
   for the method to compile.
5. **Ensure the shared envelopes exist.** If the app has no
   `response_dto.dart` / `page_dto.dart` / `safe_map.dart` yet, copy them once
   into `model/api/common/` and `common/util/`. Otherwise reuse them.
6. **Add the endpoint.** Add the path constant to `Endpoints`
   (see `06-gateway-backend.md`). The repo references `Endpoints.<name>`, never
   a string literal.
7. **Codegen.** Run `dart run build_runner build --delete-conflicting-outputs`
   to emit the `.freezed.dart` / `.g.dart` parts for every DTO touched.
8. **Register in DI.** In `repository_binding.dart`, add
   `it.registerSingleton<IFoo>(FooRepository(it()))` immediately ABOVE the
   `//REPOSITORY_BINDING` anchor. Use one `it()` / `it.get()` per constructor
   dependency. Use `registerFactory` only for scoped/short-lived repos. See
   `03-di.md` for the binding lifecycle.

## Gotchas

- **No mapper class.** `AbstractMapper<VALUE, RESULT>` and a `MapperBinding` are
  vestigial in the source app — do not generate them. Real mapping is Freezed
  `fromJson`/`toJson` plus a `toEntity()`/`toDomain()` method on the DTO.
- **Always guard the body.** Wrap `response.data` in `safeMapOf(...)` (and list
  elements in `.asSafeMap`) before `fromJson`; raw bodies may be null. For raw
  lists: `(json as List?)?.map(...).toList() ?? []`.
- **Prefer a fallback over force-unwrap on reads.** `.data ?? const Fallback()`
  avoids runtime nulls. `.data!` is acceptable only when the endpoint is
  contractually guaranteed to return a body.
- **`//REPOSITORY_BINDING` is load-bearing.** It is a codegen insertion anchor —
  new registrations go above it. Never delete, move, or rename it.
- **`extends` vs `implements`.** Older HTTP repos `extends IFoo`; newer
  data-source-backed repos `implements IFoo` with a `const` constructor. Accept
  either; default to `implements` for new code.
- **Don't unwrap `Either` here.** Error mapping and the `Either<AppError, T>`
  boundary belong to the use case (`04-usecases.md`), not the repo. The repo
  returns plain `Future<Dto>` and lets exceptions propagate.
- **Request params are typed, not raw maps.** They live under
  `model/<concern>/req/` and expose `.toJson()` or a `.value`/`.apiValue` (enums)
  used inside the query map — they are not passed as raw `Map` literals.
- **Query params.** Use the Dart 3 null-aware map-entry spread
  `{'k': ?nullableValue}` to omit nulls, or guarded `if (x != null) 'k': x`.
