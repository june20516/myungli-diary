import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/firebase/firebase_options_prod.dart';
import 'package:myungli_diary/core/firebase/firebase_options_staging.dart';

void main() {
  group('firebaseEnvFromEnvironment', () {
    test('값을 주면 그 환경입니다', () {
      expect(
        firebaseEnvFromEnvironment(value: 'prod', isRelease: true),
        FirebaseEnv.prod,
      );
      expect(
        firebaseEnvFromEnvironment(value: 'staging', isRelease: true),
        FirebaseEnv.staging,
      );
    });

    test('debug에서 값이 없으면 staging', () {
      expect(firebaseEnvFromEnvironment(), FirebaseEnv.staging);
    });

    test('release에서 값이 없으면 StateError', () {
      expect(
        () => firebaseEnvFromEnvironment(isRelease: true),
        throwsStateError,
      );
    });

    test('모르는 값은 StateError', () {
      expect(() => firebaseEnvFromEnvironment(value: 'dev'), throwsStateError);
    });
  });

  group('firebaseOptionsFor', () {
    test('환경과 플랫폼에 맞는 설정입니다', () {
      expect(
        firebaseOptionsFor(FirebaseEnv.staging, TargetPlatform.android),
        firebaseStagingAndroid,
      );
      expect(
        firebaseOptionsFor(FirebaseEnv.staging, TargetPlatform.iOS),
        firebaseStagingIos,
      );
      expect(
        firebaseOptionsFor(FirebaseEnv.prod, TargetPlatform.android),
        firebaseProdAndroid,
      );
      expect(
        firebaseOptionsFor(FirebaseEnv.prod, TargetPlatform.iOS),
        firebaseProdIos,
      );
    });

    test('iOS·Android가 아니면 UnsupportedError', () {
      expect(
        () => firebaseOptionsFor(FirebaseEnv.staging, TargetPlatform.macOS),
        throwsUnsupportedError,
      );
    });

    test('두 환경은 서로 다른 프로젝트이고 번들 ID는 같습니다', () {
      expect(firebaseStagingAndroid.projectId, 'myungli-diary-staging');
      expect(firebaseProdAndroid.projectId, 'myungli-diary');
      expect(firebaseStagingIos.iosBundleId, 'app.myungli.diary');
      expect(firebaseProdIos.iosBundleId, 'app.myungli.diary');
    });
  });
}
