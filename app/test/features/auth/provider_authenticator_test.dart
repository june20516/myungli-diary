import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/auth/application/provider_authenticator.dart';

const _rawNonce = 'raw-nonce-0123456789abcdef012345';

ProviderContainer _container({
  TargetPlatform platform = TargetPlatform.android,
  FakeKakaoAuth? kakao,
  FakeAppleNativeAuth? appleNative,
  FakeAppleWebAuth? appleWeb,
}) {
  final container = ProviderContainer(
    overrides: [
      targetPlatformProvider.overrideWithValue(platform),
      kakaoAuthProvider.overrideWithValue(kakao ?? FakeKakaoAuth()),
      appleNativeAuthProvider.overrideWithValue(
        appleNative ?? FakeAppleNativeAuth(),
      ),
      appleWebAuthProvider.overrideWithValue(appleWeb ?? FakeAppleWebAuth()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ProviderAuthResult> _authenticate(
  ProviderContainer container,
  SocialProvider provider,
) => container
    .read(providerAuthenticatorProvider)
    .authenticate(provider, rawNonce: _rawNonce);

void main() {
  group('ProviderAuthenticator', () {
    test('apple은 Android면 웹 adapter를 씁니다', () async {
      final web = FakeAppleWebAuth();
      final native = FakeAppleNativeAuth();
      final container = _container(appleWeb: web, appleNative: native);

      final result = await _authenticate(container, SocialProvider.apple);

      final proof = (result as ProviderAuthenticated).proof;
      expect(proof, isA<AppleWebExchangeProof>());
      expect(web.openedUris, hasLength(1));
      expect(native.providerNonces, isEmpty);
    });

    test('apple은 iOS면 네이티브 adapter를 씁니다', () async {
      final web = FakeAppleWebAuth();
      final native = FakeAppleNativeAuth();
      final container = _container(
        platform: TargetPlatform.iOS,
        appleWeb: web,
        appleNative: native,
      );

      final result = await _authenticate(container, SocialProvider.apple);

      final proof = (result as ProviderAuthenticated).proof as IdTokenProof;
      expect(proof.provider, SocialProvider.apple);
      expect(proof.idToken, 'fake-apple-id-token');
      expect(proof.authorizationCode, 'fake-apple-authorization-code');
      expect(proof.rawNonce, _rawNonce);
      expect(native.providerNonces.single, hashNonce(_rawNonce));
      expect(web.openedUris, isEmpty);
    });

    test('카카오 credential은 같은 rawNonce의 IdTokenProof입니다', () async {
      final container = _container();

      final result = await _authenticate(container, SocialProvider.kakao);

      final proof = (result as ProviderAuthenticated).proof as IdTokenProof;
      expect(proof.provider, SocialProvider.kakao);
      expect(proof.idToken, 'fake-kakao-id-token');
      expect(proof.rawNonce, _rawNonce);
      expect(proof.authorizationCode, isNull);
    });

    test('LINE credential은 같은 rawNonce의 IdTokenProof입니다', () async {
      final container = _container();

      final result = await _authenticate(container, SocialProvider.line);

      final proof = (result as ProviderAuthenticated).proof as IdTokenProof;
      expect(proof.provider, SocialProvider.line);
      expect(proof.idToken, 'fake-line-id-token');
      expect(proof.rawNonce, _rawNonce);
    });

    test('Google은 credential의 rawNonce를 proof에 넣습니다', () async {
      final container = ProviderContainer(
        overrides: [
          googleAuthProvider.overrideWithValue(_SdkNonceGoogleAuth()),
        ],
      );
      addTearDown(container.dispose);

      final result = await _authenticate(container, SocialProvider.google);

      final proof = (result as ProviderAuthenticated).proof as IdTokenProof;
      expect(proof.provider, SocialProvider.google);
      expect(proof.idToken, 'google-id-token');
      expect(proof.rawNonce, 'nonce-from-sdk');
    });

    test('Apple 웹 교환은 AppleWebExchangeProof입니다', () async {
      final container = _container();

      final result = await _authenticate(container, SocialProvider.apple);

      final proof =
          (result as ProviderAuthenticated).proof as AppleWebExchangeProof;
      expect(proof.provider, SocialProvider.apple);
      expect(proof.exchangeCode, FakeAppleWebAuth.fakeAppleExchangeCode);
      expect(proof.rawNonce, _rawNonce);
    });

    test('Apple 웹 실패는 ProviderAppleWebFailed입니다', () async {
      final container = _container(
        appleWeb: FakeAppleWebAuth(returnedState: 'forged'),
      );

      final result = await _authenticate(container, SocialProvider.apple);

      expect(
        (result as ProviderAppleWebFailed).error,
        AppleWebError.stateMismatch,
      );
    });

    test('취소는 SocialSignInCancelled를 그대로 던집니다', () async {
      final container = _container(
        kakao: FakeKakaoAuth(failWith: const SocialSignInCancelled()),
      );

      await expectLater(
        _authenticate(container, SocialProvider.kakao),
        throwsA(isA<SocialSignInCancelled>()),
      );
    });
  });
}

/// SDK가 만든 nonce 원문을 돌려주는 Google 대역.
final class _SdkNonceGoogleAuth implements GoogleAuth {
  @override
  Future<GoogleCredential> signIn({required String rawNonce}) async =>
      const GoogleCredential(
        idToken: 'google-id-token',
        rawNonce: 'nonce-from-sdk',
      );
}
