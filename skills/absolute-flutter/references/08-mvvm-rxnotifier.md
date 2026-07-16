# 08 — MVVM with rx_notifier: Controller + RxNotifier + RxBuilder

The presentation layer, and the canonical state-management stack for this skill.
The ViewModel is a **`Controller`** (extends `BaseController`) that exposes UI
state as **`RxNotifier`** fields; the View is a `StatefulWidget` whose `State`
extends **`BaseState`** and reads that state inside **`RxBuilder`**. The
Controller runs use cases through the **`execSingle` / `execCallback`** ladder on
`BaseController`, which toggles loading, folds `Either<AppError, T>`, routes
errors, and force-logs-out on a 401.

This is the View/Controller side of the seam. The use case it invokes (the
`AbstractUseCase` + `Either`/`AppError` funnel) is `04-usecases.md`; the DI that
registers the Controller is `03-di.md`. Obey `references/_conventions.md`
(package imports, neutral nouns) throughout.

(Legacy aside: a few old features use `flutter_bloc` Cubits — not the pattern
for new code. Build the ViewModel as an rx_notifier `Controller`.)

## When to use

Reach for this reference whenever you build or touch a screen's presentation:

- add a **feature page** (View + Controller + State + binding);
- hold **mutable UI state** that the View should rebuild on (a list, a flag, a
  selection, a derived/computed value);
- **invoke a use case** from a Controller and want uniform loading + error +
  logout handling;
- wire the **per-feature DI binding** that registers the Controller;
- debug a widget that **won't rebuild** on state change, a "used after dispose"
  crash, or a missing global error dialog / logout redirect.

Pure domain logic (loading, submitting, composing) is NOT here — that's a use
case (`04-usecases.md`). This reference is about how the Controller *holds
reactive state* and *invokes* that logic, and how the View *observes* it.

## Pattern (the why)

**The ViewModel is a `Controller`, state lives inline on it.** Unlike BLoC there
is no separate immutable `State` data class. Each piece of mutable UI state is
its own `RxNotifier<T>`, so rebuilds are field-granular and you never copy a
whole state object to change one field. Trade-off: many notifiers per
Controller, and you must dispose each one.

**The rx_field idiom: private notifier + public getter/setter.** The repeated
shape is a `final RxNotifier<T> _x` with a `T get x` and a `set x`. WHY: the
notifier stays encapsulated — the View can never `.dispose()` it or swap it —
while the public API is plain Dart (`controller.x`, `controller.x = v`). Nullable
state seeds `RxNotifier<T?>(null)`. Non-reactive scratch state (a fetch guard, a
seen-id set) stays a plain field so it doesn't trigger rebuilds. The rename
anchors live in `assets/templates/mvvm/example_controller.dart`.

**`RxBuilder` = automatic dependency tracking.** The View reads Controller
getters **inside** `RxBuilder(builder: ...)`. Whatever notifier-backed getter the
builder touches is tracked transparently (MobX-style); when it changes, only that
builder re-runs. There is no `select`, no subscription list, no event/state
boilerplate. Derived getters (`bool get canLoadMore => !hasReachedEnd && ...`)
react to *all* the notifiers they read. Scope rebuilds tightly: a page has many
small `RxBuilder`s, not one big one. A read **outside** an `RxBuilder` is a
one-shot read and will not rebuild — this is the #1 bug.

**`BaseController` owns the execution ladder.** A Controller never unwraps an
`Either` by hand and never writes a try/catch for a use case. It calls:

- **`execSingle(param, useCase)`** — run one use case, toggle `isLoading`, fold
  its `Either<AppError, R>`, return `R?` (value on success, `null` when the error
  was already routed into `message`). Pass `showLoading: false` to drive a
  feature-local loading flag (pagination/refresh) instead of the global spinner;
  pass `mapError` to customize or suppress the surfaced message per call;
  `forceRefresh` plumbs to the use case's cache hook.
- **`execCallback(param, useCase, onSuccess: ...)`** — same ladder, but hands the
  success value to a callback (navigate, toast) instead of returning it.

Both route a `Left` through one point: a `Logout` error runs the logout use case
(resolved via the service locator) and flips `goToInitialPage`; any other
`AppError` becomes a `message`. WHY a base mixin and not a Cubit carrier: every
Controller inherits identical loading/error/logout behavior with zero
boilerplate, and the policy lives in exactly one file.

