import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/firebase_setup.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/firebase/firebase_options_prod.dart';
import 'package:myungli_diary/core/firebase/firebase_options_staging.dart';
import 'package:myungli_diary/core/platform/firebase_app_check.dart';
import 'package:myungli_diary/core/platform/firebase_crash_reporter.dart';

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

final class _RecordingCrashlyticsApi implements CrashlyticsApi {
  final collection = <bool>[];

  @override
  Future<void> setCollectionEnabled({required bool enabled}) async =>
      collection.add(enabled);

  @override
  Future<void> recordError(Object exception, StackTrace stack) async {}

  @override
  Future<void> setUserIdentifier(String id) async {}

  @override
  Future<void> log(String message) async {}
}

void main() {
  test('debug 빌드는 Crashlytics 수집을 끄고 release는 켭니다', () async {
    final debug = _RecordingCrashlyticsApi();
    final release = _RecordingCrashlyticsApi();
    await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (_) async {},
      appCheck: _RecordingAppCheckApi(),
      crashlytics: debug,
    );
    await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (_) async {},
      appCheck: _RecordingAppCheckApi(),
      crashlytics: release,
      isDebug: false,
    );
    expect(debug.collection, [false]);
    expect(release.collection, [true]);
  });

  test('환경과 플랫폼에 맞는 설정으로 초기화합니다', () async {
    final used = <FirebaseOptions>[];
    final staging = await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (options) async => used.add(options),
      appCheck: _RecordingAppCheckApi(),
      crashlytics: _RecordingCrashlyticsApi(),
    );
    final prod = await initializeFirebase(
      env: FirebaseEnv.prod,
      platform: TargetPlatform.iOS,
      initialize: (options) async => used.add(options),
      appCheck: _RecordingAppCheckApi(),
      crashlytics: _RecordingCrashlyticsApi(),
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
      crashlytics: _RecordingCrashlyticsApi(),
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
      crashlytics: _RecordingCrashlyticsApi(),
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
      crashlytics: _RecordingCrashlyticsApi(),
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
      crashlytics: _RecordingCrashlyticsApi(),
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
      crashlytics: _RecordingCrashlyticsApi(),
    );
    expect(failure?.error, same(error));
  });

  test('App Check 활성화가 실패해도 debug의 Crashlytics 수집은 끕니다', () async {
    final crashlytics = _RecordingCrashlyticsApi();
    final failure = await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (_) async {},
      appCheck: _RecordingAppCheckApi(error: StateError('활성화 실패')),
      crashlytics: crashlytics,
    );
    expect(failure, isNotNull);
    expect(crashlytics.collection, [false]);
  });
}
