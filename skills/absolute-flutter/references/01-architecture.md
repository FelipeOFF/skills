# 01 — Architecture: layered clean architecture + the dependency rule

The spine reference. It defines the layers, the one rule that holds them
together, where every file goes, and which OTHER reference owns each layer's
detail. `/af-bootstrap` and `/af-map-project` lean on this doc. Read it first
for any new app or any structural change. Read `references/_conventions.md`
(the binding contract) before emitting Dart.

## When to use

Read this reference when you are:

- scaffolding a **new app** from zero (`/af-bootstrap`) — you need the folder
  tree, the DI bootstrap order, and the `main.dart` / `app_widget.dart` wiring;
- **mapping or auditing an existing** Flutter project (`/af-map-project`) —
  you need the canonical layer set to diff the project against;
- making a **structural change** that crosses layers (adding a layer, moving a
  responsibility, deciding where a new file belongs);
- unsure **which concern reference** owns a piece of work — the table in
  *Folder placement* routes you to the right one.

Do NOT read this for single-layer work. One use case → `04-usecases.md`. One
route → `11-navigation.md`. One DTO mapper → `05-repository.md`. This doc is the
map, not the territory; load a leaf reference for leaf work.

## Pattern (the why)

A strict layered clean architecture with **one unidirectional dependency
rule**:

> Every layer may depend only on layers *inner* to it, and only through an
> **abstraction** (`AbstractUseCase`, `IExampleRepository`) — never a concrete
> class from an outer layer. Inner layers never import outer layers.

```
View (StatefulWidget + BaseState)  reads state inside RxBuilder
  └─ Controller (extends BaseController, RxNotifier fields)   ← the ViewModel
       └─ execSingle / execCallback   folds Either<AppError, T>, toggles loading
            └─ UseCase (AbstractUseCase<PARAM, RESULT>)       one verb = one class
                 └─ IExampleRepository (interface)  ← domain depends on the abstraction
                      └─ ExampleRepository (impl): dio client + drift cache
                           └─ LoggedClient / NonLoggedClient → AbstractGateway → Dio
```

`model/` (DTOs) and `di/` (get_it wiring) are cross-cutting — referenced from
any layer, owned by no single one.

**Why this exact shape:**

- **Testability by construction.** Each layer talks to an abstraction, so each
  is mockable in isolation. A Controller test mocks the use case; a use-case
  test mocks `IExampleRepository`; a repository test mocks the client. No layer
  needs a real network or DB to test.
- **Error funneling to one place.** The use case's `call()` is the *single*
  try/catch boundary: transport and unknown exceptions become a typed
  `Either<AppError, T>` there and nowhere else. The UI never sees a raw
  `DioException`. (Model + mapping: see `references/04-usecases.md`.)
- **One use case = one intent.** Fine-grained verb classes
  (`GetExampleUseCase`, `SaveTokenUseCase`) compose; a Controller injects
  several. Small surfaces are easy to name, test, and reuse.
- **Transport split by auth state, not by config.** `LoggedClient` (token +
  refresh) vs `NonLoggedClient` (anon), both extending one `AbstractGateway`.
  A repository picks transport by *type*, so auth-ness is a compile-time fact.
- **Wiring is data.** DI is a `List<AbstractBinding>` iterated in dependency
  order. Adding a layer/feature = appending a binding, not threading
  constructors through `main`.

The **inversion** is the load-bearing idea: `domain/` imports
`IExampleRepository` (an interface that *lives in* `repository/`), and DI binds
the concrete `ExampleRepository` to that interface at startup. So the arrow of
*dependency* points inward even though the arrow of *control* (a real call)
flows outward. That is what lets you swap transport or persistence without
touching the domain.

## Folder placement

`lib/` is organized **by layer, not by feature** — except `feature/` and `di/`,
which shard internally per feature. The full annotated tree is the template
`assets/templates/app_scaffold/tree.md` (copy it; do not retype it). Summary,
with the reference that owns each layer's detail:

| Layer (folder) | Holds | Owned by reference |
|---|---|---|
| `feature/<name>/` | View (Page), Controller (rx_notifier), per-feature binding + navigation | `references/08-mvvm-rxnotifier.md` |
| `domain/` | `AbstractUseCase`, concrete use cases, sealed `AppError` | `references/04-usecases.md` |
| `repository/` | `IExampleRepository` + `ExampleRepository` impl, DTO↔envelope mapping | `references/05-repository.md` |
| `service/` + `gateway/` | typed Dio clients, `AbstractGateway`, interceptors, endpoints | `references/06-gateway-backend.md` |
| `cache/` + `database/` | `FuCache` read-through cache, drift persistence | `references/07-cache-database.md` |
| `model/` | freezed/json DTOs, `ResponseDTO<T>` envelope | `references/05-repository.md` |
| `di/` | `AbstractBinding` per layer, `AppDI` orchestrator | `references/03-di.md` |
| `design_system/` | `ThemeExtension` palettes, `context.colors`/`text`/`icons` | `references/09-design-system.md` |
| `navigation/` | `AppRouter` route enum, go_router config, `BaseNavigation` | `references/11-navigation.md` |
| `common/` | base mixins, utils, per-type extensions, messages | `references/10-extensions.md` |
| (push/FCM + deep links) | push facade, lifecycle handlers, deferred nav | `references/12-push-deeplink.md` |
| (cross-cutting Dart style) | imports, naming, `const`, return types, quotes | `references/02-dart-conventions.md` |