**`BaseState` owns DI, lifecycle, and global reactive side effects.** The View's
`State` extends `BaseState<ThePage, TheController>`, which: (1) pulls the
Controller from `get_it` in a field initializer so the View never news-up its VM;
(2) calls `controller.onInit()` in `initState` — this allocates the base
notifiers BEFORE any reactive read — and `controller.dispose()` in `dispose`,
guarded by `disposeController`; (3) registers two **`rxObserver`s** — the
imperative twin of `RxBuilder` that runs now and on every change, returning an
`RxDisposer` you must call. One observer renders the global `message`
(error/dialog surface); the other reacts to `goToInitialPage` (force-logout
redirect). Because these are centralized, no feature re-implements the error
dialog or the 401 redirect.

**DI lifecycle = factory + per-View dispose.** The feature binding
`registerFactory(() => Controller(it()))` so each page push gets a *fresh*
Controller with fresh `RxNotifier` state; `BaseState` owns disposal. Override
`disposeController => false` to borrow a shared/long-lived Controller without
killing it. (DI details: `03-di.md`.)

## Folder placement

Per feature under `lib/feature/<feature>/`:

```
feature/<feature>/
  page/        <feature>_page.dart        # View: StatefulWidget + _State extends BaseState
  controller/  <feature>_controller.dart  # ViewModel: extends BaseController, RxNotifier fields
  di/          <feature>_binding.dart      # extends AbstractBinding, registerFactory the Controller
  navigation/  <feature>_navigation.dart   # go_router routes (see 11-navigation.md)
  component/                              # leaf widgets, often themselves RxBuilder-wrapped
  model/                                  # optional feature-local DTO/result types
```

Shared base infra lives outside features:

```
lib/common/base/base_controller.dart     # the ViewModel base + execution ladder
lib/common/base/base_state.dart          # the View State base (DI + lifecycle + observers)
lib/di/abstract_binding.dart             # AbstractBinding contract (03-di.md)
lib/di/app_di.dart                        # AppDI.it -> get_it (03-di.md)
```

Conventions: one Controller per page. A complex page splits state across
**multiple Controllers** (e.g. `<feature>_controller.dart` +
`<feature>_tab_controller.dart`, each registered in the same binding and each
disposed by its own `BaseState`) or via **mixins** under
`controller/<feature>_controller_mixins/`. File names `snake_case`; classes
`PascalCase` with the `Controller` / `Page` / `Binding` suffix.

## Templates

Copy a template, then rename the anchors (`Example`, `Item`, `Feature`) to the
real names. Do not regenerate from prose. The two `base_*` files are scaffolded
**once per project**; the `example_*` files are copied **per feature**.

| File | What it is |
|---|---|
| [assets/templates/mvvm/base_controller.dart](../assets/templates/mvvm/base_controller.dart) | The ViewModel base. The `isLoading` / `message` / `goToInitialPage` reactive channels, `onInit` allocation, and the `execSingle` / `execCallback` ladder that folds `Either<AppError, T>`, toggles loading, routes errors, and force-logs-out on `Logout`. Scaffold once. |
| [assets/templates/mvvm/base_state.dart](../assets/templates/mvvm/base_state.dart) | The View State base. Pulls the Controller from DI, runs `onInit`/`dispose`, and wires the two global `rxObserver`s (error message + logout redirect). Scaffold once. |
| [assets/templates/mvvm/example_controller.dart](../assets/templates/mvvm/example_controller.dart) | A feature Controller showing the **rx_field idiom** (private notifier + getter/setter), nullable state, non-reactive scratch fields, a derived getter, `execSingle` with manual loading for pagination, and full `dispose`. |
| [assets/templates/mvvm/example_page.dart](../assets/templates/mvvm/example_page.dart) | The View: `StatefulWidget` + `_State extends BaseState`, reads state inside `RxBuilder`, direct mutation, and disposing only View-local controllers. |
| [assets/templates/mvvm/example_binding.dart](../assets/templates/mvvm/example_binding.dart) | The per-feature DI binding: `registerFactory` the Controller with bare `it()` deps. |

## Step-by-step to apply

**Once per project** — scaffold the base layer:

