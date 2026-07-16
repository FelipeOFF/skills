// lib/di/repository/repository_binding.dart
//
// Central GetIt registration of every repository. One i_/impl import pair per
// repo. Singletons by default (repos are stateless wrappers over a shared
// client, so reconstruction is wasteful); registerFactory only for repos that
// must not outlive their scope. `it()` / `it.get()` resolves each constructor
// dependency. The //REPOSITORY_BINDING comment is a LOAD-BEARING codegen anchor:
// new registrations are inserted immediately above it — never delete or move it.
import 'package:get_it/get_it.dart';
import 'package:app/di/abstract_binding.dart';
import 'package:app/repository/example/i_example_repository.dart';
import 'package:app/repository/example/example_repository.dart';
import 'package:app/repository/item/i_item_repository.dart';
import 'package:app/repository/item/item_repository.dart';
import 'package:app/repository/user/i_user_repository.dart';
import 'package:app/repository/user/user_repository.dart';

class RepositoryBinding extends AbstractBinding {
  @override
  Future<void> binding(GetIt it) async {
    // Multi-dependency repo: each `it.get()` resolves one constructor arg.
    it.registerSingleton<IUserRepository>(UserRepository(it.get(), it.get()));
    it.registerSingleton<IExampleRepository>(ExampleRepository(it()));

    // Short-lived / scoped repo: factory rebuilds per resolution.
    it.registerFactory<IItemRepository>(() => ItemRepository(it()));

    //REPOSITORY_BINDING
  }
}
