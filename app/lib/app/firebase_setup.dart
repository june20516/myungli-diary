import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/platform/firebase_app_check.dart';
import 'package:myungli_diary/core/platform/firebase_crash_reporter.dart';

/// Firebase 기본 앱을 [options]로 초기화합니다(기본값).
Future<void> firebaseInitializeApp(FirebaseOptions options) =>
    Firebase.initializeApp(options: options);

/// [env] 프로젝트의 [platform] 설정으로 Firebase를 초기화하고 App Check를
/// 켭니다(결정 A93, A95).
///
/// 네이티브 설정 파일 없이 Dart 설정으로 초기화합니다. App Check provider는
/// [appCheckModeFor]가 고르고, debug provider에만 [debugToken]
/// (`APP_CHECK_DEBUG_TOKEN` dart-define, 비면 SDK가 첫 실행 때 만든 토큰)을
/// 넘깁니다(#659). Crashlytics 수집은 release에서만 켭니다. 어느 단계든
/// 실패하면 오류와 stack을 돌려주고 앱 시작은 막지 않습니다(Firebase를 쓰는
/// 기능만 실패로 끝남). 성공하면 null입니다.
Future<({Object error, StackTrace stack})?> initializeFirebase({
  required FirebaseEnv env,
  required TargetPlatform platform,
  Future<void> Function(FirebaseOptions options) initialize =
      firebaseInitializeApp,
  AppCheckApi appCheck = const SdkAppCheckApi(),
  CrashlyticsApi crashlytics = const SdkCrashlyticsApi(),
  bool isDebug = kDebugMode,
  // release에서는 상수 접힘으로 빠져 토큰 문자열이 바이너리에 남지 않습니다.
  String debugToken = kDebugMode
      ? const String.fromEnvironment('APP_CHECK_DEBUG_TOKEN')
      : '',
}) async {
  try {
    await initialize(firebaseOptionsFor(env, platform));
  } on Object catch (error, stack) {
    return (error: error, stack: stack);
  }
  final mode = appCheckModeFor(env: env, isDebug: isDebug);
  // 두 단계는 서로 막지 않습니다. 하나가 실패해도 나머지를 하고 첫 실패를 돌려줍니다.
  final steps = <Future<void> Function()>[
    () => crashlytics.setCollectionEnabled(enabled: !isDebug),
    () => appCheck.activate(
      mode: mode,
      debugToken: mode == AppCheckMode.debug && debugToken.isNotEmpty
          ? debugToken
          : null,
    ),
  ];
  ({Object error, StackTrace stack})? failure;
  for (final step in steps) {
    try {
      await step();
    } on Object catch (error, stack) {
      failure ??= (error: error, stack: stack);
    }
  }
  return failure;
}
