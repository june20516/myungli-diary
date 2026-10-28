import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/apple_native_auth.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _raw = 'raw-nonce-0123456789';

/// 받은 nonce를 남기는 SDK 경계 대역.
final class _FakeAppleApi implements AppleIdCredentialApi {
  final List<String> nonces = [];
  Exception? error;
  String? identityToken = 'apple-identity-token';

  @override
  Future<({String? identityToken, String authorizationCode})> getCredential({
    required String nonce,
  }) async {
    nonces.add(nonce);
    if (error case final error?) throw error;
    return (identityToken: identityToken, authorizationCode: 'apple-code');
  }
}

void main() {
  late _FakeAppleApi api;
  setUp(() => api = _FakeAppleApi());

  SignInWithAppleNativeAuth auth() => SignInWithAppleNativeAuth(api: api);

  test('해시 nonce로 요청하고 authorizationCode를 credential에 담습니다', () async {
    final credential = await auth().signIn(rawNonce: _raw);
    expect(api.nonces, [hashNonce(_raw)]);
    expect(credential.idToken, 'apple-identity-token');
    expect(credential.authorizationCode, 'apple-code');
  });

  test('canceled는 SocialSignInCancelled', () async {
    api.error = const SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.canceled,
      message: '',
    );
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<SocialSignInCancelled>()),
    );
  });

  test('그 밖의 오류는 그대로', () async {
    final error = PlatformException(code: 'unknown');
    api.error = error;
    await expectLater(auth().signIn(rawNonce: _raw), throwsA(same(error)));
  });

  test('identityToken이 없으면 StateError', () async {
    api.identityToken = null;
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<StateError>()),
    );
  });
}
