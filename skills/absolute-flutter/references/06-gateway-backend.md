# 06 — Gateway / backend call layer

The HTTP transport tier: dio-by-inheritance clients, a load-bearing interceptor
stack, auth + refresh, the `ResponseDto<T>` envelope, the `DioException →
AppError` funnel, and a parallel gRPC channel. Read this when you touch anything
between a repository and the wire. For what a repository DOES with these clients,
see `05-repository.md`; for how errors become `Either<AppError, T>`, see
`04-usecases.md`.

## When to use

- Bootstrapping the network layer of a new app (base client, clients, endpoints).
- Adding an authenticated or public endpoint family, or a new concrete client.
- Wiring or reordering interceptors (auth, refresh, retry, encrypt, logging).
- Adding an SSL-pinned production host or a local HTTP/1.1 mock host.
- Standing up a gRPC channel alongside the dio stack.

Do NOT use this reference to write repositories or use cases — those consume the
clients but live in `05-repository.md` / `04-usecases.md`.

## Pattern (the why)

Request flows top→bottom; errors flow bottom→top:

```
UseCase  →  Repository  →  Client (Dio subclass)  →  Interceptor stack  →  HTTP/2 / gRPC
   ▲             │                                                              │
   └── Either<AppError,T> ◄── ResponseDto<T>.fromJson ◄── raw Response ◄────────┘
```

- **Dio by inheritance.** `AbstractGateway extends DioForNative` — the client IS
  a Dio. A repository types its dependency as `LoggedClient` / `NonLoggedClient`
  and calls `.get` / `.post` directly. No per-endpoint wrapper method, and
  mocking is trivial (the dep is just a Dio). This is the load-bearing decision
  the whole tier rests on.
- **Two client families, one refresh-only client.** `NonLoggedClient` (public)
  and `LoggedClient` (auth + refresh) extend the base. A throwaway refresh-only
  client (a plain `NonLoggedClient`) performs the refresh call WITHOUT auth
  interceptors — that is what breaks the refresh→401→refresh recursion.
- **Concrete clients are singletons.** Factory + static cache field; they resolve
  their `Url` from the injected `Environment` at call time. One client per host
  means one shared HTTP/2 connection pool.
- **Interceptor order is load-bearing.** debug-capture → retry → logger → encrypt
  → apiKey → (refresh → token). Debug first so it captures the full
  request/response; refresh BEFORE token-inject so a stale session is renewed
  before the Bearer header is written. Reversing the last two breaks auth.
- **One envelope.** Every JSON body is `ResponseDto<T>` (freezed,
  `genericArgumentFactories`) wrapping `data`, `error`, `status`, `metadata`,
  `timestamp`. Repositories deserialize `ResponseDto<T>.fromJson(map, T.fromJson)`
  and return `.data`. Uniform data + error extraction everywhere.
- **Errors are values at the boundary.** Repositories let `DioException` bubble;
  they never catch. `DioException.asAppError()` maps transport/HTTP failures to
  the sealed `AppError` (401 → `Logout`, offline → `NetworkException`, parsed
  body → `Default`, else → `UnknownException`). The use case's `call()` is the
  single try/catch that converts to `Either<AppError, T>`. The UI never sees a
  raw exception.
- **gRPC coexists.** `AbstractGrpcGateway extends ClientChannel`; concrete
  channels expose typed `...ServiceClient` getters from generated
  `*.pbgrpc.dart`. Secure-by-default credentials, gzip codec.

## Folder placement

```
lib/
  gateway/
    abstract_gateway.dart          # base Dio client + interceptor assembly + SSL hook
    abstract_grpc_gateway.dart     # base gRPC ClientChannel + concrete channel
    model/
      url.dart                     # Url value object (host, port, credential, isLocalMock)
      credential.dart              # SSL pin cert/key paths
    interceptor/
      token_interceptor.dart       # injects Bearer, rejects if expired
      refresh_token_interceptor.dart  # synchronized Lock, refresh-once
      retry_interceptor.dart       # backoff + jitter, static attempt map
      api_key_interceptor.dart
      encrypt_interceptor.dart
      debug_interceptor.dart
    util/
      constants.dart               # timeouts, header names, retry tuning
      jwt_ext.dart                 # String → JWT expiry extension
      check_user_auth.dart         # refresh orchestration (uses refresh-only client)
  service/
    client/
      logged_client.dart           # LoggedClient family (often inlined in base)
      non_logged_client.dart       # NonLoggedClient family (often inlined in base)
      app_client.dart              # concrete singletons: logged / non-logged / refresh-only
    endpoint/
      endpoints.dart               # all path constants
    channel/
      feature_channel.dart         # concrete gRPC channel
  model/api/common/
    response_dto.dart              # ResponseDto<T> envelope  (see 05-repository.md)
    error_dto.dart                 # ErrorDto
  domain/
    abstract_use_case.dart         # Either<AppError,T> boundary  (see 04-usecases.md)
    app_error.dart                 # AppError hierarchy + asAppError() ext
```

`ResponseDto<T>`, `ErrorDto`, `AppError`, and `AbstractUseCase` are SHARED with
the repository and use-case concerns — this reference shows how the gateway uses
them, but their canonical templates live with those concerns. Always
`package:app/...` imports, never relative.

## Templates

Copy from `assets/templates/gateway/` and rename the anchors (`Feature`,
`Example`, `Item`, `App`) to the real names. Every file is compile-shaped with
`package:app/...` imports.

