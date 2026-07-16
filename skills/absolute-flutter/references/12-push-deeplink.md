# 12 — Push notifications + deep linking (end-to-end)

Two cooperating flows that span Dart, a background isolate, and native iOS:

- **Push** — `firebase_messaging` + `flutter_local_notifications`. Firebase
  delivers a DATA-ONLY message; the app renders the visible notification itself.
  Foreground / background / terminated handlers, FCM token refresh →
  use case → repository, and an iOS Notification Service Extension for rich media.
- **Deep link** — a link vendor (Branch) behind an abstract `DeepLinkService`,
  feeding a deferred-navigation state machine that holds a link until the user is
  authenticated, then drives `go_router`.

Read `references/_conventions.md` (the binding contract) before emitting any
Dart. For the route enum these flows target, see `11-navigation.md`; for the
token use case / repository, see `04-usecases.md` and `05-repository.md`; for the
local store the push payload and pending link persist to, see
`07-cache-database.md`.

## Table of contents

- [When to use](#when-to-use)
- [Pattern (the why)](#pattern-the-why)
- [Folder placement](#folder-placement)
- [Templates](#templates)
- [Step-by-step to apply](#step-by-step-to-apply)
- [Gotchas](#gotchas)

## When to use

- Standing up push notifications in a new app (FCM + local notifications +
  the background isolate + the iOS extension).
- Adding rich media (large icon / image attachment), a tap-to-navigate flow, or
  a retroactive tap-event queue.
- Registering / refreshing the FCM token to the backend.
- Adding inbound deep links (shared links that open a specific screen), or
  outbound short-URL sharing.
- Making a tapped link SURVIVE login — fire after the user authenticates.

Do NOT use this reference for ordinary in-app navigation — that is
`11-navigation.md`. The deferred-nav cubit here is navigation PLUMBING, not a
screen ViewModel.

## Pattern (the why)

### Push — the app renders, Firebase only delivers

```
FCM (data-only) ──┬─ foreground: onMessage.listen ──────────────┐
                  ├─ background/terminated: onBackgroundMessage ─┤ (separate isolate)
                  └─ tap: onDidReceiveNotificationResponse ──────┘
                                   │
            PushResponseDto.fromJson(message.data)
                                   │
            persist to local store keyed by `code`  ──► _showNotification
                                   │ (on tap)
            rehydrate DTO by `code` ──► fan out to OnNotificationEvent listeners
```

- **Singleton facade.** `AppPushNotificationService` wraps
  `FirebaseMessaging.instance` and a top-level `FlutterLocalNotificationsPlugin`.
  Firebase only *delivers* the data message; the app renders the visible
  notification via local notifications. WHY: ONE render path for foreground +
  background, full control over large icon / image / badge / channel, and the
  notification is never auto-shown by FCM.
- **Three lifecycle entry points.** Foreground (`onMessage.listen`), background /
  terminated (`onBackgroundMessage`, a top-level
  `@pragma('vm:entry-point')` handler in a SEPARATE isolate), and tap
  (`onDidReceiveNotificationResponse`).
- **Payload is a DB key, not the full DTO.** The notification payload is just the
  DTO's `code`. The full DTO is persisted to the local store keyed by `code` and
  rehydrated on tap. WHY: dodges payload-size limits and keeps a tap-event log.
- **Retroactive listener queue.** Tap events that fire before a feature registers
  its `OnNotificationEvent` are buffered and replayed on registration. A listener
  returns `finish` to consume the event. WHY: a feature that subscribes late
  still receives an earlier tap.
- **Token refresh → use case → repo.** `onTokenRefresh.listen(...)` runs
  `SavePushTokenUseCase` (which folds an `Either<AppError, T>`), reaching the
  backend through the repository. Topic subscription (`subscribeToTopic('all')`)
  on init.
- **iOS rich media.** A native Notification Service Extension intercepts the push,
  downloads the `image` URL, and attaches it. The Dart side ALSO pre-downloads
  the image for a `DarwinNotificationAttachment` so the foreground / local-only
  path is covered.

### Deep link — vendor behind an interface, deferred navigation

```
Branch session ─► validate (drop heartbeats) ─► string-key the map
   ─► DeepLinkData.fromBranchData ─► persist (store) ─► emit on navigationStream
                                                              │
   DeepLinkNavigationCubit:  processing ─► awaitingAuthentication ─► (login) ─► navigationReady
                                                              │
   DeepLinkNavigationConsumer (BlocListener) ─► go_router .go / .pushNamed (de-duped)
```

- **Vendor isolation.** `DeepLinkService` (interface) + `BranchDeepLinkService`
  (impl). Only the impl imports the vendor SDK; every consumer depends on the
  interface + `DeepLinkData`. WHY: swap Branch for `app_links` / Firebase Dynamic
  Links without touching consumers.
- **Typed, expiring payload.** Branch emits a raw `Map<dynamic, dynamic>` →
  validated → recursively string-keyed → mapped into an `Equatable`
  `DeepLinkData` (route enum + path/query params + metadata + timestamp + 24h
  expiry). WHY: value semantics let the cubit de-dupe; expiry avoids acting on a
  stale shared link.
- **Persist-then-emit.** A received link is written to the store BEFORE it is
  emitted, so it survives an app kill and the unauthenticated state, and is
  re-driven on the next launch.
- **Deferred-navigation state machine.** `DeepLinkNavigationCubit` watches the
  auth-token store key and the stored-link store key, holds a `pendingDeepLink`
  while unauthenticated, and only reaches `navigationReady` once the user is
  inside the authenticated area. WHY: a link tapped on the login screen must
  survive login and fire afterward.
- **Location-driven auth check.** "Authenticated" is derived from
  `AppRouter.unauthenticatedPaths` prefix-matching the current `go_router`
  location — NOT a token flag in this layer. Keeps the cubit decoupled from auth
  internals.
- **A deliberate Cubit, not a Controller.** The canonical state manager in this
  skill is the rx_notifier `Controller` (`08-mvvm-rxnotifier.md`) and feature
  screens use it. The deferred-nav machine is the one app-global cross-cutting
  exception that stays a `flutter_bloc` `Cubit` because the root `BlocListener`
  consumes its state-transition stream — do NOT model new feature logic this way.

## Folder placement

```
lib/
  push/
    push_notification_service.dart     # singleton facade + 3 handlers + bg isolate entry points
  firebase/
    firebase_options.dart              # flutterfire-generated
  service/deep_link/
    deep_link_service.dart             # abstract interface + DeepLinkServiceException
    impl/branch_deep_link_service.dart # vendor impl (only file importing the SDK)
    models/deep_link_data.dart         # Equatable payload + parsing factories
    cubit/deep_link_navigation_cubit.dart  # state machine + state + status enum
    cubit/deep_link_navigation_consumer.dart  # root BlocListener -> go_router
    di/deep_link_binding.dart          # binds interface -> impl + cubit (see 03-di.md)
  domain/notification/
    save_push_token_use_case.dart      # token refresh -> repo (see 04-usecases.md)
  model/api/common/
    push_response_dto.dart             # freezed push payload DTO (see 05-repository.md)
  navigation/
    app_routers.dart                   # AppRouter enum (path, name, isBottomNavigation,
                                        #   unauthenticatedPaths) — see 11-navigation.md
ios/
  Runner/AppDelegate.swift             # local-notif registrant + UNUserNotificationCenter delegate
  Runner/Info.plist                    # branch_key, link domains, UIBackgroundModes
  Runner/Runner.entitlements           # aps-environment + associated-domains
  AppNotificationService/              # Notification Service Extension TARGET
    NotificationService.swift
    Info.plist                         # NSExtensionPointIdentifier = ...usernotifications.service
android/app/src/main/AndroidManifest.xml  # default channel meta-data + Branch keys + intent-filters
```

`PushResponseDto`, `AppRouter`, `SavePushTokenUseCase`, and the
`AbstractDatabase` store are SHARED with other concerns — this reference shows
how push/deep-link USE them; their canonical templates live with those concerns.
Always `package:app/...` imports, never relative.

## Templates

Copy from `assets/templates/push_deeplink/` and rename the anchors (`App`,
`Feature`, `Example`) to the real names. Every Dart file is compile-shaped with
`package:app/...` imports.

| Template file | What it is |
|---|---|
| [`push_notification_service.dart`](../assets/templates/push_deeplink/push_notification_service.dart) | Singleton facade: `init()`, `registerBackgroundMessageHandler()`, the 3 lifecycle handlers, the retroactive `OnNotificationEvent` queue, token-refresh → use case, top-level `appBackgroundMessageHandler` + `_ensureBackgroundEnv` (isolate re-bootstrap), and `_showNotification` with the Android `ByteArrayAndroidBitmap` large icon + iOS `DarwinNotificationAttachment`. |
| [`deep_link_service.dart`](../assets/templates/push_deeplink/deep_link_service.dart) | The vendor-agnostic `DeepLinkService` interface + `DeepLinkServiceException`. The only contract consumers depend on. |
| [`branch_deep_link_service.dart`](../assets/templates/push_deeplink/branch_deep_link_service.dart) | Branch implementation: the ONLY file importing the vendor SDK. Session validation (drop heartbeats), recursive map string-keying, persist-then-emit, `generateShortUrl`, stored-link CRUD. |
| [`deep_link_data.dart`](../assets/templates/push_deeplink/deep_link_data.dart) | `Equatable` payload: `fromBranchData` (route-by-name + `k=v&k=v` param decode), `forSharing`, `fromJson`/`toJson`/`copyWith`, `isExpired` (24h). |
| [`deep_link_navigation_cubit.dart`](../assets/templates/push_deeplink/deep_link_navigation_cubit.dart) | Deferred-nav state machine: status enum, sealed-style `DeepLinkNavState` (named ctor per status), auth/stored-key watchers, `process(location)`, `_processStoredFromPreviousSession`. |
| [`deep_link_navigation_consumer.dart`](../assets/templates/push_deeplink/deep_link_navigation_consumer.dart) | Root `BlocListener` consumer: `listenWhen` on status, feeds the current location to `process`, drives `go_router` `.go`/`.pushNamed`, 2s de-dup, navigate-home-then-push when outside the auth area. |
| [`bootstrap_snippet.dart`](../assets/templates/push_deeplink/bootstrap_snippet.dart) | `main()`/bootstrap ORDER: `registerBackgroundMessageHandler()` BEFORE `Firebase.initializeApp`, then DI, push `init()`, and a non-blocking Branch init. |
| [`NotificationService.swift`](../assets/templates/push_deeplink/NotificationService.swift) | iOS Notification Service Extension: downloads the `image` URL, attaches it, calls `contentHandler` in `defer`, `serviceExtensionTimeWillExpire` fallback. |
| [`platform_setup.md`](../assets/templates/push_deeplink/platform_setup.md) | Native wiring: Android default-channel meta-data + Branch keys + intent-filters; iOS `Info.plist` + entitlements + `AppDelegate` registrant + the extension target's `Info.plist`; the data-only payload contract. |

## Step-by-step to apply

1. **Generate Firebase config.** Run `flutterfire configure`; confirm
   `lib/firebase/firebase_options.dart` exists with
   `DefaultFirebaseOptions.currentPlatform`.
2. **Drop in the push facade.** Copy `push_notification_service.dart`. Wire the
   two store helpers (`_savePushResponseToDb` / `_readPushResponseFromDb`) and
   `AppDI.setupBasicInfrastructure()` to your real cache layer and DI
   (`07-cache-database.md`, `03-di.md`). Ensure `PushResponseDto` exists with the
   payload fields (`code`, `title`, `message`, `image`, `icon`).
3. **Add the token use case.** `SavePushTokenUseCase` takes the FCM token and
   calls the repository (`04-usecases.md` / `05-repository.md`). Register it so
   `AppDI.it.get<SavePushTokenUseCase>()` resolves.
4. **Fix the bootstrap order.** Copy `bootstrap_snippet.dart`. The order is
   correctness: `registerBackgroundMessageHandler()` runs BEFORE
   `Firebase.initializeApp`, push `init()` after, Branch init last and
   non-blocking.
5. **Native push setup.** Follow `platform_setup.md`: Android default-channel
   meta-data (id MUST match `high_importance_channel`), the white notification
   icon, iOS `UIBackgroundModes`, `aps-environment`, and the `AppDelegate`
   local-notifications registrant.
6. **iOS rich media.** Add the Notification Service Extension target, drop in
   `NotificationService.swift`, set the extension `Info.plist`
   (`NSExtensionPointIdentifier`, principal class), and confirm the backend sends
   `mutable-content: 1` + an `image` URL.
7. **Deep link: interface + impl.** Copy `deep_link_service.dart`,
   `branch_deep_link_service.dart`, and `deep_link_data.dart`. Confirm your
   `AppRouter` enum exposes `path`, `name`, `isBottomNavigation`, and the
   `unauthenticatedPaths` list (`11-navigation.md`). Add Branch keys / link
   domains / intent-filters per `platform_setup.md`.
8. **Deferred-nav cubit + consumer.** Copy `deep_link_navigation_cubit.dart` and
   `deep_link_navigation_consumer.dart`. Register the service (interface → impl),
   the cubit, and provide the cubit above the router; wrap the app shell `child`
   with `DeepLinkNavigationConsumer`. Call `DeepLinkService.initialize()` and
   `cubit.initialize()` from a post-frame callback in the root widget's
   `initState`.
9. **Verify the auth resume.** Tap a link on the login screen → it should be held
   (`awaitingAuthentication`) → log in → it fires (`navigationReady`). Confirm a
   killed-app link is re-driven via `_processStoredFromPreviousSession`.

## Gotchas

- **Register `onBackgroundMessage` BEFORE `Firebase.initializeApp`** and before
  any UI. The handler MUST be a top-level / static function annotated
  `@pragma('vm:entry-point')` — never a closure or instance method, or it does
  not run in the background isolate.
- **The background isolate cannot see instance fields.** The plugin instance and
  the channel are file-level `const`/`final` in the template, not fields, for
  exactly this reason. Guard re-init with the static `bool` flags
  (`_isBasicInfraSetup` / `_isBackgroundEnvInitialized`) or you double-init
  Firebase + DI + the plugin.
- **Android default channel id must match.** The
  `default_notification_channel_id` meta-data in `AndroidManifest.xml` MUST equal
  the `_channel` id (`high_importance_channel`) created in Dart, or background
  notifications have no channel and never show.
- **iOS rich images need the extension target.** `NSExtensionPointIdentifier =
  com.apple.usernotifications.service`, principal class
  `$(PRODUCT_MODULE_NAME).NotificationService`, AND the payload must carry
  `mutable-content: 1` plus an `image` URL. The extension has a hard time budget
  → always call `contentHandler` in `defer` and implement
  `serviceExtensionTimeWillExpire`.
- **iOS also needs** `aps-environment` entitlement, `UIBackgroundModes`
  (`remote-notification`), and the local-notifications plugin registrant set in
  `AppDelegate` (`FlutterLocalNotificationsPlugin.setPluginRegistrantCallback`).
- **Payload = `code`, not the full DTO.** Keep the notification payload tiny; the
  full DTO lives in the local store. On tap, the `code` rehydrates it.
- **Branch `listSession()` emits empty / heartbeat maps.** Validate before
  mapping (`_isValidSession`), or you navigate to the fallback route on every
  cold start.
- **Branch returns `Map<dynamic, dynamic>`** with nested maps / lists. Recursively
  convert to `Map<String, dynamic>` before parsing (`_toStringKeyedMap`).
- **Branch test vs live key is chosen natively** (`io.branch.sdk.TestMode` in the
  manifest / `branch_key` dict on iOS) based on build, NOT hard-coded in Dart.
- **Initialize Branch async / non-blocking.** A Branch init failure must never
  block app launch — catch and continue (the template wraps it in try/catch).
- **Persist-then-emit, always.** Write the link to the store BEFORE emitting it,
  so it survives an app kill and the unauthenticated state and is re-driven on
  next launch.
- **`listenWhen: prev.status != curr.status`.** The root `BlocListener` reacts to
  status transitions ONLY; reacting to non-status `copyWith` updates (pending-link
  changes) causes nav loops.
- **Navigate home first when outside the auth area**, then `pushNamed` after a
  short delay so the authenticated navigation stack exists before the deep route
  is pushed.
- **De-dupe identical nav within 2s.** Branch and `go_router` can double-fire; the
  consumer ignores the same route+params inside a 2s window.
- **Any real host becomes `https://api.example.com`.** Never hard-code a real
  backend host or link domain in a template or doc.
