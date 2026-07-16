---
name: absolute-flutter
description: >-
  Use this skill whenever the user is building or scaffolding a new Flutter or
  Dart mobile app, adding any Flutter feature, screen, page, view model, use
  case, repository, or API/backend call, setting up Flutter push notifications
  or deep links, or mapping/refactoring an existing Flutter project toward a
  layered clean architecture — EVEN WHEN the user never names the architecture,
  rx_notifier, MVVM, clean architecture, get_it, dio, drift, or go_router. It
  applies the moment the work touches Flutter app structure: a request like
  "add a login screen", "fetch data from this endpoint", "create a settings
  feature", "wire up FCM", "open this screen from a notification", or "clean up
  my Flutter project" is in scope. This skill is THE way to produce Flutter code
  in this codebase shape: rx_notifier Controller view models, AbstractUseCase
  with Either<AppError,T> error handling, I*Repository interface/impl pairs, a
  tiered dio gateway, get_it dependency injection, drift TTL cache, and
  go_router navigation. Prefer it over ad-hoc Flutter snippets.
---

# absolute-flutter

Scaffold and extend Flutter apps in one specific, production-grade shape: a
strict **layered clean architecture** with **rx_notifier MVVM**. This skill is a
thin router — it tells you WHICH reference to read for the task at hand so you
load only what you need, then points you at copy-paste Dart templates.

## Architecture overview

The app is a unidirectional, inward-pointing layered stack. UI depends on
domain, domain depends on a repository **interface**, the repository impl
depends on transport (dio) and persistence (drift). Inner layers NEVER import
outer layers; the boundary is always an abstraction (`AbstractUseCase`,
`I*Repository`), never a concrete class or folder.

```
View (StatefulWidget + BaseState)  reads state inside RxBuilder
  └─ Controller (extends BaseController, RxNotifier fields)   ← the ViewModel
       └─ execSingle / execCallback  folds Either<AppError, T>
            └─ UseCase (AbstractUseCase<PARAM, RESULT>)        one verb = one class
                 └─ I*Repository (interface)  ← domain depends on the abstraction
                      └─ *Repository (impl): dio client + drift cache
                           └─ LoggedClient / NonLoggedClient → AbstractGateway → wire
```

The dependency rule, the layer responsibilities, and how every skeleton plugs
together are detailed in `references/01-architecture.md`. Read it first for any
new app or structural change.

**Non-negotiables** (full contract in `references/_conventions.md` — read it
before emitting any Dart):

- Generated package is `app`; imports are ALWAYS `package:app/...`, never relative.
- Errors are a sealed `AppError` (`Default`/`Logout`/`NetworkException`/
  `UnknownException`); results are `Either<AppError, T>` via dartz; the use-case
  `call()` is the single try/catch boundary.
- State management is **rx_notifier**. The ViewModel is a `Controller` extending
  `BaseController`, exposing `RxNotifier` fields, observed by `RxBuilder` in the
  View. (Legacy `flutter_bloc` Cubits exist in some features — treat as a
  one-line aside, not the pattern to reach for.)
- Neutral example nouns only: Example, Item, Auth, User, Profile, Feature, Home,
  Detail, Settings. No brand/domain names. Real hosts become `https://api.example.com`.

## Concern index

Read ONLY the reference that matches the concern in play. Each is self-contained.

| Concern | Reference file |
|---|---|
| architecture | `references/01-architecture.md` |
| dart-conventions | `references/02-dart-conventions.md` |
| model-freezed | `references/13-model-freezed.md` |
| di | `references/03-di.md` |
| usecases | `references/04-usecases.md` |
| repository | `references/05-repository.md` |
| gateway-backend | `references/06-gateway-backend.md` |
| cache-database | `references/07-cache-database.md` |
| mvvm-rxnotifier | `references/08-mvvm-rxnotifier.md` |
| design-system | `references/09-design-system.md` |
| extensions | `references/10-extensions.md` |
| i18n | `references/14-i18n.md` |
| navigation | `references/11-navigation.md` |
| push-deeplink | `references/12-push-deeplink.md` |

## Commands

Each command is granular and reads exactly one primary reference. Use them as
the entry point; they keep the token footprint small.

| Command | What it does | Reads |
|---|---|---|
| `/af-bootstrap` | Scaffold a new Flutter app from zero in this clean-architecture + rx_notifier MVVM shape (folder tree, DI bootstrap, pubspec + codegen config, `main.dart` wiring). | `references/01-architecture.md` |
| `/af-feature` | Generate a complete vertical feature slice: Page/View + Controller(rx_notifier) + State + UseCase + Repository(interface+impl) + Gateway call + DI binding + route. | `references/08-mvvm-rxnotifier.md` |
| `/af-usecase` | Add a single use case (extends `AbstractUseCase`, `Either<AppError,T>`) and wire it into a Controller + DI. | `references/04-usecases.md` |
| `/af-gateway` | Set up or extend the dio gateway/client/interceptor/endpoints backend-call layer. | `references/06-gateway-backend.md` |
| `/af-repository` | Add a repository (interface + impl + DTO mapper + envelope decode) and its DI binding. | `references/05-repository.md` |
| `/af-model` | Add a data model: freezed + json_serializable DTO (req/res), `@JsonValue` enum, sealed/union, custom `JsonConverter`, plain domain entity + `toEntity()` mapper; run build_runner. | `references/13-model-freezed.md` |
| `/af-di` | Wire dependency injection: add or order an `AbstractBinding` (get_it) for a layer or feature. | `references/03-di.md` |
| `/af-navigation` | Add a `go_router` route via the enum route table + per-feature `BaseNavigation` + context push extension. | `references/11-navigation.md` |
| `/af-push-deeplink` | Set up the full push notifications (FCM + local notifications, 3 lifecycle handlers) and deep-link (Branch + deferred-nav) stack. | `references/12-push-deeplink.md` |
| `/af-design-system` | Set up the design system: `ThemeExtension` token palettes accessed via `BuildContext` extensions (`context.colors`/`text`/`icons`), atoms. | `references/09-design-system.md` |
| `/af-i18n` | Add a localized string (edit ARB -> `dart run intl_utils:generate` -> `context.s.key`) or set up i18n from scratch incl MaterialApp wiring. | `references/14-i18n.md` |
| `/af-map-project` | Map the user's EXISTING Flutter project and report which parts of this architecture are present, missing, or refactorable, with a prioritized adoption plan. | `references/01-architecture.md` |

## How to use this skill efficiently

**First read `references/00-token-economy.md`** — it is the operating manual for
working cheaply here. The short version:

1. Pick the ONE reference that matches the concern (use the table above). Do not
   read all twelve.
2. Copy a Dart skeleton from `assets/templates/` and rename the neutral anchors
   (`Feature`, `Example`, `Item`) to the real name. Do not regenerate a file
   from scratch when a template exists.
3. Pull a second reference only when the task genuinely spans concerns (e.g. a
   full feature slice touches mvvm + usecases + repository).
4. Use grep/glob to locate symbols in the user's project rather than reading
   whole files.

## Templates

`assets/templates/` holds compile-shaped, copy-paste Dart skeletons built on the
neutral rename anchors (`class Feature...`, `class ExampleDto`, `package:app/...`).
**Prefer copying and renaming a template over regenerating a file** — it is
cheaper and keeps the output faithful to the architecture.
