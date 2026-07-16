// lib/model/example/res/example_result.dart
//
// A SEALED / UNION model: one type, several disjoint shapes. Use this when a
// value is genuinely one-of-N variants (a status outcome, a polymorphic
// payload) — NOT for a plain record-like DTO (that is a single-factory class,
// see example_response_dto.dart).
//
// Freezed union = multiple const factories, each a named variant. Freezed
// generates a sealed class so the consumer can exhaustively switch/when over
// the variants — the compiler forces every case to be handled.
//
// Rename anchors: Example / ExampleResult -> your concern.
//
// Wire mapping: a union's generated fromJson is discriminated by a `runtimeType`
// key in the JSON. When the backend instead sends a flat status STRING, prefer a
// hand-written `fromString` factory (as below) over the generated discriminator
// — it keeps you in control of the wire contract. Run build_runner to emit the
// .freezed.dart / .g.dart parts.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'example_result.freezed.dart';
part 'example_result.g.dart';

@freezed
class ExampleResult with _$ExampleResult {
  const factory ExampleResult.success({String? reference}) = ExampleResultSuccess;
  const factory ExampleResult.pending() = ExampleResultPending;
  const factory ExampleResult.failed({String? reason}) = ExampleResultFailed;
  const factory ExampleResult.unknown() = ExampleResultUnknown;

  factory ExampleResult.fromJson(Map<String, dynamic> json) => _$ExampleResultFromJson(json);

  // Hand-written wire mapping from a flat status string — preferred over the
  // generated runtimeType discriminator when the backend sends a plain enum-ish
  // status field rather than a tagged union.
  factory ExampleResult.fromStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'SUCCESS':
        return const ExampleResult.success();
      case 'PENDING':
        return const ExampleResult.pending();
      case 'FAILED':
        return const ExampleResult.failed();
      default:
        return const ExampleResult.unknown();
    }
  }
}

// Consumer: exhaustive switch over the union. Dart 3 switch expressions on a
// sealed class are compile-checked — add a variant above and this won't compile
// until you handle it. `.when`/`.map` (Freezed-generated) are the equivalent
// fluent forms; pick whichever reads better at the call site.
extension ExampleResultX on ExampleResult {
  bool get isTerminal => switch (this) {
        ExampleResultSuccess() => true,
        ExampleResultFailed() => true,
        ExampleResultPending() => false,
        ExampleResultUnknown() => false,
      };

  String get label => when(
        success: (reference) => 'Succeeded',
        pending: () => 'In progress',
        failed: (reason) => reason ?? 'Failed',
        unknown: () => 'Unknown',
      );
}
