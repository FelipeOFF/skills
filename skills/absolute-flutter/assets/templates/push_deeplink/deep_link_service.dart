import 'package:app/navigation/app_routers.dart';
import 'package:app/service/deep_link/models/deep_link_data.dart';

/// Vendor-agnostic deep-link contract. EVERY consumer (the cubit, use cases,
/// features) depends ONLY on this interface plus [DeepLinkData] — never on a
/// concrete SDK. WHY: the link vendor can be swapped (Branch ->
/// app_links / Firebase Dynamic Links) without touching any consumer.
///
/// The concrete implementation lives in `impl/` and is the ONLY file allowed to
/// import the vendor SDK. DI binds this interface to that impl as a singleton.
abstract interface class DeepLinkService {
  /// Emits a typed [DeepLinkData] every time an inbound link is resolved. The
  /// cubit listens here and decides when to actually navigate.
  Stream<DeepLinkData> get navigationStream;

  /// Start listening for inbound links. Call once, after DI is ready. A vendor
  /// init failure must NOT block app launch (catch + continue at the call site).
  Future<void> initialize();

  /// Build a shareable short URL for [route] + params. Throws
  /// [DeepLinkServiceException] on failure.
  Future<String> generateShortUrl({
    required AppRouter route,
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    String? title,
    String? description,
    String? imageUrl,
  });

  /// Persist-then-emit: store the link, then push it onto [navigationStream].
  Future<void> processDeepLink(DeepLinkData data);

  /// Persist a link so it survives app kill and the unauthenticated state.
  Future<void> storeDeepLink(DeepLinkData data);

  Future<DeepLinkData?> getStoredDeepLink();

  Future<void> clearStoredDeepLink();

  Future<bool> hasStoredDeepLinks();

  /// Clear pending links on logout so a previous session's link does not fire
  /// for the next user.
  Future<void> handleLogout();

  void dispose();
}

/// The single error type this service surfaces. Consumers add it to the stream
/// or rethrow; they never leak a vendor-specific error.
class DeepLinkServiceException implements Exception {
  const DeepLinkServiceException(this.message);

  final String message;

  @override
  String toString() => 'DeepLinkServiceException: $message';
}
