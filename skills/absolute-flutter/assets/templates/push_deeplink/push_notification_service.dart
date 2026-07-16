import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:app/common/util/logger.dart';
import 'package:app/data/database/abstract_database.dart';
import 'package:app/di/app_di.dart';
import 'package:app/domain/notification/save_push_token_use_case.dart';
import 'package:app/firebase/firebase_options.dart';
import 'package:app/model/api/common/push_response_dto.dart';

/// Push notification facade (FCM + flutter_local_notifications).
///
/// Rename anchors: `App` -> the real app name (`AppPushNotificationService` ->
/// `<Name>PushNotificationService`). Keep the file-level (`_*`) plugin, channel,
/// and re-entrancy flags exactly as they are — they are NOT instance fields on
/// purpose (the background isolate cannot see instance state; see Gotchas in
/// `12-push-deeplink.md`).
///
/// Design: Firebase delivers a DATA-ONLY message; the app renders the visible
/// notification itself via local notifications. WHY: one render path for
/// foreground + background, full control over large icon / image / badge /
/// channel, and a tap payload that is a DB lookup key rather than the full DTO.

const String _defaultIcon = '@drawable/ic_notification';

/// File-level plugin instance. MUST be top-level (not an instance field) so the
/// background isolate's entry-point functions can reach it.
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

/// The single Android channel. Its id/name/importance MUST match the
/// `default_notification_channel_id` meta-data in `AndroidManifest.xml`
/// (see `platform_setup.md`) or background notifications land on no channel.
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel',
  'App Notification',
  description: 'General notifications',
  importance: Importance.high,
);

/// Re-entrancy guards for the background isolate. Static-style top-level bools:
/// the isolate shares no state with the UI isolate, so it re-bootstraps once and
/// these flags stop a double-init of Firebase / DI / the plugin.
bool _isBasicInfraSetup = false;
bool _isBackgroundEnvInitialized = false;

/// A listener returns [NotificationEventResume.finish] to CONSUME the event
/// (it is removed from the retroactive queue) or [NotificationEventResume.unFinish]
/// to let later listeners also see it.
enum NotificationEventResume { finish, unFinish }

typedef OnNotificationEvent = Future<NotificationEventResume> Function(PushResponseDto response);

class AppPushNotificationService {
  AppPushNotificationService._internal();

  static final AppPushNotificationService _instance = AppPushNotificationService._internal();

  factory AppPushNotificationService() => _instance;

  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final List<OnNotificationEvent> _listeners = <OnNotificationEvent>[];

  /// Retroactive queue: tap events that arrive before a feature registers its
  /// listener are buffered and replayed on registration (see [addOnNotificationEvent]).
  final List<PushResponseDto> _pendingResponses = <PushResponseDto>[];

  /// Foreground bootstrap. Call AFTER `Firebase.initializeApp`, from app start.
  /// Does NOT register the background handler — that is done earlier, see
  /// [registerBackgroundMessageHandler] and `bootstrap_snippet.dart`.
  Future<void> init() async {
    await _requestPermissions();
    _initLocalNotificationsPlugin();
    await _createChannel();
    await _messaging.subscribeToTopic('all');
    _listenForeground();
    _listenTokenRefresh();
  }

  /// MUST be called BEFORE `Firebase.initializeApp` and before any UI. The
  /// handler is a top-level function ([appBackgroundMessageHandler]) — never a
  /// closure or instance method, or it will not run in the background isolate.
  void registerBackgroundMessageHandler() {
    FirebaseMessaging.onBackgroundMessage(appBackgroundMessageHandler);
  }

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final PushResponseDto dto = PushResponseDto.fromJson(message.data);
    await _savePushResponseToDb(dto);
    await _showNotification(message, dto);
  }

  void _initLocalNotificationsPlugin() {
    _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(_defaultIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Tap handler. The payload is just the DTO's `code` (a DB lookup key) — the
  /// full DTO is rehydrated from the local store and fanned out to listeners.
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    final String? code = response.payload;
    if (code == null) return;
    final PushResponseDto? dto = await _readPushResponseFromDb(code);
    if (dto != null) await _fanOut(dto);
  }

  void _listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((String token) async {
      final result = await AppDI.it.get<SavePushTokenUseCase>()(token);
      result.fold(
        (failure) => logger.e('🔔 PUSH: save token failed: $failure'),
        (_) => logger.d('🔔 PUSH: token saved'),
      );
    });
  }

  Future<AuthorizationStatus> _requestPermissions() async {
    final NotificationSettings settings = await _messaging.requestPermission(
      provisional: true,
      criticalAlert: true,
    );
    return settings.authorizationStatus;
  }

  /// Register a tap listener. Any buffered tap events that fired before this
  /// listener existed are replayed immediately; a listener returning `finish`
  /// consumes the buffered event.
  Future<void> addOnNotificationEvent(OnNotificationEvent event) async {
    _listeners.add(event);
    for (final PushResponseDto pending in List<PushResponseDto>.of(_pendingResponses)) {
      if (await event(pending) == NotificationEventResume.finish) {
        _pendingResponses.remove(pending);
        break;
      }
    }
  }

  void removeOnNotificationEvent(OnNotificationEvent event) => _listeners.remove(event);

  Future<void> _fanOut(PushResponseDto response) async {
    _pendingResponses.add(response);
    for (final OnNotificationEvent listener in List<OnNotificationEvent>.of(_listeners)) {
      if (await listener(response) == NotificationEventResume.finish) {
        _pendingResponses.remove(response);
        break;
      }
    }
  }

  Future<String?> getToken() => _messaging.getToken();
}

