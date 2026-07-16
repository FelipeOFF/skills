// lib/di/abstract_binding.dart
//
// The Binding contract. Every registration in the app lives in a class that
// implements this — the app never calls it.registerX(...) inline. AppDI
// iterates a List<AbstractBinding> and awaits binding(it) on each, so the
// signature is async even when a given binding has nothing to await.
import 'package:get_it/get_it.dart';

abstract class AbstractBinding {
  const AbstractBinding();

  /// Register this layer's / feature's dependencies into [it].
  ///
  /// Async because some bindings await an async-registered dependency (the DB
  /// via `it.getAsync<T>()`) before building a sync singleton on top of it.
  Future<void> binding(GetIt it);
}
