import 'package:equatable/equatable.dart';

import 'package:app/navigation/app_routers.dart';

/// Typed, immutable deep-link payload. Hand-written [Equatable] (not freezed):
/// it needs custom parsing factories (`fromBranchData`) and value semantics so
/// the cubit can de-dupe identical links.
///
/// Rename anchors: none — this DTO is domain-neutral. `AppRouter` is your route
/// enum (see `app_routers.dart`); unknown route names fall back to
/// `AppRouter.home`.
///
/// Links carry a [timestamp] and expire after 24h ([isExpired]) so the app does
/// not act on a stale shared link.
class DeepLinkData extends Equatable {
  const DeepLinkData({
    required this.route,
    required this.timestamp,
    this.pathParameters = const <String, String>{},
    this.queryParameters = const <String, dynamic>{},
    this.metadata = const <String, dynamic>{},
  });

  final AppRouter route;
  final Map<String, String> pathParameters;
  final Map<String, dynamic> queryParameters;
  final Map<String, dynamic> metadata;
  final int timestamp;

  static const Duration _expiry = Duration(hours: 24);

  bool get isExpired => DateTime.now().millisecondsSinceEpoch - timestamp >= _expiry.inMilliseconds;

  /// Maps a Branch session map (already string-keyed) into a typed link. The
  /// `route` string resolves to an [AppRouter] by name, falling back to
  /// `AppRouter.home` for unknown names. Param strings are `k=v&k=v` encoded.
  factory DeepLinkData.fromBranchData(Map<String, dynamic> data) {
    final String routeName = (data['route'] as String?) ?? AppRouter.home.name;
    final AppRouter route = AppRouter.values.firstWhere(
      (AppRouter r) => r.name == routeName,
      orElse: () => AppRouter.home,
    );
    return DeepLinkData(
      route: route,
      pathParameters: _decodeStringParams(data['pathParameters'] as String?),
      queryParameters: _decodeParams(data['queryParameters'] as String?),
      metadata: Map<String, dynamic>.from(data),
      timestamp: _parseTimestamp(data['timestamp']),
    );
  }

  /// Builds a link for outbound sharing (consumed by `generateShortUrl`).
  factory DeepLinkData.forSharing({
    required AppRouter route,
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
  }) {
    return DeepLinkData(
      route: route,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory DeepLinkData.fromJson(Map<String, dynamic> json) {
    final String routeName = (json['route'] as String?) ?? AppRouter.home.name;
    final AppRouter route = AppRouter.values.firstWhere(
      (AppRouter r) => r.name == routeName,
      orElse: () => AppRouter.home,
    );
    return DeepLinkData(
      route: route,
      pathParameters: Map<String, String>.from(json['pathParameters'] as Map? ?? <String, String>{}),
      queryParameters: Map<String, dynamic>.from(json['queryParameters'] as Map? ?? <String, dynamic>{}),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? <String, dynamic>{}),
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'route': route.name,
        'pathParameters': pathParameters,
        'queryParameters': queryParameters,
        'metadata': metadata,
        'timestamp': timestamp,
      };

  DeepLinkData copyWith({
    AppRouter? route,
    Map<String, String>? pathParameters,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? metadata,
    int? timestamp,
  }) {
    return DeepLinkData(
      route: route ?? this.route,
      pathParameters: pathParameters ?? this.pathParameters,
      queryParameters: queryParameters ?? this.queryParameters,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  static Map<String, String> _decodeStringParams(String? raw) {
    final Map<String, dynamic> decoded = _decodeParams(raw);
    return decoded.map((String k, dynamic v) => MapEntry<String, String>(k, '$v'));
  }

  static Map<String, dynamic> _decodeParams(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final Map<String, dynamic> result = <String, dynamic>{};
    for (final String pair in raw.split('&')) {
      final int eq = pair.indexOf('=');
      if (eq <= 0) continue;
      result[pair.substring(0, eq)] = pair.substring(eq + 1);
    }
    return result;
  }

  /// Branch may deliver the timestamp as `String` or `int`. Default to now.
  static int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? DateTime.now().millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  @override
  List<Object?> get props => <Object?>[route, pathParameters, queryParameters, timestamp];
}
