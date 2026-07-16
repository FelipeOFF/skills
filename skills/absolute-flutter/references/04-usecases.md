# 04 — Use cases: AbstractUseCase + the Either/AppError funnel

The domain layer. A use case is one unit of business logic — call a repository,
maybe compose other use cases, return a typed result. Everything here funnels
through ONE error boundary so the UI never sees a raw exception.

This reference is the use-case side of the seam. The Controller side of the
ladder (`execSingle` / `execCallback`, loading toggle, error routing,
auto-logout) lives in the rx_notifier `BaseController` mixin — see
`08-mvvm-rxnotifier.md`. Read this one to write the use case; read that one to
invoke it.

## When to use

Reach for a use case whenever a Controller needs to *do something* that isn't
pure UI state: load data, submit a form, run a multi-step flow, observe a
stream. The Controller must NOT call a repository directly and must NOT touch
Dio — it goes Controller → use case → repository. One use case = one action =
one file.

- **Single value out** → `AbstractUseCase<PARAM, RESULT>` (a `Future`).
- **A live/observable source** (query stream, socket, reactive cache) →
  `AbstractStreamUseCase<PARAM, RESULT>`.
- **Pure UI state** (a toggle, a text field) → no use case; it's a `RxNotifier`
  field on the Controller (`08-mvvm-rxnotifier.md`).

## Pattern (the why)

**One abstract base owns the error boundary.** `AbstractUseCase<PARAM, RESULT>`
defines the contract; a subclass overrides ONLY `execute(PARAM)` with pure
happy-path logic that returns a `RESULT` or throws freely. The base's `call()`
is the **single** try/catch in the whole domain layer: it runs `execute`, wraps
success in `Right`, and converts any throwable into a typed `AppError` on the
`Left`. No subclass ever writes a try/catch or imports dartz. Error policy lives
in exactly one place.

**Results cross the boundary as `Either<AppError, T>` (dartz).** `Left` carries
the sealed `AppError`; `Right` carries the success value. The Controller folds
that `Either` through the ladder — it never unwraps it by hand.

**`AppError` is a domain type, not Dio's.** A single extension,
`DioException.asAppError()`, is the ONLY Dio→domain translation point. It
classifies: offline → `NetworkException`, 401 → `Logout`, parseable body →
`Default`, else → `UnknownException`. Because `Logout` is a first-class variant,
the Controller ladder can centrally trigger logout + navigation on any 401 from
any screen — no per-screen status-code checks.

**Callable convention.** `useCase(param)` invokes `.call()` and yields the
`Either`. Subclasses also expose the raw `execute()` so one use case can compose
another's `execute` and stay inside the same error frame (a throw propagates up
to the outermost `call()`), or call `.call()` when it wants the inner `Either`
to fold.

**Optional cache hook.** The base's `cache(params)` returns `null` by default,
so caching is opt-in per use case without touching `call()` or subclasses that
don't need it. `forceRefresh` plumbs through `call`. See `07-cache-database.md`
for the concrete decorator.

## Folder placement

```
lib/
  domain/
    abstract_use_case.dart            # AbstractUseCase<PARAM,RESULT>
    abstract_stream_use_case.dart     # AbstractStreamUseCase<PARAM,RESULT>
    app_error.dart                    # sealed AppError variants
    dio_error_mapper.dart             # DioException.asAppError() extension
    example/                          # one folder per feature/aggregate
      example_use_case.dart           # one use case = one file
      example_orchestrating_use_case.dart
      dto/example_dto.dart
  repository/
    example/ i_example_repository.dart  # the repo INTERFACE the use case depends on
  common/
    util/ either_helpers.dart           # unwrapRight / unwrapLeft
  di/
    domain/ domain_binding.dart         # registers every use case in get_it
```

- File names: `snake_case`. Pick ONE suffix convention (`_use_case.dart`) and
  stick to it.
- Class names: `PascalCase` + `UseCase` suffix. The params class lives in the
  SAME file, below the use case (`FeatureExampleParams`).
- Imports are always `package:app/...` — never relative, even within a feature
  folder.

## Templates

Copy a template, then rename the anchors (`Feature`, `Example`, `Item`) to the
real names. Do not regenerate from scratch.

