// lib/di/service/service_binding.dart  (RENAME ANCHOR: this is a *layer* binding)
//
// A core layer binding showing every registration kind you need below the
// presentation layer. Copy it for any infra/data/domain/repository layer file
// and keep the kind-by-layer rule:
//   - eager registerSingleton<I>(Impl(...))  for data/domain/repository (fail fast at boot)
//   - registerLazySingleton<T>(() => ...)     for cross-cutting services cheap to defer
//   - registerSingletonAsync<T>(() async ...) for async deps (DB), awaited via getAsync
//
// Bare `it()` is the callable shorthand for `it.get()`; it resolves positionally
// by the *declared constructor parameter type*. Use explicit `it<T>()` only to
// disambiguate.
import 'package:get_it/get_it.dart';

import 'package:app/data/source/example_data_source.dart';
import 'package:app/data/source/i_example_data_source.dart';
import 'package:app/database/abstract_database.dart';
import 'package:app/domain/repository/example_repository.dart';
import 'package:app/domain/repository/i_example_repository.dart';
import 'package:app/service/auth_checker.dart';
import 'package:app/service/cache_manager.dart';
import 'package:app/service/i_logged_client.dart';
import 'package:app/service/logged_client.dart';
import 'package:app/di/abstract_binding.dart';

class ServiceBinding extends AbstractBinding {
  const ServiceBinding();

  @override
  Future<void> binding(GetIt it) async {
    // Eager singleton, zero deps.
    it.registerSingleton<CacheManager>(CacheManager());

    // Await an async-registered dep (the DB) BEFORE building a sync singleton
    // that needs it — using sync it<AbstractDatabase>() here would throw because
    // registerSingletonAsync has not resolved yet.
    it.registerSingleton<AuthChecker>(AuthChecker(await it.getAsync<AbstractDatabase>()));

    // Interface-typed, impl as value; nested deps resolved positionally.
    it.registerSingleton<ILoggedClient>(LoggedClient(it(), it()));

    // Data source bound by interface (data layer also uses this kind).
    it.registerSingleton<IExampleDataSource>(ExampleDataSource(it()));

    // Repository bound by interface, impl as value — keeps the dependency rule
    // (domain depends on the abstraction, not the concrete class).
    it.registerSingleton<IExampleRepository>(ExampleRepository(it()));

    // LazySingleton for a heavyweight / optional cross-cutting service.
    it.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  }
}

// Placeholder type so this skeleton is self-contained and compile-shaped.
// In a real layer file this lives in its own module under package:app/...
class AnalyticsService {
  const AnalyticsService();
}
