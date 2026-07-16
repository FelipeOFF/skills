// json_converter.dart — custom JsonConverter for a field freezed/json_serializable
// cannot map on its own (here: a String <-> DateTime timestamp).
//
// Placement: lib/common/helper/. Apply it on a DTO field with the annotation,
// e.g. `@TimestampSerializer() required DateTime createdAt`.
//
// Rename anchor: TimestampSerializer -> your converter name; swap the type
// arguments <DateTime?, dynamic> for whatever you convert between.

import 'package:json_annotation/json_annotation.dart';

class TimestampSerializer implements JsonConverter<DateTime?, dynamic> {
  const TimestampSerializer();

  @override
  DateTime? fromJson(final dynamic timestamp) {
    final raw = timestamp as String?;
    if (raw == null) {
      return null;
    }
    final date = DateTime.parse(raw);
    return date.toLocal();
  }

  @override
  String? toJson(final DateTime? date) => date?.toUtc().toIso8601String();
}