| File | What it is |
|---|---|
| [assets/templates/usecase/abstract_use_case.dart](../assets/templates/usecase/abstract_use_case.dart) | `AbstractUseCase<PARAM,RESULT>`: `call()` try/catch funnel + optional `cache()` hook + `execute()` contract. The base every use case extends. |
| [assets/templates/usecase/abstract_stream_use_case.dart](../assets/templates/usecase/abstract_stream_use_case.dart) | Stream twin: `execute` yields `Stream<RESULT>`, `call` re-emits as `Right` and maps errors to `Left`. |
| [assets/templates/usecase/app_error.dart](../assets/templates/usecase/app_error.dart) | Sealed `AppError` with `Default`, `Logout`, `NetworkException`, `UnknownException`. The `Left` type. |
| [assets/templates/usecase/dio_error_mapper.dart](../assets/templates/usecase/dio_error_mapper.dart) | `DioException.asAppError()`: the single transport→domain mapping (offline/401/body/unknown). |
| [assets/templates/usecase/either_helpers.dart](../assets/templates/usecase/either_helpers.dart) | `unwrapRight` / `unwrapLeft` extension getters over `Either`. |
| [assets/templates/usecase/example_use_case.dart](../assets/templates/usecase/example_use_case.dart) | Concrete use case with a colocated `...Params` object + repository call. |
| [assets/templates/usecase/example_orchestrating_use_case.dart](../assets/templates/usecase/example_orchestrating_use_case.dart) | Orchestrating use case: repo + composes other use cases via `execute()` (raw) and `call()` (Either). |

The Controller-side ladder that *invokes* these (`execSingle` / `execCallback`)
is emitted with the rx_notifier `BaseController` mixin — see
`08-mvvm-rxnotifier.md`, not here.

## Step-by-step to apply

1. **Once per project**, scaffold the base layer: copy `abstract_use_case.dart`,
   `abstract_stream_use_case.dart`, `app_error.dart`, `dio_error_mapper.dart`,
   and `either_helpers.dart` into `lib/domain/` (and `either_helpers.dart` into
   `lib/common/util/`). Wire `dio_error_mapper.dart` to your real
   connectivity check and error-body shape.
2. **Pick the PARAM type.** No input → `void` (`execute(void param)`); a single
   value → that type directly (`String`, a DTO); multiple values → a dedicated
   `<Name>Params` class colocated below the use case.
3. **Copy a concrete template.** Repository pass-through or params object →
   `example_use_case.dart`. Composes other use cases → `example_orchestrating_use_case.dart`.
   Rename `Feature`/`Example` to the real names.
4. **Depend on the repository INTERFACE** (`IExampleRepository`), injected as a
   `final` private field. `const` constructor when there's no logic. The use
   case never imports a repository *impl* or Dio. (Repository side:
   `05-repository.md`.)
5. **Write only `execute`.** Pure happy path: call the repo, compose sub-use-cases,
   return the `RESULT` or throw. No try/catch, no dartz, no `Either`.
6. **Register it in `domain_binding.dart`** — one line, `it()` auto-resolves
   each dependency: `it.registerSingleton(FeatureExampleUseCase(it()));`. Use
   `registerSingleton` (use cases are stateless). DI details: `03-di.md`.
7. **Invoke it from the Controller** via `execSingle(param, useCase)` from the
   `BaseController` mixin — never call `.call()` and fold the `Either` by hand
   in the Controller. See `08-mvvm-rxnotifier.md`.

## Gotchas

- **`execute(void param)` still needs an argument.** When there's no input the
  param is still required by the signature; callers pass `null` (or `unit` /
  `none()` if you typed it as dartz `Unit`). If you use the cache hook, make the
  key logic special-case the no-input case so the cache key isn't garbage.
- **`call()` swallows ALL throwables into `Left`.** A non-Dio throw from
  `execute` becomes an opaque `UnknownException`. Log inside `execute` for
  anything you need to diagnose, or model the failure as a typed `AppError`.
- **`unwrapRight` returns `R?`.** A legitimately-null success is
  indistinguishable from "was a Left" if you read it without checking
  `isLeft()` first. The ladder checks `isLeft()` before unwrapping — preserve
  that order if you ever read an `Either` by hand.
- **Compose with `execute()` vs `call()` deliberately.** `execute()` stays raw
  (inner throw propagates to the outer `call()`); `.call()` returns the inner
  `Either` so you can fold and tolerate a sub-failure. Pick based on whether the
  inner failure should fail the whole flow.
- **`Logout` reaches back into DI.** The Controller ladder resolves the logout
  use case via the service locator when it sees a `Logout` error. Acceptable for
  this one cross-cutting concern — don't generalize use-cases-reaching-into-DI.
- **`dio_error_mapper.dart` is the ONLY place that touches `DioException`.** If
  you find a status-code check or `e.response` read anywhere else, it's a leak —
  move it into `asAppError()`.
