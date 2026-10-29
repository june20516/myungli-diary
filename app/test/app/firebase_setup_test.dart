import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/firebase_setup.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/firebase/firebase_options_prod.dart';
import 'package:myungli_diary/core/firebase/firebase_options_staging.dart';
import 'package:myungli_diary/core/platform/firebase_app_check.dart';

final class _RecordingAppCheckApi implements AppCheckApi {
  new({this.error});

  final Error? error;
  final activations = <(AppCheckMode, String?)>[];

  @override
  Future<void> activate({
    required AppCheckMode mode,
    String? debugToken,
  }) async {
    activations.add((mode, debugToken));
    if (error case final error?) throw error;
  }

  @override
  Future<String?> getToken() async => null;
}

void main() {
  test('환경과 플랫폼에 맞는 설정으로 초기화합니다', () async {
    final used = <FirebaseOptions>[];
    final staging = await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (options) async => used.add(options),
      appCheck: _RecordingAppCheckApi(),
    );
    final prod = await initializeFirebase(
      env: FirebaseEnv.prod,
      platform: TargetPlatform.iOS,
      initialize: (options) async => used.add(options),
      appCheck: _RecordingAppCheckApi(),
    );
    expect(staging, isNull);
    expect(prod, isNull);
    expect(used, [firebaseStagingAndroid, firebaseProdIos]);
  });

  test('초기화가 실패하면 오류를 돌려주고 던지지 않습니다', () async {
    final error = FirebaseException(plugin: 'core', message: '실패');
    final appCheck = _RecordingAppCheckApi();
    final failure = await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (_) async => throw error,
      appCheck: appCheck,
    );
    expect(failure?.error, same(error));
    expect(appCheck.activations, isEmpty);
  });

  test('Firebase 초기화 뒤 App Check를 한 번 활성화합니다', () async {
    final appCheck = _RecordingAppCheckApi();
    final failure = await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (_) async {},
      appCheck: appCheck,
      debugToken: 'debug-token',
    );
    expect(failure, isNull);
    expect(appCheck.activations, [(AppCheckMode.debug, 'debug-token')]);
  });

  test('debug token이 비면 null로 넘깁니다(SDK가 첫 실행 토큰을 만듦)', () async {
    final appCheck = _RecordingAppCheckApi();
    await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (_) async {},
      appCheck: appCheck,
    );
    expect(appCheck.activations, [(AppCheckMode.debug, null)]);
  });

  test('attest 모드에는 debug token을 넘기지 않습니다', () async {
    final appCheck = _RecordingAppCheckApi();
    await initializeFirebase(
      env: FirebaseEnv.prod,
      platform: TargetPlatform.android,
      initialize: (_) async {},
      appCheck: appCheck,
      isDebug: false,
      debugToken: 'debug-token',
    );
    expect(appCheck.activations, [(AppCheckMode.attest, null)]);
  });

  test('App Check 활성화 실패는 failure로 돌려주고 던지지 않습니다', () async {
    final error = StateError('활성화 실패');
    final failure = await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (_) async {},
      appCheck: _RecordingAppCheckApi(error: error),
    );
    expect(failure?.error, same(error));
  });
}
