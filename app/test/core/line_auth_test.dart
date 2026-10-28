import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/line_auth.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

const _raw = 'raw-nonce-0123456789';

AuthConfig _config({String channelId = '1234567890'}) => AuthConfig(
  kakaoNativeAppKey: '',
  lineChannelId: channelId,
  googleIosClientId: '',
  googleServerClientId: '',
  appleServicesId: '',
  appleRedirectUri: '',
  appLinkHost: '',
);

/// 부른 순서를 남기는 SDK 경계 대역.
final class _FakeLineApi implements LineLoginApi {
  Exception? loginError;
  String? idToken = 'line-id-token';
  Exception? logoutError;
  final List<String> calls = [];
  final List<String> nonces = [];

  @override
  Future<String?> login({required String nonce}) async {
    calls.add('login');
    nonces.add(nonce);
    if (loginError case final error?) throw error;
    return idToken;
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    if (logoutError case final error?) throw error;
  }
}

void main() {
  late _FakeLineApi api;
  setUp(() => api = _FakeLineApi());

  LineSdkAuth auth({AuthConfig? config}) =>
      LineSdkAuth(config: config ?? _config(), api: api);

  test('해시 nonce로 로그인', () async {
    final credential = await auth().signIn(rawNonce: _raw);
    expect(credential.idToken, 'line-id-token');
    expect(api.nonces, [hashNonce(_raw)]);
    expect(api.calls, ['login', 'logout']);
  });

  test('PlatformException CANCEL은 SocialSignInCancelled', () async {
    api.loginError = PlatformException(code: 'CANCEL');
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<SocialSignInCancelled>()),
    );
    expect(api.calls, ['login']);
  });

  test('그 밖의 오류는 그대로', () async {
    final error = PlatformException(code: 'NETWORK_ERROR');
    api.loginError = error;
    await expectLater(auth().signIn(rawNonce: _raw), throwsA(same(error)));
  });

  test('idTokenRaw가 없으면 StateError', () async {
    api.idToken = null;
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<StateError>()),
    );
  });

  test('성공 뒤 logout, 실패해도 성공', () async {
    api.logoutError = PlatformException(code: 'NETWORK_ERROR');
    final credential = await auth().signIn(rawNonce: _raw);
    expect(credential.idToken, 'line-id-token');
    expect(api.calls, ['login', 'logout']);
  });

  test('설정이 없으면 ProviderNotConfigured', () async {
    await expectLater(
      auth(config: _config(channelId: '')).signIn(rawNonce: _raw),
      throwsA(
        isA<ProviderNotConfigured>().having(
          (e) => e.provider,
          'provider',
          SocialProvider.line,
        ),
      ),
    );
    expect(api.calls, isEmpty);
  });
}
