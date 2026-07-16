import 'dart:async';
import 'dart:convert';

import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

import 'package:app/common/util/logger.dart';
import 'package:app/data/database/abstract_database.dart';
import 'package:app/data/database/database_keys.dart';
import 'package:app/navigation/app_routers.dart';
import 'package:app/service/deep_link/deep_link_service.dart';
import 'package:app/service/deep_link/models/deep_link_data.dart';

/// The ONLY file that imports the link vendor SDK. Everything else depends on
/// [DeepLinkService] + [DeepLinkData]. Swap this class to change vendors.
///
/// Rename anchors: none — this is infrastructure. `AbstractDatabase` /
/// `DatabaseKeys` are your cache/database layer (see `07-cache-database.md`).
class BranchDeepLinkService implements DeepLinkService {
  BranchDeepLinkService(this._database);

  final AbstractDatabase _database;

  final StreamController<DeepLinkData> _navController = StreamController<DeepLinkData>.broadcast();
  StreamSubscription<Map<dynamic, dynamic>>? _sessionSub;

  @override
  Stream<DeepLinkData> get navigationStream => _navController.stream;

  @override
  Future<void> initialize() async {
    // Drop any non-persistent leftover from a prior run before listening.
    await _database.deleteNonPersistent(DatabaseKeys.storedDeepLink.name);
    _sessionSub = FlutterBranchSdk.listSession().listen(_onSessionData, onError: _onSessionError);
  }

  void _onSessionData(Map<dynamic, dynamic> data) {
    // Branch emits empty / heartbeat maps — ignore them or you navigate to the
    // fallback route on every cold start.
    if (!_isValidSession(data)) {
      logger.d('🔗 SERVICE: ignored empty/heartbeat Branch session');
      return;
    }
    final Map<String, dynamic> stringKeyed = _toStringKeyedMap(data);
    final DeepLinkData link = DeepLinkData.fromBranchData(stringKeyed);
    logger.d('🔗 SERVICE: resolved link route=${link.route.name}');
    unawaited(
      processDeepLink(link).catchError(
        (Object e) => _navController.addError(DeepLinkServiceException('auto-process failed: $e')),
      ),
    );
  }

  void _onSessionError(Object error, StackTrace stackTrace) {
    logger.e('🔗 SERVICE: Branch session error', error: error, stackTrace: stackTrace);
    _navController.addError(DeepLinkServiceException('session error: $error'));
  }

  @override
  Future<void> processDeepLink(DeepLinkData data) async {
    await storeDeepLink(data); // persist FIRST: survives kill / pre-auth
    _navController.add(data); // then emit to the cubit
  }

  @override
  Future<String> generateShortUrl({
    required AppRouter route,
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    String? title,
    String? description,
    String? imageUrl,
  }) async {
    final BranchUniversalObject buo = BranchUniversalObject(
      canonicalIdentifier: 'app_${route.name}_${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'App',
      contentDescription: description ?? '',
      imageUrl: imageUrl ?? '',
      contentMetadata: BranchContentMetaData()
        ..addCustomMetadata('route', route.name)
        ..addCustomMetadata('pathParameters', _encodeParams(pathParameters))
        ..addCustomMetadata('queryParameters', _encodeParams(queryParameters)),
    );
    final BranchLinkProperties props = BranchLinkProperties(feature: 'sharing', campaign: route.name);

    final BranchResponse res = await FlutterBranchSdk.getShortUrl(buo: buo, linkProperties: props);
    if (res.success) return res.result?.toString() ?? '';
    throw DeepLinkServiceException(res.errorMessage ?? 'short url generation failed');
  }

  @override
  Future<void> storeDeepLink(DeepLinkData data) async {
    await _database.writeNonPersistent(DatabaseKeys.storedDeepLink.name, jsonEncode(data.toJson()));
  }

  @override
  Future<DeepLinkData?> getStoredDeepLink() async {
    final String? raw = await _database.readNonPersistent(DatabaseKeys.storedDeepLink.name);
    if (raw == null || raw.isEmpty) return null;
    return DeepLinkData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> clearStoredDeepLink() async {
    await _database.deleteNonPersistent(DatabaseKeys.storedDeepLink.name);
  }

  @override
  Future<bool> hasStoredDeepLinks() async => (await getStoredDeepLink()) != null;

  @override
  Future<void> handleLogout() async => clearStoredDeepLink();

  @override
  void dispose() {
    _sessionSub?.cancel();
    _navController.close();
  }

  // --- helpers ---

  bool _isValidSession(Map<dynamic, dynamic> data) {
    if (data.isEmpty) return false;
    // Branch flags a real click-through; a heartbeat has neither.
    final bool clicked = data['+clicked_branch_link'] == true;
    final bool hasRoute = data.containsKey('route');
    return clicked || hasRoute;
  }

  /// Branch returns `Map<dynamic, dynamic>` with nested maps / lists. Recurse
  /// into a `Map<String, dynamic>` before parsing.
  Map<String, dynamic> _toStringKeyedMap(Map<dynamic, dynamic> input) {
    return input.map((dynamic key, dynamic value) {
      final dynamic converted = value is Map
          ? _toStringKeyedMap(value)
          : value is List
              ? value.map((dynamic e) => e is Map ? _toStringKeyedMap(e) : e).toList()
              : value;
      return MapEntry<String, dynamic>('$key', converted);
    });
  }

  String _encodeParams(Map<String, dynamic> params) =>
      params.entries.map((MapEntry<String, dynamic> e) => '${e.key}=${e.value}').join('&');
}
