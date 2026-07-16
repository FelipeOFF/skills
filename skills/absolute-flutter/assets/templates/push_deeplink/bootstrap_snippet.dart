import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

import 'package:app/common/util/logger.dart';
import 'package:app/config/environment.dart';
import 'package:app/di/app_di.dart';
import 'package:app/firebase/firebase_options.dart';
import 'package:app/push/push_notification_service.dart';

/// Bootstrap ORDER for push + deep link. The order is correctness, not style —
/// see the Gotchas in `12-push-deeplink.md`.
///
/// Rename anchors: `App` -> the real app name. `Environment` is your env config.
Future<void> bootstrap(Environment environment) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Register the background message handler BEFORE Firebase.initializeApp and
  //    before any UI. It binds the top-level @pragma('vm:entry-point') handler.
  AppPushNotificationService().registerBackgroundMessageHandler();

  // 2) Initialize Firebase.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3) App DI / infrastructure.
  await AppDI.setup(environment);

  // 4) Foreground push: permissions, channel, topic, token-refresh, fg listener.
  await AppPushNotificationService().init();

  // 5) Initialize the link vendor ASYNC and NON-BLOCKING. A Branch init failure
  //    must never block app launch — catch and continue.
  unawaited(_initBranch(environment));

  runApp(const AppRoot());
}

Future<void> _initBranch(Environment environment) async {
  try {
    await FlutterBranchSdk.init(enableLogging: environment.isLoggingEnabled);
  } catch (e, st) {
    logger.e('🔗 BOOTSTRAP: Branch init failed (continuing)', error: e, stackTrace: st);
  }
}

/// Placeholder root widget. In the real app this wires the DeepLinkService and
/// the DeepLinkNavigationCubit, and calls `DeepLinkService.initialize()` from a
/// post-frame callback in the root widget's `initState`.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
