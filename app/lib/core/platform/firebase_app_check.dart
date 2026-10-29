import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/platform/app_check.dart';

/// App Check provider 종류.
enum AppCheckMode {
  /// Firebase 콘솔에 등록한 debug token(staging debug 빌드 전용, server S24).
  debug,

  /// 기기 증명(Android Play Integrity, iOS DeviceCheck). App Attest는
  /// entitlement와 콘솔 등록이 생기면 바꿉니다.
  attest,
}

/// [env]와 빌드 모드에 맞는 provider 종류.
///
/// debug 빌드이고 staging일 때만 [AppCheckMode.debug]입니다. release는
/// staging(비공개 테스트)이어도 기기 증명을 써서 debug provider와 토큰이 배포
/// 빌드에 들어가지 않게 합니다(#659).
AppCheckMode appCheckModeFor({
  required FirebaseEnv env,
  bool isDebug = kDebugMode,
}) => isDebug && env == FirebaseEnv.staging
    ? AppCheckMode.debug
    : AppCheckMode.attest;

/// Firebase App Check SDK 경계. SDK 호출을 그대로 옮기기만 하고 분기는
/// [FirebaseAppCheckAdapter]와 `initializeFirebase`에 둡니다.
abstract interface class AppCheckApi {
  /// [mode]의 provider로 App Check를 켭니다. [debugToken]이 null이면 SDK가 첫
  /// 실행 때 만든 토큰을 로그에 찍습니다.
  Future<void> activate({required AppCheckMode mode, String? debugToken});

  /// 지금 쓸 App Check 토큰. 없으면 null.
  Future<String?> getToken();
}

/// 실제 Firebase App Check SDK를 부르는 경계(기본값).
final class SdkAppCheckApi implements AppCheckApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<void> activate({required AppCheckMode mode, String? debugToken}) =>
      switch (mode) {
        AppCheckMode.debug => FirebaseAppCheck.instance.activate(
          providerAndroid: AndroidDebugProvider(debugToken: debugToken),
          providerApple: AppleDebugProvider(debugToken: debugToken),
        ),
        // 기본 provider가 Android Play Integrity, iOS DeviceCheck입니다.
        AppCheckMode.attest => FirebaseAppCheck.instance.activate(),
      };

  @override
  Future<String?> getToken() => FirebaseAppCheck.instance.getToken();
}

/// App Check의 실제 구현(#657).
///
/// 토큰을 받지 못하면(SDK 오류, Firebase 초기화 실패, [timeout] 초과) null을
/// 돌려주고, 요청은 `X-Firebase-AppCheck` 없이 나갑니다. 막을지는 server가
/// 정합니다.
final class FirebaseAppCheckAdapter implements AppCheck {
  /// adapter를 만듭니다.
  const new({
    this.api = const SdkAppCheckApi(),
    this.timeout = const Duration(seconds: 3),
  });

  /// SDK 경계.
  final AppCheckApi api;

  /// 토큰을 기다리는 최대 시간.
  final Duration timeout;

  @override
  Future<String?> token() async {
    try {
      return await api.getToken().timeout(timeout);
    } on Object {
      return null;
    }
  }
}