Rule of thumb: **a new file goes in the folder of its layer, named for its
intent.** A "get the user profile" verb is `domain/profile/get_profile_use_case.dart`,
never inside `feature/`. The View only ever calls a Controller; the Controller
only ever calls use cases.

## Templates

The scaffold emits three assets under
`assets/templates/app_scaffold/`. Copy and rename the anchors
(`Feature`, `Example`, `Item`, `App*`) — do not regenerate from prose.

| File | What it is |
|---|---|
| `assets/templates/app_scaffold/tree.md` | The annotated `lib/` folder tree + the inward dependency rule. Source of truth for where files go. |
| `assets/templates/app_scaffold/main.dart` | Entry point. `WidgetsFlutterBinding.ensureInitialized()` → `AppDI.setupDI()` → pre-run setup → `runApp(const AppWidget())`. DI is bootstrapped BEFORE any widget builds. |
| `assets/templates/app_scaffold/app_widget.dart` | Root widget: `MaterialApp.router` with `routerConfig: AppRouter.config` (go_router) and the `ThemeExtension` token palettes (`AppColors` / `AppText`) attached via `theme.extensions`. |

`main.dart` references `AppDI` (owned by `references/03-di.md`).
`app_widget.dart` references `AppRouter` (owned by `references/11-navigation.md`)
and `AppColors`/`AppText` (owned by `references/09-design-system.md`). Generate
those alongside the scaffold so the imports resolve.

## Step-by-step to apply

For `/af-bootstrap` (new app):

1. **Create the tree.** Lay down `lib/` per
   `assets/templates/app_scaffold/tree.md`. Empty folders are fine; the rule is
   the placement, not the file count.
2. **Drop `main.dart` and `app_widget.dart`** from the templates. Keep
   `main.dart` tiny — bootstrap only. Rename the `App*` anchors if your app
   prefixes differ.
3. **Stand up the inner ring first.** The DI bootstrap order in `main.dart`
   (`AppDI.setupDI()`) is the dependency graph: environment → database →
   gateway → service → repository → domain → features. Build the bindings in
   that order so each can `it()`-resolve only what is already registered. See
   `references/03-di.md` for `AbstractBinding` + `AppDI`.
4. **Add the error model + use-case base.** `domain/app_error.dart` (sealed
   `AppError`) and `domain/abstract_use_case.dart` (the `Either` funnel) — both
   from `references/04-usecases.md`. Nothing above the domain compiles cleanly
   without these.
5. **Wire transport.** `AbstractGateway` + `LoggedClient`/`NonLoggedClient` +
   `DioException.asAppError()` from `references/06-gateway-backend.md`.
6. **Add the design system + router** so `app_widget.dart` resolves:
   `AppColors`/`AppText` (`references/09-design-system.md`) and `AppRouter`
   (`references/11-navigation.md`).
7. **Add the first feature slice** (View + Controller + State + UseCase +
   Repository + binding + route) per `references/08-mvvm-rxnotifier.md`. That
   reference walks the full vertical and pulls in `04` and `05` as needed.

For `/af-map-project` (existing app): read the tree above and *grep*, do not
write. For each layer, locate its marker symbol (`AbstractUseCase`,
`I*Repository`, `AbstractGateway`, `AbstractBinding`, `BaseController`) and
report present / missing / refactorable, then a prioritized adoption plan
ordered inside-out (error model + use-case base first, UI last).

## Gotchas

- **Inner layers never import outer ones.** A use case importing anything from
  `feature/`, or a repository importing a Controller, breaks the rule and the
  testability it buys. If you feel the urge, the dependency belongs on an
  interface the inner layer owns.
- **Depend on the interface, not the impl.** `domain/` imports
  `IExampleRepository`; DI binds `ExampleRepository` to it. Importing the
  concrete repository from the domain defeats the inversion — and the mock.
- **DI bootstrap precedes the first frame.** `await AppDI.setupDI()` must
  finish before `runApp`. A widget's first build can resolve a Controller, which
  resolves use cases and repositories — if the container is half-populated, that
  throws at frame one. Keep DI ahead of `runApp` in `main.dart`.
- **Binding order *is* the dependency graph.** A binding may `it()`-resolve only
  things registered earlier in `AppDI`'s list (env → db → gateway → service →
  repo → domain → features). Reorder and resolution fails at startup. Detail in
  `references/03-di.md`.
- **Controllers are factories, everything else is a singleton.** Repositories,
  use cases, clients = `registerSingleton`. Controllers = `registerFactory`
  (fresh per screen) or stale reactive state leaks across navigations.
- **All imports are `package:app/...`.** Relative lib imports (`../`) are
  lint-banned (`always_use_package_imports`, `avoid_relative_lib_imports`), even
  within one feature folder. See `references/02-dart-conventions.md`.
- **`app_widget.dart` holds no logic.** It builds theme + router and stops.
  Business logic lives in feature Controllers; routing lives in `navigation/`;
  tokens live in `design_system/`. Keep the root widget declarative.
- **A legacy `flutter_bloc`/Cubit path may exist** in older features. It is a
  one-line aside, not the pattern. New work uses an rx_notifier `Controller`
  extending `BaseController` (`references/08-mvvm-rxnotifier.md`); do not extend
  the Cubit path.
</content>
