// lib/model/example/example_entity.dart
//
// A DOMAIN ENTITY — the shape the rest of the app reasons about, decoupled from
// the wire. Plain, immutable, NO freezed/json: a domain entity has no fromJson,
// because it never touches the network. It is the TARGET of a DTO's toEntity()
// mapper (see example_mapper_ext.dart) and the boundary that keeps backend wire
// churn from leaking into use cases and UI.
//
// Rename anchors: Example / ExampleEntity / ExampleStatus -> your concern.
//
// Why a hand-written entity instead of passing the DTO around? Use one when:
//  - the UI/use case needs non-nullable, validated fields (the DTO is all-nullable);
//  - the domain shape differs from the wire shape (flattened, renamed, computed);
//  - you want a stable type the backend cannot break by renaming a JSON key.
// If none of that applies, returning the DTO directly is fine — do not add an
// entity just for ceremony (see 05-repository.md: DTO-as-return is the common case).
//
// Equality: this is a const class with final fields. For value equality without
// freezed, either extend Equatable (props list) or implement ==/hashCode. The
// neutral version below uses final fields + const ctor; add Equatable in the
// real app if you compare instances.

import 'package:app/model/example/example_status.dart';

class ExampleEntity {
  const ExampleEntity({
    required this.id,
    required this.title,
    required this.status,
    this.amount,
  });

  final String id;
  final String title;
  final ExampleStatus status;
  final double? amount;
}
