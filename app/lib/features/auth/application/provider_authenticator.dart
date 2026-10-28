import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/auth/model/provider_proof.dart';

export 'package:myungli_diary/features/auth/model/provider_proof.dart';

/// 제공자 인증이 끝난 결과입니다. 취소는 [SocialSignInCancelled]를 던집니다.
@immutable
sealed class ProviderAuthResult {
  const new();
}

/// 인증했고 server에 보낼 [proof]가 있습니다.
final class ProviderAuthenticated extends ProviderAuthResult {
  /// 증명을 담습니다.
  const new(this.proof);

  /// server에 보낼 증명.
  final ProviderProof proof;
}

/// Android Apple 웹 흐름의 복귀가 실패를 알렸습니다. server는 부르지 않습니다.
final class ProviderAppleWebFailed extends ProviderAuthResult {
  /// 실패 이유를 담습니다.
  const new(this.error);

  /// 실패 이유.
  final AppleWebError error;
}

/// 플랫폼에 맞는 제공자 adapter로 인증하고 [ProviderProof]로 바꿉니다.
///
/// 로그인, 붙이기, 합치기 인증이 함께 씁니다(결정 A84).
final class ProviderAuthenticator {
  /// adapter를 [_ref]에서 읽습니다.
  const new(this._ref);

  final Ref _ref;

  /// [provider]로 인증합니다. [rawNonce]의 해시는 adapter가 제공자에게 보냅니다.
  ///
  /// 사용자가 취소하면 [SocialSignInCancelled], 그 밖의 실패는 `AppError`를 던집니다.
  Future<ProviderAuthResult> authenticate(
    SocialProvider provider, {
    required String rawNonce,
  }) {
    // adapter는 첫 await 전에 읽어 호출한 쪽이 버려져도 시작한 인증이 끝나게 합니다.
    switch (provider) {
      case SocialProvider.kakao:
        final auth = _ref.read(kakaoAuthProvider);
        return _idToken(
          provider,
          rawNonce,
          () async => (await auth.signIn(rawNonce: rawNonce)).idToken,
        );
      case SocialProvider.line:
        final auth = _ref.read(lineAuthProvider);
        return _idToken(
          provider,
          rawNonce,
          () async => (await auth.signIn(rawNonce: rawNonce)).idToken,
        );
      case SocialProvider.google:
        final auth = _ref.read(googleAuthProvider);
        return auth.signIn(rawNonce: rawNonce).then((credential) {
          return ProviderAuthenticated(
            IdTokenProof(
              provider: provider,
              idToken: credential.idToken,
              rawNonce: credential.rawNonce,
            ),
          );
        });
      case SocialProvider.apple:
        return _ref.read(targetPlatformProvider) == TargetPlatform.android
            ? _appleWeb(rawNonce)
            : _appleNative(rawNonce);
    }
  }

  Future<ProviderAuthResult> _idToken(
    SocialProvider provider,
    String rawNonce,
    Future<String> Function() signIn,
  ) async => ProviderAuthenticated(
    IdTokenProof(
      provider: provider,
      idToken: await signIn(),
      rawNonce: rawNonce,
    ),
  );

  Future<ProviderAuthResult> _appleNative(String rawNonce) async {
    final credential = await _ref
        .read(appleNativeAuthProvider)
        .signIn(rawNonce: rawNonce);
    return ProviderAuthenticated(
      IdTokenProof(
        provider: SocialProvider.apple,
        idToken: credential.idToken,
        authorizationCode: credential.authorizationCode,
        rawNonce: rawNonce,
      ),
    );
  }

  Future<ProviderAuthResult> _appleWeb(String rawNonce) async {
    final result = await _ref
        .read(appleWebAuthProvider)
        .signIn(rawNonce: rawNonce);
    // 교환 코드는 일회용이라 실패해도 같은 코드로 다시 보내지 않습니다.
    return switch (result) {
      AppleWebExchange(:final exchangeCode) => ProviderAuthenticated(
        AppleWebExchangeProof(exchangeCode: exchangeCode, rawNonce: rawNonce),
      ),
      AppleWebFailure(:final error) => ProviderAppleWebFailed(error),
    };
  }
}

/// 제공자 인증.
final providerAuthenticatorProvider = Provider<ProviderAuthenticator>(
  ProviderAuthenticator.new,
);
