// lib/di/app_di.dart
//
// The single container handle + the ordered two-phase bootstrap.
// Phase 1 (setupBasicInfrastructure): env -> db -> network -> data -> repo ->
// domain. Phase 2 (setupRemainingBindings): mappers + every feature module.
// Order in each list encodes dependency direction and is load-bearing.
import 'package:get_it/get_it.dart';

import 'package:app/configurations/di/environment_binding.dart';
import 'package:app/database/di/database_binding.dart';
import 'package:app/di/abstract_binding.dart';
import 'package:app/di/data_source/data_source_binding.dart';
import 'package:app/di/domain/domain_binding.dart';
import 'package:app/di/gateway/gateway_binding.dart';
import 'package:app/di/mapper/mapper_binding.dart';
import 'package:app/di/repository/repository_binding.dart';
import 'package:app/di/service/service_binding.dart';
import 'package:app/feature/detail/di/detail_binding.dart';
import 'package:app/feature/example/di/example_binding.dart';
import 'package:app/feature/home/di/home_binding.dart';

class AppDI {
  AppDI._();

  /// The one and only locator handle. No second container anywhere.
  static final GetIt it = GetIt.instance;

  /// Phase 1 — infrastructure. Order is the dependency order:
  /// Environment (logger + config) MUST be first; everything below reads it.
  /// Domain is last because every use case depends on the repositories above.
  static final List<AbstractBinding> _listOfBasicInfrastructure = <AbstractBinding>[
    const EnvironmentBinding(),
    const DatabaseBinding(),
    const GatewayBinding(),
    const ServiceBinding(),
    const DataSourceBinding(),
    const RepositoryBinding(),
    const DomainBinding(),
  ];

  /// Phase 2 — the full list: infra prefix + mappers + every feature module.
  /// A feature that is not appended here never registers.
  static final List<AbstractBinding> _listOfBinding = <AbstractBinding>[
    ..._listOfBasicInfrastructure,
    const MapperBinding(),
    // Features (presentation) — one binding per feature, appended here.
    const ExampleBinding(),
    const HomeBinding(),
    const DetailBinding(),
  ];

  /// Phase 1: run infra so logging + Environment + DB exist before `main`
  /// initializes any third-party SDK and before any feature registers.
  static Future<void> setupBasicInfrastructure() async {
    for (final AbstractBinding b in _listOfBasicInfrastructure) {
      await b.binding(it);
    }
  }

  /// Phase 2: run mappers + features. `.skip()` drops the infra prefix already
  /// registered in phase 1, so nothing is double-registered.
  static Future<void> setupRemainingBindings() async {
    final List<AbstractBinding> remaining = _listOfBinding.skip(_listOfBasicInfrastructure.length).toList();
    for (final AbstractBinding b in remaining) {
      await b.binding(it);
    }
  }
}