1. Copy `base_controller.dart` and `base_state.dart` into `lib/common/base/`.
   Wire `base_controller.dart` to your real `LogoutUseCase` and `GenericMessage`
   types; wire `base_state.dart` to your `AppRouter.initial` route and the
   message's `show(context)` surface.

**Per feature** — add a page:

1. **Copy `example_controller.dart`** to
   `lib/feature/<feature>/controller/<feature>_controller.dart`. Rename `Example`
   to `<Feature>`. Delete the demo fields and add your own with the rx_field
   idiom: `final RxNotifier<T> _x = RxNotifier(seed); T get x => _x.value; set x(T v) => _x.value = v;`.
   Use a plain field for non-reactive scratch state; a getter for derived state.
2. **Inject use cases** as `final` private fields via the constructor. The
   Controller never calls a repository or Dio directly — it goes through a use
   case (`04-usecases.md`).
3. **Run logic via the ladder.** `final r = await execSingle(param, _useCase);
   if (isDisposed || r == null) return; x = r;`. Use `showLoading: false` plus a
   feature-local flag for pagination/refresh; use `execCallback` when the result
   feeds a side effect rather than state.
4. **Override `dispose`**: dispose every `RxNotifier` this Controller owns, then
   `await super.dispose();` (which disposes the base notifiers).
5. **Copy `example_page.dart`** to
   `lib/feature/<feature>/page/<feature>_page.dart`. Rename, make `_State extends
   BaseState<<Feature>Page, <Feature>Controller>`, trigger the initial load in
   `initState` after `super.initState()`, and read state **inside `RxBuilder`** —
   one narrow builder per independently-changing subtree.
6. **Copy `example_binding.dart`** to
   `lib/feature/<feature>/di/<feature>_binding.dart`. `registerFactory(() =>
   <Feature>Controller(it()))`. Then **append `const <Feature>Binding()` to the
   features list in `app_di.dart`** — the binding does nothing until it is in the
   list (`03-di.md`).
7. **Add the route** (`11-navigation.md`) and push the page.

## Gotchas

- **State read outside an `RxBuilder` is a one-time read** — the widget will NOT
  rebuild on change. Forgetting to wrap is the #1 bug. Wrap the *smallest*
  subtree that depends on the state.
- **Every `RxNotifier` you create must be `.dispose()`d.** A Controller overrides
  `dispose()` to dispose each field, then `await super.dispose()` for the base
  notifiers. View-local `RxNotifier`s held in the `State` are disposed by the
  `State`. Missing this leaks and causes late-write crashes.
- **Do NOT dispose the Controller in the View.** `BaseState.dispose()` already
  calls `controller.dispose()` (guarded by `disposeController`). The page disposes
  only its own `TextEditingController` / `ScrollController` / `AnimationController`
  / View-local `RxNotifier`s.
- **`onInit` must run before any reactive read.** The base notifiers (`_message`,
  `_isLoading`, `_goToInitialPage`) are allocated in `onInit`, which
  `BaseState.initState` calls. Bypass `BaseState` and the base getters return
  `null`. Override `onInit` for feature seeding, but call `super.onInit()` first.
- **Async-after-dispose.** A long request can complete after the page is gone.
  Always `if (isDisposed) return;` before writing state, and return `null` from
  `mapError` when disposed to suppress a stale error dialog. The base `set`ters
  for `isLoading` / `message` are already no-ops once disposed.
- **Post-mutation navigation needs `addPostFrameCallback`.** Popping/pushing
  synchronously inside a builder or right after a state write during build throws.
  Defer to the next frame:
  `WidgetsBinding.instance.addPostFrameCallback((_) { if (controller.done) context.pop(); });`.
- **`registerFactory` for Controllers, not singleton.** Each screen needs a fresh
  Controller with fresh `RxNotifier` state. Promote to `registerLazySingleton`
  (and set `disposeController => false` on the borrowing State) only for a
  genuinely app-global Controller.
- **Multiple Controllers per complex page is intentional.** Tabs/sub-flows each
  get their own Controller, registered together in the feature binding and
  disposed by their respective `BaseState`s (or the parent).
- **Don't unwrap `Either` in the Controller.** Always go through `execSingle` /
  `execCallback`. A bare `.call()` + manual `fold` bypasses the loading toggle,
  the error routing, and the `Logout` redirect.
