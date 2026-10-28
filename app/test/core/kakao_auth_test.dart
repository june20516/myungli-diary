import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/kakao_auth.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

const _raw = 'raw-nonce-0123456789';

AuthConfig _config({String key = 'kakao-key'}) => AuthConfig(
  kakaoNativeAppKey: key,
  lineChannelId: '',
  googleIosClientId: '',
  googleServerClientId: '',
  appleServicesId: '',
  appleRedirectUri: '',
  appLinkHost: '',
);

/// 부른 순서를 남기는 SDK 경계 대역.
final class _FakeKakaoApi implements KakaoLoginApi {
  bool talkInstalled = true;
  Exception? talkError;
  Exception? accountError;
  String? idToken = 'kakao-id-token';
  Exception? clearError;
  final List<String> calls = [];
  final List<String> nonces = [];

  @override
  Future<bool> isKakaoTalkInstalled() async {
    calls.add('installed');
    return talkInstalled;
  }

  @override
  Future<String?> loginWithKakaoTalk({required String nonce}) async {
    calls.add('talk');
    nonces.add(nonce);
    if (talkError case final error?) throw error;
    return idToken;
  }

  @override
  Future<String?> loginWithKakaoAccount({required String nonce}) async {
    calls.add('account');
    nonces.add(nonce);
    if (accountError case final error?) throw error;
    return idToken;
  }

  @override
  Future<void> clearTokens() async {
    calls.add('clear');
    if (clearError case final error?) throw error;
  }
}

void main() {
  late _FakeKakaoApi api;
  setUp(() => api = _FakeKakaoApi());

  KakaoSdkAuth auth({AuthConfig? config}) =>
      KakaoSdkAuth(config: config ?? _config(), api: api);

  test('카카오톡이 있으면 해시 nonce로 카카오톡 로그인', () async {
    final credential = await auth().signIn(rawNonce: _raw);
    expect(credential.idToken, 'kakao-id-token');
    expect(api.calls, ['installed', 'talk', 'clear']);
    expect(api.nonces, [hashNonce(_raw)]);
  });

  test('카카오톡 CANCELED는 SocialSignInCancelled이고 계정 로그인을 부르지 않습니다', () async {
    api.talkError = PlatformException(code: 'CANCELED');
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<SocialSignInCancelled>()),
    );
    expect(api.calls, ['installed', 'talk']);
  });

  test('카카오톡 그 밖의 실패는 계정 로그인으로 넘어갑니다', () async {
    api.talkError = PlatformException(code: 'NotSupportError');
    final credential = await auth().signIn(rawNonce: _raw);
    expect(credential.idToken, 'kakao-id-token');
    expect(api.calls, ['installed', 'talk', 'account', 'clear']);
    expect(api.nonces, [hashNonce(_raw), hashNonce(_raw)]);
  });

  test('카카오톡이 없으면 바로 계정 로그인', () async {
    api.talkInstalled = false;
    await auth().signIn(rawNonce: _raw);
    expect(api.calls, ['installed', 'account', 'clear']);
  });

  test('계정 로그인 CANCELED는 SocialSignInCancelled', () async {
    api
      ..talkInstalled = false
      ..accountError = PlatformException(code: 'CANCELED');
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<SocialSignInCancelled>()),
    );
  });

  test('계정 로그인 그 밖의 오류는 그대로 던집니다', () async {
    final error = PlatformException(code: 'NetworkError');
    api
      ..talkInstalled = false
      ..accountError = error;
    await expectLater(auth().signIn(rawNonce: _raw), throwsA(same(error)));
  });

  test('idToken이 없으면 StateError', () async {
    api.idToken = null;
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<StateError>()),
    );
  });

  test('성공 뒤 토큰을 지우고, 지우기 실패해도 credential을 돌려줍니다', () async {
    api.clearError = Exception('저장소 오류');
    final credential = await auth().signIn(rawNonce: _raw);
    expect(credential.idToken, 'kakao-id-token');
    expect(api.calls.last, 'clear');
  });

  test('설정이 없으면 ProviderNotConfigured이고 SDK를 부르지 않습니다', () async {
    await expectLater(
      auth(config: _config(key: '')).signIn(rawNonce: _raw),
      throwsA(
        isA<ProviderNotConfigured>().having(
          (e) => e.provider,
          'provider',
          SocialProvider.kakao,
        ),
      ),
    );
    expect(api.calls, isEmpty);
  });
}
