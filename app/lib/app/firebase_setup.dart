import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';

/// Firebase 기본 앱을 [options]로 초기화합니다(기본값).
Future<void> firebaseInitializeApp(FirebaseOptions options) =>
    Firebase.initializeApp(options: options);

/// [env] 프로젝트의 [platform] 설정으로 Firebase를 초기화합니다(결정 A93).
///
/// 네이티브 설정 파일 없이 Dart 설정으로 초기화합니다. 실패하면 오류와 stack을 돌려주고
/// 앱 시작은 막지 않습니다(Firebase를 쓰는 기능만 실패로 끝남). 성공하면 null입니다.
Future<({Object error, StackTrace stack})?> initializeFirebase({
  required FirebaseEnv env,
  required TargetPlatform platform,
  Future<void> Function(FirebaseOptions options) initialize =
      firebaseInitializeApp,
}) async {
  try {
    await initialize(firebaseOptionsFor(env, platform));
    return null;
  } on Object catch (error, stack) {
    return (error: error, stack: stack);
  }
}
