import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/platform/firebase_app_check.dart';

/// Firebase 기본 앱을 [options]로 초기화합니다(기본값).
Future<void> firebaseInitializeApp(FirebaseOptions options) =>
    Firebase.initializeApp(options: options);

/// [env] 프로젝트의 [platform] 설정으로 Firebase를 초기화하고 App Check를
/// 켭니다(결정 A93, A95).
///
/// 네이티브 설정 파일 없이 Dart 설정으로 초기화합니다. App Check provider는
/// [appCheckModeFor]가 고르고, debug provider에만 [debugToken]
/// (`APP_CHECK_DEBUG_TOKEN` dart-define, 비면 SDK가 첫 실행 때 만든 토큰)을
/// 넘깁니다(#659). 어느 단계든 실패하면 오류와 stack을 돌려주고 앱 시작은
/// 막지 않습니다(Firebase를 쓰는 기능만 실패로 끝남). 성공하면 null입니다.
Future<({Object error, StackTrace stack})?> initializeFirebase({
  required FirebaseEnv env,
  required TargetPlatform platform,
  Future<void> Function(FirebaseOptions options) initialize =
      firebaseInitializeApp,
  AppCheckApi appCheck = const SdkAppCheckApi(),
  bool isDebug = kDebugMode,
  String debugToken = const String.fromEnvironment('APP_CHECK_DEBUG_TOKEN'),
}) async {
  try {
    await initialize(firebaseOptionsFor(env, platform));
    final mode = appCheckModeFor(env: env, isDebug: isDebug);
    await appCheck.activate(
      mode: mode,
      debugToken: mode == AppCheckMode.debug && debugToken.isNotEmpty
          ? debugToken
          : null,
    );
    return null;
  } on Object catch (error, stack) {
    return (error: error, stack: stack);
  }
}
