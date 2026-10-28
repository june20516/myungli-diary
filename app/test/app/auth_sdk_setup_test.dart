import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/auth_sdk_setup.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/platform/apple_native_auth.dart';
import 'package:myungli_diary/core/platform/apple_web_auth.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/google_auth.dart';
import 'package:myungli_diary/core/platform/kakao_auth.dart';
import 'package:myungli_diary/core/platform/line_auth.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

AuthConfig _config({String kakao = '', String line = ''}) => AuthConfig(
  kakaoNativeAppKey: kakao,
  lineChannelId: line,
  googleIosClientId: '',
  googleServerClientId: '',
  appleServicesId: '',
  appleRedirectUri: '',
  appLinkHost: '',
);

void main() {
  group('realPlatformOverrides', () {
    test('http는 다섯 로그인 provider를 실제 구현으로', () {
      final container = ProviderContainer(
        overrides: realPlatformOverrides(ApiMode.http),
      );
      addTearDown(container.dispose);
      expect(container.read(kakaoAuthProvider), isA<KakaoSdkAuth>());
      expect(container.read(lineAuthProvider), isA<LineSdkAuth>());
      expect(container.read(googleAuthProvider), isA<GoogleSdkAuth>());
      expect(
        container.read(appleNativeAuthProvider),
        isA<SignInWithAppleNativeAuth>(),
      );
      expect(container.read(appleWebAuthProvider), isA<WebAuthAppleWebAuth>());
    });

    test('Google adapter는 실행 플랫폼이 iOS인지 압니다', () {
      for (final (platform, ios) in [
        (TargetPlatform.iOS, true),
        (TargetPlatform.android, false),
      ]) {
        final container = ProviderContainer(
          overrides: [
            ...realPlatformOverrides(ApiMode.http),
            targetPlatformProvider.overrideWithValue(platform),
          ],
        );
        addTearDown(container.dispose);
        expect(
          (container.read(googleAuthProvider) as GoogleSdkAuth).isIos,
          ios,
        );
      }
    });

    test('fake는 대역', () {
      final container = ProviderContainer(
        overrides: realPlatformOverrides(ApiMode.fake),
      );
      addTearDown(container.dispose);
      expect(container.read(kakaoAuthProvider), isA<FakeKakaoAuth>());
      expect(container.read(lineAuthProvider), isA<FakeLineAuth>());
      expect(container.read(googleAuthProvider), isA<FakeGoogleAuth>());
    });
  });

  group('initializeAuthSdks', () {
    late List<String> calls;
    setUp(() => calls = []);

    Future<void> run(AuthConfig config) async {
      await initializeAuthSdks(
        config,
        initKakao: (key) async => calls.add('kakao:$key'),
        setupLine: (channelId) async => calls.add('line:$channelId'),
      );
    }

    test('설정이 있는 SDK만 초기화합니다', () async {
      await run(_config(kakao: ' k123 ', line: '1234'));
      expect(calls, ['kakao:k123', 'line:1234']);
    });

    test('설정이 비면 부르지 않습니다', () async {
      await run(_config());
      expect(calls, isEmpty);
    });

    test('한 SDK가 실패해도 다른 SDK는 초기화하고 오류를 모아 알립니다', () async {
      final error = StateError('init 실패');
      final failures = await initializeAuthSdks(
        _config(kakao: 'k', line: 'l'),
        initKakao: (_) async => throw error,
        setupLine: (channelId) async => calls.add('line:$channelId'),
      );
      expect(calls, ['line:l']);
      expect(failures.single.error, same(error));
    });
  });
}
