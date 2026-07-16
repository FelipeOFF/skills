# 11 — Navigation: go_router with an enum route table

Routing is a **central enum route table** read by **decentralized per-feature
navigation classes**, wrapped in a custom `GoRoute` that turns transitions into
a one-line enum, and called through **typed `context.pushToXxx()` extensions**.
The root router installs a non-blocking `redirect` for deep-link orchestration
and an rx_notifier observer hook that drives navigation when a deferred deep
link becomes ready.

Read `_conventions.md` first; it is the binding contract this doc obeys.

## When to use

Reach for this reference when the task is any of:

- Add a screen and register its route.
- Add a bottom-navigation tab to the shell.
- Add a typed navigation call (`context.pushToFeature(id)`).
- Add or change a page transition.
- Wire deep-link handling, or change the redirect/auth-area logic.

For where this layer sits in the whole app, see `01-architecture.md`. For the
View/Controller that a route resolves, see `08-mvvm-rxnotifier.md` — the route
`builder` constructs a `const Page()`; the page's `BaseState` resolves its own
Controller from DI, so navigation never news-up a ViewModel.

## Pattern (the why)

- **One enum is the route table.** `enum AppRouter` carries each screen's
  `path`, `name`, and metadata flags (`requiresAuthentication`,
  `isBottomNavigation`). Path and name are NEVER raw strings at a call site —
  always `AppRouter.x.path` / `AppRouter.x.name`. This is the single source of
  truth: the unauthenticated allow-list, the bottom-nav tab set, and the
  deep-link target resolver all *derive* from the enum. Flip a flag in one place
  and everything follows. The enum also exposes the built root GoRouter as a
  static `AppRouter.config` so `app_widget.dart` wires one symbol.
- **Routes are decentralized per feature.** Each feature owns one class that
  `extends BaseNavigation` and returns its own `List<RouteBase>`. A single
  aggregator (`AppNavigations`) flattens every feature navigation into one flat
  list. Adding a feature = one navigation class + one line in the aggregator;
  the root router file (`router.dart`) never grows.