// ---------------------------------------------------------------------------
// SHARED notification rendering. Top-level so both the foreground path and the
// background isolate use the SAME code path. Keep these top-level.
// ---------------------------------------------------------------------------

Future<void> _createChannel() async {
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
}

Future<void> _showNotification(RemoteMessage message, PushResponseDto dto) async {
  final AndroidBitmap<Object>? largeIcon = await _downloadAndroidBitmap(dto.image);
  final String? iosAttachmentPath = await _downloadIosAttachment(dto.image);

  final NotificationDetails details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      icon: dto.icon ?? _defaultIcon,
      colorized: true,
      color: const Color(0xFF222222),
      largeIcon: largeIcon,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      subtitle: dto.message,
      interruptionLevel: InterruptionLevel.active,
      badgeNumber: int.tryParse(message.notification?.apple?.badge ?? '0') ?? 0,
      attachments: iosAttachmentPath != null
          ? <DarwinNotificationAttachment>[DarwinNotificationAttachment(iosAttachmentPath)]
          : null,
    ),
  );

  // payload = dto.code: a DB lookup key, NOT the full DTO (avoids payload-size
  // limits and keeps a tap-event log).
  await _localNotifications.show(message.hashCode, dto.title, dto.message, details, payload: dto.code);
}

/// Decode a base64 / network image into an Android large icon. Returns null on
/// any failure so the notification still shows without the bitmap.
Future<AndroidBitmap<Object>?> _downloadAndroidBitmap(String? source) async {
  if (source == null || source.isEmpty) return null;
  try {
    final Uint8List bytes = base64Decode(source);
    return ByteArrayAndroidBitmap(bytes);
  } catch (e, st) {
    logger.e('🔔 PUSH: android bitmap decode failed', error: e, stackTrace: st);
    return null;
  }
}

/// Pre-download the image to a temp file for a Darwin attachment. The native
/// Notification Service Extension also attaches rich media — this covers the
/// foreground / local-only path. Returns null on any failure.
Future<String?> _downloadIosAttachment(String? source) async {
  if (!Platform.isIOS || source == null || source.isEmpty) return null;
  try {
    final Uint8List bytes = base64Decode(source);
    final Directory dir = Directory.systemTemp.createTempSync('notification_attachments');
    final File file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e, st) {
    logger.e('🔔 PUSH: ios attachment write failed', error: e, stackTrace: st);
    return null;
  }
}

// --- local store helpers (back these with your cache/database layer) ---

Future<void> _savePushResponseToDb(PushResponseDto dto) async {
  await AppDI.it.get<AbstractDatabase>().write('events_happened_${dto.code}', jsonEncode(dto.toJson()));
}

Future<PushResponseDto?> _readPushResponseFromDb(String code) async {
  final String? raw = await AppDI.it.get<AbstractDatabase>().read('events_happened_$code');
  if (raw == null) return null;
  return PushResponseDto.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

// ---------------------------------------------------------------------------
// BACKGROUND ISOLATE ENTRY POINTS
// Top-level, @pragma('vm:entry-point'). They run in a SEPARATE isolate that
// shares no state with the UI isolate, so they must re-bootstrap Firebase + DI
// + the plugin, guarded by the static flags above.
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> appBackgroundMessageHandler(RemoteMessage message) async {
  if (!_isBasicInfraSetup) await _ensureBackgroundEnv();
  final PushResponseDto dto = PushResponseDto.fromJson(message.data);
  await _savePushResponseToDb(dto);
  await _showNotification(message, dto);
}

@pragma('vm:entry-point')
Future<void> _ensureBackgroundEnv() async {
  if (_isBackgroundEnvInitialized) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  await AppDI.setupBasicInfrastructure();

  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings(_defaultIcon),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await _createChannel();

  _isBackgroundEnvInitialized = true;
  _isBasicInfraSetup = true;
}
