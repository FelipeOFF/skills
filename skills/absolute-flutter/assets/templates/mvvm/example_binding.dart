// lib/feature/example/di/example_binding.dart
//
// The feature (presentation) binding. It registers this feature's Controller
// with registerFactory so every push of the page gets a FRESH Controller with
// fresh RxNotifier state. Constructor deps (use cases) resolve with bare it().
//
// Remember to append `const ExampleBinding()` to the features list in
// `app_di.dart` — the binding file alone does nothing until it is in the list.
import 'package:get_it/get_it.dart';

import 'package:app/di/abstract_binding.dart';
import 'package:app/feature/example/controller/example_controller.dart';

class ExampleBinding extends AbstractBinding {
  const ExampleBinding();

  @override
  Future<void> binding(GetIt it) async {
    it.registerFactory<ExampleController>(() => ExampleController(it()));
  }
}
