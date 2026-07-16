// Base Dio client for the whole app. Clients ARE Dio instances (inheritance,
// not composition): every repository types its dependency as one of the
// abstract client families below and calls `.get` / `.post` directly. This file
// owns BaseOptions, the HTTP/1.1-vs-HTTP/2 adapter choice, the SSL pinning hook,
// and the (load-bearing) interceptor assembly order.
//
// Rename anchors: none here — this base is reused verbatim. Concrete singletons
// live in `app_client.dart`. `Url`, `Environment`, and the interceptor types are
// project symbols imported as package:app/...

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:app/gateway/interceptor/api_key_interceptor.dart';
import 'package:app/gateway/interceptor/debug_interceptor.dart';
import 'package:app/gateway/interceptor/encrypt_interceptor.dart';
import 'package:app/gateway/interceptor/retry_interceptor.dart';
import 'package:app/gateway/model/url.dart';
import 'package:app/gateway/util/constants.dart';
import 'package:app/main/environment.dart';

/// The single base every HTTP client extends. `extends DioForNative` means the
/// instance IS a Dio: repositories depend on a thin `Dio`-typed surface and need
/// no per-endpoint wrapper method.
abstract class AbstractGateway extends DioForNative {
  /// Resolved at construction by the concrete client (usually from Environment).
  abstract final Url url;

  /// When true, the EncryptInterceptor is added and an api key is required.
  final bool isEnableEncrypt;

  /// Optional api key; presence adds the ApiKeyInterceptor.
  final String? apiKey;

  AbstractGateway({this.isEnableEncrypt = false, this.apiKey}) : super() {
    if (isEnableEncrypt && apiKey == null) {
      throw StateError('Encryption requires an api key.');
    }
    options = getBaseOptions();
    _configureConnection();
    interceptors.addAll(_getInterceptors().whereType<Interceptor>());
  }

  BaseOptions getBaseOptions() => BaseOptions(
        baseUrl: '${url.baseHost}${url.port != null ? ':${url.port}' : ''}',
        sendTimeout: kSendTimeout,
        connectTimeout: kConnectTimeout,
        receiveTimeout: kReceiveTimeout,
        persistentConnection: true,
        headers: const {
          'Connection': 'keep-alive',
          'Keep-Alive': 'timeout=30, max=100',
        },
      );

  /// HTTP/2 by default; fall back to HTTP/1.1 only for a local mock host.
  void _configureConnection() {
    if (url.isLocalMock) {
      httpClientAdapter = IOHttpClientAdapter();
      return;
    }
    _configureHttp2Connection();
  }

  void _configureHttp2Connection() {
    final Environment env = GetIt.instance.get<Environment>();
    httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 60),
        onClientCreate: (Uri uri, ClientSetting config) async {
          if (!env.isEnableSslPinning) {
            // Non-prod: accept self-signed certs from staging hosts.
            config.onBadCertificate = (_) => true;
            return;
          }
          // Prod: pin the bundled certificate chain. SSL PINNING HOOK.
          final SecurityContext context = SecurityContext(withTrustedRoots: true);
          final String? certificatePem = url.credential?.certificatePem;
          if (certificatePem != null) {
            context.useCertificateChainBytes(await _loadAssetBytes(certificatePem));
          }
          config.context = context;
        },
      ),
    );
  }

  Future<List<int>> _loadAssetBytes(String assetPath) async {
    // Replace with rootBundle.load in the real app; kept dependency-light here.
    final File file = File(assetPath);
    return file.readAsBytes();
  }

  /// Order is load-bearing: debug capture FIRST (sees the full request/response),
  /// then retry, then logging, then encrypt, then apiKey, then the subclass
  /// extras (LoggedClient injects refresh-before-token here). `.whereType`
  /// downstream filters the nullable slots.
  List<Interceptor?> _getInterceptors() => <Interceptor?>[
        if (kDebugMode) DebugInterceptor(),
        RetryInterceptor(),
        getLogger(),
        if (isEnableEncrypt) EncryptInterceptor(apiKey!),
        if (apiKey != null) ApiKeyInterceptor(apiKey!),
        ...additionalInterceptors,
      ];

  /// Logging hook; concrete clients can override to swap or silence the logger.
  Interceptor? getLogger() => null;

  /// Extension point: LoggedClient overrides this to append auth interceptors.
  List<Interceptor?> get additionalInterceptors => const <Interceptor?>[];
}

/// Public-endpoint family: no auth, no refresh. Marker subclass.
abstract class NonLoggedClient extends AbstractGateway {
  NonLoggedClient({super.isEnableEncrypt, super.apiKey});
}

/// Authenticated family: appends refresh + token interceptors. Order in
/// `additionalInterceptors` is intentional — refresh BEFORE token injection.
abstract class LoggedClient extends AbstractGateway {
  LoggedClient({super.isEnableEncrypt, super.apiKey});

  Interceptor? getTokenInterceptor();
  Interceptor? getRefreshTokenInterceptor();

  @override
  List<Interceptor?> get additionalInterceptors => <Interceptor?>[
        getRefreshTokenInterceptor(),
        getTokenInterceptor(),
      ];
}
