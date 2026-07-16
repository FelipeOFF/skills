import 'package:app/domain/abstract_use_case.dart';
import 'package:app/domain/example/dto/example_dto.dart';
import 'package:app/repository/example/i_example_repository.dart';

/// A concrete use case with a params object.
///
/// Rename anchors: `Example` -> the real entity, `Feature` -> the real action.
/// Shapes to know:
///   - No input        -> `extends AbstractUseCase<void, T>` and `execute(void p)`.
///   - One value        -> `extends AbstractUseCase<String, T>` etc.
///   - Multiple values  -> a `<Name>Params` class colocated below, as here.
///
/// The use case depends on a repository INTERFACE (`IExampleRepository`),
/// injected as a `final` private field via get_it. It never touches Dio.
class FeatureExampleUseCase extends AbstractUseCase<FeatureExampleParams, ExampleDto> {
  final IExampleRepository _repository;

  const FeatureExampleUseCase(this._repository);

  @override
  Future<ExampleDto> execute(FeatureExampleParams param) async {
    return _repository.fetchExample(id: param.id, includeDetail: param.includeDetail);
  }
}

/// Params object for [FeatureExampleUseCase]. Plain class (not Equatable /
/// freezed), `required` named fields, colocated in the SAME file below the use
/// case — keeps the use case self-contained, no separate params directory.
class FeatureExampleParams {
  final String id;
  final bool includeDetail;

  const FeatureExampleParams({required this.id, this.includeDetail = false});
}
