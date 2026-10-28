import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/apple_web_auth.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

const _raw = 'raw-nonce-0123456789';
const _servicesId = 'app.myungli.diary.web';
const _redirect = 'https://api.example.com/v1/auth/apple/callback';
const _host = 'link.example.com';
const _exchange = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';

AuthConfig _config({
  String servicesId = _servicesId,
  String redirect = _redirect,
  String host = _host,
}) => AuthConfig(
  kakaoNativeAppKey: '',
  lineChannelId: '',
  googleIosClientId: '',
  googleServerClientId: '',
  appleServicesId: servicesId,
  appleRedirectUri: redirect,
  appLinkHost: host,
);

/// 브라우저 대역. 연 주소와 옵션을 남기고, [reply]로 복귀 주소를 만듭니다.
final class _FakeBrowser {
  final List<({Uri url, String httpsHost, String httpsPath})> opened = [];
  String Function(Uri url) reply = (url) =>
      'https://$_host/auth/apple?exchange=$_exchange'
      '&state=${url.queryParameters['state']}';
  Exception? error;

  Future<String> authenticate({
    required Uri url,
    required String httpsHost,
    required String httpsPath,
  }) async {
    opened.add((url: url, httpsHost: httpsHost, httpsPath: httpsPath));
    if (error case final error?) throw error;
    return reply(url);
  }
}

void main() {
  late _FakeBrowser browser;
  setUp(() => browser = _FakeBrowser());

  WebAuthAppleWebAuth auth({AuthConfig? config}) => WebAuthAppleWebAuth(
    config: config ?? _config(),
    nonces: NonceGenerator(),
    authenticate: browser.authenticate,
  );

  test('authorize URL에 Services ID, redirect_uri, 해시 nonce, state', () async {
    await auth().signIn(rawNonce: _raw);
    final url = browser.opened.single.url;
    expect(url.host, 'appleid.apple.com');
    expect(url.queryParameters['client_id'], _servicesId);
    expect(url.queryParameters['redirect_uri'], _redirect);
    expect(url.queryParameters['nonce'], hashNonce(_raw));
    expect(
      url.queryParameters['state']!.length,
      greaterThanOrEqualTo(NonceGenerator.minLength),
    );
  });

  test('httpsHost는 APP_LINK_HOST, httpsPath는 /auth/apple', () async {
    await auth().signIn(rawNonce: _raw);
    expect(browser.opened.single.httpsHost, _host);
    expect(browser.opened.single.httpsPath, '/auth/apple');
  });

  test('복귀 결과를 parseAppleWebReturn으로 해석(교환 코드)', () async {
    expect(
      await auth().signIn(rawNonce: _raw),
      const AppleWebExchange(_exchange),
    );
  });

  test('state가 다르면 AppleWebFailure(stateMismatch)', () async {
    browser.reply = (_) =>
        'https://$_host/auth/apple?exchange=$_exchange&state=forged-state';
    expect(
      await auth().signIn(rawNonce: _raw),
      const AppleWebFailure(AppleWebError.stateMismatch),
    );
  });

  test('CANCELED는 AppleWebFailure(userCancelled)', () async {
    browser.error = PlatformException(code: 'CANCELED');
    expect(
      await auth().signIn(rawNonce: _raw),
      const AppleWebFailure(AppleWebError.userCancelled),
    );
  });

  test('그 밖의 PlatformException은 그대로', () async {
    final error = PlatformException(code: 'EUNKNOWN');
    browser.error = error;
    await expectLater(auth().signIn(rawNonce: _raw), throwsA(same(error)));
  });

  test('설정 셋 중 하나라도 비면 ProviderNotConfigured이고 브라우저를 열지 않습니다', () async {
    final notConfigured = isA<ProviderNotConfigured>().having(
      (e) => e.provider,
      'provider',
      SocialProvider.apple,
    );
    for (final config in [
      _config(servicesId: ''),
      _config(redirect: ''),
      _config(host: ''),
    ]) {
      await expectLater(
        auth(config: config).signIn(rawNonce: _raw),
        throwsA(notConfigured),
      );
    }
    expect(browser.opened, isEmpty);
  });
}
