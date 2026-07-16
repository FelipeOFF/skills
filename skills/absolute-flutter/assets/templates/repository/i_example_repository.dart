// lib/repository/example/i_example_repository.dart
//
// Abstract contract for one concern. Lives in the SAME folder as the impl.
// Class is always I-prefixed; the impl drops the I.
// The interface imports ONLY the DTOs/params it exposes — never the client,
// Endpoints, or util helpers (those are impl details).
import 'package:app/model/api/common/page_dto.dart';
import 'package:app/model/api/common/response_dto.dart';
import 'package:app/model/api/example/example_dto.dart';
import 'package:app/model/api/example/req/list_examples_req.dart';

abstract class IExampleRepository {
  // Read of one entity. Returns the DTO directly (no hand-written domain model).
  Future<ExampleDto> getExample(String? id);

  // Paginated read: the inner DTO is wrapped once in PageDto, then in the
  // ResponseDTO envelope.
  Future<ResponseDTO<PageDto<ExampleDto>>> getExamplesPaging(ListExamplesReq req);

  // Mutation. Mutations return Future<void> or Future<bool>, never the envelope.
  Future<void> favoriteExample(int id);
}
