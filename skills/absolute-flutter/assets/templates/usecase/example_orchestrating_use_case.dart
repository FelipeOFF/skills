import 'package:app/domain/abstract_use_case.dart';
import 'package:app/domain/example/dto/example_dto.dart';
import 'package:app/domain/example/save_example_use_case.dart';
import 'package:app/domain/example/after_example_use_case.dart';
import 'package:app/repository/example/i_example_repository.dart';

/// An orchestrating use case: it depends on a repository AND composes other use
/// cases. Two composition styles, picked by whether you want the sub-error:
///
///   - `_other.execute(x)` — RAW. Stays inside this use case's error frame;
///     a throw from the inner use case propagates and is caught by THIS use
///     case's `call()`. Use when the inner failure should fail the whole thing.
///   - `_other(x)` / `_other.call(x)` — returns the inner `Either`. Use when
///     you want to fold the sub-result (e.g. tolerate a failure and continue).
class FeatureOrchestratingUseCase extends AbstractUseCase<ExampleDto, ExampleResultDto?> {
  final IExampleRepository _repository;
  final SaveExampleUseCase _saveExampleUseCase;
  final AfterExampleUseCase _afterExampleUseCase;

  const FeatureOrchestratingUseCase(
    this._repository,
    this._saveExampleUseCase,
    this._afterExampleUseCase,
  );

  @override
  Future<ExampleResultDto?> execute(ExampleDto param) async {
    final response = await _repository.submitExample(param);
    if (response == null) return null;

    // Raw composition: propagate any throw into this use case's error frame.
    final saved = await _saveExampleUseCase.execute(response);

    // Callable composition: run a side-effecting follow-up; its Either is
    // ignored here because a failure must not fail the parent flow.
    await _afterExampleUseCase(response);

    return saved;
  }
}
