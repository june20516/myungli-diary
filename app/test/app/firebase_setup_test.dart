import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/firebase_setup.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/firebase/firebase_options_prod.dart';
import 'package:myungli_diary/core/firebase/firebase_options_staging.dart';

void main() {
  test('환경과 플랫폼에 맞는 설정으로 초기화합니다', () async {
    final used = <FirebaseOptions>[];
    final staging = await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (options) async => used.add(options),
    );
    final prod = await initializeFirebase(
      env: FirebaseEnv.prod,
      platform: TargetPlatform.iOS,
      initialize: (options) async => used.add(options),
    );
    expect(staging, isNull);
    expect(prod, isNull);
    expect(used, [firebaseStagingAndroid, firebaseProdIos]);
  });

  test('초기화가 실패하면 오류를 돌려주고 던지지 않습니다', () async {
    final error = FirebaseException(plugin: 'core', message: '실패');
    final failure = await initializeFirebase(
      env: FirebaseEnv.staging,
      platform: TargetPlatform.android,
      initialize: (_) async => throw error,
    );
    expect(failure?.error, same(error));
  });
}
