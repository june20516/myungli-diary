import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/firebase/firebase_options_prod.dart';
import 'package:myungli_diary/core/firebase/firebase_options_staging.dart';

/// 앱이 쓰는 Firebase 프로젝트(결정 A93).
///
/// App Check 토큰은 앱이 붙는 server의 Firebase 프로젝트와 같아야 하므로, 빌드 모드가 아니라
/// API 주소처럼 빌드 값(`FIREBASE_ENV`)으로 고릅니다. 비공개 테스트용 release 빌드가 staging
/// server에 붙을 수 있기 때문입니다.
enum FirebaseEnv {
  /// `myungli-diary-staging`.
  staging,

  /// `myungli-diary`.
  prod,
}

/// `FIREBASE_ENV` dart-define을 읽습니다.
///
/// debug에서 값이 없으면 staging이고, release에서 값이 없거나 모르는 값이면 [StateError]입니다.
FirebaseEnv firebaseEnvFromEnvironment({
  String value = const String.fromEnvironment('FIREBASE_ENV'),
  bool isRelease = kReleaseMode,
}) {
  if (value.isEmpty) {
    if (isRelease) {
      throw StateError('release 빌드에는 FIREBASE_ENV(staging, prod)가 필요합니다.');
    }
    return FirebaseEnv.staging;
  }
  return FirebaseEnv.values.firstWhere(
    (env) => env.name == value,
    orElse: () =>
        throw StateError('FIREBASE_ENV는 staging, prod 중 하나여야 합니다: $value'),
  );
}

/// [env] 프로젝트의 [platform] 앱 설정. 앱은 iOS·Android 전용입니다.
FirebaseOptions firebaseOptionsFor(FirebaseEnv env, TargetPlatform platform) =>
    switch ((env, platform)) {
      (FirebaseEnv.staging, TargetPlatform.android) => firebaseStagingAndroid,
      (FirebaseEnv.staging, TargetPlatform.iOS) => firebaseStagingIos,
      (FirebaseEnv.prod, TargetPlatform.android) => firebaseProdAndroid,
      (FirebaseEnv.prod, TargetPlatform.iOS) => firebaseProdIos,
      _ => throw UnsupportedError('Firebase는 iOS·Android만 씁니다: $platform'),
    };