| Template file | What it is |
|---|---|
| [`abstract_gateway.dart`](../assets/templates/gateway/abstract_gateway.dart) | Base `DioForNative` client: `BaseOptions`, HTTP/1.1-vs-HTTP/2 adapter choice, SSL pinning hook, the ordered interceptor assembly, plus the `NonLoggedClient` / `LoggedClient` families. |
| [`logged_client.dart`](../assets/templates/gateway/logged_client.dart) | Standalone `LoggedClient` family copy target (for projects that keep client families in `service/client/` apart from the base). |
| [`non_logged_client.dart`](../assets/templates/gateway/non_logged_client.dart) | Standalone `NonLoggedClient` marker family copy target. |
| [`app_client.dart`](../assets/templates/gateway/app_client.dart) | Concrete singletons: `AppLoggedClient`, `AppNonLoggedClient`, and the refresh-only `AppRefreshTokenClient` (plain `NonLoggedClient`, no auth interceptors). |
| [`token_interceptor.dart`](../assets/templates/gateway/token_interceptor.dart) | Injects `Bearer`; rejects missing/expired tokens with a synthetic 401 that the funnel maps to `Logout`. |
| [`refresh_token_interceptor.dart`](../assets/templates/gateway/refresh_token_interceptor.dart) | Refresh-before-token; `synchronized` `Lock` so concurrent 401s trigger ONE refresh; logout on failure. |
| [`retry_interceptor.dart`](../assets/templates/gateway/retry_interceptor.dart) | Exponential backoff + jitter, retryable-error classification, static per-request attempt map, `cleanupRetryTracking()`. |
| [`endpoints.dart`](../assets/templates/gateway/endpoints.dart) | `const`-only path-constant class: private prefix consts + public paths, `{param}` placeholders + a `fill` helper. |
| [`abstract_grpc_gateway.dart`](../assets/templates/gateway/abstract_grpc_gateway.dart) | Base `ClientChannel` (secure-by-default, gzip codec) + a concrete channel exposing a typed generated service client. |

## Step-by-step to apply

1. **Drop in the base.** Copy `abstract_gateway.dart`. Confirm your `Url` value
   object exposes `baseHost`, `port`, `credential`, and `isLocalMock`, and that
   `Environment` exposes `serverUrl` and `isEnableSslPinning`.
2. **Place the interceptors.** Copy `token_interceptor.dart`,
   `refresh_token_interceptor.dart`, `retry_interceptor.dart` into
   `gateway/interceptor/`. Wire your token store and `CheckUserAuth` types.
3. **Add concrete clients.** Copy `app_client.dart`. Keep all three singletons —
   the refresh-only client MUST stay a plain `NonLoggedClient`.
4. **Define endpoints.** Copy `endpoints.dart`; add prefix consts per API surface
   and public paths under them. Use `{param}` placeholders, substitute via
   `Endpoints.fill(...)` at the call site.
5. **Register in DI.** `registerLazySingleton` the interceptors,
   `registerSingleton` the clients (constructor-inject the interceptors). See
   `03-di.md`. Repositories receive `LoggedClient` / `NonLoggedClient`.
6. **(If gRPC)** Copy `abstract_grpc_gateway.dart`, point the concrete channel at
   `env.grpcUrl`, and expose your generated `...ServiceClient` getters.
7. **Verify the funnel.** Ensure `DioException.asAppError()` and the `AppError`
   hierarchy exist (from `04-usecases.md`) and that the synthetic 401 path maps
   to `Logout`.

## Gotchas

- **Interceptor order is correctness, not style.** `additionalInterceptors`
  returns `[refresh, token]` and is appended AFTER the base list; `.whereType`
  filters the nullable slots. Reverse the pair and you inject a stale Bearer
  before refreshing — auth breaks silently.
- **Refresh must use a no-auth client.** If the refresh request runs through a
  client that has the token/refresh interceptors, a 401 on refresh re-triggers
  refresh forever. Keep `AppRefreshTokenClient` a plain `NonLoggedClient`.
- **The Lock prevents refresh storms.** Without `synchronized`, a screen firing
  five parallel calls that all 401 would launch five refreshes; the first
  invalidates the others. The `Lock` serializes them to one.
- **Synthetic 401 = client-side logout.** `TokenInterceptor` rejects an
  expired-token request locally (no network) with a fabricated 401; that is what
  `asAppError` turns into `Logout`. Expiry is read from the JWT `exp` claim, so
  device clock skew can cause false rejects — allow a small leeway in
  `isExpiredJwt`.
- **Retry uses a STATIC attempt map** keyed by `method+uri+body.hashCode`; call
  `RetryInterceptor.cleanupRetryTracking()` periodically (e.g. on app resume) or
  it leaks. Retries fetch on a FRESH `Dio()`, not the original instance, so the
  full interceptor stack does not re-run mid-retry.
- **Singletons ignore later constructor args.** Concrete clients (and the
  refresh-only client) cache in a static field; once built, a second
  `AppLoggedClient(...)` returns the cached instance and drops new args. Reset the
  static fields explicitly in tests.
- **Envelope fields are loosely typed.** `data` / `status` / `metadata` on
  `ResponseDto<T>` are `dynamic`/nullable; guard with a safe-map helper before
  `fromJson`. Backend error-code constants compared in the funnel (e.g.
  user-unauthenticated) are string-matched — keep them in sync with the backend.
- **SSL pinning loads from the asset bundle.** Cert/key paths resolve from the
  package asset bundle (`packages/<pkg>/<path>`); a wrong package prefix silently
  disables pinning in prod. Verify on a real prod build.
- **gRPC hosts are bare host strings** (no scheme), `port` defaults to 443.
  Double-check the dev/stg/prod env mapping — it is easy to point a secure
  channel at the wrong host.
- **Any real host becomes `https://api.example.com`.** Never hard-code a real
  backend host in a template or doc.
