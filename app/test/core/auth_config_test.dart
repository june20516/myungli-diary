import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';

AuthConfig _with({
  String kakaoNativeAppKey = '',
  String lineChannelId = '',
  String googleIosClientId = '',
  String googleServerClientId = '',
  String appleServicesId = '',
  String appleRedirectUri = '',
  String appLinkHost = '',
}) => AuthConfig(
  kakaoNativeAppKey: kakaoNativeAppKey,
  lineChannelId: lineChannelId,
  googleIosClientId: googleIosClientId,
  googleServerClientId: googleServerClientId,
  appleServicesId: appleServicesId,
  appleRedirectUri: appleRedirectUri,
  appLinkHost: appLinkHost,
);

void main() {
  test('AuthConfig 빈 값은 모든 제공자가 설정 안 됨', () {
    expect(_with().isKakaoConfigured, isFalse);
    expect(_with().isLineConfigured, isFalse);
    expect(_with().isGoogleConfigured(ios: false), isFalse);
    expect(_with().isGoogleConfigured(ios: true), isFalse);
    expect(_with().isAppleWebConfigured, isFalse);
  });

  test('공백뿐인 값은 빈 값으로 봅니다', () {
    expect(_with(kakaoNativeAppKey: '  ').isKakaoConfigured, isFalse);
    expect(_with(lineChannelId: ' ').isLineConfigured, isFalse);
  });

  test('값이 있으면 그 제공자는 설정됨', () {
    expect(_with(kakaoNativeAppKey: 'abc').isKakaoConfigured, isTrue);
    expect(_with(lineChannelId: '1234').isLineConfigured, isTrue);
  });

  test('isGoogleConfigured는 ios면 iOS client id도 봅니다', () {
    final serverOnly = _with(
      googleServerClientId: 'web.apps.googleusercontent.com',
    );
    expect(serverOnly.isGoogleConfigured(ios: false), isTrue);
    expect(serverOnly.isGoogleConfigured(ios: true), isFalse);
    final both = _with(
      googleServerClientId: 'web.apps.googleusercontent.com',
      googleIosClientId: 'ios.apps.googleusercontent.com',
    );
    expect(both.isGoogleConfigured(ios: true), isTrue);
    final iosOnly = _with(googleIosClientId: 'ios.apps.googleusercontent.com');
    expect(iosOnly.isGoogleConfigured(ios: true), isFalse);
  });

  test('isAppleWebConfigured는 셋 중 하나라도 비면 false', () {
    const servicesId = 'app.myungli.diary.web';
    const redirect = 'https://api.example.com/v1/auth/apple/callback';
    const host = 'link.example.com';
    expect(
      _with(
        appleServicesId: servicesId,
        appleRedirectUri: redirect,
        appLinkHost: host,
      ).isAppleWebConfigured,
      isTrue,
    );
    expect(
      _with(appleRedirectUri: redirect, appLinkHost: host).isAppleWebConfigured,
      isFalse,
    );
    expect(
      _with(
        appleServicesId: servicesId,
        appLinkHost: host,
      ).isAppleWebConfigured,
      isFalse,
    );
    expect(
      _with(
        appleServicesId: servicesId,
        appleRedirectUri: redirect,
      ).isAppleWebConfigured,
      isFalse,
    );
  });

  test('빌드에 값을 넘기지 않으면 fromEnvironment는 모두 빈 값입니다', () {
    expect(AuthConfig.fromEnvironment.isKakaoConfigured, isFalse);
    expect(AuthConfig.fromEnvironment.isAppleWebConfigured, isFalse);
  });
}
