// lib/model/example/example_status.dart
//
// A JSON-mapped ENUM. Two flavours shown:
//
//  1. ExampleStatus — a PLAIN enum whose constants carry a @JsonValue. Used as a
//     field type inside a freezed DTO; json_serializable maps the wire string
//     <-> constant for free. No part files, no codegen of its own — it rides
//     along with whatever DTO references it.
//
//  2. ExampleTier — an ENHANCED enum that ALSO holds a payload (here `weight`).
//     Same @JsonValue mapping, plus per-constant data and helpers. Use this when
//     the enum needs an associated value or a derived property at the source.
//
// Rename anchors: Example / ExampleStatus / ExampleTier -> your concern.
//
// Keep PRESENTATION off the enum — labels/icons belong in an `extension XOnEnum`
// (see 10-extensions.md), not here. This file is pure wire mapping + data.

import 'package:freezed_annotation/freezed_annotation.dart';

enum ExampleStatus {
  @JsonValue('ACTIVE')
  active,
  @JsonValue('ARCHIVED')
  archived,
  @JsonValue('PENDING')
  pending,
}

enum ExampleTier {
  @JsonValue('FREE')
  free(0),
  @JsonValue('PLUS')
  plus(1),
  @JsonValue('PRO')
  pro(2);

  const ExampleTier(this.weight);

  final int weight;

  // Null-tolerant lookup for spots where the value arrives outside json_serializable
  // (e.g. a query string or a hand-decoded map). Falls back instead of throwing.
  static ExampleTier fromWeight(int? weight) =>
      ExampleTier.values.firstWhere((tier) => tier.weight == weight, orElse: () => ExampleTier.free);
}
