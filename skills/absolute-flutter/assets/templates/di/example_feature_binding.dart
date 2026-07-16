// lib/feature/example/di/example_binding.dart
//
// A feature (presentation) binding. It registers exactly this feature's
// Controller(s). Use registerFactory so each screen gets a FRESH Controller
// instance with fresh RxNotifier state — never a shared one. Constructor deps
// (use cases, repositories) are resolved with bare it().
//
// Variants below, in order of how often you reach for them:
//   - registerFactory          : the default for a screen Controller.
//   - named-arg factory        : same, when the Controller has many deps.
//   - registerLazySingleton    : a Controller that must SURVIVE across screens.
//   - registerFactoryParam     : a Controller that needs runtime args at push time.
import 'package:get_it/get_it.dart';

import 'package:app/di/abstract_binding.dart';
import 'package:app/feature/detail/detail_controller.dart';
import 'package:app/feature/example/example_controller.dart';
import 'package:app/feature/home/home_controller.dart';

// Default: one fresh Controller per screen. This is the common case.
class ExampleBinding extends AbstractBinding {
  const ExampleBinding();

  @override
  Future<void> binding(GetIt it) async {
    it.registerFactory<ExampleController>(() => ExampleController(it(), it()));
  }
}

// Named-arg style: same registerFactory, clearer when there are several deps.
class HomeBinding extends AbstractBinding {
  const HomeBinding();

  @override
  Future<void> binding(GetIt it) async {
    it.registerFactory<HomeController>(
      () => HomeController(
        getItemsUseCase: it(),
        getProfileUseCase: it(),
      ),
    );
  }
}

// Long-lived Controller (registerLazySingleton) + a runtime-parameterised
// Controller (registerFactoryParam). Reach for these only when the default
// per-screen factory genuinely does not fit.
class DetailBinding extends AbstractBinding {
  const DetailBinding();

  @override
  Future<void> binding(GetIt it) async {
    // Survives across screens — promote to a singleton only for app-global state.
    it.registerLazySingleton<DetailController>(() => DetailController(it()));

    // Needs an id passed at push time: registerFactoryParam<T, P1, P2>.
    it.registerFactoryParam<DetailItemController, String, void>(
      (String itemId, _) => DetailItemController(getDetailUseCase: it(), itemId: itemId),
    );
  }
}
