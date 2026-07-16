// lib/repository/example/example_repository.dart
//
// Impl of the concern. Same folder as the interface. `extends` the I-interface
// (older HTTP repos) or `implements` it (newer data-source-backed repos) — both
// are accepted; default to `implements` for new code. Deps are private final
// fields set by a positional constructor (constructor injection only, no
// service-locator calls inside the body). Every remote call: hit the injected
// client, then decode the JSON envelope at this boundary via ResponseDTO.
import 'package:app/common/util/safe_map.dart';
import 'package:app/model/api/common/page_dto.dart';
import 'package:app/model/api/common/response_dto.dart';
import 'package:app/model/api/example/example_dto.dart';
import 'package:app/model/api/example/req/list_examples_req.dart';
import 'package:app/repository/example/i_example_repository.dart';
import 'package:app/service/client/logged_client.dart';
import 'package:app/service/endpoint/endpoints.dart';

class ExampleRepository implements IExampleRepository {
  ExampleRepository(this._client);

  final LoggedClient _client;

  @override
  Future<ExampleDto> getExample(String? id) async {
    final response = await _client.get(
      Endpoints.example,
      queryParameters: {'id': ?id}, // Dart 3 null-aware spread omits null keys
    );
    // Envelope decode at the boundary: wrap raw body in ResponseDTO<ExampleDto>,
    // supply the inner T.fromJson, return .data with a const fallback so a null
    // body never surfaces as a runtime null upstream.
    return ResponseDTO<ExampleDto>.fromJson(
      safeMapOf(response.data),
      (json) => ExampleDto.fromJson(safeMapOf(json)),
    ).data ??
        const ExampleDto();
  }

  @override
  Future<ResponseDTO<PageDto<ExampleDto>>> getExamplesPaging(ListExamplesReq req) async {
    final result = await _client.get(
      Endpoints.examples,
      queryParameters: {'page': req.page, 'search': ?req.search, 'size': 10},
    );
    // Paginated: wrap once more in PageDto, mapping each list element through
    // the DTO factory.
    return ResponseDTO<PageDto<ExampleDto>>.fromJson(
      safeMapOf(result.data),
      (json) => PageDto<ExampleDto>.fromJson(
        safeMapOf(json),
        (e) => ExampleDto.fromJson(e.asSafeMap),
      ),
    );
  }

  @override
  Future<void> favoriteExample(int id) async {
    // Mutation: fire the call, ignore the body. Errors propagate to the use case.
    await _client.post(Endpoints.favoriteExample, queryParameters: {'exampleId': id});
  }
}