- **`AppGoRoute` makes transitions declarative.** A custom `GoRoute` subclass
  takes an `AppRouter` enum (for path + name) and a `Transitions` enum, then
  auto-builds a `CustomTransitionPage` from the route's `builder`. Features
  declare a `builder` + a transition type instead of hand-writing a
  `pageBuilder`. Pass an explicit `pageBuilder` only for special pages (a shell
  tab's `NoTransitionPage`); it wins over the auto-wrap.
- **Typed call sites.** Navigation goes through `context.pushToXxx(...)`
  extensions. Each method centralizes one route's param construction
  (path/query/`extra`), so changing a route signature touches one method, not
  every caller. Call sites read as intent (`context.pushToUserProfile(id)`), not
  stringly-typed `pushNamed`.
- **Redirect is orchestration, not gating.** The global `redirect` returns
  `null` (never a hard destination) and only schedules deferred deep-link
  processing on the next frame. Auth gating is implicit: the only public routes
  are the initial/login screens (`AppRouter.unauthenticatedPaths`, derived from
  `requiresAuthentication`), and the deep-link hook routes through `mainHome` to
  establish authenticated context before pushing a protected target.
- **The deep-link "hook" is an rx_notifier observer.** Deep-link state lives in a
  `DeepLinkController extends BaseController` (a state machine: idle → processing
  → awaitingAuthentication → navigationReady). A root `DeepLinkHook` widget
  observes it with `rxObserver` and drives `router.go` / `router.pushNamed` when
  a pending link becomes ready, with a dedup window so a re-fire does not push
  twice. (Legacy aside: an earlier variant carried this in a Cubit consumed by a
  `BlocListener`; the rx_notifier observer replaces it — do not reach for the
  Cubit form in new code.)

## Folder placement

```
lib/
  navigation/
    app_router.dart                 # enum AppRouter (THE route table) + string ext + static config
    router.dart                     # buildAppRouter(): root GoRouter + redirect + DeepLinkHook
    app_navigations.dart            # AppNavigations: aggregates feature navs -> flat route list
    base_navigation.dart            # abstract BaseNavigation + expandToRoutes ext + NavigationKey
    helper/
      app_go_route.dart             # AppGoRoute extends GoRoute (transition wrapper)
      transitions.dart              # Transitions enum + CustomTransitionPage subclasses + factory
    feature/
      main_navigation.dart          # ShellRoute for the bottom-nav tabs
      <feature>_navigation.dart     # one per feature, extends BaseNavigation
  common/util/
    nav_context_ext.dart            # NavContextExt: context.pushToXxx(...) typed methods
```

The View + Controller that a route builds live under `feature/<name>/`
(`08-mvvm-rxnotifier.md`). The `DeepLinkController` is a feature controller under
`feature/deep_link/`.

## Templates

Copy from `assets/templates/navigation/` and rename the anchors (`Feature`,
`Example`, `Item`, `User`, `Home`, `Settings`) to the real names. Do not
regenerate from scratch.

| File | What it is |
|---|---|
| [`app_router_enum.dart`](../assets/templates/navigation/app_router_enum.dart) | The `enum AppRouter` route table: `path`/`name`/`requiresAuthentication`/`isBottomNavigation`, derived allow-list + bottom-nav getters, the `String.toAppRouter` ext, and the static `config` GoRouter accessor. Save as `navigation/app_router.dart`. |
| [`app_go_route.dart`](../assets/templates/navigation/app_go_route.dart) | `AppGoRoute extends GoRoute`: the transition wrapper that auto-builds a `CustomTransitionPage` from a `builder` + a `Transitions` enum. |
| [`transitions.dart`](../assets/templates/navigation/transitions.dart) | `Transitions` enum + `CustomTransitionPage` subclasses + `TransitionsFactory`. One `case` per transition. |
| [`base_navigation.dart`](../assets/templates/navigation/base_navigation.dart) | `abstract BaseNavigation`, the `expandToRoutes` flatten extension, `NavigationKey` (root + main navigator keys), and an example feature navigation. |
| [`app_navigations.dart`](../assets/templates/navigation/app_navigations.dart) | `AppNavigations`: the single registration point — one line per feature, flattened into the router's route list. |
| [`shell_route.dart`](../assets/templates/navigation/shell_route.dart) | `MainNavigation`: the `ShellRoute` wrapping the bottom-nav tabs, each tab a `NoTransitionPage`. Save under `navigation/feature/main_navigation.dart`. |
| [`router.dart`](../assets/templates/navigation/router.dart) | `buildAppRouter()`: the root `GoRouter`, the non-blocking `redirect`, and the `DeepLinkHook` rx_notifier observer that drives deferred deep links. |
| [`nav_context_ext.dart`](../assets/templates/navigation/nav_context_ext.dart) | `NavContextExt`: typed `context.pushToXxx(...)` methods + `namedLocationWithAppRouter` + `pushReplacementWithAppRouter`. |

`app_router.dart`, `router.dart`, `app_go_route.dart`, `transitions.dart`,
`base_navigation.dart`, and `nav_context_ext.dart` are shared infrastructure —
copy them ONCE per app. The per-feature navigation classes and the
`AppNavigations` line are per-feature.

## Step-by-step to apply

1. **Scaffold the infrastructure once.** Copy `app_router.dart`, `router.dart`,
   `app_go_route.dart`, `transitions.dart`, `base_navigation.dart`, and
   `nav_context_ext.dart` into `lib/navigation/` (+ `common/util/`). Wire
   `app_widget.dart` to `MaterialApp.router(routerConfig: AppRouter.config)`
   (already the case in the app scaffold).
2. **Add the route to the enum.** In `app_router.dart`, add one `AppRouter`
   value: `featureDetail('/feature/:featureId', 'FeatureDetail')`. Use `:param`
   for path params. Flag `isBottomNavigation: true` for a shell tab; flag
   `requiresAuthentication: false` for a public screen (default is `true`).
3. **Write the feature navigation.** Create
   `navigation/feature/<feature>_navigation.dart` extending `BaseNavigation`.
   Return an `AppGoRoute(router: AppRouter.featureDetail, defaultTransition:
   Transitions.slideLeft, builder: (context, state) => FeaturePage(featureId:
   state.pathParameters['featureId'] ?? ''))`. The `builder` returns a `const`
   page that forwards only ROUTE inputs — the page resolves its Controller from
   DI inside `BaseState`.
4. **Register it.** Add one line to `AppNavigations.listOfNavigation` in
   `app_navigations.dart`: `FeatureNavigation()`. Nothing else touches the root
   router.
5. **Add a typed call site.** In `nav_context_ext.dart`, add
   `Future<void> pushToFeature(String featureId) => pushNamed(
   AppRouter.featureDetail.name, pathParameters: {'featureId': featureId});`.
   Call it as `context.pushToFeature(id)`.
6. **Bottom-nav tab?** Add the `mainXxx` enum value (flagged
   `isBottomNavigation: true`), then add an `AppGoRoute(... parentNavigatorKey:
   NavigationKey.mainNavigatorKey, pageBuilder: (c, s) => const
   NoTransitionPage(child: TabPage()))` inside the `ShellRoute.routes` in
   `shell_route.dart`.
7. **Deep link to a new route?** Ensure the route's enum value exists; the
   `DeepLinkController` resolves the incoming URL to an `AppRouter` via
   `String.toAppRouter` and the `DeepLinkHook` routes it (replace for bottom-nav,
   push for detail). Add the route to your native deep-link / app-link config.
8. **New transition?** Add a `Transitions` enum value, a matching
   `CustomTransitionPage` subclass, and one `case` in `TransitionsFactory`. Use
   it via `AppGoRoute(defaultTransition: Transitions.yourValue)`.

## Gotchas

- **`pushNamed` takes `.name`, `go`/`initialLocation` take `.path`.** Mixing
  them throws or silently mis-navigates. The typed extensions use `.name`; the
  redirect/startsWith checks and the bottom-nav deep-link branch use `.path`.
- **go_router 14 API.** There is no `state.location`. Read the current path via
  `state.uri.path`, query via `state.uri.queryParameters`, path params via
  `state.pathParameters`, and the live router state via `router.state.uri`. The
  templates already use this; do not regress to `state.location`.
- **Path params are mandatory.** A `:param` route throws unless every param is in
  `pathParameters`. The typed extensions centralize this — always navigate
  through them, not raw `pushNamed`.
- **Query params are always `String?`.** Coerce inside the builder (`int.tryParse`,
  `== 'true'`); a missing key is `null`, not an absent-throwing read.
- **`extra` does NOT survive a cold-start deep link.** Only path/query params
  survive a real URL. Pass a preloaded DTO via `extra` for in-app pushes (instant
  render, no refetch), but the screen must still be able to fetch from the path
  param alone, because a deep link arrives with no `extra`. The `DeepLinkHook`
  reconstructs `extra` from its own `deepLinkData`.
- **Redirect must stay cheap and side-effect-free** except the post-frame
  schedule — it runs on EVERY navigation. It returns `null`; it never gates.
  Hard gating is implicit via the public-route allow-list + the "establish auth
  context first" branch.
- **Dedup the deep-link hook.** Without the 2s key/window guard, a re-fire of the
  same status pushes the same route twice. After a `Future.delayed` re-entry,
  guard `mounted` before touching the router.
- **Bottom-nav deep links `go` (replace); detail deep links `pushNamed` (stack).**
  Mixing them breaks back behaviour — a replaced tab has no parent to pop to, and
  a pushed tab strands the shell.
- **Shell routes need `parentNavigatorKey: NavigationKey.mainNavigatorKey`.**
  That pins the tab stack under the shell's navigator; detail routes omit it and
  push on the root navigator ABOVE the shell. Getting this wrong makes detail
  pages render inside the bottom bar (or tabs render full-screen).
- **`NavigationKey` keys are statics — never re-create them.** They are
  `GlobalKey`s; constructing a second one detaches the navigator state.
- **One canonical enum file name.** Save the enum template as
  `navigation/app_router.dart` (matching `app_widget.dart`'s
  `package:app/navigation/app_router.dart`). Keep every import on that single
  path; do not introduce an `app_routers.dart` alias.
