@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/common/native_auth_config.dart';

/// `config/auth.json`(A81)과 네이티브 설정(Android manifest, iOS xcconfig·Info.plist)이
/// 같은 자리를 가리키는지 확인합니다.
void main() {
  test('Auth.xcconfig는 auth.json에서 생성한 내용과 같습니다', () {
    final config = readAuthConfigJson(File(authConfigPath));
    expect(
      File(authXcconfigPath).readAsStringSync(),
      renderAuthXcconfig(config),
    );
  });

  test('빈 GOOGLE_IOS_CLIENT_ID는 google-unconfigured', () {
    expect(googleReversedClientId(''), 'google-unconfigured');
    expect(googleReversedClientId('  '), 'google-unconfigured');
  });

  test('채운 GOOGLE_IOS_CLIENT_ID는 reversed client id', () {
    expect(
      googleReversedClientId('123-abc.apps.googleusercontent.com'),
      'com.googleusercontent.apps.123-abc',
    );
  });

  test('빈 카카오 키는 URL scheme이 kakao-unconfigured가 되게 채웁니다', () {
    expect(
      renderAuthXcconfig(const {'KAKAO_NATIVE_APP_KEY': ''}),
      contains('KAKAO_NATIVE_APP_KEY=-unconfigured\n'),
    );
  });

  test('xcconfig는 카카오 키와 Google reversed client id를 담습니다', () {
    final rendered = renderAuthXcconfig(const {
      'KAKAO_NATIVE_APP_KEY': 'k123',
      'GOOGLE_IOS_CLIENT_ID': '123-abc.apps.googleusercontent.com',
    });
    expect(rendered, contains('KAKAO_NATIVE_APP_KEY=k123\n'));
    expect(
      rendered,
      contains(
        'GOOGLE_REVERSED_CLIENT_ID=com.googleusercontent.apps.123-abc\n',
      ),
    );
  });

  test('AndroidManifest에 카카오 AuthCodeHandlerActivity, CallbackActivity /auth/apple, '
      'queries 두 패키지가 있습니다', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest,
      contains('com.kakao.sdk.flutter.auth.AuthCodeHandlerActivity'),
    );
    expect(manifest, contains(r'android:scheme="${kakaoScheme}"'));
    expect(manifest, contains('android:host="oauth"'));
    expect(
      manifest,
      contains('com.linusu.flutter_web_auth_2.CallbackActivity'),
    );
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains(r'android:host="${appLinkHost}"'));
    expect(manifest, contains('android:path="/auth/apple"'));
    expect(manifest, contains('<package android:name="com.kakao.talk"'));
    expect(manifest, contains('<package android:name="jp.naver.line.android"'));
  });

  test('Info.plist에 URL scheme 셋과 조회 scheme이 있습니다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains(r'kakao$(KAKAO_NATIVE_APP_KEY)'));
    expect(plist, contains(r'line3rdp.$(PRODUCT_BUNDLE_IDENTIFIER)'));
    expect(plist, contains(r'$(GOOGLE_REVERSED_CLIENT_ID)'));
    for (final scheme in ['kakaokompassauth', 'kakaolink', 'lineauth2']) {
      expect(plist, contains('<string>$scheme</string>'));
    }
  });

  test('Debug·Release xcconfig가 Auth.xcconfig를 포함합니다', () {
    for (final name in ['Debug', 'Release']) {
      expect(
        File('ios/Flutter/$name.xcconfig').readAsStringSync(),
        contains('#include "Auth.xcconfig"'),
      );
    }
  });

  test('LINE iOS SDK는 5.16.0으로 고정합니다(5.17.0부터 iOS 15, 플러그인 패키지는 13, A92)', () {
    for (final path in [
      'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
      'ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
    ]) {
      final pins =
          (jsonDecode(File(path).readAsStringSync())
                  as Map<String, Object?>)['pins']!
              as List<Object?>;
      final line = pins.cast<Map<String, Object?>>().singleWhere(
        (pin) => pin['identity'] == 'line-sdk-ios-swift',
      );
      expect((line['state']! as Map<String, Object?>)['version'], '5.16.0');
    }
  });

  test('Runner는 Sign in with Apple entitlement를 씁니다', () {
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('com.apple.developer.applesignin'),
    );
    expect(
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
  });
}
